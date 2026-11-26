-- The Campfire Tales window. Categories down the left, their buttons on the
-- right.
--
-- Categories of one-liners (greetings, toasts, actions) are a page of
-- buttons: click one to say it. Categories of tales (jokes, stories,
-- riddles, songs) have fewer buttons and a block of text underneath, the
-- page: click a button to read the whole tale there, then Tell it. While it
-- is told, the page shows what has been said, the line up next and the
-- pauses written into it.
--
--   (o) Campfire Tales                                              [x]
--       Warming up by the fire: camp benefits in 0:42
--   +-------------+-----------------------------------------------+
--   | Greetings   | Jokes                            [Surprise me] |
--   | Small Talk  | A setup, a pause, then the punchline.         |
--   | Jokes       | [ Hearthstone   ] [ The skeleton    ]         |
--   | Crude Jokes | [ Gnome fire    ] [ The Barrens     ]         |
--   | ...         | +-------------------------------------------+ |
--   |             | | Gnome fire   4 lines, about 15 seconds  [Tell it] |
--   |             | | 1 How many gnomes does it take to ...     | |
--   |             | |       pause, 2 seconds                    | |
--   |             | | 2 Five.                                   | |
--   +-------------+-----------------------------------------------+
--   Gnome fire, line 2 of 4 - next line in 3         [Say it now] [Stop]
--
-- Built from the game's own parts, like the Krump and Juju boxes:
-- ButtonFrameTemplate gives the frame, title bar, round portrait, close
-- button and inset; the buttons and text boxes are Blizzard's too.

local _, ns = ...

local WIDTH, HEIGHT = 680, 600
local PAD = 12
local INSET_WIDTH = WIDTH - 10       -- the inset is 10 narrower than the window
local INSET_HEIGHT = HEIGHT - 86     -- the title bar above it, the button bar below
local LIST_WIDTH = 150               -- the category column
local LIST_ROW = 24
local GRID_X = PAD + LIST_WIDTH + 14 -- where the buttons start, from the inset's left
local GRID_WIDTH = INSET_WIDTH - GRID_X - PAD
local COLUMNS, GAP = 2, 8
local BUTTON_WIDTH = (GRID_WIDTH - GAP * (COLUMNS - 1)) / COLUMNS
local BUTTON_HEIGHT, BUTTON_STEP = 22, 26
local GRID_TOP = -PAD - 56
local ROWS = 9                       -- rows of buttons on a page of one-liners
local TALE_ROWS = 5                  -- above the block of text
local MINE_ROWS = 4                  -- on Your Own, which has the editor below
local PAGE_TOP = GRID_TOP - TALE_ROWS * BUTTON_STEP - 6
local PAGE_HEIGHT = INSET_HEIGHT + PAGE_TOP - 10
local PAGE_TEXT_WIDTH = GRID_WIDTH - 34
local PAGE_HEADER = 30               -- the title bar of the block of text
local BORDER = 6                     -- Blizzard's text boxes draw their border outside the box
local R, G, B = 1, 0.6, 0.2          -- firelight orange
local PORTRAIT = "Interface\\Icons\\Spell_Fire_Fire"
ns.ROWS, ns.TALE_ROWS, ns.MINE_ROWS, ns.COLUMNS = ROWS, TALE_ROWS, MINE_ROWS, COLUMNS

-- The colours chat uses for each kind of line.
local KIND_COLOR = {
	SAY = { 1, 1, 1 },
	YELL = { 1, 0.25, 0.25 },
	EMOTE = { 1, 0.5, 0.25 },
}

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

local function hint(owner, title, ...)
	GameTooltip:SetOwner(owner, "ANCHOR_TOP")
	GameTooltip:AddLine(title)
	for index = 1, select("#", ...) do
		GameTooltip:AddLine((select(index, ...)), 1, 1, 1, true)
	end
	GameTooltip:Show()
end

-- What the buttons do, set further down. Buttons are made as they are
-- needed, and get these when they are made.
local onButtonClick, showTooltip, onCategoryClick, showCategoryTooltip, onRowClick, showRowTooltip

---------------------------------------------------------------------------
-- The strip above the inset: the fire, and who is talking
---------------------------------------------------------------------------

local fireText = text(frame, "GameFontHighlight", "TOPLEFT", frame, "TOPLEFT", 66, -36)
fireText:SetWidth(330)
fireText:SetWordWrap(false)

local accentButton = CreateFrame("Button", nil, frame)
accentButton:SetSize(240, 20)
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
-- The page: the whole tale, as a block of text
---------------------------------------------------------------------------

local pageBox = CreateFrame("Frame", nil, inset, "InsetFrameTemplate")
pageBox:SetPoint("TOPLEFT", inset, "TOPLEFT", GRID_X - 4, PAGE_TOP)
pageBox:SetSize(GRID_WIDTH + 8, PAGE_HEIGHT)
pageBox:Hide()

local tellButton = button(pageBox, "Tell it", 100)
tellButton:SetPoint("TOPRIGHT", pageBox, "TOPRIGHT", -6, -5)

local pageTitle = text(pageBox, "GameFontNormal", "TOPLEFT", pageBox, "TOPLEFT", 10, -10)
pageTitle:SetWordWrap(false)
local pageInfo = text(pageBox, "GameFontDisableSmall", "LEFT", pageTitle, "RIGHT", 10, 0)
pageInfo:SetWordWrap(false)

local moreAbove = text(pageBox, "GameFontDisableSmall", "TOPLEFT", pageBox, "TOPLEFT", 32, -PAGE_HEADER, "...")
local moreBelow = text(pageBox, "GameFontDisableSmall", "BOTTOMLEFT", pageBox, "BOTTOMLEFT", 32, 4, "...")

local pageRows = {}

local function pageRow(index)
	local made = pageRows[index]
	if made then
		return made
	end
	made = CreateFrame("Button", nil, pageBox)
	made:SetSize(GRID_WIDTH - 4, 14)
	made.Current = made:CreateTexture(nil, "BACKGROUND")
	made.Current:SetAllPoints()
	made.Current:SetColorTexture(R, G, B, 0.18)
	made.Highlight = made:CreateTexture(nil, "HIGHLIGHT")
	made.Highlight:SetAllPoints()
	made.Highlight:SetColorTexture(1, 1, 1, 0.06)
	made.Number = made:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	made.Number:SetPoint("TOPRIGHT", made, "TOPLEFT", 20, -1)
	made.Number:SetJustifyH("RIGHT")
	made.Text = made:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	made.Text:SetPoint("TOPLEFT", made, "TOPLEFT", 26, -1)
	made.Text:SetWidth(PAGE_TEXT_WIDTH)
	made.Text:SetJustifyH("LEFT")
	made.Text:SetJustifyV("TOP")
	made.Text:SetWordWrap(true)
	made:SetScript("OnClick", function(self) onRowClick(self) end)
	made:SetScript("OnEnter", function(self) showRowTooltip(self) end)
	made:SetScript("OnLeave", tooltipOff)
	pageRows[index] = made
	return made
end

---------------------------------------------------------------------------
-- Your Own: making buttons
---------------------------------------------------------------------------

local editor = CreateFrame("Frame", nil, inset)
editor:SetSize(GRID_WIDTH, 200)
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

local editorHint = text(editor, "GameFontDisableSmall", "TOPLEFT", linesLabel, "BOTTOMLEFT", 0, -32,
	"A line of just /wait 3 is a 3-second pause, for a punchline. {target:friends} is your target's name, or \"friends\" without one. {his} becomes her for a female character.")
editorHint:SetWidth(GRID_WIDTH)
editorHint:SetWordWrap(true)

local status = text(editor, "GameFontHighlightSmall", "TOPLEFT", editorHint, "BOTTOMLEFT", 0, -10)
status:SetWidth(GRID_WIDTH)
status:SetWordWrap(true)

---------------------------------------------------------------------------
-- The bar along the bottom: the tale being told
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
frame.Page, frame.PageTitle, frame.PageInfo, frame.PageRows, frame.TellButton = pageBox, pageTitle, pageInfo, pageRows, tellButton
frame.MoreAbove, frame.MoreBelow = moreAbove, moreBelow
frame.Editor, frame.NameBox, frame.LinesBox, frame.SaveButton, frame.RemoveButton, frame.Status =
	editor, nameBox, linesBox, saveButton, removeButton, status
frame.TellText, frame.NextButton, frame.StopButton = tellText, nextButton, stopButton

---------------------------------------------------------------------------
-- Behaviour
---------------------------------------------------------------------------

local shownKey -- the category on show
local page = 1
local selected = {}     -- category key -> the tale picked for its page
local pickedDuring = {} -- category key -> the tale being told when that was picked

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

local function contains(list, wanted)
	for _, item in ipairs(list) do
		if item == wanted then
			return true
		end
	end
	return false
end

-- "about 20 seconds", "about a minute", "about 2 minutes".
local function roughly(seconds)
	if seconds < 50 then
		return "about " .. math.max(5, math.floor(seconds / 5 + 0.5) * 5) .. " seconds"
	elseif seconds < 90 then
		return "about a minute"
	end
	return "about " .. math.floor(seconds / 60 + 0.5) .. " minutes"
end
ns.Roughly = roughly

local function linesAndTime(lines)
	local said = #lines == 1 and "1 line" or (#lines .. " lines")
	if #lines < 2 then
		return said
	end
	return said .. ", " .. roughly(ns.TellingTime(lines))
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
		tellText:SetText(where .. " - " .. (state.label or "next line") .. " in " .. math.ceil(state.dueIn or 0))
		nextButton:SetText("Say it now")
		nextButton:Show()
	else
		tellText:SetText(where .. " - paused")
		nextButton:SetText("Next line")
		nextButton:Show()
	end
	stopButton:Show()
end

local function beingTold()
	local state = ns.TellingState()
	return state and state.entry or false
end

local function pick(category, entry)
	selected[category.key] = entry
	pickedDuring[category.key] = beingTold()
end

-- The tale on the page: the one being told, unless another was picked to
-- read since it started; else the one picked, or the first.
local function pickedTale(category, entries)
	local told = beingTold()
	if told and contains(entries, told) and pickedDuring[category.key] ~= told then
		return told
	end
	local picked = selected[category.key]
	if picked and contains(entries, picked) then
		return picked
	end
	return entries[1]
end

-- Draws the tale on the page, line by line, with the pauses between.
-- While it is being told: lines said are grey, the line up next is lit.
-- If it is too long for the page, it follows the line being told.
local function drawPage(entry)
	if not entry then
		pageBox:Hide()
		return
	end
	pageBox:Show()
	local state = ns.TellingState()
	local telling = state and state.entry == entry
	local lines = telling and state.lines or ns.PrepareLines(entry)
	local current = telling and state.index or nil

	pageTitle:SetText(entry.label)
	pageInfo:SetText(linesAndTime(lines))
	tellButton:SetText(telling and "Start over" or "Tell it")

	-- What goes on the page, in order: { line = index } or { beat = index }.
	local rows = {}
	for index, line in ipairs(lines) do
		if index > 1 and line.beat and line.beat > 0 then
			rows[#rows + 1] = { beat = index }
		end
		rows[#rows + 1] = { line = index }
	end

	local me = ns.PlayerName()
	local heights, total, currentRow = {}, 0, nil
	for index, row in ipairs(rows) do
		local made = pageRow(index)
		made.entry, made.lineIndex = entry, row.line
		made.Current:SetShown(false)
		if row.beat then
			local beat = lines[row.beat].beat
			made.Number:SetText("")
			made.Text:SetText("|cff808080- pause, " .. beat .. (beat == 1 and " second" or " seconds") .. " -|r")
			made:EnableMouse(false)
			if current == row.beat then
				currentRow = currentRow or index
			end
		else
			local line = lines[row.line]
			local words = line.text
			if line.kind == "EMOTE" then
				words = me .. " " .. words
			end
			local color = KIND_COLOR[line.kind]
			if current and row.line < current then
				color = { 0.5, 0.5, 0.5 }
			end
			made.Text:SetText(words)
			made.Text:SetTextColor(color[1], color[2], color[3])
			made.Number:SetText(row.line)
			made:EnableMouse(true)
			if current == row.line then
				made.Current:SetShown(true)
				currentRow = currentRow or index
			end
		end
		heights[index] = (made.Text:GetStringHeight() or 12) + 2
		total = total + heights[index] + 3
	end

	local room = PAGE_HEIGHT - PAGE_HEADER - 14
	local first = 1
	if total > room and currentRow then
		first = math.max(1, currentRow - 1)
	end
	moreAbove:SetShown(first > 1)
	local y = -PAGE_HEADER - (first > 1 and 12 or 0)
	local hiddenBelow = false
	for index = 1, #rows do
		local made = pageRows[index]
		if index < first or hiddenBelow or (-y + heights[index]) > (PAGE_HEIGHT - 14) then
			hiddenBelow = hiddenBelow or index >= first
			made:Hide()
		else
			made:ClearAllPoints()
			made:SetPoint("TOPLEFT", pageBox, "TOPLEFT", 4, y)
			made:SetHeight(heights[index])
			made:Show()
			y = y - heights[index] - 3
		end
	end
	moreBelow:SetShown(hiddenBelow)
	for index = #rows + 1, #pageRows do
		pageRows[index]:Hide()
	end
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
	local withPage = ns.HasPage(current)

	local picked = withPage and pickedTale(current, entries) or nil

	local rows = (current.mine and MINE_ROWS) or (withPage and TALE_ROWS) or ROWS
	local perPage = rows * COLUMNS
	local pages = math.max(1, math.ceil(#entries / perPage))
	page = math.min(math.max(page, 1), pages)
	for slot = 1, perPage do
		local entry = entries[(page - 1) * perPage + slot]
		local made = gridButton(slot)
		made.entry, made.category = entry, current
		if entry then
			made:SetText(colored(current, entry.label))
			if picked == entry then
				made:LockHighlight()
			else
				made:UnlockHighlight()
			end
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
	drawPage(picked)

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

-- What everyone will see, as near as can be told before it is said. A
-- tale with a page only says how long it is: the page has the words.
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
	local lines = ns.PrepareLines(entry)
	if self.category and ns.HasPage(self.category) then
		GameTooltip:AddLine(linesAndTime(lines) .. ".", 1, 1, 1)
		GameTooltip:AddLine("Click to read it below, then Tell it.", 0.7, 0.7, 0.7, true)
		GameTooltip:Show()
		return
	end
	local me = ns.PlayerName()
	for index, line in ipairs(lines) do
		if index > MAX_SHOWN then
			GameTooltip:AddLine("...and " .. (#lines - MAX_SHOWN) .. " more lines.", 0.7, 0.7, 0.7)
			break
		end
		if line.beat and line.beat > 0 and index > 1 then
			GameTooltip:AddLine("(pause, " .. line.beat .. " seconds)", 0.5, 0.5, 0.5)
		end
		local color = KIND_COLOR[line.kind]
		if line.kind == "EMOTE" then
			GameTooltip:AddLine(me .. " " .. line.text, color[1], color[2], color[3], true)
		else
			GameTooltip:AddLine(me .. KIND_SAYS[line.kind] .. line.text, color[1], color[2], color[3], true)
		end
	end
	if #lines == 1 and ns.DoesStraightAway(lines[1]) then
		GameTooltip:AddLine("Click to do it now.", 0.7, 0.7, 0.7, true)
	elseif #lines > 1 then
		GameTooltip:AddLine("Click to start. Each line goes in your chat line: press Enter to say it, and the next one follows once everyone has read it.", 0.7, 0.7, 0.7, true)
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
	if self.category and ns.HasPage(self.category) then
		-- A tale: read it on the page first.
		pick(self.category, entry)
	else
		ns.Tell(entry)
	end
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

-- A line on the page: tell the tale from there.
function onRowClick(self)
	local entry, index = self.entry, self.lineIndex
	if not entry or not index then
		return
	end
	local state = ns.TellingState()
	if state and state.entry == entry then
		ns.JumpTo(index)
	else
		ns.Tell(entry, index)
	end
	update()
end

function showRowTooltip(self)
	if not self.lineIndex then
		return
	end
	hint(self, "Line " .. self.lineIndex, "Click to tell it from this line.")
end

tellButton:SetScript("OnClick", function()
	local current = currentCategory()
	local entry = pickedTale(current, ns.EntriesOf(current))
	if entry then
		ns.Tell(entry)
		update()
	end
end)
tellButton:SetScript("OnEnter", function(self)
	hint(self, self:GetText(), "Tells it a line at a time. After each line you say, the next waits until everyone has had time to read it, and longer before a punchline.",
		"Each line goes in your chat line: press Enter to say it.")
end)
tellButton:SetScript("OnLeave", tooltipOff)

randomButton:SetScript("OnClick", function()
	local current = currentCategory()
	local entry = ns.RandomEntry(current)
	if entry then
		if ns.HasPage(current) then
			pick(current, entry)
		end
		ns.Tell(entry)
		update()
	end
end)
randomButton:SetScript("OnEnter", function(self)
	hint(self, "Surprise me", "Says something from this category at random.")
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
nextButton:SetScript("OnEnter", function(self)
	local state = ns.TellingState()
	if state and state.pending then
		hint(self, "Say it now", "Puts the next line in the chat line straight away, without waiting for everyone to finish reading.")
	else
		hint(self, "Next line", "Puts the line back in the chat line, to carry on.")
	end
end)
nextButton:SetScript("OnLeave", tooltipOff)
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

-- While the window is open, the countdowns tick (to the camp benefits,
-- and to the next line of a tale), and switching Krump or Juju on or off
-- brings their categories in or out.
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
		updateTelling()
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
