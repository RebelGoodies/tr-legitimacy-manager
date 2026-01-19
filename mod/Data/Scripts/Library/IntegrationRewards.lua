---Units that become buildable when the faction is integrated.
---Update unit Affiliation and Required_Special_Structures in xml when adding rewards.
return {
	["EMPIRE"] = {
		"Imperial_Stormtrooper_Company", -- Standard
		"AT_ST_A_Company",
		"Deathhawk_Company",
		"Imperial_AT_AT_Walker_Turbolaser_Refit_Company",
		"Lancer_Frigate",
		"Vindicator_Cruiser",
		"Interdictor_Star_Destroyer",
		"Impellor_Carrier",        -- Fractal
		"Compellor_Battlecruiser", -- Fractal
	},
	["PENTASTAR"] = {
		"Pellaeon_Reaper_Dummy", -- HeroUpgrade
		"Enforcer_Trooper_Company",
		"AT_DP_Company",
		"Nemesis_Gunship_Company",
		"C10_Siege_Tower_Company",
		"Victory_II_Frigate",
		"Venator_Star_Destroyer",
		"Secutor_Star_Destroyer",
		"Praetor_Carrier_Battlecruiser",
		"Mandator_III_Dreadnought", --SSD
	},
	["GREATER_MALDROOD"] = {
		"Crimson_Victory_II_Star_Destroyer", -- Standard
		"Navy_Commando_Company",
		"Imperial_ISP_Company",
		"2M_Repulsor_Tank_Company",
		"Heavy_Recovery_Vehicle_Company",
		"Customs_Corvette",
		"Broadside_Cruiser",
		"Tector_Star_Destroyer",
		"Altor_Replenishment_Ship",
		"Bellator_Star_Dreadnought", --SSD
	},
	["ZSINJ_EMPIRE"] = {
		"Defiler_Company", -- Requires Urai
		"EVO_Trooper_Company",
		"Repulsor_Scout_Company",
		"Imperial_APC_Company",
		"Tracked_Shield_Disabler_Company",
		"Vengeance_Frigate",
		"Dragon_Heavy_Cruiser",
		"Aggressor_Star_Destroyer",
		"Sorannan_Star_Destroyer",
		"Vengeance_Star_Dreadnought", --SSD
	},
	["ERIADU_AUTHORITY"] = {
		"Daala_Knight_Hammer_Dummy", -- HeroUpgrade
		"Army_Special_Missions_Company",
		"AT_MP_Company",
		"1M_Tank_Company",
		"Lancet_Air_Artillery_Company",
		"Arquitens",
		"Gladiator_I",
		"Torpedo_Sphere",
		"Praetor_II_Battlecruiser",
		"Assertor_Star_Dreadnought", --SSD
	},
	["WARLORDS"] = {
		"Imperial_Army_Trooper_Company",
		"AT_ST_Company",
		"TIE_Crawler_Company",
		"Imperial_AT_AT_Walker_Company",
		"Executor_Star_Dreadnought", --SSD
	},
	["EMPIREOFTHEHAND"] = {
	},
	["CHISS"] = {
	},
	["CORELLIA"] = {
	},
	["CORPORATE_SECTOR"] = {
		"Lucrehulk_CSA",
	},
	["INDEPENDENT_FORCES"] = {
	},
	["HUTT_CARTELS"] = {
	},
	["HAPES_CONSORTIUM"] = {
	},
	["REBEL"] = {
		"Home_One_Type",
		"Viscount_Star_Defender", --SSD
	},
	["UNDERWORLD"] = {},
	["KILLIK_HIVES"] = {
	},
	["SSIRUUVI_IMPERIUM"] = {
	},
	["MANDALORIANS"] = {
	},
	["YEVETHA"] = {
		"Imperial_AT_TE_Walker_Company",
		"Acclamator_II",
		"Aramadia_Star_Dreadnought", --SSD
	},

	---Optional text describing the reward units
	["REWARD_TEXT"] = {
		["EMPIRE"] = { -- Galactic Empire
			"Stormtrooper Platoon",
			"AT-ST/A Walker Company",
			"\"Deathhawk\" Combat Airspeeder Wing",
			"Turbolaser Refit AT-AT Walker",
			"Lancer Frigate",
			"Vindicator Heavy Cruiser",
			"Interdictor Star Destroyer",
			"Impellor Carrier",
			"Compellor Battlecruiser",
		},
		["PENTASTAR"] = { -- Pentastar Alignment
			"Enforcer Trooper Platoon",
			"AT-DP Walker Company",
			"Nemesis-class Gunship",
			"C-10 Siege Tower",
			"Victory-II Frigate",
			"Venator Star Destroyer",
			"Secutor Star Destroyer",
			"Praetor Carrier Battlecruiser",
			"Mandator-III Star Dreadnought",
		},
		["GREATER_MALDROOD"] = { -- Greater Maldrood
			"Crimson Victory-II Star Destroyer",
			"Navy Commando Platoon",
			"Infantry Support Platform Company",
			"2-M Repulsor Tank Company",
			"Heavy Recovery Vehicle Company",
			"Customs Light Corvette",
			"Broadside Cruiser",
			"Tector Star Destroyer",
			"Altor Replenishment Ship",
			"Bellator Star Dreadnought",
		},
		["ZSINJ_EMPIRE"] = { -- Zsinj's Empire
			"EVO Trooper Platoon",
			"Repulsor Scout Company",
			"Imperial APC Company",
			"Tracked Shield Disabler Company",
			"Vengeance Frigate",
			"Dragon Heavy Cruiser",
			"Aggressor Star Destroyer",
			"Sorannan Star Destroyer",
			"Vengeance Star Dreadnought",
		},
		["ERIADU_AUTHORITY"] = { -- Eriadu Authority
			"Army Special Missions Platoon",
			"AT-MP Walker Company",
			"1-M Repulsortank Company",
			"Lancet Wing",
			"Arquitens Light Cruiser",
			"Gladiator-I Star Destroyer",
			"Torpedo Sphere",
			"Praetor-II Battlecruiser",
			"Assertor Star Dreadnought",
		},
		["WARLORDS"] = { -- Minor Warlords
			"Army Trooper Platoon",
			"AT-ST Walker Company",
			"TIE Crawler Company",
			"AT-AT Walker",
			"Executor Star Dreadnought",
		},
		["EMPIREOFTHEHAND"] = { -- Empire of the Hand
		},
		["CHISS"] = { -- Chiss Ascendancy
		},
		["CORELLIA"] = { -- Corellians
		},
		["CORPORATE_SECTOR"] = { -- Corporate Sector Authority
			"Lucrehulk Battle Carrier",
		},
		["INDEPENDENT_FORCES"] = { -- Independent Forces
		},
		["HUTT_CARTELS"] = { -- Hutt Cartels
		},
		["HAPES_CONSORTIUM"] = { -- Hapes Consortium
		},
		["REBEL"] = { -- New Republic
			"MC80 Home One Type Cruiser",
			"Viscount Star Defender",
		},
		["UNDERWORLD"] = { -- Yuuzhan Vong
		},
		["KILLIK_HIVES"] = { -- Killik Hives
		},
		["SSIRUUVI_IMPERIUM"] = { -- Ssi-Ruuvi Imperium
		},
		["MANDALORIANS"] = { -- Mandalorian Clans
		},
		["YEVETHA"] = { -- Duskhan League
			"AT-TE Walker",
			"Acclamator-II Cruiser",
			"Aramadia Star Dreadnought",
		},
	},
}