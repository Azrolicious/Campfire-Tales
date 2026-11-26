-- Campfire Tales settings: Options > AddOns > Campfire Tales (or /tales config).
-- Built with the game's own settings list, so it looks like every other page.

local _, ns = ...

local category

function ns.OpenOptions()
	if category then
		Settings.OpenToCategory(category:GetID())
	else
		ns.Print("The settings panel is not available. Type /tales help for the chat commands.")
	end
end

function ns.BuildOptions()
	if category or not (Settings and Settings.RegisterVerticalLayoutCategory) then
		return
	end

	local db = ns.db
	category = Settings.RegisterVerticalLayoutCategory("Campfire Tales")

	local function checkbox(variable, label, tooltip, default, key)
		local setting = Settings.RegisterProxySetting(category, variable,
			Settings.VarType.Boolean, label, default,
			function() return db[key] end,
			function(value)
				db[key] = value
				ns.Refresh()
			end)
		Settings.CreateCheckbox(category, setting, tooltip)
	end

	checkbox("CAMPFIRETALES_AUTO_OPEN", "Open when I sit at a campfire",
		"Opens the Campfire Tales window when you sit down by a campfire and the Welcoming Campfire buff starts counting down. Type /tales to open it any time.",
		ns.DEFAULTS.autoOpen, "autoOpen")

	-- How long the next line of a tale waits, so everyone can read the last.
	if Settings.CreateDropdown and Settings.CreateControlTextContainer then
		local paceSetting = Settings.RegisterProxySetting(category, "CAMPFIRETALES_PACE", Settings.VarType.String,
			"Time to read between lines", ns.DEFAULTS.pace,
			function() return db.pace end,
			function(value)
				db.pace = value
				ns.Refresh()
			end)
		local function paceOptions()
			local container = Settings.CreateControlTextContainer()
			for _, key in ipairs(ns.PACE_ORDER) do
				container:Add(key, ns.PACE_NAMES[key][1], ns.PACE_NAMES[key][2])
			end
			return container:GetData()
		end
		Settings.CreateDropdown(category, paceSetting, paceOptions,
			"In a story, joke or riddle, how long the next line waits after you say one, so that everyone has time to read it. Pauses written into the tale, such as the beat before a punchline, come on top. The window counts down, and Say it now skips the wait.")
	end

	checkbox("CAMPFIRETALES_ACTIONS_NOW", "Do actions straight away",
		"A button with a single action on it, such as poking the fire, does it as soon as you click. Switch this off to have actions go into the chat line like everything else, so you can change them before pressing Enter.",
		ns.DEFAULTS.actionsNow, "actionsNow")

	checkbox("CAMPFIRETALES_CRUDE", "Crude humour",
		"The Crude Jokes, Insults and Tavern Tales categories, and the rude ones among Ork Yarns and Troll Tales. Untick to hide them, for when you are somewhere they would not go down well.",
		ns.DEFAULTS.crude, "crude")

	checkbox("CAMPFIRETALES_ACCENTS", "Krump and Juju categories",
		"While Krump or Juju is talking on this character, adds tales written for an Ork or a troll, and a button for each of their emotes.",
		ns.DEFAULTS.accents, "accents")

	Settings.RegisterAddOnCategory(category)
end
