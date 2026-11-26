-- Noticing the campfire.
--
-- Sit down by a campfire in Forever (/sit) and you get "Welcoming Campfire",
-- a buff that counts down for a minute. When it runs out it becomes "Camp
-- Benefits", every buff from the things put in the fire.
--
-- When Welcoming Campfire turns up, the window opens (unless that is
-- switched off in the settings). The top of the window counts down to the
-- camp benefits while you wait.

local _, ns = ...

-- The buffs' names, in case Blizzard renames them or another language
-- needs adding.
ns.FIRE_BUFFS = {
	welcoming = { "Welcoming Campfire" },
	benefits = { "Camp Benefits" },
}

local state = { welcoming = nil, benefits = nil } -- aura data, or nil
local watching = false

local function readable(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function auraByName(name)
	if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
		local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
		if ok and type(data) == "table" then
			return data
		end
		if ok then
			return nil
		end
	end
	-- Older clients: go through the buffs one by one.
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		for index = 1, 40 do
			local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
			if not ok or type(data) ~= "table" then
				break
			end
			if readable(data.name) and data.name == name then
				return data
			end
		end
	elseif UnitBuff then
		for index = 1, 40 do
			local buff, _, _, _, duration, expirationTime = UnitBuff("player", index)
			if not buff then
				break
			end
			if readable(buff) and buff == name then
				return { name = buff, duration = duration, expirationTime = expirationTime }
			end
		end
	end
	return nil
end

local function find(names)
	for _, name in ipairs(names) do
		local data = auraByName(name)
		if data then
			return data
		end
	end
	return nil
end

-- Looks at your buffs. quiet: only take note, do not open the window (at
-- login, so a /reload by the fire does not pop it open again).
function ns.CheckFire(quiet)
	local before = state.welcoming
	state.welcoming = find(ns.FIRE_BUFFS.welcoming)
	state.benefits = find(ns.FIRE_BUFFS.benefits)
	if state.welcoming and not before and not quiet then
		ns.SatDown()
	end
	ns.Refresh()
end

-- Just sat down at a campfire.
function ns.SatDown()
	if not ns.db then
		return
	end
	if ns.db.autoOpen and ns.OpenWindow and not ns.WindowShown() then
		ns.OpenWindow()
	end
	if not ns.db.greeted then
		ns.db.greeted = true
		ns.Print("The fire's warm. Pick something to say, or type /tales to open this window any time."
			.. (ns.db.autoOpen and "" or " (It stays shut by itself: /tales auto on to change that.)"))
	end
end

local function secondsLeft(data)
	local expires = data and data.expirationTime
	if not readable(expires) or type(expires) ~= "number" or expires <= 0 then
		return nil
	end
	local ok, now = pcall(GetTime)
	if not ok or type(now) ~= "number" then
		return nil
	end
	return math.max(0, expires - now)
end

local function clock(seconds)
	seconds = math.ceil(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- One line for the top of the window: how the fire is doing for you.
function ns.FireStatus()
	if state.welcoming then
		local left = secondsLeft(state.welcoming)
		if left then
			return "Warming up by the fire: camp benefits in " .. clock(left)
		end
		return "Warming up by the fire."
	elseif state.benefits then
		local left = secondsLeft(state.benefits)
		if left and left > 0 then
			return "Camp benefits: " .. clock(left) .. " left"
		end
		return "Camp benefits are with you."
	end
	return nil
end

function ns.AtTheFire()
	return state.welcoming ~= nil
end

function ns.WatchFire()
	if watching then
		return
	end
	watching = true
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("UNIT_AURA")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
	frame:SetScript("OnEvent", function(_, event, unit)
		if event == "UNIT_AURA" then
			if unit == "player" then
				ns.CheckFire()
			end
		else
			ns.CheckFire(true)
		end
	end)
	ns.CheckFire(true)
end
