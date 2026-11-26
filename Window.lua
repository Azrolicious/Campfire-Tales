-- The Campfire Tales window. Categories down the left, their buttons on the
-- right. Click a button to say it.
--
--   (o) Campfire Tales                                         [x]
--       Warming up by the fire: camp benefits in 0:42
--   +-------------+------------------------------------------+
--   | Greetings   | Greetings                  [Surprise me] |
--   | Small Talk  | Welcome people to the fire.              |
--   | Jokes       | [ Well met      ] [ Room for one more ]  |
--   | ...         | [ Rest your feet] [ It doesn't bite   ]  |
--   +-------------+------------------------------------------+
--   The Last Ember, line 2 of 7 - press Enter     [Next] [Stop]
--
-- Built from the game's own parts, like the Krump and Juju boxes:
-- ButtonFrameTemplate gives the frame, title bar, round portrait, close
-- button and inset; the buttons and text boxes are Blizzard's too.

local _, ns = ...

local WIDTH, HEIGHT = 640, 480
local PAD = 12
local INSET_WIDTH = WIDTH - 10       -- the inset is 10 narrower than the window
local LIST_WIDTH = 150               -- the category column
local LIST_ROW = 24
local GRID_X = PAD + LIST_WIDTH + 14 -- where the buttons start, from the inset's left
local GRID_WIDTH = INSET_WIDTH - GRID_X - PAD
local COLUMNS, GAP = 2, 8
local BUTTON_WIDTH = (GRID_WIDTH - GAP * (COLUMNS - 1)) / COLUMNS
local BUTTON_HEIGHT, BUTTON_STEP = 22, 26
local GRID_TOP = -PAD - 56
local ROWS = 9                       -- rows of buttons on a page
local MINE_ROWS = 4                  -- on Your Own, which has the editor below
local BORDER = 6                     -- Blizzard's text boxes draw their border outside the box
local R, G, B = 1, 0.6, 0.2          -- firelight orange
local PORTRAIT = "Interface\\Icons\\Spell_Fire_Fire"
ns.ROWS, ns.MINE_ROWS, ns.COLUMNS = ROWS, MINE_ROWS, COLUMNS

local frame = CreateFrame("Frame", "CampfireTalesFrame", UIParent, "ButtonFrameTemplate")
frame:SetSize(WIDTH, HEIGHT)
frame:SetPoint("CENTER", 0, 40)
frame:SetFrameStrata("MEDIUM")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
frame:Hide()

if frame.SetTitle then
	frame:SetTitle("Campfire Tales")
end
if frame.SetPortraitToAsset then
	frame:SetPortraitToAsset(PORTRAIT)
end

-- Escape closes it, like the game's own windows.
table.insert(UISpecialFrames, "CampfireTalesFrame")

local inset = frame.Inset or frame

local close = frame.CloseButton
if not close then
	close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
end
close:SetScript("OnClick", function() frame:Hide() end)

local function text(on, font, anchor, relativeTo, relativePoint, x, y, words)
	local fontString = on:CreateFontString(nil, "OVERLAY", font)
	fontString:SetPoint(anchor, relativeTo, relativePoint, x, y)
	fontString:SetJustifyH("LEFT")
	if words then
		fontString:SetText(words)
	end
	return fontString
end

local function button(on, label, width)
	local made = CreateFrame("Button", nil, on, "UIPanelButtonTemplate")
	made:SetSize(width, BUTTON_HEIGHT)
	made:SetText(label)
	return made
end

local function editBox(on, width, maxLetters)
	local box = CreateFrame("EditBox", nil, on, "InputBoxTemplate")
	box:SetSize(width, 20)
	box:SetAutoFocus(false)
	box:SetMaxLetters(maxLetters)
	box:SetScript("OnEscapePressed", function() frame:Hide() end)
	return box
end

local function tooltipOff()
	GameTooltip:Hide()
end

-- What the buttons do, set further down. Buttons are made as they are
-- needed, and get these when they are made.
local onButtonClick, showTooltip, onCategoryClick, showCategoryTooltip

---------------------------------------------------------------------------
-- The strip above the inset: the fire, and who is talking
---------------------------------------------------------------------------

local fireText = text(frame, "GameFontHighlight", "TOPLEFT", frame, "TOPLEFT", 66, -36)
fireText:SetWidth(320)
fireText:SetWordWrap(false)

local accentButton = CreateFrame("Button", nil, frame)
accentButton:SetSize(230, 20)
accentButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -32)
local accentText = accentButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
accentText:SetPoint("RIGHT", accentButton, "RIGHT", 0, 0)
accentText:SetJustifyH("RIGHT")
accentButton:Hide()

---------------------------------------------------------------------------
-- Categories, down the left
---------------------------------------------------------------------------

local divider = inset:CreateTexture(nil, "ARTWORK")
divider:SetColorTexture(1, 1, 1, 0.12)
divider:SetPoint("TOPLEFT", inset, "TOPLEFT", PAD + LIST_WIDTH + 6, -8)
divider:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", PAD + LIST_WIDTH + 6, 8)
divider:SetWidth(1)

local categoryButtons = {}

local function categoryButton(index)
	local made = categoryButtons[index]
	if made then
		return made
	end
	made = CreateFrame("Button", nil, inset)
	made:SetSize(LIST_WIDTH, LIST_ROW - 2)
	made:SetPoint("TOPLEFT", inset, "TOPLEFT", PAD - 4, -PAD + 4 - (index - 1) * LIST_ROW)
	made.Selected = made:CreateTexture(nil, "BACKGROUND")
	made.Selected:SetAllPoints()
	made.Selected:SetColorTexture(R, G, B, 0.22)
	local highlight = made:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
	highlight:SetBlendMode("ADD")
	highlight:SetAlpha(0.5)
	made.Text = made:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	made.Text:SetPoint("LEFT", made, "LEFT", 8, 0)
	made.Text:SetPoint("RIGHT", made, "RIGHT", -4, 0)
	made.Text:SetJustifyH("LEFT")
	made.Text:SetWordWrap(false)
	made:SetScript("OnClick", function(self) onCategoryClick(self) end)
	made:SetScript("OnEnter", function(self) showCategoryTooltip(self) end)
	made:SetScript("OnLeave", tooltipOff)
	categoryButtons[index] = made
	return made
end

---------------------------------------------------------------------------
-- The buttons of the category on show
---------------------------------------------------------------------------

local title = text(inset, "GameFontNormalLarge", "TOPLEFT", inset, "TOPLEFT", GRID_X, -PAD)

local randomButton = button(inset, "Surprise me", 110)
randomButton:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -PAD, -PAD + 5)

local nextPage = button(inset, ">", 26)
nextPage:SetPoint("RIGHT", randomButton, "LEFT", -10, 0)
local pageText = text(inset, "GameFontHighlightSmall", "RIGHT", nextPage, "LEFT", -6, 0)
pageText:SetJustifyH("CENTER")
local prevPage = button(inset, "<", 26)
prevPage:SetPoint("RIGHT", pageText, "LEFT", -6, 0)

local about = text(inset, "GameFontHighlightSmall", "TOPLEFT", title, "BOTTOMLEFT", 0, -6)
about:SetWidth(GRID_WIDTH)
about:SetWordWrap(true)

local empty = text(inset, "GameFontDisableSmall", "TOPLEFT", inset, "TOPLEFT", GRID_X, GRID_TOP - 4)
empty:SetWidth(GRID_WIDTH)
empty:SetWordWrap(true)

local grid = {}

local function gridButton(slot)
	local made = grid[slot]
	if made then
		return made
	end
	made = button(inset, "", BUTTON_WIDTH)
	made:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local column = (slot - 1) % COLUMNS
	local row = math.floor((slot - 1) / COLUMNS)
	made:SetPoint("TOPLEFT", inset, "TOPLEFT", GRID_X + column * (BUTTON_WIDTH + GAP), GRID_TOP - row * BUTTON_STEP)
	made:SetScript("OnClick", function(self, mouseButton) onButtonClick(self, mouseButton) end)
	made:SetScript("OnEnter", function(self) showTooltip(self) end)
	made:SetScript("OnLeave", tooltipOff)
	grid[slot] = made
	return made
end

---------------------------------------------------------------------------
-- Your Own: making buttons
---------------------------------------------------------------------------

local editor = CreateFrame("Frame", nil, inset)
editor:SetSize(GRID_WIDTH, 180)
editor:SetPoint("TOPLEFT", inset, "TOPLEFT", GRID_X, GRID_TOP - MINE_ROWS * BUTTON_STEP - 8)
editor:Hide()

local editorLine = editor:CreateTexture(nil, "ARTWORK")
editorLine:SetColorTexture(1, 1, 1, 0.12)
editorLine:SetPoint("TOPLEFT", editor, "TOPLEFT", 0, 0)
editorLine:SetSize(GRID_WIDTH, 1)

local makeTitle = text(editor, "GameFontNormal", "TOPLEFT", editor, "TOPLEFT", 0, -10, "Make your own button")
local nameLabel = text(editor, "GameFontHighlightSmall", "TOPLEFT", makeTitle, "BOTTOMLEFT", 0, -8, "Button name:")
local nameBox = editBox(editor, 180 - BORDER, 24)
nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", BORDER, -4)

local saveButton = button(editor, "Save button", 110)
saveButton:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)
local removeButton = button(editor, "Remove", 90)
removeButton:SetPoint("LEFT", saveButton, "RIGHT", 6, 0)

local linesLabel = text(editor, "GameFontHighlightSmall", "TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -34,
	"What to say. Start with /e for an action. Put // between lines for a story:")
linesLabel:SetWidth(GRID_WIDTH)
local linesBox = editBox(editor, GRID_WIDTH - BORDER, 2400)
linesBox:SetPoint("TOPLEFT", linesLabel, "BOTTOMLEFT", BORDER, -4)

local hint = text(editor, "GameFontDisableSmall", "TOPLEFT", linesLabel, "BOTTOMLEFT", 0, -32,
	"{target:friends} is your target's name, or \"friends\" without one. {his} becomes her for a female character.")
hint:SetWidth(GRID_WIDTH)
hint:SetWordWrap(true)

local status = text(editor, "GameFontHighlightSmall", "TOPLEFT", hint, "BOTTOMLEFT", 0, -10)
status:SetWidth(GRID_WIDTH)
status:SetWordWrap(true)

---------------------------------------------------------------------------
-- The bar along the bottom: the story being told
---------------------------------------------------------------------------

local stopButton = button(frame, "Stop", 80)
stopButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 4)
local nextButton = button(frame, "Next line", 110)
nextButton:SetPoint("RIGHT", stopButton, "LEFT", -4, 0)

local tellText = text(frame, "GameFontHighlightSmall", "BOTTOMLEFT", frame, "BOTTOMLEFT", PAD + 4, 10)
tellText:SetWidth(WIDTH - 226)
tellText:SetWordWrap(false)

local IDLE = "|cff808080Actions happen at once. Words go in your chat line, and Enter says them.|r"

-- For the tests, and for anyone poking at the window from a macro.
frame.CategoryButtons, frame.Buttons, frame.Title, frame.About, frame.Empty = categoryButtons, grid, title, about, empty
frame.RandomButton, frame.PrevPage, frame.NextPage, frame.PageText = randomButton, prevPage, nextPage, pageText
frame.FireText, frame.AccentButton, frame.AccentText = fireText, accentButton, accentText
frame.Editor, frame.NameBox, frame.LinesBox, frame.SaveButton, frame.RemoveButton, frame.Status =
	editor, nameBox, linesBox, saveButton, removeButton, status
frame.TellText, frame.NextButton, frame.StopButton = tellText, nextButton, stopButton

---------------------------------------------------------------------------
-- Behaviour
---------------------------------------------------------------------------

local shownKey -- the category on show
local page = 1

local function currentCategory(categories)
	categories = categories or ns.Categories()
	local wanted = shownKey or (ns.db and ns.db.category)
	for _, category in ipairs(categories) do
		if category.key == wanted then
			return category, categories
		end
	end
	return categories[1], categories
end

local function colored(category, label)
	if category.mine then
		return "|cffff9933" .. label .. "|r"
	elseif category.accent then
		return "|cff" .. ns.AccentInfo(category.accent).color .. label .. "|r"
	end
	return label
end

local function updateFire()
	local line = ns.FireStatus and ns.FireStatus()
	if line then
		fireText:SetText(line)
	else
		fireText:SetText("|cff808080Sit down by a campfire to warm up.|r")
	end
end

local function updateAccent()
	local accent = ns.TalkingAccent and ns.TalkingAccent()
	if not accent then
		accentButton.accent = nil
		accentButton:Hide()
		return
	end
	accentButton.accent = accent
	accentText:SetText(ns.AccentName(accent) .. " is talking: words come out in " .. ns.AccentInfo(accent).speech)
	accentButton:Show()
end

local function updateTelling()
	local state = ns.TellingState()
	if not state then
		tellText:SetText(IDLE)
		nextButton:Hide()
		stopButton:Hide()
		return
	end
	local where = "|cffff9933" .. state.title .. "|r"
	if state.count > 1 then
		where = string.format("%s, line %d of %d", where, state.index, state.count)
	end
	if state.waiting then
		tellText:SetText(where .. " - press Enter to say it")
		nextButton:Hide()
	elseif state.pending then
		tellText:SetText(where .. " - coming up")
		nextButton:Show()
	else
		tellText:SetText(where .. " - paused")
		nextButton:Show()
	end
	stopButton:Show()
end

local function update()
	if not frame:IsShown() or not ns.db then
		return
	end
	local current, categories = currentCategory()
	shownKey = current.key

	for index, category in ipairs(categories) do
		local made = categoryButton(index)
		made.category = category
		made.Text:SetText(colored(category, category.name))
		made.Selected:SetShown(category == current)
		made:Show()
	end
	for index = #categories + 1, #categoryButtons do
		categoryButtons[index]:Hide()
	end

	title:SetText(current.name)
	about:SetText(current.about or "")

	local entries = ns.EntriesOf(current)
	local perPage = (current.mine and MINE_ROWS or ROWS) * COLUMNS
	local pages = math.max(1, math.ceil(#entries / perPage))
	page = math.min(math.max(page, 1), pages)
	for slot = 1, perPage do
		local entry = entries[(page - 1) * perPage + slot]
		local made = gridButton(slot)
		made.entry, made.category = entry, current
		if entry then
			made:SetText(colored(current, entry.label))
			made:Show()
		else
			made:Hide()
		end
	end
	for slot = perPage + 1, #grid do
		grid[slot]:Hide()
	end
	prevPage:SetShown(pages > 1)
	nextPage:SetShown(pages > 1)
	pageText:SetShown(pages > 1)
	prevPage:SetEnabled(page > 1)
	nextPage:SetEnabled(page < pages)
	pageText:SetText(page .. " / " .. pages)
	randomButton:SetEnabled(#entries > 0)

	if #entries == 0 then
		empty:SetText(current.mine and "Nothing here yet. Fill in the boxes below and press Save button."
			or "Nothing here.")
		empty:Show()
	else
		empty:Hide()
	end
	editor:SetShown(current.mine == true)
	if current.mine then
		removeButton:SetEnabled(#entries > 0)
	end

	updateFire()
	updateAccent()
	updateTelling()
end
ns.RefreshWindow = update

local function showCategory(key)
	shownKey = key
	if ns.db then
		ns.db.category = key
	end
	page = 1
	update()
end

local function say(ok, message)
	if ok then
		status:SetTextColor(R, G, B)
	else
		status:SetTextColor(1, 0.35, 0.3)
	end
	status:SetText(message)
end

-- Right-click one of your own: load it into the boxes below.
local function edit(entry)
	nameBox:SetText(entry.label)
	linesBox:SetText(table.concat(entry.lines, " // "))
	say(true, "Change \"" .. entry.label .. "\" below and press Save button.")
	linesBox:SetFocus()
end

local KIND_SAYS = { SAY = " says: ", YELL = " yells: " }
local MAX_SHOWN = 8

-- What everyone will see, as near as can be told before it is said.
function showTooltip(self)
	local entry = self.entry
	if not entry then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(entry.label)
	if entry.emote then
		GameTooltip:AddLine(ns.AccentName(entry.accent) .. "'s " .. entry.command .. " emote, worded for your voice.", 1, 1, 1, true)
		GameTooltip:AddLine("Click to do it, aimed at your target if you have one.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
		return
	end
	local me = ns.PlayerName()
	local lines = ns.PrepareLines(entry)
	for index, line in ipairs(lines) do
		if index > MAX_SHOWN then
			GameTooltip:AddLine("...and " .. (#lines - MAX_SHOWN) .. " more lines.", 0.7, 0.7, 0.7)
			break
		end
		if line.kind == "EMOTE" then
			GameTooltip:AddLine(me .. " " .. line.text, 1, 0.5, 0.25, true)
		else
			GameTooltip:AddLine(me .. KIND_SAYS[line.kind] .. line.text, 1, 1, 1, true)
		end
	end
	if #lines == 1 and ns.DoesStraightAway(lines[1]) then
		GameTooltip:AddLine("Click to do it now.", 0.7, 0.7, 0.7, true)
	elseif #lines > 1 then
		GameTooltip:AddLine("Click to start. Each line goes in your chat line: press Enter to say it, and the next one follows.", 0.7, 0.7, 0.7, true)
	else
		GameTooltip:AddLine("Click to put it in your chat line, then press Enter to say it.", 0.7, 0.7, 0.7, true)
	end
	local accent = ns.TalkingAccent()
	if accent then
		GameTooltip:AddLine(ns.AccentName(accent) .. " says the words the " .. ns.AccentInfo(accent).speech
			.. " way: the preview above the chat line shows how.", 1, 1, 1, true)
	end
	if self.category and self.category.mine then
		GameTooltip:AddLine("One of yours. Right-click to change it.", 0.7, 0.7, 0.7, true)
	end
	GameTooltip:Show()
end

function onButtonClick(self, mouseButton)
	local entry = self.entry
	if not entry then
		return
	end
	if mouseButton == "RightButton" then
		if self.category and self.category.mine then
			edit(entry)
		end
		return
	end
	nameBox:ClearFocus()
	linesBox:ClearFocus()
	ns.Tell(entry)
	update()
end

function onCategoryClick(self)
	showCategory(self.category.key)
end

function showCategoryTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(self.category.name)
	if self.category.about then
		GameTooltip:AddLine(self.category.about, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

randomButton:SetScript("OnClick", function()
	local entry = ns.RandomEntry(currentCategory())
	if entry then
		ns.Tell(entry)
		update()
	end
end)
randomButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:AddLine("Surprise me")
	GameTooltip:AddLine("Says something from this category at random.", 1, 1, 1, true)
	GameTooltip:Show()
end)
randomButton:SetScript("OnLeave", tooltipOff)

prevPage:SetScript("OnClick", function()
	page = page - 1
	update()
end)
nextPage:SetScript("OnClick", function()
	page = page + 1
	update()
end)

nextButton:SetScript("OnClick", function()
	ns.NextLine()
end)
stopButton:SetScript("OnClick", function()
	ns.StopTelling()
end)

accentButton:SetScript("OnClick", function(self)
	if self.accent then
		ns.OpenAccentBox(self.accent)
	end
end)
accentButton:SetScript("OnEnter", function(self)
	local accent = self.accent
	if not accent then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:AddLine(accent)
	GameTooltip:AddLine("Everything Campfire Tales puts in your chat line goes out in " .. ns.AccentInfo(accent).speech
		.. ", the same as anything you type, and the preview above the chat line shows how.", 1, 1, 1, true)
	GameTooltip:AddLine("Click to open the " .. accent .. " box.", 0.7, 0.7, 0.7, true)
	GameTooltip:Show()
end)
accentButton:SetScript("OnLeave", tooltipOff)

local function saveMine()
	local ok, message = ns.SaveMine(nameBox:GetText(), linesBox:GetText())
	say(ok, message)
	if ok then
		nameBox:SetText("")
		linesBox:SetText("")
		nameBox:ClearFocus()
		linesBox:ClearFocus()
	end
	update()
end

local function removeMine()
	local ok, message = ns.RemoveMine(nameBox:GetText())
	say(ok, message)
	if ok then
		nameBox:SetText("")
		linesBox:SetText("")
	end
	update()
end

saveButton:SetScript("OnClick", saveMine)
removeButton:SetScript("OnClick", removeMine)
nameBox:SetScript("OnEnterPressed", function() linesBox:SetFocus() end)
nameBox:SetScript("OnTabPressed", function() linesBox:SetFocus() end)
linesBox:SetScript("OnEnterPressed", saveMine)
linesBox:SetScript("OnTabPressed", function() nameBox:SetFocus() end)

-- While the window is open, the countdown to the camp benefits ticks, and
-- switching Krump or Juju on or off brings their categories in or out.
local sinceTick, sinceCheck = 0, 0
local lastAccent
frame:SetScript("OnUpdate", function(_, elapsed)
	sinceTick = sinceTick + (elapsed or 0)
	sinceCheck = sinceCheck + (elapsed or 0)
	if sinceCheck >= 1 then
		sinceCheck = 0
		local accent = ns.TalkingAccent()
		if accent ~= lastAccent then
			lastAccent = accent
			update()
		end
	end
	if sinceTick >= 0.2 then
		sinceTick = 0
		updateFire()
	end
end)

frame:SetScript("OnShow", function()
	status:SetText("")
	lastAccent = ns.TalkingAccent()
	update()
end)

frame:SetScript("OnHide", function()
	nameBox:ClearFocus()
	linesBox:ClearFocus()
end)

-- Opens the window, on the given category if there is one.
function ns.OpenWindow(key)
	if key then
		shownKey = key
		ns.db.category = key
		page = 1
	end
	if frame:IsShown() then
		update()
	else
		frame:Show()
	end
end

function ns.ToggleWindow()
	if frame:IsShown() then
		frame:Hide()
	else
		ns.OpenWindow()
	end
end

function ns.WindowShown()
	return frame:IsShown()
end
