---@class ImperialTable
---@field legitimacy integer
---@field controls_planets boolean
---@field percentile_legitimacy integer
---@field factions_integrated integer
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
---@return table<string, table>
function GetImperialTables()
	-- Custom destruction unlock lists
	local success, rewards = pcall(require, "IntegrationRewards")
	if not success then
		rewards = {
			-- Defaults
			["EMPIRE"] = {"Imperial_Stormtrooper_Squad"},
			["PENTASTAR"] = {"PellaeonUpgrade"},
			["GREATER_MALDROOD"] = {"Crimson_Victory"},
			["ZSINJ_EMPIRE"] = {"Imperial_Defiler_Squad"},
			["ERIADU_AUTHORITY"] = {"DaalaUpgrade"},
		}
	end

	-- Custom or Default reward text
	reward_text = rewards["REWARD_TEXT"] or {
		["EMPIRE"] = {"TEXT_GOVERNMENT_EMPIRE_INTEGRATION_REWARD_STORMTROOPER"},
		["PENTASTAR"] = {"TEXT_GOVERNMENT_EMPIRE_INTEGRATION_REWARD_PELLAEON_REAPER"},
		["GREATER_MALDROOD"] = {"TEXT_GOVERNMENT_EMPIRE_INTEGRATION_REWARD_CCVSD"},
		["ERIADU_AUTHORITY"] = {"TEXT_GOVERNMENT_EMPIRE_INTEGRATION_REWARD_DAALA_KNIGHT_HAMMER"},
	}

	local tables = {
		---Always part of the Imperial legitimacy system
		---@type table<string, ImperialTable>
		imperial_table = {
			["EMPIRE"] = StarterImperialTable(rewards["EMPIRE"], reward_text["EMPIRE"]),
			["PENTASTAR"] = StarterImperialTable(rewards["PENTASTAR"], reward_text["PENTASTAR"]),
			["GREATER_MALDROOD"] = StarterImperialTable(rewards["GREATER_MALDROOD"], reward_text["GREATER_MALDROOD"]),
			["ZSINJ_EMPIRE"] = StarterImperialTable(rewards["ZSINJ_EMPIRE"], reward_text["ZSINJ_EMPIRE"]),
			["ERIADU_AUTHORITY"] = StarterImperialTable(rewards["ERIADU_AUTHORITY"], reward_text["ERIADU_AUTHORITY"]),
		},

		---Added to Imperial legitimacy system if option selected
		---@type table<string, ImperialTable>
		add_imperial_options = {
			["EMPIREOFTHEHAND"] = StarterImperialTable(rewards["EMPIREOFTHEHAND"], reward_text["EMPIREOFTHEHAND"]),
			["CORPORATE_SECTOR"] = StarterImperialTable(rewards["CORPORATE_SECTOR"], reward_text["CORPORATE_SECTOR"]),
			["WARLORDS"] = StarterImperialTable(rewards["WARLORDS"], reward_text["WARLORDS"]),
			["CORELLIA"] = StarterImperialTable(rewards["CORELLIA"], reward_text["CORELLIA"]),
			["CHISS"] = StarterImperialTable(rewards["CHISS"], reward_text["CHISS"]),
			["SSIRUUVI_IMPERIUM"] = StarterImperialTable(rewards["SSIRUUVI_IMPERIUM"], reward_text["SSIRUUVI_IMPERIUM"]),
			["KILLIK_HIVES"] = StarterImperialTable(rewards["KILLIK_HIVES"], reward_text["KILLIK_HIVES"]),
			["MANDALORIANS"] = StarterImperialTable(rewards["MANDALORIANS"], reward_text["MANDALORIANS"]),
			["YEVETHA"] = StarterImperialTable(rewards["YEVETHA"], reward_text["YEVETHA"]),
			["INDEPENDENT_FORCES"] = StarterImperialTable(rewards["INDEPENDENT_FORCES"], reward_text["INDEPENDENT_FORCES"]),
			["HUTT_CARTELS"] = StarterImperialTable(rewards["HUTT_CARTELS"], reward_text["HUTT_CARTELS"]),
			["HAPES_CONSORTIUM"] = StarterImperialTable(rewards["HAPES_CONSORTIUM"], reward_text["HAPES_CONSORTIUM"]),
			["REBEL"] = StarterImperialTable(rewards["REBEL"], reward_text["REBEL"]),
			--["UNDERWORLD"] = StarterImperialTable(rewards["UNDERWORLD"], reward_text["UNDERWORLD"]),
		},
		
		---SSD heroes who are leaders do not need to be on this list
		---@type table<integer|string, string|string[]>
		leader_table = {
			-- Green Empire leaders
			["PESTAGE_TEAM"] = {"SATE_PESTAGE"}, ["YSANNE_ISARD_TEAM"] = {"YSANNE_ISARD"},
			"HISSA_MOFFSHIP", "HISSA_MOFFSHIP_NO_TRANSITION", "THRAWN_CHIMAERA", "FLIM_TIERCE_IRONHAND",
			-- Green Empire heroes with warlord trait
			"HARRSK_WHIRLWIND", "HARRSK_SHOCKWAVE", "KRENNEL_WARLORD", "NORYM_KIM_BLOOD_GAINS", "TETHYS_CALLOUS",
			["SHARGAEL_TEAM"] = {"SHARGAEL_AT_TE"},
			
			-- Pentastar leaders
			["JEREC_TEAM"] = {"JEREC"}, ["ARDUS_KAINE_TEAM"] = {"ARDUS_KAINE"},
			
			-- Greater Maldrood leaders
			"TREUTEN_13X", "TREUTEN_CRIMSON_SUNRISE", "KOSH_LANCET",
			
			-- Zsinj's Empire leaders
			"ZSINJ_IRON_FIST_VSD",
			-- Zsinj's Empire heroes with warlord trait
			"SCREED_DEMOLISHER", "SLAGORTH_ARC",
			["TYBER_ZANN_TEAM"] = {"TYBER_ZANN"},
			["TYBER_ZANN_TEAM2"] = {"TYBER_ZANN2"},
			
			-- Eriadu Authority leaders
			"DELVARDUS_THALASSA", "DELVARDUS_BRILLIANT",
			
			-- EOTH leaders
			"THRAWN_GREY_WOLF", "THRAWN_CLONE_EVISCERATOR", "NIRIZ_ADMONITOR",
			
			-- Legitimacy group heroes with warlord trait
			"DELURIN_GALAXY_DRAGON", "NICLARA_PULSARS_REVENGE", "PRENTIOCH_PRENTIOCH", "LANKIN_KNIGHT", "YZU_CONSTITUTION", "BRANDL_ISD",
			["NIVERS_TEAM"] = {"NIVERS_AT_AT_WALKER"}, ["GANN_TEAM"] = {"GANN_JUGGERNAUT_A6"}, ["FOGA_BRILL_TEAM"] = {"FOGA_BRILL"}, ["JAALIB_TEAM"] = {"JAALIB"}, ["GRAZZ_TEAM"] = {"GRAZZ_AT_AT_WALKER"},
			-- Legacy of War
			"SARNE_RAPTOR", ["HETHRIR_TEAM"] = {"HETHRIR"}, ["DEVIAN_TEAM"] = {"ENNIX_DEVIAN"},
			
			-- Legitimacy winner leaders
			["EMPEROR_PALPATINE_TEAM"] = {"EMPEROR_PALPATINE"}, ["CARNOR_JAX_TEAM"] = {"CARNOR_JAX"}, 
			"DAALA_GORGON", "PELLAEON_GRAND_CHIMAERA",

			-- Hutt Cartel leaders (used in Zsinj custom integrations)
			["SMEBBA_DUNK_TEAM"] = {"SMEBBA_DUNK"}, ["BOSSATO_TEAM"] = {"BOSSATO"},
		},
		
		---SSD heroes need to be on *this* list whether or not they are leaders
		---@type table<string, string>
		hero_ssd_table = {
			["ISARD_LUSANKYA"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_ISARD",
			["LUSANKYA_NO_TRANSITION"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_ISARD",
			["NIGHT_HAMMER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_CRONUS_NIGHT_HAMMER",
			["DELVARDUS_NIGHT_HAMMER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_DELVARDUS",
			["DAALA_KNIGHT_HAMMER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_DAALA",
			["PELLAEON_REAPER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_PELLAEON_REAPER",
			["PELLAEON_MEGADOR"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_PELLAEON_MEGADOR",
			["ROGRISS_DOMINION"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_ROGRISS_DOMINION",
			["KAINE_REAPER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_KAINE",
			["VENGEANCE_JEREC"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_SYSCO_VENGEANCE",
			["ZSINJ_IRON_FIST_EXECUTOR"] = "TEXT_GOVERNMENT_EMPIRE_SSD_LEADER_ZSINJ",
			["RAZORS_KISS"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_RASLAN_RAZORS_KISS",
			["DROMMEL_GUARDIAN"] = "TEXT_GOVERNMENT_EMPIRE_SSD_WARLORD_DROMMEL",
			["GRUNGER_AGGRESSOR"] = "TEXT_GOVERNMENT_EMPIRE_SSD_WARLORD_GRUNGER",
			["GRONN_ACULEUS"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_GRONN",
			["KIEZ_WHELM"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_KIEZ",
			["DANGOR_JAVELIN"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_DANGOR",
			["WRATH_ASSERTOR"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_WRATH",
			["VANTO_DESTINY"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_VANTO",
			["RAX_RAVAGER"] = "TEXT_GOVERNMENT_EMPIRE_SSD_HERO_RAX",
		},

		---For factions in add_imperial_options if they get dark empire
		---@type string[]
		dark_empire_units = {
			"Reward_Eclipse_Star_Destroyer",
            "Reward_Sovereign",
            "Reward_MTC_Sensor",
            "Reward_MTC_Support",
            "Reward_TaggeCo_HQ",
            "Reward_Hunter_Killer_Probot",
            "Reward_Imperial_XR85_Company",
            "Reward_Imperial_Chrysalide_Company",
            "Reward_Imperial_Dark_Jedi_Squad",
            "Reward_Imperial_Dark_Stormtrooper_Squad",
            "Reward_Imperial_Compforce_Assault_Squad",
		},

		---For factions in add_imperial_options if they become Imperial
		---@type string[]
		base_imperial_units = {
			"Reward_Generic_Victory_Destroyer_Two",
			"Reward_Generic_Star_Destroyer",
			"U_Ground_Advanced_Vehicle_Factory",
			"Reward_Imperial_B5_Juggernaut_Company",
		}
	}

	--Special cases
	tables.imperial_table["EMPIRE"].integrate_value = 2
	tables.imperial_table["ZSINJ_EMPIRE"].zann_unlocked = false

	return tables
end