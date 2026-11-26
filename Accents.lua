-- Campfire Tales with Krump and Juju.
--
-- Krump (Ork) and Juju (troll) change what you type into their accent just
-- before it is sent. Campfire Tales puts its lines in the chat line, so they
-- come out in the accent with nothing more to do, and the preview above the
-- chat line shows how before you press Enter.
--
-- On top of that, while one of them is the one talking on this character,
-- the window gets two more categories: tales written for that race (Ork
-- Yarns or Troll Tales), and a button for each of that addon's emotes
-- (/waaagh, /voodoo and the rest, your own ones too).
--
-- Krump and Juju sign in to the shared RoleplayAccents table so that only
-- one of them talks on a character. Campfire Tales only reads it.

local _, ns = ...

local strfind, strlower, strupper = string.find, string.lower, string.upper

-- What Campfire Tales knows about each one. Another accent addon that signs
-- in to RoleplayAccents works too, with its own name and plain colours.
local KNOWN = {
	Krump = { speech = "Ork", color = "6fbf3f", box = "Krump_ToggleBox" },
	Juju = { speech = "troll", color = "3fbfaf", box = "Juju_ToggleBox" },
}

local function ask(other, question)
	local ok, answer = pcall(other[question])
	return ok and answer == true
end

-- The accent addon talking on this character, or nil. Uses the same rule as
-- Krump and Juju: of the ones switched on, the one made for the character's
-- race talks; if neither or both are, the one first in the alphabet does.
function ns.TalkingAccent()
	local accents = RoleplayAccents
	if type(accents) ~= "table" then
		return nil
	end
	local best, bestNative
	for name, other in pairs(accents) do
		if type(name) == "string" and type(other) == "table" and type(other.IsOn) == "function"
			and ask(other, "IsOn") then
			local native = type(other.IsNative) == "function" and ask(other, "IsNative")
			if not best or (native and not bestNative) or (native == bestNative and name < best) then
				best, bestNative = name, native
			end
		end
	end
	return best
end

function ns.AccentInfo(name)
	return KNOWN[name] or { speech = name, color = "ffffff" }
end

-- "Krump" in Krump's green.
function ns.AccentName(name)
	return "|cff" .. ns.AccentInfo(name).color .. name .. "|r"
end

-- Opens Krump's or Juju's own window, if it has one.
function ns.OpenAccentBox(name)
	local open = _G[ns.AccentInfo(name).box or ""]
	if type(open) == "function" then
		open()
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- Their emotes
--
-- Krump gives each emote a slash command called KRUMP_EMOTE_<NAME>, and Juju
-- JUJU_EMOTE_<NAME>. Running one does exactly what typing it does: the
-- wording follows the character's voice, aimed at your target if you have
-- one. A command the game or another addon already had is not Krump's, so it
-- is not listed.
---------------------------------------------------------------------------

local function commandNames()
	local names = {}
	if type(SlashCmdList) ~= "table" then
		return names
	end
	for name in pairs(SlashCmdList) do
		names[name] = true
	end
	-- Once the game has read a command, it moves it into a table behind
	-- SlashCmdList: look there too.
	local meta = getmetatable(SlashCmdList)
	if meta and type(meta.__index) == "table" then
		for name in pairs(meta.__index) do
			names[name] = true
		end
	end
	return names
end

local cachedFor, cached = nil, nil

function ns.AccentEmotes(accent)
	if type(accent) ~= "string" then
		return {}
	end
	local prefix = "^" .. strupper(accent) .. "_EMOTE_"
	local emotes = {}
	for name in pairs(commandNames()) do
		local command = type(name) == "string" and strfind(name, prefix) and _G["SLASH_" .. name .. "1"]
		if type(command) == "string" and type(SlashCmdList[name]) == "function" then
			emotes[#emotes + 1] = {
				label = strlower(command),
				command = strlower(command),
				accent = accent,
				emote = true,
				run = function()
					local handler = SlashCmdList[name]
					if type(handler) == "function" then
						handler("") -- nothing typed: aimed at your target, if any
					end
				end,
			}
		end
	end
	table.sort(emotes, function(a, b) return a.label < b.label end)
	-- Keep the same tables while nothing changes, so the window's buttons
	-- keep theirs.
	if cachedFor == accent and cached and #cached == #emotes then
		local same = true
		for index, emote in ipairs(emotes) do
			if cached[index].label ~= emote.label then
				same = false
				break
			end
		end
		if same then
			return cached
		end
	end
	cachedFor, cached = accent, emotes
	return emotes
end

---------------------------------------------------------------------------
-- The extra categories
---------------------------------------------------------------------------

local emoteCategories = {}

-- Tales for the accent that is talking, then its emotes.
function ns.AccentCategories()
	local accent = ns.TalkingAccent()
	if not accent then
		return {}
	end
	local list = {}
	local tales = ns.Tales.accents[accent]
	if tales then
		tales.accent = accent
		list[#list + 1] = tales
	end
	if #ns.AccentEmotes(accent) > 0 then
		local category = emoteCategories[accent]
		if not category then
			category = {
				key = strlower(accent) .. "emotes",
				name = accent .. " Emotes",
				about = accent .. "'s emotes, and any you made in " .. accent .. ". Aimed at your target if you have one.",
				accent = accent,
				emotes = true,
			}
			emoteCategories[accent] = category
		end
		list[#list + 1] = category
	end
	return list
end
