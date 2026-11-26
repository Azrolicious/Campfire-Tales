-- Campfire Tales tests. Run from anywhere with a plain Lua 5.1:
--
--     lua5.1 tests/run.lua
--
-- Loads the addon into a stand-in game client (tests/mock.lua), sits down
-- at a campfire, clicks buttons and presses Enter.
--
-- If Krump or Juju sits next to Campfire Tales (in the AddOns folder, say),
-- they are loaded beside it too, to check that campfire lines come out in
-- Ork and troll. Point KRUMP_DIR or JUJU_DIR at them if they live elsewhere.

local root = (arg and arg[0] or "tests/run.lua"):match("^(.*)[/\\]tests[/\\][^/\\]+$") or "."
package.path = root .. "/tests/?.lua;" .. package.path

local Mock = require("mock")

local passed, failed = 0, 0

local function check(name, got, want)
	if got == want then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL  " .. name)
		print("      want: " .. tostring(want))
		print("      got:  " .. tostring(got))
	end
end

local function contains(text, part)
	return type(text) == "string" and string.find(text, part, 1, true) ~= nil
end

-- Krump and Juju, if they can be found.
local function findAddon(name, variable)
	local candidates = { os.getenv(variable), root .. "/../" .. name, root .. "/../" .. string.lower(name) }
	for _, dir in pairs(candidates) do
		local file = dir and io.open(dir .. "/" .. name .. ".toc")
		if file then
			file:close()
			return dir
		end
	end
	return nil
end
local KRUMP = findAddon("Krump", "KRUMP_DIR")
local JUJU = findAddon("Juju", "JUJU_DIR")

-- A game with Campfire Tales loaded, and Krump and Juju first if asked for.
local function newGame(config, with)
	config = config or {}
	if config.race == nil then
		config.race = "Human"
	end
	local addons = {}
	for _, name in ipairs(with or {}) do
		local dir = (name == "Krump" and KRUMP) or (name == "Juju" and JUJU)
		addons[#addons + 1] = { root = dir, name = name }
	end
	addons[#addons + 1] = { root = root, name = "CampfireTales" }
	return Mock.new(config):load(addons)
end

local function window(game)
	return game.env.CampfireTalesFrame
end

-- The category button with this name, in the window's list.
local function categoryButton(game, name)
	for _, made in ipairs(window(game).CategoryButtons) do
		if made.shown and made.category and made.category.name == name then
			return made
		end
	end
	return nil
end

local function categoryNames(game)
	local names = {}
	for _, made in ipairs(window(game).CategoryButtons) do
		if made.shown then
			names[#names + 1] = made.category.name
		end
	end
	return table.concat(names, ", ")
end

local function showCategory(game, name)
	local made = categoryButton(game, name)
	assert(made, "no category " .. name .. " in: " .. categoryNames(game))
	made:click()
end

-- The button with this label, on the page on show. Labels can be coloured.
local function button(game, label)
	for _, made in ipairs(window(game).Buttons) do
		if made.shown and made.entry and made.entry.label == label then
			return made
		end
	end
	return nil
end

local function click(game, label, mouseButton)
	local made = button(game, label)
	assert(made, "no button " .. label)
	made:click(mouseButton)
end

local function shownButtons(game)
	local count = 0
	for _, made in ipairs(window(game).Buttons) do
		if made.shown then
			count = count + 1
		end
	end
	return count
end

local function hover(game, made)
	made:run("OnEnter")
	return table.concat(game.tooltip, "\n")
end

local function openWindow(game, category)
	game.env.SlashCmdList.CAMPFIRETALES("")
	if category then
		showCategory(game, category)
	end
end

---------------------------------------------------------------------------
-- What there is to say
---------------------------------------------------------------------------

do
	local game = newGame()
	local ns = game.ns
	local KNOWN = { target = true, me = true, zone = true, time = true, his = true, him = true, he = true }
	-- the longest names and places the game is likely to fill in
	local long = {
		target = "Thundermaneson", me = "Bloodfeatherz", zone = "The Hinterlands Overlook Path",
		time = "afternoon", pronouns = { his = "their", him = "them", he = "they" },
	}

	local function checkCategory(category, seenKeys)
		check("category has a key: " .. tostring(category.name), type(category.key), "string")
		check("category key is unique: " .. category.key, seenKeys[category.key], nil)
		seenKeys[category.key] = true
		check("category has a name: " .. category.key, type(category.name), "string")
		check("category says what it is: " .. category.key, type(category.about), "string")
		local entries = ns.Tales.Entries(category)
		check("category has buttons: " .. category.key, #entries > 0, true)
		check("category fits on one page: " .. category.key, #entries <= ns.ROWS * ns.COLUMNS, true)
		local labels = {}
		for _, entry in ipairs(entries) do
			local where = category.key .. " / " .. tostring(entry.label)
			check("label fits on its button: " .. where, #entry.label <= 26, true)
			check("label is unique: " .. where, labels[entry.label], nil)
			labels[entry.label] = true
			check("button has lines: " .. where, #entry.lines > 0, true)
			for index, line in ipairs(entry.lines) do
				local at = where .. " line " .. index
				check("no | in a line: " .. at, string.find(line, "|", 1, true), nil)
				for word in string.gmatch(line, "{(%a+)[^}]*}") do
					check("known {word}: " .. at .. " {" .. word .. "}", KNOWN[word], true)
				end
				local kind, text = ns.ParseLine(ns.Fill(line, long))
				check("line fits in chat: " .. at, #text <= 200, true)
				check("line is said, yelled or acted: " .. at, kind == "SAY" or kind == "YELL" or kind == "EMOTE", true)
				check("nothing left in curly brackets: " .. at, string.find(text, "[{}]"), nil)
			end
		end
	end

	local seenKeys = { mine = true }
	for _, category in ipairs(ns.Tales.categories) do
		checkCategory(category, seenKeys)
	end
	for name, category in pairs(ns.Tales.accents) do
		checkCategory(category, seenKeys)
		check("accent tales are for Krump or Juju: " .. name, name == "Krump" or name == "Juju", true)
	end
	check("ten categories to begin with", #ns.Tales.categories, 10)
	local names = {}
	for _, category in ipairs(ns.Tales.categories) do
		names[#names + 1] = category.name
	end
	check("the categories, in order", table.concat(names, ", "),
		"Greetings, Small Talk, Jokes, Riddles, Short Stories, Spooky Tales, Songs, Toasts, Fireside, Farewells")
end

---------------------------------------------------------------------------
-- Filling in the words in curly brackets
---------------------------------------------------------------------------

do
	local game = newGame({ name = "Brenna", sex = 3, zone = "Elwynn Forest", subzone = "Goldshire", hour = 9 })
	local ns = game.ns
	check("fill: no target, a word given", ns.Fill("Well met, {target:friends}!"), "Well met, friends!")
	check("fill: no target, no word given", ns.Fill("Hello, {target}."), "Hello, friend.")
	game.target = "Grukk"
	check("fill: your target", ns.Fill("Well met, {target:friends}!"), "Well met, Grukk!")
	check("fill: your target without a word", ns.Fill("Hello, {target}."), "Hello, Grukk.")
	game.target = nil
	check("fill: her", ns.Fill("/e warms {his} hands."), "/e warms her hands.")
	check("fill: she", ns.Fill("{he} sits"), "she sits")
	check("fill: your name", ns.Fill("I am {me}."), "I am Brenna.")
	check("fill: the subzone", ns.Fill("First time in {zone}?"), "First time in Goldshire?")
	check("fill: morning", ns.Fill("Good {time}!"), "Good morning!")
	check("fill: something unknown is left alone", ns.Fill("{banana} and {target:friends}"), "{banana} and friends")

	local afternoon = newGame({ hour = 14, zone = "Durotar" })
	check("fill: afternoon", afternoon.ns.Fill("{time}"), "afternoon")
	check("fill: the zone when there is no subzone", afternoon.ns.Fill("{zone}"), "Durotar")
	check("fill: his for a male character", afternoon.ns.Fill("{his}"), "his")
	local night = newGame({ hour = 2 })
	check("fill: late at night is still evening", night.ns.Fill("Good {time}."), "Good evening.")
	check("fill: nowhere in particular", night.ns.Fill("{zone}"), "these parts")
	local nobody = newGame({ sex = 1 })
	check("fill: their when the game does not say", nobody.ns.Fill("{his} pack"), "their pack")

	check("parse: say", select(1, ns.ParseLine("Hello there.")), "SAY")
	local kind, text = ns.ParseLine("/e pokes the fire.")
	check("parse: action", kind .. "|" .. text, "EMOTE|pokes the fire.")
	kind, text = ns.ParseLine("/y BOO!")
	check("parse: yell", kind .. "|" .. text, "YELL|BOO!")
	kind, text = ns.ParseLine("/me waves.")
	check("parse: /me", kind .. "|" .. text, "EMOTE|waves.")
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

do
	local game = newGame()
	local frame = window(game)
	check("window: shut after login", frame.shown, false)
	check("window: has a title", frame.title, "Campfire Tales")
	game.env.SlashCmdList.CAMPFIRETALES("")
	check("window: /tales opens it", frame.shown, true)
	check("window: categories", categoryNames(game),
		"Greetings, Small Talk, Jokes, Riddles, Short Stories, Spooky Tales, Songs, Toasts, Fireside, Farewells, Your Own")
	check("window: opens on Greetings", frame.Title.text, "Greetings")
	check("window: Greetings is picked", categoryButton(game, "Greetings").Selected.shown, true)
	check("window: a button for each greeting", shownButtons(game), #game.ns.Tales.Entries(game.ns.Tales.categories[1]))
	check("window: idle hint", contains(frame.TellText.text, "Enter says them"), true)
	check("window: Stop is hidden while nothing is told", frame.StopButton.shown, false)
	check("window: no accent line without Krump or Juju", frame.AccentButton.shown, false)
	check("window: away from a fire", contains(frame.FireText.text, "Sit down by a campfire"), true)
	check("window: the editor is only on Your Own", frame.Editor.shown, false)
	check("window: no pages when it all fits", frame.NextPage.shown, false)

	showCategory(game, "Jokes")
	check("window: Jokes", frame.Title.text, "Jokes")
	check("window: Jokes is picked", categoryButton(game, "Jokes").Selected.shown, true)
	check("window: Greetings is not", categoryButton(game, "Greetings").Selected.shown, false)
	check("window: remembers the category", game.ns.db.category, "jokes")
	check("window: the joke buttons", button(game, "Hearthstone") ~= nil, true)

	local tooltip = hover(game, button(game, "Hearthstone"))
	check("tooltip: who says what", contains(tooltip, "Grokk says: Me and my hearthstone"), true)
	check("tooltip: both lines", contains(tooltip, "Grokk says: Neither of us"), true)
	check("tooltip: how it is told", contains(tooltip, "press Enter to say it, and the next one follows"), true)
	categoryButton(game, "Spooky Tales"):run("OnEnter")
	check("tooltip: a category says what it is", contains(table.concat(game.tooltip, "\n"), "fire burning low"), true)

	frame:Hide()
	game.env.SlashCmdList.CAMPFIRETALES("")
	check("window: opens where it was left", frame.Title.text, "Jokes")
	game.env.SlashCmdList.CAMPFIRETALES("")
	check("window: /tales again shuts it", frame.shown, false)
	game.env.SlashCmdList.CAMPFIRETALES("spooky")
	check("window: /tales spooky opens on Spooky Tales", frame.shown and frame.Title.text, "Spooky Tales")
	game.env.CampfireTales_Toggle()
	check("window: the key binding shuts it", frame.shown, false)
	game.env.CampfireTales_OnAddonCompartmentClick(nil, "LeftButton")
	check("window: the addon menu opens it", frame.shown, true)
	game.env.CampfireTales_OnAddonCompartmentClick(nil, "RightButton")
	check("window: right-click in the addon menu opens the settings", game.openedCategory, "Campfire Tales")
	check("window: Escape closes it", game.env.UISpecialFrames[1], "CampfireTalesFrame")
end

---------------------------------------------------------------------------
-- Saying one line
---------------------------------------------------------------------------

do
	local game = newGame()
	local frame = window(game)
	openWindow(game, "Greetings")

	click(game, "Well met")
	check("say: goes in the chat line", game.openedChat, "/s Well met, friends! Pull up a log, the fire's warm.")
	local text, chatType = game:chatText()
	check("say: as Say", chatType, "SAY")
	check("say: nothing said yet", #game.sent, 0)
	check("say: the bar says to press Enter", contains(frame.TellText.text, "press Enter to say it"), true)
	check("say: Stop is on show", frame.StopButton.shown, true)
	local sent = game:pressEnter()
	check("say: Enter says it", sent and sent.text, "Well met, friends! Pull up a log, the fire's warm.")
	check("say: out loud", sent and sent.chatType, "SAY")
	check("say: done", game.ns.TellingState(), nil)
	check("say: the bar is idle again", contains(frame.TellText.text, "Enter says them"), true)
	game:wait(5)
	check("say: nothing more goes in the chat line", #game.opened, 1)

	game.target = "Grukk"
	click(game, "Well met")
	check("say: to your target", game.openedChat, "/s Well met, Grukk! Pull up a log, the fire's warm.")
	game:pressEscape()
	check("say: Escape pauses", game.ns.TellingState() and game.ns.TellingState().waiting, false)
	check("say: the bar says paused", contains(frame.TellText.text, "paused"), true)
	check("say: Next line is on show", frame.NextButton.shown, true)
	frame.NextButton:click()
	check("say: Next line puts it back", game.openedChat, "/s Well met, Grukk! Pull up a log, the fire's warm.")
	check("say: Next line hides while it waits for Enter", frame.NextButton.shown, false)
	frame.StopButton:click()
	check("say: Stop", game.ns.TellingState(), nil)
	game:pressEnter()
	game:wait(5)
	check("say: after Stop nothing follows", #game.opened, 3)
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

do
	local game = newGame()
	openWindow(game, "Fireside")
	click(game, "Poke the fire")
	check("action: done straight away", game.sent[1] and game.sent[1].text,
		"pokes the fire with a stick, sending sparks dancing into the dark.")
	check("action: as an emote", game.sent[1] and game.sent[1].chatType, "EMOTE")
	check("action: the chat line stays shut", game.openedChat, nil)
	check("action: nothing waits for Enter", game.ns.TellingState(), nil)

	local tooltip = hover(game, button(game, "Warm your hands"))
	check("action: tooltip shows the emote", contains(tooltip, "Grokk holds his hands out to the flames and sighs."), true)
	check("action: tooltip says it happens now", contains(tooltip, "Click to do it now."), true)

	game.target = "Grukk"
	click(game, "Share food")
	check("action: aimed at your target", game.sent[2] and game.sent[2].text, "offers Grukk a share of his supper.")
	game.target = nil
	click(game, "Share food")
	check("action: or everyone", game.sent[3] and game.sent[3].text, "offers everyone a share of his supper.")

	-- An action with words in it, no Krump or Juju: done straight away too.
	click(game, "Nod off")
	check("action: words and all", game.sent[4] and game.sent[4].text, "nods off, then jerks awake. \"I'm awake! I'm awake.\"")

	-- If the game will not let it through, it goes in the chat line.
	game.blockSending = true
	click(game, "Add a log")
	check("action: blocked, so it goes in the chat line", game.openedChat, "/e tosses another log on the fire. It crackles happily.")
	game.blockSending = false
	local sent = game:pressEnter()
	check("action: then Enter does it", sent and sent.chatType .. ": " .. sent.text, "EMOTE: tosses another log on the fire. It crackles happily.")

	-- Switched off: actions go in the chat line like everything else.
	game.settings.CAMPFIRETALES_ACTIONS_NOW.set(false)
	check("action: the setting", game.ns.db.actionsNow, false)
	click(game, "Count the stars")
	check("action: in the chat line when switched off", game.openedChat, "/e lies back and counts the stars.")
	check("action: tooltip says so", contains(hover(game, button(game, "Count the stars")), "Click to put it in your chat line"), true)
end

---------------------------------------------------------------------------
-- Telling a story, a line at a time
---------------------------------------------------------------------------

do
	local game = newGame()
	local frame = window(game)
	local ns = game.ns
	openWindow(game, "Short Stories")
	click(game, "The Last Ember")
	check("story: first line in the chat line", game.openedChat, "/s Let me tell you about the last ember.")
	check("story: the bar", contains(frame.TellText.text, "line 1 of 7 - press Enter"), true)
	game:pressEnter()
	check("story: first line said", game.sent[1] and game.sent[1].text, "Let me tell you about the last ember.")
	check("story: the next is on its way", ns.TellingState().pending, true)
	check("story: the bar says coming up", contains(frame.TellText.text, "line 2 of 7 - coming up"), true)
	game:wait(0.5)
	check("story: not straight away", #game.opened, 1)
	game:wait(0.6)
	check("story: then the second line", game.openedChat,
		"/s Long ago, a traveller crossed the mountains in deep winter, carrying a single ember in a clay pot.")
	game:pressEscape()
	check("story: Escape pauses it", ns.TellingState().index, 2)
	game:wait(5)
	check("story: and it stays paused", #game.opened, 2)
	ns.NextLine()
	check("story: carry on", game.openedChat,
		"/s Long ago, a traveller crossed the mountains in deep winter, carrying a single ember in a clay pot.")
	-- A slash command instead of the line does not count as saying it.
	game.chatBox.text = "/nosuchcommand"
	game:pressEnter()
	game:wait(2)
	check("story: a slash command does not count", ns.TellingState().index, 2)
	game.env.CampfireTales_NextLine()
	for _ = 2, 6 do
		game:pressEnter()
		game:wait(1)
	end
	check("story: the last line is an action", game.openedChat, "/e gestures at the flames. \"Who knows? Maybe it was this one.\"")
	local sent = game:pressEnter()
	check("story: said as an emote", sent and sent.chatType, "EMOTE")
	check("story: every line said", #game.sent, 7)
	check("story: finished", ns.TellingState(), nil)
	game:wait(5)
	check("story: nothing after the end", #game.opened, 9)

	-- Answering someone between lines: the next line waits for you.
	click(game, "The Smallest Lantern")
	game:pressEnter()
	game:startTyping("haha, go on")
	game:wait(3)
	check("story: waits while you type", game.chatBox.text, "haha, go on")
	check("story: still on its way", ns.TellingState().pending, true)
	local reply = game:pressEnter()
	check("story: your own words are said", reply and reply.text, "haha, go on")
	check("story: and do not count as a line", ns.TellingState().index, 2)
	game:wait(1)
	check("story: then the next line", game.openedChat,
		"/s A gnome tinker built it out of a thimble, a spring and a spark of something she wouldn't name.")
	ns.StopTelling()
	game:pressEscape()

	-- Picking another story part way through starts that one instead.
	click(game, "The Smallest Lantern")
	game:pressEnter()
	click(game, "Hogger's Day Off")
	check("story: another one", ns.TellingState().title, "Hogger's Day Off")
	game:wait(5)
	check("story: the old one's next line never comes", game.openedChat,
		"/s Here's one you won't believe. It's the story of Hogger's day off.")

	-- /tales stop
	game.env.SlashCmdList.CAMPFIRETALES("stop")
	check("story: /tales stop", ns.TellingState(), nil)
	game.env.SlashCmdList.CAMPFIRETALES("next")
	check("story: /tales next with no story", contains(game.printed[#game.printed], "No story is being told"), true)

	-- An action in the middle of a story is done without stopping it.
	click(game, "The Stars Above")
	game:pressEnter()
	showCategory(game, "Fireside")
	click(game, "Poke the fire")
	check("story: an action on the side", game.sent[#game.sent].chatType, "EMOTE")
	check("story: carries on after it", ns.TellingState() and ns.TellingState().title, "The Stars Above")

	-- Yelling: the spooky one ends with a BOO!
	ns.StopTelling()
	showCategory(game, "Spooky Tales")
	click(game, "The Lantern in Duskwood")
	for _ = 1, 5 do
		game:pressEnter()
		game:wait(1)
	end
	check("story: a yell", game.openedChat, "/y BOO!")
	local boo = game:pressEnter()
	check("story: yelled", boo and boo.chatType .. ": " .. boo.text, "YELL: BOO!")

	-- Riddles and jokes are two lines.
	showCategory(game, "Riddles")
	click(game, "Hungry fire")
	game:pressEnter()
	game:wait(1)
	check("riddle: the answer is ready", game.openedChat, "/s A fire! Like this one. So please don't pour your drink on it.")
	game:pressEnter()
	check("riddle: done", ns.TellingState(), nil)
end

---------------------------------------------------------------------------
-- Surprise me, and /tales random
---------------------------------------------------------------------------

do
	local game = newGame()
	local ns = game.ns
	openWindow(game, "Jokes")
	local labels = {}
	for _, entry in ipairs(ns.Tales.Entries(ns.Tales.categories[3])) do
		labels[entry.label] = true
	end
	window(game).RandomButton:click()
	check("random: something from the category on show", labels[ns.TellingState().title], true)
	ns.StopTelling()
	game.env.SlashCmdList.CAMPFIRETALES("random spook")
	local spooky = {}
	for _, entry in ipairs(ns.Tales.Entries(ns.Tales.categories[6])) do
		spooky[entry.label] = true
	end
	check("random: /tales random spook finds Spooky Tales", spooky[ns.TellingState().title], true)
	game.env.SlashCmdList.CAMPFIRETALES("random nonsense")
	check("random: no such category", contains(game.printed[#game.printed], "No category called \"nonsense\""), true)
	game.env.SlashCmdList.CAMPFIRETALES("random mine")
	check("random: an empty category", contains(game.printed[#game.printed], "Your Own has nothing in it yet"), true)
	showCategory(game, "Your Own")
	check("random: Surprise me is off on an empty page", window(game).RandomButton.enabled, false)
end

---------------------------------------------------------------------------
-- Your own buttons
---------------------------------------------------------------------------

do
	local game = newGame()
	local frame = window(game)
	local ns = game.ns
	openWindow(game, "Your Own")
	check("mine: the editor is on show", frame.Editor.shown, true)
	check("mine: empty to begin with", frame.Empty.shown, true)

	frame.NameBox:SetText("Bad pun")
	frame.LinesBox:SetText("Why did the gnome cross the road? // To get to the other side. Of the explosion.")
	frame.SaveButton:click()
	check("mine: saved", frame.Status.text, "Saved \"Bad pun\", 2 lines.")
	check("mine: boxes cleared", frame.NameBox.text, "")
	check("mine: kept", ns.db.mine[1] and ns.db.mine[1].label, "Bad pun")
	check("mine: two lines", ns.db.mine[1] and #ns.db.mine[1].lines, 2)
	check("mine: a button for it", button(game, "Bad pun") ~= nil, true)
	check("mine: in orange", button(game, "Bad pun").text, "|cffff9933Bad pun|r")
	check("mine: not empty any more", frame.Empty.shown, false)
	click(game, "Bad pun")
	check("mine: says it", game.openedChat, "/s Why did the gnome cross the road?")
	game:pressEnter()
	game:wait(1)
	check("mine: second line", game.openedChat, "/s To get to the other side. Of the explosion.")
	game:pressEscape()
	ns.StopTelling()

	check("mine: an action of your own", (ns.SaveMine("Bow", "/e bows to {target:everyone}.")), true)
	click(game, "Bow")
	check("mine: done straight away", game.sent[#game.sent].text, "bows to everyone.")

	-- Right-click loads it into the boxes to change.
	click(game, "Bad pun", "RightButton")
	check("mine: right-click loads the name", frame.NameBox.text, "Bad pun")
	check("mine: and the lines", frame.LinesBox.text,
		"Why did the gnome cross the road? // To get to the other side. Of the explosion.")
	frame.LinesBox:SetText("Just the one line now.")
	frame.SaveButton:click()
	check("mine: same name replaces it", #ns.db.mine, 2)
	check("mine: with the new line", ns.db.mine[1].lines[1], "Just the one line now.")
	check("mine: tooltip says right-click", contains(hover(game, button(game, "Bad pun")), "Right-click to change it"), true)

	local ok, message = ns.SaveMine("", "Hello")
	check("mine: needs a name", ok, false)
	ok, message = ns.SaveMine("Hello", "   ")
	check("mine: needs something to say", ok, false)
	check("mine: says how", contains(message, "// between lines"), true)
	ok = ns.SaveMine(string.rep("a", 25), "Hello")
	check("mine: name too long", ok, false)
	ok = ns.SaveMine("Long", string.rep("a", 201))
	check("mine: line too long", ok, false)
	ok = ns.SaveMine("Many", string.rep("line // ", 13))
	check("mine: too many lines", ok, false)
	ns.SaveMine("Colours", "Hello |cffff0000red|r")
	check("mine: no colour codes", ns.db.mine[3].lines[1], "Hello cffff0000redr")

	-- Paging: four rows of two fit above the editor.
	for index = 4, 10 do
		ns.SaveMine("Line " .. index, "Number " .. index)
	end
	check("mine: ten of them", #ns.db.mine, 10)
	check("mine: eight on a page", shownButtons(game), 8)
	check("mine: pages", frame.PageText.shown and frame.PageText.text, "1 / 2")
	check("mine: back is off on the first page", frame.PrevPage.enabled, false)
	frame.NextPage:click()
	check("mine: the second page", shownButtons(game), 2)
	check("mine: last of them", button(game, "Line 10") ~= nil, true)
	check("mine: next is off on the last page", frame.NextPage.enabled, false)
	frame.PrevPage:click()
	check("mine: back to the first", frame.PageText.text, "1 / 2")

	-- Removing.
	frame.NameBox:SetText("line 10")
	frame.RemoveButton:click()
	check("mine: removed", frame.Status.text, "Removed \"Line 10\".")
	check("mine: nine left", #ns.db.mine, 9)
	ok, message = ns.RemoveMine("Nope")
	check("mine: not one of yours", message, "\"Nope\" is not one of your buttons.")

	for index = 11, 40 do
		ns.SaveMine("Line " .. index, "Number " .. index)
	end
	check("mine: thirty at most", #ns.db.mine, ns.MAX_MINE)
	ok, message = ns.SaveMine("One more", "Too many")
	check("mine: full up", contains(message, "Remove one first"), true)

	-- Kept between sessions; anything broken is dropped.
	local saved = { CampfireTalesDB = { mine = { { label = "Kept", lines = { "Still here." } }, "broken", { label = 5 } } } }
	local again = newGame({ saved = saved })
	check("mine: kept after a reload", #again.ns.db.mine, 1)
	check("mine: the one kept", again.ns.db.mine[1].label, "Kept")
	check("settings: defaults filled in", again.ns.db.autoOpen, true)
end

---------------------------------------------------------------------------
-- Sitting down at a campfire
---------------------------------------------------------------------------

do
	local game = newGame()
	local frame = window(game)
	game:addAura("Well Fed", 600)
	check("fire: another buff does nothing", frame.shown, false)
	game:addAura("Welcoming Campfire", 60)
	check("fire: sitting down opens the window", frame.shown, true)
	check("fire: the countdown", frame.FireText.text, "Warming up by the fire: camp benefits in 1:00")
	check("fire: hello, the first time", contains(game.printed[1], "The fire's warm"), true)
	game:wait(15)
	check("fire: it counts down", frame.FireText.text, "Warming up by the fire: camp benefits in 0:45")
	frame:Hide()
	game:addAura("Well Fed", 600)
	check("fire: closed stays closed while you sit", frame.shown, false)
	game:wait(45)
	game:removeAura("Welcoming Campfire")
	game:addAura("Camp Benefits", 1800)
	check("fire: camp benefits do not open it", frame.shown, false)
	openWindow(game)
	check("fire: camp benefits", frame.FireText.text, "Camp benefits: 30:00 left")
	frame:Hide()
	game:removeAura("Camp Benefits")
	game:addAura("Welcoming Campfire", 60)
	check("fire: sitting down again opens it again", frame.shown, true)
	check("fire: hello only once", #game.printed, 1)

	game.settings.CAMPFIRETALES_AUTO_OPEN.set(false)
	frame:Hide()
	game:removeAura("Welcoming Campfire")
	game:addAura("Welcoming Campfire", 60)
	check("fire: not when switched off", frame.shown, false)
	game.env.SlashCmdList.CAMPFIRETALES("auto on")
	check("fire: /tales auto on", game.ns.db.autoOpen, true)
	game.env.SlashCmdList.CAMPFIRETALES("auto")
	check("fire: /tales auto flips it", game.ns.db.autoOpen, false)

	-- Logging in, or a /reload, by the fire does not pop it open.
	local again = Mock.new({ race = "Human" })
	again.auras["Welcoming Campfire"] = { name = "Welcoming Campfire", duration = 60, expirationTime = again.now + 30 }
	again:load({ { root = root, name = "CampfireTales" } })
	check("fire: not on login", again.env.CampfireTalesFrame.shown, false)
	again:fire("PLAYER_ENTERING_WORLD")
	check("fire: not after a loading screen", again.env.CampfireTalesFrame.shown, false)
	again.env.SlashCmdList.CAMPFIRETALES("")
	check("fire: but it knows", again.env.CampfireTalesFrame.FireText.text, "Warming up by the fire: camp benefits in 0:30")

	-- Older ways of reading buffs.
	for _, api in ipairs({ "byIndex", "unitBuff" }) do
		local old = newGame({ auraApi = api })
		old:addAura("Rested", 0)
		old:addAura("Welcoming Campfire", 60)
		check("fire: found with " .. api, old.env.CampfireTalesFrame.shown, true)
	end
end

---------------------------------------------------------------------------
-- Settings and chat commands
---------------------------------------------------------------------------

do
	local game = newGame()
	check("settings: registered", game.registeredCategory and game.registeredCategory.name, "Campfire Tales")
	for _, variable in ipairs({ "CAMPFIRETALES_AUTO_OPEN", "CAMPFIRETALES_ACTIONS_NOW", "CAMPFIRETALES_ACCENTS" }) do
		check("settings: " .. variable, game.settings[variable] ~= nil, true)
	end
	game.env.SlashCmdList.CAMPFIRETALES("config")
	check("settings: /tales config", game.openedCategory, "Campfire Tales")
	game.env.SlashCmdList.CAMPFIRETALES("help")
	check("help: lists the categories", contains(game.printed[#game.printed], "greetings, talk, jokes"), true)
	check("slash: /campfiretales too", game.env.SLASH_CAMPFIRETALES2, "/campfiretales")
end

---------------------------------------------------------------------------
-- With Krump
---------------------------------------------------------------------------

if not KRUMP then
	print("skipped: Krump is not next to Campfire Tales (set KRUMP_DIR to its folder)")
else
	local game = newGame({ race = "Orc", name = "Grokk" }, { "Krump" })
	local frame = window(game)
	local krump = game.addons.Krump
	check("krump: Krump is talking", game.ns.TalkingAccent(), "Krump")
	openWindow(game)
	check("krump: Ork categories", categoryNames(game),
		"Greetings, Small Talk, Jokes, Riddles, Short Stories, Spooky Tales, Songs, Toasts, Fireside, Farewells, Ork Yarns, Krump Emotes, Your Own")
	check("krump: says so at the top", frame.AccentButton.shown and contains(frame.AccentText.text, "is talking: words come out in Ork"), true)
	check("krump: in Krump's green", contains(frame.AccentText.text, "|cff6fbf3fKrump|r"), true)

	-- A greeting goes out in Ork.
	local english = "Well met, friends! Pull up a log, the fire's warm."
	local ork = krump.TranslateFor("SAY", english)
	check("krump: Ork is different", ork ~= english, true)
	showCategory(game, "Greetings")
	click(game, "Well met")
	check("krump: the preview above the chat line", game.env.KrumpPreviewFrame.shown, true)
	check("krump: shows the Ork", game.env.KrumpPreviewFrame.fontString.text, ork)
	local sent = game:pressEnter()
	check("krump: said in Ork", sent and sent.text, ork)
	check("krump: and the telling is done", game.ns.TellingState(), nil)
	check("krump: tooltip mentions Krump", contains(hover(game, button(game, "Well met")), "the Ork way"), true)

	-- A story, line by line, all in Ork.
	showCategory(game, "Ork Yarns")
	click(game, "The Boar That Fought Back")
	for index = 1, 6 do
		local line = game.ns.Tales.Entries(game.ns.Tales.accents.Krump)[3].lines[index]
		local said = game:pressEnter()
		check("krump: yarn line " .. index .. " in Ork", said and said.text, krump.TranslateFor("SAY", line))
		game:wait(1)
	end
	check("krump: yarn told", game.ns.TellingState(), nil)

	-- An action with words in it goes through the chat line, so Krump can
	-- say the words.
	showCategory(game, "Fireside")
	click(game, "Nod off")
	local nodOff = "nods off, then jerks awake. \"I'm awake! I'm awake.\""
	check("krump: action with words goes in the chat line", game.openedChat, "/e " .. nodOff)
	sent = game:pressEnter()
	check("krump: emote", sent and sent.chatType, "EMOTE")
	check("krump: the words in Ork", sent and sent.text, "nods off, then jerks awake. \"I'z awake! I'z awake.\"")
	local tooltip = hover(game, button(game, "Nod off"))
	check("krump: its tooltip says chat line", contains(tooltip, "Click to put it in your chat line"), true)
	-- Without words it is done straight away, as always.
	local before = #game.opened
	click(game, "Poke the fire")
	check("krump: plain action straight away", #game.opened, before)
	check("krump: plain action done", game.sent[#game.sent].text, "pokes the fire with a stick, sending sparks dancing into the dark.")

	-- Krump's emotes.
	showCategory(game, "Krump Emotes")
	check("krump: a button per emote", button(game, "/waaagh") ~= nil and button(game, "/loktar") ~= nil, true)
	check("krump: in Krump's green", button(game, "/waaagh").text, "|cff6fbf3f/waaagh|r")
	before = #game.sent
	click(game, "/waaagh")
	check("krump: /waaagh is done", #game.sent, before + 1)
	check("krump: by Krump", game.sent[#game.sent].text, krump.EmoteText("waaagh"))
	game.target = "Thrall"
	click(game, "/oi")
	check("krump: aimed at your target", game.sent[#game.sent].text, krump.EmoteText("oi", "Thrall"))
	game.target = nil
	check("krump: emote tooltip", contains(hover(game, button(game, "/oi")), "/oi emote"), true)
	krump.SaveOwnEmote("squig", "lets a squig loose.")
	frame:Hide()
	openWindow(game, "Krump Emotes")
	check("krump: your own Krump emotes too", button(game, "/squig") ~= nil, true)
	window(game).RandomButton:click()
	check("krump: Surprise me does an emote", #game.sent > before + 2, true)

	-- The accent button opens the Krump box.
	frame.AccentButton:click()
	check("krump: the accent line opens the Krump box", game.env.KrumpBoxFrame.shown, true)

	-- Krump off: back to the plain categories.
	game.env.SlashCmdList.KRUMP("off")
	game:wait(1)
	check("krump: switched off, no Ork categories", categoryNames(game),
		"Greetings, Small Talk, Jokes, Riddles, Short Stories, Spooky Tales, Songs, Toasts, Fireside, Farewells, Your Own")
	check("krump: back to the first category when Krump's goes", frame.Title.text, "Greetings")
	check("krump: no accent line", frame.AccentButton.shown, false)
	click(game, "Well met")
	sent = game:pressEnter()
	check("krump: said plainly", sent and sent.text, english)
	game.env.SlashCmdList.KRUMP("on")

	-- The setting.
	game.settings.CAMPFIRETALES_ACCENTS.set(false)
	check("krump: setting off hides the Ork categories", categoryButton(game, "Ork Yarns"), nil)
	check("krump: but the words still come out in Ork", frame.AccentButton.shown, true)
	game.settings.CAMPFIRETALES_ACCENTS.set(true)
	check("krump: setting on brings them back", categoryButton(game, "Ork Yarns") ~= nil, true)

	-- Not an Orc: Krump sleeps, and so do its categories.
	local human = newGame({ race = "Human" }, { "Krump" })
	check("krump: asleep on a human", human.ns.TalkingAccent(), nil)
	openWindow(human)
	check("krump: no Ork categories on a human", categoryButton(human, "Ork Yarns"), nil)

	-- Every line Campfire Tales has fits in chat once it is in Ork.
	local long = {
		target = "Thundermaneson", me = "Bloodfeatherz", zone = "The Hinterlands Overlook Path",
		time = "afternoon", pronouns = { his = "their", him = "them", he = "they" },
	}
	local categories = {}
	for _, category in ipairs(game.ns.Tales.categories) do
		categories[#categories + 1] = category
	end
	categories[#categories + 1] = game.ns.Tales.accents.Krump
	local tooLong = {}
	for _, category in ipairs(categories) do
		for _, entry in ipairs(game.ns.Tales.Entries(category)) do
			for _, line in ipairs(entry.lines) do
				local kind, text = game.ns.ParseLine(game.ns.Fill(line, long))
				local out = krump.Translator.Translate(text, { vocab = true, quotesOnly = kind == "EMOTE", maxBytes = 100000 })
				if #out > krump.Translator.MAX_BYTES then
					tooLong[#tooLong + 1] = entry.label
				end
			end
		end
	end
	check("krump: every line fits in chat in Ork", table.concat(tooLong, ", "), "")
end

---------------------------------------------------------------------------
-- With Juju
---------------------------------------------------------------------------

if not JUJU then
	print("skipped: Juju is not next to Campfire Tales (set JUJU_DIR to its folder)")
else
	local with = KRUMP and { "Krump", "Juju" } or { "Juju" }
	local game = newGame({ race = "Troll", name = "Zanjin" }, with)
	local juju = game.addons.Juju
	check("juju: Juju is talking", game.ns.TalkingAccent(), "Juju")
	openWindow(game)
	check("juju: troll categories", categoryButton(game, "Troll Tales") ~= nil and categoryButton(game, "Juju Emotes") ~= nil, true)
	check("juju: no Ork ones", categoryButton(game, "Ork Yarns"), nil)
	check("juju: says so at the top", contains(window(game).AccentText.text, "words come out in troll"), true)

	showCategory(game, "Small Talk")
	click(game, "What brings you here?")
	local sent = game:pressEnter()
	check("juju: said in troll", sent and sent.text, juju.TranslateFor("SAY", "So, what brings you out this way?"))
	check("juju: and it did change", sent and sent.text ~= "So, what brings you out this way?", true)

	showCategory(game, "Juju Emotes")
	local before = #game.sent
	click(game, "/voodoo")
	check("juju: /voodoo", game.sent[before + 1] and game.sent[before + 1].text, juju.EmoteText("voodoo"))

	local tooLong = {}
	for _, entry in ipairs(game.ns.Tales.Entries(game.ns.Tales.accents.Juju)) do
		for _, line in ipairs(entry.lines) do
			local kind, text = game.ns.ParseLine(line)
			local out = juju.Translator.Translate(text, { vocab = true, quotesOnly = kind == "EMOTE", maxBytes = 100000 })
			if #out > juju.Translator.MAX_BYTES then
				tooLong[#tooLong + 1] = entry.label
			end
		end
	end
	check("juju: Troll Tales fit in chat in troll", table.concat(tooLong, ", "), "")

	if KRUMP then
		-- An Orc with both: Krump talks.
		local orc = newGame({ race = "Orc" }, { "Krump", "Juju" })
		check("both: Krump talks on an Orc", orc.ns.TalkingAccent(), "Krump")
		-- /juju on an Orc switches Krump off: now Juju talks.
		orc.env.SlashCmdList.JUJU("on")
		check("both: /juju on, and Juju talks", orc.ns.TalkingAccent(), "Juju")
	end
end

---------------------------------------------------------------------------
-- The addon adds only the globals it means to
---------------------------------------------------------------------------

do
	local game = newGame()
	local expected = {
		CampfireTalesDB = true, CampfireTalesFrame = true,
		SLASH_CAMPFIRETALES1 = true, SLASH_CAMPFIRETALES2 = true,
		BINDING_HEADER_CAMPFIRETALES = true, BINDING_NAME_CAMPFIRETALES_TOGGLE = true,
		BINDING_NAME_CAMPFIRETALES_NEXT = true,
		CampfireTales_Toggle = true, CampfireTales_NextLine = true,
		CampfireTales_OnAddonCompartmentClick = true, CampfireTales_OnAddonCompartmentEnter = true,
		CampfireTales_OnAddonCompartmentLeave = true,
	}
	local mockGlobals = {}
	for key in pairs(Mock.new().env) do mockGlobals[key] = true end
	local stray = {}
	for key in pairs(game.env) do
		if not expected[key] and not mockGlobals[key] then
			stray[#stray + 1] = key
		end
	end
	table.sort(stray)
	check("no stray globals", table.concat(stray, ", "), "")
	for key in pairs(expected) do
		check("global exists: " .. key, game.env[key] ~= nil, true)
	end
end

---------------------------------------------------------------------------

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
