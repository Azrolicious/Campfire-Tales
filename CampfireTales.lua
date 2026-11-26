-- Campfire Tales core: saved settings, filling in the words in curly
-- brackets, your own lines, and the /tales command.

local ADDON, ns = ...

local gsub, strfind, strmatch, strlower = string.gsub, string.find, string.match, string.lower

local ORANGE = "|cffff9933"
ns.ORANGE = ORANGE
local PREFIX = ORANGE .. "Campfire Tales|r: "

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end
ns.Print = Print

---------------------------------------------------------------------------
-- Settings (account-wide)
---------------------------------------------------------------------------

local DEFAULTS = {
	autoOpen = true,      -- open the window when you sit down at a campfire
	actionsNow = true,    -- do a one-line action as soon as its button is clicked
	accents = true,       -- show Krump's or Juju's categories while one of them is talking
	category = "greetings", -- the category the window opens on
	mine = {},            -- your own buttons: { label = ..., lines = { ... } }, in order
}
ns.DEFAULTS = DEFAULTS

local function fillDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

-- Redraws whatever is on show after something changes.
function ns.Refresh()
	if ns.RefreshWindow then
		ns.RefreshWindow()
	end
end

---------------------------------------------------------------------------
-- Reading the game
---------------------------------------------------------------------------

-- The game can mark text as secret, and addons may not look inside it.
local function readable(value)
	return type(value) == "string" and not (issecretvalue and issecretvalue(value))
end
ns.Readable = readable

function ns.PlayerName()
	local ok, name = pcall(UnitName, "player")
	return ok and readable(name) and name or "You"
end

-- Your target's name, if you have one other than yourself.
function ns.TargetName()
	local ok, name = pcall(function()
		if UnitExists("target") and not UnitIsUnit("target", "player") then
			return UnitName("target")
		end
	end)
	return ok and readable(name) and name ~= "" and name or nil
end

local function zoneName()
	for _, get in ipairs({ GetSubZoneText, GetZoneText }) do
		local ok, name = pcall(get)
		if ok and readable(name) and strfind(name, "%S") then
			return name
		end
	end
	return "these parts"
end

-- Morning, afternoon or evening, by the game's clock. Night counts as
-- evening, because "Good night!" means goodbye.
local function timeOfDay()
	local ok, hour = pcall(GetGameTime)
	hour = ok and tonumber(hour) or 20
	if hour >= 5 and hour < 12 then
		return "morning"
	elseif hour >= 12 and hour < 18 then
		return "afternoon"
	end
	return "evening"
end

local PRONOUNS = {
	[2] = { his = "his", him = "him", he = "he" },
	[3] = { his = "her", him = "her", he = "she" },
}
local NEUTRAL = { his = "their", him = "them", he = "they" }

-- Who, where and when, worked out once when a tale starts so that every
-- line of it says the same.
function ns.Context()
	local ok, sex = pcall(UnitSex, "player")
	return {
		target = ns.TargetName(),
		me = ns.PlayerName(),
		zone = zoneName(),
		time = timeOfDay(),
		pronouns = (ok and PRONOUNS[sex]) or NEUTRAL,
	}
end

-- Fills in {target}, {target:everyone}, {me}, {zone}, {time} and {his}.
-- Anything else in curly brackets is left as it is.
function ns.Fill(text, context)
	context = context or ns.Context()
	return (gsub(text, "{(%a+):?([^}]*)}", function(word, fallback)
		if word == "target" then
			return context.target or (fallback ~= "" and fallback) or "friend"
		elseif word == "me" then
			return context.me
		elseif word == "zone" then
			return context.zone
		elseif word == "time" then
			return context.time
		end
		return context.pronouns[word]
	end))
end

---------------------------------------------------------------------------
-- Lines
---------------------------------------------------------------------------

-- How a line starts says how it is said.
local KINDS = {
	["/s"] = "SAY", ["/say"] = "SAY",
	["/y"] = "YELL", ["/yell"] = "YELL",
	["/e"] = "EMOTE", ["/me"] = "EMOTE", ["/emote"] = "EMOTE",
}

-- "/e pokes the fire." -> "EMOTE", "pokes the fire."
function ns.ParseLine(line)
	local command, rest = strmatch(line, "^%s*(/%a+)%s+(.-)%s*$")
	local kind = command and KINDS[strlower(command)]
	if kind then
		return kind, rest
	end
	return "SAY", (gsub(gsub(line, "^%s+", ""), "%s+$", ""))
end

-- A button's lines, filled in and ready to say: { kind = ..., text = ... }.
function ns.PrepareLines(entry, context)
	context = context or ns.Context()
	local prepared = {}
	for _, line in ipairs(entry.lines or {}) do
		local kind, text = ns.ParseLine(ns.Fill(line, context))
		if strfind(text, "%S") then
			prepared[#prepared + 1] = { kind = kind, text = text }
		end
	end
	return prepared
end

---------------------------------------------------------------------------
-- Categories: the built-in ones, Krump's or Juju's while one of them is
-- talking, and your own at the bottom.
---------------------------------------------------------------------------

local mineCategory = {
	key = "mine",
	name = "Your Own",
	about = "Buttons you make yourself. Right-click one to change it.",
	mine = true,
}

function ns.Categories()
	local list = {}
	for _, category in ipairs(ns.Tales.categories) do
		list[#list + 1] = category
	end
	if ns.AccentCategories and (not ns.db or ns.db.accents) then
		for _, category in ipairs(ns.AccentCategories()) do
			list[#list + 1] = category
		end
	end
	list[#list + 1] = mineCategory
	return list
end

function ns.FindCategory(wanted)
	if not readable(wanted) then
		return nil
	end
	wanted = strlower(gsub(wanted, "%s+", ""))
	if wanted == "" then
		return nil
	end
	local categories = ns.Categories()
	for _, category in ipairs(categories) do
		if category.key == wanted then
			return category
		end
	end
	-- "/tales random spook" finds Spooky Tales
	for _, category in ipairs(categories) do
		if strfind(strlower(gsub(category.name, "%s+", "")), wanted, 1, true) == 1 then
			return category
		end
	end
	return nil
end

-- The buttons in a category.
function ns.EntriesOf(category)
	if not category then
		return {}
	end
	if category.mine then
		return ns.db and ns.db.mine or {}
	elseif category.emotes then
		return ns.AccentEmotes(category.accent)
	end
	return ns.Tales.Entries(category)
end

function ns.RandomEntry(category)
	local entries = ns.EntriesOf(category)
	if #entries == 0 then
		return nil
	end
	return entries[math.random(1, #entries)]
end

---------------------------------------------------------------------------
-- Your own buttons
---------------------------------------------------------------------------

local MAX_MINE = 30
local MAX_LABEL = 24
local MAX_LINES = 12
local MAX_LINE = 200
ns.MAX_MINE = MAX_MINE

local function trim(text)
	return (gsub(gsub(gsub(text, "^%s+", ""), "%s+$", ""), "%s+", " "))
end

local function findMine(label)
	local key = strlower(label)
	for index, entry in ipairs(ns.db.mine) do
		if strlower(entry.label) == key then
			return index, entry
		end
	end
	return nil
end

-- SaveMine("Bad pun", "Why did... // Because...") keeps a button of your own.
-- A button with the same name is replaced. Returns true and a message, or
-- false and why not.
function ns.SaveMine(label, text)
	label = readable(label) and trim(gsub(label, "|", "")) or ""
	if label == "" then
		return false, "Give the button a name first."
	end
	if #label > MAX_LABEL then
		return false, "Keep the name to " .. MAX_LABEL .. " letters or fewer."
	end
	text = readable(text) and gsub(text, "|", "") or ""
	local lines = {}
	for line in string.gmatch(text .. "//", "(.-)//") do
		line = trim(line)
		if line ~= "" then
			if #line > MAX_LINE then
				return false, "Keep each line to " .. MAX_LINE .. " letters or fewer. Put // between lines to split them up."
			end
			lines[#lines + 1] = line
		end
	end
	if #lines == 0 then
		return false, "Type what to say. Start with /e for an action, and put // between lines for a story."
	end
	if #lines > MAX_LINES then
		return false, "A button can hold up to " .. MAX_LINES .. " lines."
	end
	local index = findMine(label)
	if not index then
		if #ns.db.mine >= MAX_MINE then
			return false, "You have " .. MAX_MINE .. " buttons already. Remove one first."
		end
		index = #ns.db.mine + 1
	end
	ns.db.mine[index] = { label = label, lines = lines }
	ns.Refresh()
	if #lines > 1 then
		return true, "Saved \"" .. label .. "\", " .. #lines .. " lines."
	end
	return true, "Saved \"" .. label .. "\"."
end

function ns.RemoveMine(label)
	label = readable(label) and trim(label) or ""
	local index = label ~= "" and findMine(label)
	if not index then
		return false, "\"" .. label .. "\" is not one of your buttons."
	end
	local removed = table.remove(ns.db.mine, index)
	ns.Refresh()
	return true, "Removed \"" .. removed.label .. "\"."
end

---------------------------------------------------------------------------
-- /tales
---------------------------------------------------------------------------

local function categoryKeys()
	local keys = {}
	for _, category in ipairs(ns.Categories()) do
		keys[#keys + 1] = category.key
	end
	return table.concat(keys, ", ")
end

local function printHelp()
	Print("/tales - open or close the Campfire Tales window. It also opens by itself when you sit down at a campfire.")
	Print("/tales random <category> - something at random, such as /tales random jokes. Handy in a macro.")
	Print("/tales next - put the next line of a story in the chat line, after you pressed Escape on it")
	Print("/tales stop - stop telling the story")
	Print("/tales auto on|off - open the window when you sit at a campfire")
	Print("/tales config - open the settings")
	Print("Categories: " .. categoryKeys() .. ".")
end

local function handleSlash(message)
	local command, rest = strmatch(message or "", "^%s*(%S*)%s*(.-)%s*$")
	command = strlower(command or "")

	if command == "" then
		ns.ToggleWindow()
	elseif command == "help" then
		printHelp()
	elseif command == "random" then
		local category
		if rest ~= "" then
			category = ns.FindCategory(rest)
		else
			category = ns.FindCategory(ns.db.category) or ns.Categories()[1]
		end
		if not category then
			Print("No category called \"" .. rest .. "\". Try one of: " .. categoryKeys() .. ".")
			return
		end
		local entry = ns.RandomEntry(category)
		if not entry then
			Print(category.name .. " has nothing in it yet.")
			return
		end
		ns.Tell(entry)
	elseif command == "next" or command == "continue" then
		if not ns.NextLine() then
			Print("No story is being told. Pick one in the window: /tales")
		end
	elseif command == "stop" then
		ns.StopTelling()
	elseif command == "auto" then
		local value = strlower(rest)
		if value == "on" or value == "off" then
			ns.db.autoOpen = value == "on"
		else
			ns.db.autoOpen = not ns.db.autoOpen
		end
		Print(ns.db.autoOpen and "The window opens when you sit down at a campfire."
			or "The window stays shut until you type /tales.")
	elseif command == "config" or command == "options" or command == "settings" then
		ns.OpenOptions()
	else
		local category = ns.FindCategory(command)
		if category then
			ns.OpenWindow(category.key)
		else
			printHelp()
		end
	end
end

SLASH_CAMPFIRETALES1 = "/tales"
SLASH_CAMPFIRETALES2 = "/campfiretales"
SlashCmdList["CAMPFIRETALES"] = handleSlash

---------------------------------------------------------------------------
-- Key bindings and the minimap addon menu
---------------------------------------------------------------------------

BINDING_HEADER_CAMPFIRETALES = "Campfire Tales"
BINDING_NAME_CAMPFIRETALES_TOGGLE = "Open or close Campfire Tales"
BINDING_NAME_CAMPFIRETALES_NEXT = "Put the next line of a story in the chat line"

function CampfireTales_Toggle()
	ns.ToggleWindow()
end

function CampfireTales_NextLine()
	ns.NextLine()
end

function CampfireTales_OnAddonCompartmentClick(_, button)
	if button == "RightButton" then
		ns.OpenOptions()
	else
		ns.ToggleWindow()
	end
end

function CampfireTales_OnAddonCompartmentEnter(_, menuButton)
	GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
	GameTooltip:AddLine("Campfire Tales")
	GameTooltip:AddLine("Click to open the window. Right-click for settings.", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end

function CampfireTales_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end

---------------------------------------------------------------------------
-- Start-up
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name ~= ADDON then
			return
		end
		if type(CampfireTalesDB) ~= "table" then
			CampfireTalesDB = {}
		end
		fillDefaults(CampfireTalesDB, DEFAULTS)
		-- Drop anything in "mine" that is not a proper button.
		local kept = {}
		for _, entry in ipairs(CampfireTalesDB.mine) do
			if type(entry) == "table" and readable(entry.label) and type(entry.lines) == "table" then
				kept[#kept + 1] = entry
			end
		end
		CampfireTalesDB.mine = kept
		ns.db = CampfireTalesDB
	elseif event == "PLAYER_LOGIN" then
		if not ns.db then
			return
		end
		if ns.BuildOptions then
			ns.BuildOptions()
		end
		if ns.WatchFire then
			ns.WatchFire()
		end
	end
end)
