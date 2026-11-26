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
-- Enter on one line, the next is put in the chat line a moment later. Press
-- Escape to pause; the window's Next line button (or /tales next) carries
-- on from there. If you open the chat line yourself in between, to answer
-- someone, the next line waits until you are done.

local _, ns = ...

local strfind = string.find

local PAUSE = 1 -- seconds between saying one line and the next appearing

local CHAT_PREFIX = { SAY = "/s ", YELL = "/y ", EMOTE = "/e " }

local telling      -- { title, lines = { { kind, text } }, index }: the tale being told
local waiting = false -- the chat line holds the current line
local sent = false    -- and Enter was pressed on it
local pending = false -- the next line will be put in the chat line shortly
local ourBox       -- the chat box that line went into
local opening = false
local typing       -- a chat box with the keyboard, ours or not
local generation = 0  -- goes up whenever the telling changes, so old timers do nothing

local function readable(value)
	return type(value) == "string" and not (issecretvalue and issecretvalue(value))
end

local function openChat(text)
	local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
	if open then
		open(text)
		return true
	end
	return false
end

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
	ourBox, opening = nil, true
	openChat(CHAT_PREFIX[line.kind] .. line.text)
	ns.Refresh()
end

-- Puts the next line in the chat line once nobody is typing in it.
local function putWhenFree(mine)
	if mine ~= generation or not telling or not pending then
		return
	end
	if typing then
		C_Timer.After(PAUSE, function() putWhenFree(mine) end)
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
function ns.Tell(entry)
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
	telling = { title = entry.label, lines = lines, index = 1 }
	putLine()
	return true
end

-- Puts the current line (back) in the chat line. False if no tale is being
-- told.
function ns.NextLine()
	if not telling then
		return false
	end
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
	return {
		title = telling.title,
		index = telling.index,
		count = #telling.lines,
		waiting = waiting,   -- in the chat line now: press Enter
		pending = pending,   -- the next line is on its way
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
	local mine = generation
	C_Timer.After(PAUSE, function() putWhenFree(mine) end)
	ns.Refresh()
end

EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusLost", closed, owner)
EventRegistry:RegisterCallback("ChatFrame.OnEditBoxHide", closed, owner)
