--Units that become buildable when the faction is integrated.
--Update unit Affiliation and Required_Special_Structures in xml when adding rewards.
return {
	["EMPIRE"] = {
		"Imperial_Boarding_Shuttle", --
		"Generic_Dominator", --
		"Combat_Escort_Carrier", --
		"Reward_Vindicator_Cruiser",
		"Reward_Impellor",
		"Reward_Compellor",
		"Imperial_Stormtrooper_Squad",
		"Reward_Imperial_Stormtrooper_Squad",
		"Reward_Imperial_AT_ST_Company",
		-- "Reward_Imperial_AT_ST_A_Company",
		"Reward_Imperial_Deathhawk_Group",
		"Reward_Imperial_AT_AT_Company",
		-- "Reward_Imperial_AT_AT_Refit_Company",
	},
	["PENTASTAR"] = {
		"PellaeonUpgrade",
		"Imperial_Nemesis_Gunship_Group", --
		"Raider_Corvette", --
		-- "Reward_Enforcer",
		"Reward_Generic_Venator",
		"Reward_Generic_Secutor",
		"Reward_Generic_Mandator_III",
		"Reward_Generic_Praetor_Carrier",
		"Reward_Pentastar_Enforcer_Trooper_Squad",
		"Reward_Imperial_AT_DP_Company",
		"Reward_Imperial_Century_Tank_Company",
		"Reward_Imperial_C10_Siege_Tower_Company",
	},
	["GREATER_MALDROOD"] = {
		"Crimson_Victory",
		"Reward_Crimson_Victory",
		"Reward_Generic_Tector",
		"Reward_Altor_Replenishment_Ship",
		"Reward_Generic_Bellator",
		"Imperial_Navy_Commando_Squad",
		"Reward_Imperial_Navy_Commando_Squad",
		"Reward_Imperial_ISP_Company",
		"Reward_Imperial_2M_Company",
		"Reward_Imperial_Heavy_Recovery_Vehicle_Company",
	},
	["ZSINJ_EMPIRE"] = {
		"Imperial_Defiler_Squad",
		"Imperial_AT_AP_Walker_Company", --
		"Reward_Imperial_Defiler_Squad",
		"Reward_Generic_Aggressor",
		"Reward_Generic_Sorannan",
		"Reward_Generic_Vengeance",
		"Reward_Zsinj_EVO_Trooper_Squad",
		"Reward_Imperial_Repulsor_Scout_Company",
		"Reward_Imperial_APC_Company",
		"Reward_Imperial_TRSD_Company",
	},
	["ERIADU_AUTHORITY"] = {
		"DaalaUpgrade",
		"Imperial_1H_Tank_Company", --
		"Arquitens", --
		"Reward_Generic_Gladiator",
		"Reward_Torpedo_Sphere",
		"Reward_Assertor",
		"Reward_Imperial_Army_Special_Missions_Squad",
		"Reward_Imperial_AT_MP_Company",
		"Reward_Imperial_1M_Tank_Company",
		"Reward_Imperial_Lancet_Group",
	},
	["EMPIREOFTHEHAND"] = {
		"Reward_Chaf_Destroyer",
		"Reward_Chiss_Star_Destroyer",
		"Reward_Peltast",
		"Reward_Phalanx_Trooper_Squad",
		"Reward_Flame_Tank_Company",
	},
	["CORPORATE_SECTOR"] = {
		"Zsinj_Ship_Market", --
		"SLIROUPGRADE", --
		"Reward_Recusant",
		"Reward_Invincible_Cruiser",
		"Reward_Lucrehulk_CSA",
		"Reward_CSA_B1_Droid_Squad",
	},
	["HUTT_CARTELS"] = {
		"Voracious_Carrier", --
		"TEUBBOUPGRADE", --
		"Reward_Barabbula_Frigate",
		"Reward_Karagga_Destroyer",
		"Reward_Vontor_Destroyer",
		"Reward_DorBulla_Warship",
	},
	["HAPES_CONSORTIUM"] = {
		"Reward_Flare",
		"Reward_Pulsar",
		"Reward_Terephon_Cruiser",
		"Reward_Hapan_LightTank_Company",
		"Reward_Hapan_HeavyTank_Company",
	},
	["REBEL"] = {
		"Reward_MC30c",
		"Reward_Calamari_Cruiser",
		"Reward_MC80B",
		"Reward_Rebel_Marine_Squad",
		"Reward_Rebel_T3B_Company",
	},
	["UNDERWORLD"] = {},
	["WARLORDS"] = {},
	["CORELLIA"] = {
		"Reward_Proficient",
	},
	["CHISS"] = {
		"Reward_Fruoro",
		"Reward_Syndic_Destroyer",
	},
	["SSIRUUVI_IMPERIUM"] = {
		"Reward_SsiRuuk_Soldier_Squad",
		"Reward_Shree_Cruiser",
	},
	["KILLIK_HIVES"] = {},
	["MANDALORIANS"] = {},
	["YEVETHA"] = {
		"Reward_Generic_Aramadia",
		"Reward_Yevetha_Infantry_Squad",
		"Reward_Yevethan_Plex_Squad",
	},
	["INDEPENDENT_FORCES"] = {
		"Reward_Super_Transport_XI_Modified",
		"Reward_Military_Soldier_Team",
	},

	--Optional text describing the reward units
	["REWARD_TEXT"] = {
		["EMPIRE"] = {
			"Vindicator Heavy Cruiser",
			"Impellor Carrier",
			"Compellor Battlecruiser",
			"Stormtrooper Platoon",
			"AT-ST Walker Company",
			'"Deathhawk" Combat Airspeeder Wing',
			"AT-AT Walker Company"
		},
		["PENTASTAR"] = {
			-- "Enforcer Picket Ship",
			"Venator Star Destroyer",
			"Secutor Star Destroyer",
			"Praetor Carrier Battlecruiser",
			"Mandator-III Star Dreadnought",
			"Executor Star Dreadnought, Reaper [ Pellaeon's Regime Leader Upgrade ]",
			"Enforcer Trooper Platoon",
			"AT-DP Walker Company",
			"TIE Crawler Company",
			"C-10 Siege Tower",
		},
		["GREATER_MALDROOD"] = {
			"Crimson Victory-II Star Destroyer",
			"Tector Star Destroyer",
			"Altor Replenishment Ship",
			"Bellator Star Dreadnought",
			"Navy Commando Platoon",
			"Infantry Support Platform Company",
			"2-M Repulsor Tank Company",
			"Heavy Recovery Vehicle Company",
		},
		["ZSINJ_EMPIRE"] = {
			"Aggressor Star Destroyer",
			"Sorannan Star Destroyer",
			"Vengeance Star Dreadnought",
			"EVO Trooper Platoon",
			"Repulsor Scout Company",
			"Imperial APC Company",
			"Tracked Shield Disabler Company",
		},
		["ERIADU_AUTHORITY"] = {
			"Gladiator-I Star Destroyer",
			"Torpedo Sphere",
			"Assertor Star Dreadnought",
			"Executor Star Dreadnought, Knight Hammer [ Daala's Regime Leader Upgrade ]",
			"Army Special Missions Platoon",
			"AT-MP Walker Company",
			"1-M Repulsortank Company",
			"Lancet Wing",
		},
		["EMPIREOFTHEHAND"] = {
			"Chaf Destroyer",
			"Chiss Star Destroyer",
			"Peltast Star Destroyer",
			"Phalanx Trooper Platoon",
			"Flame Tank Company",
		},
		["CORPORATE_SECTOR"] = {
			"Recusant Light Destroyer",
			"Invincible Cruiser",
			"Lucrehulk Battle Carrier",
			"B1 Battle Droid Squad",
		},
		["HUTT_CARTELS"] = {
			"Barabbula Frigate",
			"Kossak Frigate",
			"Vontor Destroyer",
			"Dor'bulla Warship",
		},
		["HAPES_CONSORTIUM"] = {
			"Flare Corvette",
			"Pulsar Cruiser",
			"Terephon Cruiser",
			"Water Dragon-M Hovertank Company",
			"Fire Dragon Hovertank Company",
		},
		["REBEL"] = {
			"MC30c Frigate",
			"MC80 Liberty Cruiser",
			"MC80B Cruiser",
			"Marine Platoon",
			"T3-B Tracked Tank Company",
		},
		["CORELLIA"] = {
			"Proficient Light Cruiser",
		},
		["CHISS"] = {
			"Fruoro Picket Ship",
			"Syndic Destroyer",
		},
		["SSIRUUVI_IMPERIUM"] = {
			"Ssi-Ruuk Soldier Platoon",
			"Shree Battle Cruiser",
		},
		["YEVETHA"] = {
			"Aramadia Star Dreadnought",
			"Yevethan Soldier Platoon",
			"Yevethan Rocket Company",
		},
		["INDEPENDENT_FORCES"] = {
			"Modified Super Transport XI",
			"Local Military Platoon",
		},
	},
}