-- Saying things. The game does not let addons speak out loud by themselves
-- in the open world, so every spoken line goes into the chat line, the same
-- as if you had typed it there, and Enter says it. That also means anything
-- that changes what you type on the way out (Krump, Juju) changes these too.
--
-- A one-line action (an emote) is done straight away instead, the way the
-- game's own emotes are. Unless Krump or Juju is talking and the action has
-- "spoken words" in it: then it goes into the chat line as well, so that
-- they can say the words their way.
--
-- A button with several lines is told one line at a time. After you press
-- Enter on one line, the next waits long enough for everyone to read the
-- one you just said, plus any pause written into the tale (a beat before
-- the punchline), and then goes into the chat line. The window counts it
-- down; "Say it now" skips the wait.
--
-- Press Escape to pause; the window's Next line button (or /tales next)
-- carries on from there. If you open the chat line yourself in between, to
-- answer someone, the next line waits until you are done.

local _, ns = ...

local strfind, gmatch = string.find, string.gmatch

local PAUSE = 1 -- the shortest wait between lines, in seconds

-- How long people get to read a line, by the pace setting.
local PACES = { quick = 0.6, steady = 1, slow = 1.5, off = 0 }
ns.PACE_ORDER = { "quick", "steady", "slow", "off" }
ns.PACE_NAMES = {
	quick = { "Quick", "Just enough time to read each line." },
	steady = { "Steady", "Time to read each line at an easy pace, and every pause written into the tale." },
	slow = { "Slow", "Plenty of time to read, for long lines and slow readers." },
	off = { "No waiting", "The next line is ready a moment after you say one. You set the pace." },
}

local CHAT_PREFIX = { SAY = "/s ", YELL = "/y ", EMOTE = "/e " }

local telling      -- { entry, title, lines = { { kind, text, beat } }, index, due }
local waiting = false -- the chat line holds the current line
local sent = false    -- and Enter was pressed on it
local pending = false -- the next line goes into the chat line once its wait is over
local ourBox       -- the chat box that line went into
local opening = false
local typing       -- a chat box with the keyboard, ours or not
local generation = 0  -- goes up whenever the telling changes, so old timers do nothing

local function readable(value)
	return type(value) == "string" and not (issecretvalue and issecretvalue(value))
end

local function now()
	local ok, time = pcall(GetTime)
	return ok and type(time) == "number" and time or 0
end

local function openChat(text)
	local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
	if open then
		open(text)
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- Time to read
---------------------------------------------------------------------------

-- Seconds to read a line at an easy pace: about four words a second, and
-- never less than two seconds or more than ten.
function ns.ReadingTime(text)
	local words = 0
	for _ in gmatch(text, "%S+") do
		words = words + 1
	end
	return math.min(10, math.max(2, 1 + words / 4))
end

local function pace()
	return PACES[ns.db and ns.db.pace] or PACES.steady
end

-- How long lines[index] waits after the line before it is said.
function ns.WaitBefore(lines, index)
	local line, before = lines[index], lines[index - 1]
	if not line or not before then
		return 0
	end
	local factor = pace()
	if factor == 0 then
		return PAUSE
	end
	return math.max(PAUSE, ns.ReadingTime(before.text) * factor + (line.beat or 0))
end

-- Roughly how long the listeners spend waiting through a whole tale.
function ns.TellingTime(lines)
	local total = 0
	for index = 2, #lines do
		total = total + ns.WaitBefore(lines, index)
	end
	return total
end

---------------------------------------------------------------------------
-- Telling
---------------------------------------------------------------------------

-- True if this line can be done the moment its button is clicked.
function ns.DoesStraightAway(line)
	if line.kind ~= "EMOTE" or not (ns.db and ns.db.actionsNow) then
		return false
	end
	-- Spoken words in an action go through the chat line while Krump or Juju
	-- is talking, so that they come out in the accent too.
	if strfind(line.text, "\"", 1, true) and ns.TalkingAccent and ns.TalkingAccent() then
		return false
	end
	return true
end

local function sendEmote(text)
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	return send ~= nil and pcall(send, text, "EMOTE")
end

local function putLine()
	local line = telling.lines[telling.index]
	generation = generation + 1
	waiting, sent, pending = true, false, false
	telling.due = nil
	ourBox, opening = nil, true
	openChat(CHAT_PREFIX[line.kind] .. line.text)
	ns.Refresh()
end

-- Puts the next line in the chat line once its wait is over and nobody is
-- typing in the chat line.
local function putWhenReady(mine)
	if mine ~= generation or not telling or not pending then
		return
	end
	local left = (telling.due or 0) - now()
	if left > 0.05 then
		C_Timer.After(left, function() putWhenReady(mine) end)
		return
	end
	if typing then
		C_Timer.After(PAUSE, function() putWhenReady(mine) end)
		return
	end
	putLine()
end

local function finish()
	telling = nil
	waiting, sent, pending, opening = false, false, false, false
	generation = generation + 1
	ns.Refresh()
end

-- Says what a button says. entry is { label = ..., lines = { ... } }, or a
-- button that runs something of its own (Krump's and Juju's emotes).
-- from: the line to start at, if not the first.
function ns.Tell(entry, from)
	if not entry then
		return false
	end
	if entry.run then
		entry.run()
		return true
	end
	local lines = ns.PrepareLines(entry)
	if #lines == 0 then
		return false
	end
	-- An action on its own: done now, and a story being told carries on.
	if #lines == 1 and ns.DoesStraightAway(lines[1]) then
		if sendEmote(lines[1].text) then
			return true
		end
		-- The game would not let it through: the chat line it is.
	end
	from = math.min(math.max(tonumber(from) or 1, 1), #lines)
	telling = { entry = entry, title = entry.label, lines = lines, index = from }
	putLine()
	return true
end

-- Puts the current line (back) in the chat line straight away, skipping
-- any wait. False if no tale is being told.
function ns.NextLine()
	if not telling then
		return false
	end
	putLine()
	return true
end

-- Carries on from another line of the tale being told.
function ns.JumpTo(index)
	if not telling or not telling.lines[index] then
		return false
	end
	telling.index = index
	putLine()
	return true
end

function ns.StopTelling()
	if telling then
		finish()
	end
end

-- What the window shows about the tale being told, or nil.
function ns.TellingState()
	if not telling then
		return nil
	end
	local line = telling.lines[telling.index]
	return {
		entry = telling.entry,
		title = telling.title,
		lines = telling.lines,
		index = telling.index,
		count = #telling.lines,
		waiting = waiting,   -- in the chat line now: press Enter
		pending = pending,   -- the next line is waiting for everyone to read
		dueIn = pending and math.max(0, (telling.due or 0) - now()) or nil,
		label = line and line.label, -- "punchline", "answer", or nil
	}
end

---------------------------------------------------------------------------
-- Watching the chat line
---------------------------------------------------------------------------

local owner = {}

EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function(_, editBox)
	typing = editBox
	if opening then
		ourBox, opening = editBox, false
	end
end, owner)

-- After slash commands are worked out and just before the text is sent.
-- A command such as /dance leaves nothing to send, so it does not count.
EventRegistry:RegisterCallback("ChatFrame.OnEditBoxPreSendText", function(_, editBox)
	if not waiting or (ourBox and editBox ~= ourBox) then
		return
	end
	local text = editBox:GetText()
	if readable(text) and strfind(text, "%S") then
		sent = true
	end
end, owner)

-- The chat line closed: either the line was said, or Escape was pressed.
local function closed(_, editBox)
	if editBox == typing then
		typing = nil
	end
	if not waiting or (ourBox and editBox ~= ourBox) then
		return
	end
	waiting, opening = false, false
	if not sent then
		ns.Refresh() -- paused
		return
	end
	telling.index = telling.index + 1
	if telling.index > #telling.lines then
		finish()
		return
	end
	pending = true
	local wait = ns.WaitBefore(telling.lines, telling.index)
	telling.due = now() + wait
	local mine = generation
	C_Timer.After(wait, function() putWhenReady(mine) end)
	ns.Refresh()
end

EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusLost", closed, owner)
EventRegistry:RegisterCallback("ChatFrame.OnEditBoxHide", closed, owner)
