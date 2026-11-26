-- A tiny stand-in for the game client, just big enough to load Campfire
-- Tales (and Krump and Juju beside it) and push chat messages through it the
-- way the real chat box does. It started as a copy of Krump's own, so that
-- Krump and Juju load in it unchanged.
--
-- The chat box here follows the same order of steps as the game's own
-- ChatFrameEditBoxBaseMixin:SendText: work out slash commands, announce
-- "ChatFrame.OnEditBoxPreSendText", then read the text and send it.

local Mock = {}

local function noop() end

local function widget(methods)
	local object = {}
	for _, name in ipairs(methods) do
		object[name] = noop
	end
	return object
end

-- Chat-type slash commands the fake chat box understands.
local CHAT_COMMANDS = {
	["/s"] = "SAY", ["/say"] = "SAY",
	["/y"] = "YELL", ["/yell"] = "YELL",
	["/e"] = "EMOTE", ["/me"] = "EMOTE", ["/emote"] = "EMOTE",
	["/p"] = "PARTY", ["/party"] = "PARTY",
	["/raid"] = "RAID", ["/rw"] = "RAID_WARNING",
	["/g"] = "GUILD", ["/guild"] = "GUILD", ["/o"] = "OFFICER",
}

-- Mock.new{ race = "Orc", name = "Grokk", target = nil, saved = {...},
--           zone = "Durotar", subzone = "Razor Hill", hour = 20 }
function Mock.new(config)
	config = config or {}
	local game = {
		sent = {},        -- every chat message that left the client
		printed = {},     -- every line an addon printed to the chat window
		settings = {},    -- settings panel entries, by variable name
		frames = {},      -- frames created by the addon
		target = config.target,
		openedCategory = nil,
		now = 1000,       -- what GetTime says
		auras = {},       -- the player's buffs, by name: { name, duration, expirationTime }
		opened = {},      -- every text put in the chat line, in order
		tooltip = {},     -- the lines of the tooltip on show
	}

	local env = setmetatable({}, { __index = _G })
	game.env = env
	env._G = env

	-- string and table helpers the game provides as globals
	env.strmatch, env.strlower, env.strupper, env.strsub = string.match, string.lower, string.upper, string.sub
	env.strfind = string.find
	env.format = string.format
	env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

	-- saved variables, as if read back from disk
	for name, value in pairs(config.saved or {}) do
		env[name] = value
	end

	-- units
	-- config.sex: 2 male, 3 female, as the game's UnitSex returns
	env.UnitSex = function(unit)
		if unit == "player" then
			return config.sex or 2
		end
	end
	env.UnitRace = function(unit)
		if unit == "player" then
			local race = config.race or "Orc"
			return race, race
		end
	end
	-- creatures and other units: game.units[token] = { name = "Hogger",
	-- player = false, pet = false, hostile = true }
	game.units = {}
	env.UnitExists = function(unit) return game.units[unit] ~= nil end
	env.UnitIsPlayer = function(unit)
		if game.units[unit] then
			return game.units[unit].player == true
		end
		-- game.target, a plain name, is a player you have targeted
		return unit == "target" and game.target ~= nil
	end
	env.UnitPlayerControlled = function(unit) return game.units[unit] ~= nil and game.units[unit].pet == true end
	env.UnitCanAttack = function(_, unit) return game.units[unit] ~= nil and game.units[unit].hostile == true end
	env.UnitIsUnit = function(a, b) return a == b end
	local unitExists = env.UnitExists
	env.UnitExists = function(unit) return unitExists(unit) or (unit == "target" and game.target ~= nil) end

	-- messages sent by addon code: emotes
	env.C_ChatInfo = { SendChatMessage = function(text, chatType, _, target)
		if game.blockSending then
			error("blocked")
		end
		game.sent[#game.sent + 1] = { text = text, chatType = chatType, target = target }
	end }

	-- guild, friends and Battle.net friends: config.guild, config.friends,
	-- config.battlenet = lists of names
	env.IsInGuild = function() return config.guild ~= nil end
	env.GetNumGuildMembers = function() return config.guild and #config.guild or 0 end
	env.GetGuildRosterInfo = function(index) return config.guild[index] end
	env.C_GuildInfo = { GuildRoster = function() game.rosterRequested = true end }
	env.C_FriendList = {
		GetNumFriends = function() return config.friends and #config.friends or 0 end,
		GetFriendInfoByIndex = function(index) return { name = config.friends[index] } end,
	}
	env.BNGetNumFriends = function() return config.battlenet and #config.battlenet or 0 end
	env.C_BattleNet = {
		GetFriendNumGameAccounts = function() return 1 end,
		GetFriendGameAccountInfo = function(friend)
			local entry = config.battlenet[friend]
			return { clientProgram = entry.program or "WoW", characterName = entry.name }
		end,
	}
	env.UnitName = function(unit)
		if game.units[unit] then
			return game.units[unit].name
		elseif unit == "player" then
			return config.name or "Grokk"
		elseif unit == "target" then
			return game.target
		elseif config.group then
			local index = tonumber(string.match(unit, "^party(%d+)$"))
			return index and config.group[index]
		end
	end
	-- numbered channels: config.channels = { [1] = "General - Durotar", ... }
	env.GetChannelName = function(id)
		id = tonumber(id) or 0
		local name = config.channels and config.channels[id]
		if name then
			return id, name
		end
		return 0, nil
	end
	env.GetNumGroupMembers = function() return config.group and #config.group + 1 or 0 end
	env.IsInRaid = function() return false end

	-- chat window
	env.DEFAULT_CHAT_FRAME = {
		AddMessage = function(_, message) game.printed[#game.printed + 1] = message end,
	}
	env.SlashCmdList = {}
	-- opening the chat line with text in it: see game:chatLine below
	env.ChatFrameUtil = { OpenChat = function(text) game:openChat(text) end }
	-- the tooltip keeps its lines, for tests: game.tooltip
	env.GameTooltip = {
		SetOwner = function(_, owner) game.tooltip = {} game.tooltipOwner = owner end,
		AddLine = function(_, line) game.tooltip[#game.tooltip + 1] = line end,
		Show = function() game.tooltipShown = true end,
		Hide = function() game.tooltipShown = false end,
	}

	-- time, place and the player's buffs
	env.GetTime = function() return game.now end
	env.GetZoneText = function() return config.zone or "" end
	env.GetSubZoneText = function() return config.subzone or "" end
	env.GetGameTime = function() return config.hour or 20, 0 end
	-- config.auraApi: "byName" (the default), "byIndex" or "unitBuff"
	local auraApi = config.auraApi or "byName"
	local function auraList()
		local list = {}
		for _, aura in pairs(game.auras) do
			list[#list + 1] = aura
		end
		table.sort(list, function(a, b) return a.name < b.name end)
		return list
	end
	if auraApi == "byName" then
		env.C_UnitAuras = { GetAuraDataBySpellName = function(unit, name, filter)
			assert(filter == "HELPFUL", "buffs are HELPFUL")
			if unit == "player" then
				return game.auras[name]
			end
		end }
	elseif auraApi == "byIndex" then
		env.C_UnitAuras = { GetAuraDataByIndex = function(unit, index)
			if unit == "player" then
				return auraList()[index]
			end
		end }
	elseif auraApi == "unitBuff" then
		env.UnitBuff = function(unit, index)
			local aura = unit == "player" and auraList()[index]
			if aura then
				return aura.name, nil, 0, nil, aura.duration, aura.expirationTime
			end
		end
	end
	function game:addAura(name, duration)
		self.auras[name] = { name = name, duration = duration or 0,
			expirationTime = duration and self.now + duration or 0 }
		self:fire("UNIT_AURA", "player")
	end
	function game:removeAura(name)
		self.auras[name] = nil
		self:fire("UNIT_AURA", "player")
	end
	-- the screen: 1920 by 1080, at scale 1
	env.UIParent = {
		GetEffectiveScale = function() return 1 end,
		GetWidth = function() return 1920 end,
		GetHeight = function() return 1080 end,
	}
	-- where the mouse is, in screen pixels: set game.cursor = { x, y }
	env.GetCursorPosition = function()
		local cursor = game.cursor or { 0, 0 }
		return cursor[1], cursor[2]
	end
	env.UISpecialFrames = {}
	env.ChatFontNormal = {}

	-- Timers run when the test says a frame has passed (game:nextFrame), or
	-- when it lets time go by (game:wait). A timer runs once its time is up.
	local timers = {}
	env.C_Timer = { After = function(delay, func)
		timers[#timers + 1] = { due = game.now + (tonumber(delay) or 0), func = func }
	end }
	local function runDue()
		local ran = true
		while ran do
			ran = false
			for index, timer in ipairs(timers) do
				if timer.due <= game.now then
					table.remove(timers, index)
					timer.func()
					ran = true
					break
				end
			end
		end
	end
	function game:nextFrame()
		runDue()
	end
	-- Lets seconds go by: due timers run, and every frame on show gets
	-- its OnUpdate.
	function game:wait(seconds)
		self.now = self.now + seconds
		runDue()
		for _, frame in ipairs(self.frames) do
			if frame.scripts.OnUpdate and frame:IsVisible() then
				frame.scripts.OnUpdate(frame, seconds)
			end
		end
	end

	-- the game's callback registry
	local callbacks = {}
	env.EventRegistry = {
		RegisterCallback = function(_, event, func, owner)
			assert(type(event) == "string" and type(func) == "function", "bad RegisterCallback arguments")
			assert(owner ~= nil and type(owner) ~= "number", "callback owner must be a non-number value")
			callbacks[event] = callbacks[event] or {}
			callbacks[event][owner] = func
		end,
		TriggerEvent = function(_, event, ...)
			for owner, func in pairs(callbacks[event] or {}) do
				func(owner, ...)
			end
		end,
	}
	game.callbacks = callbacks

	-- frames
	local function region(methods)
		local object = widget({ "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "AddMaskTexture" })
		object.shown = true
		-- the last point set, for tests: { point, relativeTo, relativePoint, x, y }
		function object:SetPoint(...) self.point = { ... } end
		function object:ClearAllPoints() self.point = nil end
		-- where it is on screen: set .center = { x, y } to give it one
		function object:GetCenter()
			if self.center then
				return self.center[1], self.center[2]
			end
		end
		function object:GetEffectiveScale() return 1 end
		function object:Show() self.shown = true end
		function object:Hide() self.shown = false end
		function object:SetShown(shown) self.shown = shown and true or false end
		function object:IsShown() return self.shown end
		for _, name in ipairs(methods) do
			object[name] = noop
		end
		return object
	end

	-- frame type names are not case-sensitive in the game
	local FRAME_TYPES = { frame = "Frame", editbox = "EditBox", button = "Button", eventframe = "Frame" }

	env.CreateFrame = function(frameType, name, parent, template)
		frameType = FRAME_TYPES[string.lower(tostring(frameType))]
			or error("mock does not know frame type " .. tostring(frameType))
		local frame = region({
			"SetFrameStrata", "SetToplevel", "SetClampedToScreen", "EnableMouse", "SetHyperlinksEnabled",
			"SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetHighlightTexture",
		})
		-- set .mouseOver = true to have the mouse over it
		function frame:IsMouseOver() return self.mouseOver == true end
		function frame:CreateMaskTexture()
			return region({ "SetTexture" })
		end
		frame.events, frame.scripts, frame.shown = {}, {}, true
		frame.fontStrings = {}
		frame.name, frame.frameType, frame.parent, frame.template = name, frameType, parent, template
		function frame:RegisterEvent(event) self.events[event] = true end
		function frame:UnregisterEvent(event) self.events[event] = nil end
		function frame:SetScript(script, handler) self.scripts[script] = handler end
		function frame:run(script, ...)
			if self.scripts[script] then
				return self.scripts[script](self, ...)
			end
		end
		function frame:Show()
			if not self.shown then
				self.shown = true
				self:run("OnShow")
			end
		end
		function frame:Hide()
			if self.shown then
				self.shown = false
				self:run("OnHide")
			end
		end
		function frame:IsShown() return self.shown end
		function frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
		-- shown on screen: this frame and every frame it sits in
		function frame:IsVisible()
			local at = self
			while at do
				if at.shown == false then
					return false
				end
				at = at.parent
			end
			return true
		end
		function frame:GetWidth() return 400 end
		function frame:CreateTexture()
			local texture = region({ "SetColorTexture", "SetAtlas", "SetBlendMode", "SetAlpha", "SetVertexColor" })
			function texture:SetTexture(path) self.texture = path end
			return texture
		end
		function frame:CreateFontString()
			local fontString = region({ "SetJustifyH", "SetJustifyV", "SetWordWrap" })
			function fontString:SetTextColor(r, g, b) self.color = { r, g, b } end
			function fontString:SetText(text) self.text = text end
			function fontString:GetText() return self.text end
			-- Wraps at its width (about 6 pixels a letter), 14 pixels a row.
			function fontString:SetWidth(width) self.width = width end
			function fontString:GetStringHeight()
				local plain = (self.text and tostring(self.text) or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
				if not self.width or self.width <= 0 then
					return 14
				end
				return 14 * math.max(1, math.ceil(#plain * 6 / self.width))
			end
			function fontString:GetStringWidth() return 7 * #(self.text or "") end
			frame.fontString = fontString
			frame.fontStrings[#frame.fontStrings + 1] = fontString
			return fontString
		end

		if frameType == "EditBox" then
			for _, method in ipairs({ "SetFontObject", "SetAutoFocus", "SetMaxLetters", "SetTextInsets", "HighlightText" }) do
				frame[method] = noop
			end
			frame.text, frame.focus = "", false
			function frame:GetText() return self.text end
			function frame:SetText(text)
				self.text = text
				self:run("OnTextChanged", false)
			end
			function frame:SetFocus() game.focus = self end
			function frame:ClearFocus() if game.focus == self then game.focus = nil end end
			function frame:HasFocus() return game.focus == self end
			-- the player typing: the text changes with userInput = true
			function frame:userType(text)
				game.focus = self
				self.text = text
				self:run("OnTextChanged", true)
			end
		elseif frameType == "Button" then
			function frame:SetText(text) self.text = text end
			function frame:GetText() return self.text end
			function frame:RegisterForClicks() end
			function frame:LockHighlight() self.locked = true end
			function frame:UnlockHighlight() self.locked = false end
			frame.enabled = true
			function frame:SetEnabled(enabled) self.enabled = enabled and true or false end
			function frame:IsEnabled() return self.enabled end
			-- a disabled or hidden button ignores clicks, as in the game
			function frame:click(mouseButton)
				if self.enabled and self.shown then
					self:run("OnClick", mouseButton or "LeftButton")
				end
			end
		end

		function frame:GetParent() return self.parent end
		function frame:SetID(id) self.id = id end
		function frame:GetID() return self.id end

		-- the parts of Blizzard's templates that Krump uses
		if template == "ButtonFrameTemplate" then
			frame.NineSlice = {}
			frame.Inset = env.CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
			frame.CloseButton = env.CreateFrame("Button", nil, frame, "UIPanelCloseButton")
			function frame:SetTitle(title) self.title = title end
			function frame:SetPortraitToAsset(texture) self.portraitTexture = texture end
		elseif template == "InsetFrameTemplate" or template == "TooltipBackdropTemplate" then
			frame.NineSlice = {}
		elseif template == "WowScrollBoxList" then
			-- a list with every row made at once (the real one makes only
			-- the rows in view, and reuses them as it scrolls)
			frame.rows = {}
			function frame:SetDataProvider(provider)
				local items = provider.items
				for index, item in ipairs(items) do
					local row = self.rows[index]
					if not row then
						row = env.CreateFrame(self.view.frameType, nil, self)
						self.rows[index] = row
					end
					row:Show()
					self.view.initializer(row, item)
				end
				for index = #items + 1, #self.rows do
					self.rows[index]:Hide()
				end
			end
			-- the rows on show, for tests
			function frame:ShownRows()
				local shown = {}
				for _, row in ipairs(self.rows) do
					if row.shown then shown[#shown + 1] = row end
				end
				return shown
			end
		elseif template == "PanelTabButtonTemplate" and parent then
			parent.Tabs = parent.Tabs or {}
			table.insert(parent.Tabs, frame)
		end

		game.frames[#game.frames + 1] = frame
		if name then
			env[name] = frame
		end
		return frame
	end

	-- settings panel
	env.Settings = {
		VarType = { Boolean = "boolean", String = "string" },
		RegisterVerticalLayoutCategory = function(name)
			local category = { name = name, GetID = function() return name end }
			local layout = { initializers = {}, AddInitializer = function(self, init) self.initializers[#self.initializers + 1] = init end }
			game.category, game.layout = category, layout
			return category, layout
		end,
		RegisterProxySetting = function(category, variable, variableType, name, default, get, set)
			assert(category == game.category, "setting registered on the wrong category")
			assert(type(variable) == "string" and type(name) == "string", "setting needs a variable and a name")
			assert(type(default) == variableType, variable .. ": default must be a " .. variableType)
			assert(type(get()) == variableType, variable .. ": getter must return a " .. variableType)
			local setting = { variable = variable, name = name, default = default, get = get, set = set }
			function setting:GetVariableType() return variableType end
			assert(not game.settings[variable], variable .. " registered twice")
			game.settings[variable] = setting
			return setting
		end,
		CreateCheckbox = function(category, setting, tooltip)
			assert(setting:GetVariableType() == "boolean")
			setting.tooltip = tooltip
		end,
		CreateDropdown = function(category, setting, options, tooltip)
			assert(setting:GetVariableType() == "string", "dropdowns here hold text")
			setting.options = options()
			setting.tooltip = tooltip
		end,
		CreateControlTextContainer = function()
			local container = { data = {} }
			function container:Add(value, label, tooltip)
				self.data[#self.data + 1] = { value = value, label = label, text = label, tooltip = tooltip }
			end
			function container:GetData() return self.data end
			return container
		end,
		RegisterAddOnCategory = function(category) game.registeredCategory = category end,
		OpenToCategory = function(id) game.openedCategory = id end,
	}
	-- Blizzard's scrolling list helpers
	env.CreateScrollBoxListLinearView = function()
		local view = {}
		function view:SetElementExtent(extent) self.extent = extent end
		function view:SetElementInitializer(frameType, initializer) self.frameType, self.initializer = frameType, initializer end
		return view
	end
	env.ScrollUtil = { InitScrollBoxListWithScrollBar = function(box, bar, view) box.view, box.scrollBar = view, bar end }
	env.CreateDataProvider = function(items) return { items = items or {} } end

	-- Blizzard's right-click menus. The last one opened is game.menu:
	-- { owner = ..., root = ... }, and each entry in root.entries has a
	-- kind (title, radio, button, divider) and text. A radio has
	-- isSelected() and select(); a button has click() and entries of its
	-- own when it opens a submenu.
	local function menuDescription()
		local description = { entries = {} }
		function description:CreateTitle(text)
			local entry = { kind = "title", text = text }
			self.entries[#self.entries + 1] = entry
			return entry
		end
		function description:CreateRadio(text, isSelected, setSelected, data)
			local entry = { kind = "radio", text = text, data = data }
			function entry.isSelected() return isSelected(data) end
			function entry.select() setSelected(data) end
			self.entries[#self.entries + 1] = entry
			return entry
		end
		function description:CreateButton(text, callback)
			local entry = menuDescription()
			entry.kind, entry.text = "button", text
			function entry.click() if callback then callback() end end
			self.entries[#self.entries + 1] = entry
			return entry
		end
		function description:CreateDivider()
			self.entries[#self.entries + 1] = { kind = "divider" }
		end
		return description
	end
	if not config.noMenus then
		env.MenuUtil = { CreateContextMenu = function(owner, generator)
			local root = menuDescription()
			generator(owner, root)
			game.menu = { owner = owner, root = root }
			return root
		end }
		-- set game.menuOpen = true while a menu is open
		env.Menu = { GetManager = function()
			return { GetOpenMenu = function() return game.menuOpen end }
		end }
	end

	-- Blizzard's tab helpers
	env.PanelTemplates_SetNumTabs = function(owner, count) owner.numTabs = count end
	env.PanelTemplates_SetTab = function(owner, id) owner.selectedTab = id end

	env.CreateSettingsListSectionHeaderInitializer = function(text) return { header = text } end

	-- the game's player frame, with its portrait in the middle of the left
	-- of the screen unless config.portraitAt = { x, y } says otherwise
	if config.playerFrame ~= false then
		env.PlayerFrame = env.CreateFrame("Button", "PlayerFrame", env.UIParent)
		env.PlayerFrame.PlayerFrameContainer = env.CreateFrame("Frame", nil, env.PlayerFrame)
		local portrait = env.PlayerFrame.PlayerFrameContainer:CreateTexture()
		portrait.center = config.portraitAt or { 200, 540 }
		env.PlayerFrame.PlayerFrameContainer.PlayerPortrait = portrait
	end

	-----------------------------------------------------------------------
	-- Driving the game
	-----------------------------------------------------------------------

	-- Loads addons the way the client does: for each, every file listed in
	-- its .toc, in order, each handed the addon name and one shared table.
	-- addons = { { root = "path", name = "Krump" }, ... }, loaded in order;
	-- the last one's table is game.ns. Then the player logs in.
	function game:load(addons)
		self.addons = {}
		self.files = {}
		for _, addon in ipairs(addons) do
			local ns = {}
			for line in io.lines(addon.root .. "/" .. addon.name .. ".toc") do
				line = line:gsub("%s+$", "")
				if line ~= "" and line:sub(1, 1) ~= "#" then
					local chunk = assert(loadfile(addon.root .. "/" .. line))
					setfenv(chunk, env)
					chunk(addon.name, ns)
					self.files[#self.files + 1] = addon.name .. "/" .. line
				end
			end
			self.addons[addon.name] = ns
			self.ns = ns
			self:fire("ADDON_LOADED", addon.name)
		end
		self:fire("PLAYER_LOGIN")
		return self
	end

	function game:fire(event, ...)
		for _, frame in ipairs(self.frames) do
			if frame.events[event] and frame.scripts.OnEvent then
				frame.scripts.OnEvent(frame, event, ...)
			end
		end
	end

	-- A chat box. Behaves like the game's, as far as Krump can tell.
	function game:editBox()
		local box = { text = "", chatType = "SAY", sticky = "SAY", hooks = {} }
		function box:GetText() return self.text end
		function box:SetText(text)
			self.text = text
			for _, hook in ipairs(self.hooks) do
				hook(self, false)
			end
		end
		function box:GetChatType() return self.chatType end
		function box:SetChatType(chatType) self.chatType = chatType end
		function box:GetAttribute(name) if name == "chatType" then return self.chatType end end
		function box:GetChannelTarget()
			local id = env.GetChannelName(self.channelTarget)
			return id
		end
		function box:GetWidth() return 400 end
		function box:HookScript(script, handler)
			assert(script == "OnTextChanged", "unexpected script hook: " .. tostring(script))
			self.hooks[#self.hooks + 1] = handler
		end

		function box:ParseText()
			local text = self.text
			if text:sub(1, 1) ~= "/" then
				return
			end
			local command = text:match("^(/%S+)") or ""
			local message = text:sub(#command + 2):match("^%s*(.*)$")
			local lowered = command:lower()
			if CHAT_COMMANDS[lowered] then
				self.chatType = CHAT_COMMANDS[lowered]
				self:SetText(message)
			elseif lowered == "/w" or lowered == "/whisper" then
				local target, rest = message:match("^(%S+)%s*(.*)$")
				self.chatType, self.tellTarget = "WHISPER", target
				self:SetText(rest or "")
			elseif lowered:match("^/%d+$") then
				self.chatType, self.channelTarget = "CHANNEL", tonumber(lowered:sub(2))
				self:SetText(message)
			else
				for name, handler in pairs(env.SlashCmdList) do
					local index = 1
					while env["SLASH_" .. name .. index] do
						if env["SLASH_" .. name .. index] == lowered then
							handler(message, self)
							self:SetText("")
							return
						end
						index = index + 1
					end
				end
				self:SetText("") -- unknown command
			end
		end

		function box:SendText()
			self:ParseText()
			env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxPreSendText", self)
			local chatType = self:GetChatType()
			local text = self:GetText()
			if text:find("%s*[^%s]+") then
				local target
				if chatType == "WHISPER" or chatType == "BN_WHISPER" then
					target = self.tellTarget
				elseif chatType == "CHANNEL" then
					target = self.channelTarget
				end
				game.sent[#game.sent + 1] = { text = text, chatType = chatType, target = target }
			end
		end

		-- Type a line and press Enter. Returns what was sent, if anything.
		function box:say(text)
			local before = #game.sent
			env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", self)
			self:SetText(text)
			self:SendText()
			self:SetText("")
			self.chatType = self.sticky
			env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxHide", self)
			local message = game.sent[before + 1]
			return message and message.text, message
		end

		-- Type without pressing Enter.
		function box:type(text)
			env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", self)
			self:SetText(text)
		end

		return box
	end

	-----------------------------------------------------------------------
	-- The chat line, as an addon puts text in it
	--
	-- ChatFrameUtil.OpenChat("/s Hello") opens the chat line with the text
	-- in it. The game works out a chat-type command at the front straight
	-- away (it becomes the "Say:" header), so this does too. Then the test
	-- presses Enter (game:pressEnter) or Escape (game:pressEscape).
	-----------------------------------------------------------------------

	function game:openChat(text)
		self.openedChat = text
		self.opened[#self.opened + 1] = text
		local box = self.chatBox or self:editBox()
		self.chatBox = box
		box.chatType = box.sticky
		local command, rest = text:match("^(/%S+)%s+(.*)$")
		if command and CHAT_COMMANDS[command:lower()] then
			box.chatType = CHAT_COMMANDS[command:lower()]
			text = rest
		end
		self.chatOpen = true
		env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", box)
		box:SetText(text)
	end

	-- What is in the chat line now, and the chat type it will go out as.
	function game:chatText()
		if not self.chatOpen then
			return nil
		end
		return self.chatBox.text, self.chatBox.chatType
	end

	local function closeChat(box)
		box:SetText("")
		box.chatType = box.sticky
		game.chatOpen = false
		env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost", box)
		env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxHide", box)
	end

	-- Enter in the chat line. Returns the message sent, if any.
	function game:pressEnter()
		assert(self.chatOpen, "the chat line is not open")
		local box = self.chatBox
		local before = #self.sent
		box:SendText()
		closeChat(box)
		return self.sent[before + 1]
	end

	-- The player opens the chat line themselves and starts typing.
	function game:startTyping(text)
		local box = self.chatBox or self:editBox()
		self.chatBox = box
		box.chatType = box.sticky
		self.chatOpen = true
		env.EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", box)
		box:SetText(text or "")
	end

	function game:pressEscape()
		assert(self.chatOpen, "the chat line is not open")
		closeChat(self.chatBox)
	end

	return game
end

return Mock
