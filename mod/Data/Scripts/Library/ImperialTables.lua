---@class ImperialTable
---@field legitimacy integer
---@field controls_planets boolean
---@field percentile_legitimacy integer
---@field factions_integrated integer
---@field pending_integration boolean
---@field is_integrated boolean
---@field next_tier integer
---@field failed_rolls integer
---@field max_unlocked boolean
---@field joined_groups string[]
---@field joined_groups_detail LegitimacyReward[]
---@field destruction_unlocks string[]
---@field destruction_unlock_descs string[]
---@field heroes_killed_since_last_roll integer
---@field integrate_value integer
---@field zann_unlocked boolean?
---@field add_option string?
---@field option_integrate string?
---@field option_legitimized string?
---@field integrated_by_option boolean?

---Returns an imperial table with starter values
---@param rewards string[]?
---@param reward_text string[]?
---@return table<string, ImperialTable> starter_table
function StarterImperialTable(rewards, reward_text)
	-- Needed for every imperial table
	local starter_table = {
		legitimacy = 25,
		controls_planets = false,
		percentile_legitimacy = 0,
		factions_integrated = 0,
		pending_integration = false,
		is_integrated = false,
		next_tier = 1,
		failed_rolls = 0,
		max_unlocked = false,
		joined_groups = {},
		joined_groups_detail = {}, -- NEW
		destruction_unlocks = rewards or {},
		destruction_unlock_descs = reward_text or {},
		heroes_killed_since_last_roll = 0,
		integrate_value = 1,
	}
	return starter_table
end

---Returns tables needed for GovernmentEmpire.lua
---@return ImperialTables
function GetImperialTables()
	-- Custom destruction unlock lists
	local success, rewards = pcall(require, "IntegrationRewards")
	if not success then
		rewards = {
			-- Defaults
			["EMPIRE"] = {"Imperial_Stormtrooper_Company"},
			["PENTASTAR"] = {"Pellaeon_Reaper_Dummy"},
			["GREATER_MALDROOD"] = {"Crimson_Victory_II_Star_Destroyer"},
			["ZSINJ_EMPIRE"] = {"Defiler_Company"},
			["ERIADU_AUTHORITY"] = {"Daala_Knight_Hammer_Dummy"},
			["IMPERIAL_PROTEUS"] = {},
		}
	end

	---Custom or Default reward text
	---@type table<string, string[]>
	reward_text = rewards["REWARD_TEXT"] or {
		["EMPIRE"] = {"TEXT_GOVERNMENT_EMPIRE_INTEGRATION_REWARD_STORMTROOPER"},
		["PENTASTAR"] = {"TEXT_GOVERNMENT_EMPIRE_INTEGRATION_REWARD_PELLAEON_REAPER"},
		["GREATER_MALDROOD"] = {"TEXT_GOVERNMENT_EMPIRE_INTEGRATION_REWARD_CCVSD"},
		["ZSINJ_EMPIRE"] = {},
		["ERIADU_AUTHORITY"] = {"TEXT_GOVERNMENT_EMPIRE_INTEGRATION_REWARD_DAALA_KNIGHT_HAMMER"},
		["IMPERIAL_PROTEUS"] = {},
	}

	---@class (exact) ImperialTables
	---@field imperial_table table<string, ImperialTable>
	---@field leader_table table<integer, string> | table<string, string[]>
	---@field hero_ssd_table table<string, string>
	---@field add_imperial_options table<string, ImperialTable>
	---@field dark_empire_units string[]
	---@field base_imperial_units string[]
	local tables = {
		---Always part of the Imperial legitimacy system
		---@type table<string, ImperialTable>
		imperial_table = {},

		---SSD heroes who are leaders do not need to be on this list
		---@type table<integer, string> | table<string, string[]>
		leader_table = {
			-- Green Empire leaders
			["PESTAGE_TEAM"] = {"SATE_PESTAGE"},
			["YSANNE_ISARD_TEAM"] = {"YSANNE_ISARD"},
			"HISSA_MOFFSHIP",
			"THRAWN_CHIMAERA",
			"FLIM_TIERCE_IRONHAND",

			-- Pentastar leaders
			["ARDUS_KAINE_TEAM"] = {"ARDUS_KAINE"},

			-- Greater Maldrood leaders
			"TREUTEN_13X",
			"TREUTEN_CRIMSON_SUNRISE",
			"KOSH_LANCET",

			-- Zsinj's Empire leaders
			"ZSINJ_IRON_FIST_VSD",

			-- Eriadu Authority leaders
			"DELVARDUS_BRILLIANT",
			"DELVARDUS_THALASSA",

			-- Legitimacy winner leaders
			["EMPEROR_PALPATINE_TEAM"] = {"EMPEROR_PALPATINE"},
			["CARNOR_JAX_TEAM"] = {"CARNOR_JAX"},
			"DAALA_GORGON",
			"PELLAEON_CHIMAERA_GRAND"
		},
		
		---SSD heroes need to be on *this* list whether or not they are leaders
		---@type table<string, string>
		hero_ssd_table = {
			["ISARD_LUSANKYA"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_ISARD",
			["CRONUS_NIGHT_HAMMER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_CRONUS_NIGHT_HAMMER",
			["DELVARDUS_NIGHT_HAMMER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_DELVARDUS",
			["DAALA_KNIGHT_HAMMER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_DAALA",
			["PELLAEON_REAPER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_PELLAEON_REAPER",
			["PELLAEON_MEGADOR"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_PELLAEON_MEGADOR",
			["ROGRISS_DOMINION"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_ROGRISS_DOMINION",
			["KAINE_REAPER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_KAINE",
			["SYSCO_VENGEANCE"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_SYSCO_VENGEANCE",
			["ZSINJ_IRON_FIST_EXECUTOR"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_ZSINJ",
			["RASLAN_RAZORS_KISS"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_RASLAN_RAZORS_KISS",
			["DROMMEL_GUARDIAN"] = "TEXT_GOVERNMENT_EMPIRE_SSD_WARLORD_DROMMEL",
			["GRUNGER_AGGRESSOR"] = "TEXT_GOVERNMENT_EMPIRE_SSD_WARLORD_GRUNGER",
			["GRONN_ACULEUS"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_GRONN",
			["BALAN_JAVELIN"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_BALAN",
			["KIEZ_WHELM"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_KIEZ",
			["COMEG_BELLATOR"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_COMEG",
			["X1_EXECUTOR"] = "TEXT_GOVERNMENT_EMPIRE_SSD_WARLORD_X1",
			["THORN_ASSERTOR"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_THORN",
		},

		---Added to Imperial legitimacy system if option selected
		---@type table<string, ImperialTable>
		add_imperial_options = {},

		---For factions in add_imperial_options if they get dark empire
		---@type string[]
		dark_empire_units = {
            "Eclipse_Star_Dreadnought",
            "Sovereign_Star_Dreadnought",
            "MTC_Sensor",
            "MTC_Support",
            "TaggeCo_HQ",
            "Hunter_Killer_Probot",
            "XR85_Company",
            "Imperial_Chrysalide_Company",
            "Imperial_Dark_Jedi_Company",
            "Dark_Stormtrooper_Company",
            "Compforce_Assault_Company",
            -- "Xecr_Nist_Dark_Side_Location_Set",
		},

		---For factions in add_imperial_options if they become Imperial
		---@type string[]
		base_imperial_units = {
			"Victory_I_Star_Destroyer",
			"Imperial_I_Star_Destroyer",
			"U_Ground_Advanced_Vehicle_Factory",
			"Imperial_A5_Juggernaut_Company",
		}
	}

	-- Init imperial_table
	for _, faction in pairs({
		"EMPIRE",
		"PENTASTAR",
		"GREATER_MALDROOD",
		"ZSINJ_EMPIRE",
		"ERIADU_AUTHORITY",
		"IMPERIAL_PROTEUS",
	}) do
		tables.imperial_table[faction] = StarterImperialTable(rewards[faction], reward_text[faction])
	end

	--Special cases
	tables.imperial_table["EMPIRE"].integrate_value = 2
	tables.imperial_table["ZSINJ_EMPIRE"].zann_unlocked = false

	-- Init add_imperial_options
	for _, faction in pairs({
		"CORELLIA",
		"CORPORATE_SECTOR",
		"EMPIREOFTHEHAND",
		"CHISS",
		"WARLORDS",
		"INDEPENDENT_FORCES",
		"HUTT_CARTELS",
		"HAPES_CONSORTIUM",
		"REBEL",
		--"UNDERWORLD",
		"KILLIK_HIVES",
		"SSIRUUVI_IMPERIUM",
		"MANDALORIANS",
		"YEVETHA",
	}) do
		tables.add_imperial_options[faction] = StarterImperialTable(rewards[faction], reward_text[faction])
	end

	return tables
end
