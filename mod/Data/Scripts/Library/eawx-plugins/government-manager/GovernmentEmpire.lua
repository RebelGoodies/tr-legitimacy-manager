require("deepcore/std/class")
require("deepcore/crossplot/crossplot")
require("eawx-util/GalacticUtil")
require("eawx-util/ChangeOwnerUtilities")
require("PGSpawnUnits")
require("TRCommands")
StoryUtil = require("eawx-util/StoryUtil")
UnitUtil = require("eawx-util/UnitUtil")
require("UnitSwitcherLibrary")
require("eawx-util/Sort")
require("eawx-plugins/government-manager/ExtraSwap")
require("HeroFighterLibrary")

---@class GovernmentEmpire
GovernmentEmpire = class()

---@param gc GalacticConquest
---@param absorb integer
---@param dark_empire boolean
---@param id string
function GovernmentEmpire:new(gc, absorb, dark_empire, id)
	self.HumanPlayer = gc.HumanPlayer
	self.human_faction = Find_Player("local").Get_Faction_Name()
	self.PlayerEmpire = Find_Player("Empire")
	self.PlayerPentastar = Find_Player("Pentastar")
	self.PlayerMaldrood = Find_Player("Greater_Maldrood")
	self.PlayerZsinj = Find_Player("Zsinj_Empire")
	self.PlayerEriadu = Find_Player("Eriadu_Authority")
	self.LegitimacyAbsorb = 3
	self.StartingEra = GlobalValue.Get("CURRENT_ERA")
	self.Unit_List = require("hardpoint-lists/PersistentLibrary")
	self.StartingEmpires = 0

	self.id = id

	GlobalValue.Set("IMPERIAL_REMNANT", "EMPIRE")
	-- Zsinj's Criminal Empire Submod
	GlobalValue.Set("ZANN_CONTACTED", "FALSE")
	GlobalValue.Set("ZSINJ_SHIP_MARKET_UNLOCK", "FALSE")

	self.DarkEmpirePlanetBasedOnlyThreshold = table.getn(FindPlanet.Get_All_Planets())/2

	if absorb and absorb > 0 then
		self.LegitimacyAbsorb = absorb
	end

	require("ImperialTables")
	local tables = GetImperialTables()

	---Always part of Imperial legitimacy system.
	---  imperial_table = {["FACTION"] = {...}}
	---@type table<string, ImperialTable>
	self.imperial_table = tables.imperial_table or {}

	---Added to Imperial legitimacy system if option selected.
	---  add_imperial_options = {["FACTION"] = {...}}
	---@type table<string, ImperialTable>
	self.add_imperial_options = tables.add_imperial_options or {}

	---SSD heroes who are leaders do not need to be on this list.
	---  leader_table = {"SPACE_HERO", ["HERO_TEAM"] = {"GROUND_HERO"}}
	---@type table<integer|string, string|string[]>
	self.leader_table = tables.leader_table or {}

	---SSD heroes need to be on *this* list whether or not they are leaders.
	---  hero_ssd_table = {["HERO"] = "TEXT"}
	---@type table<string, string>
	self.hero_ssd_table = tables.hero_ssd_table or {}

	---For factions in add_imperial_options if they get Dark Empire.
	---@type string[]
	self.dark_empire_units = tables.dark_empire_units or {}

	---For factions in add_imperial_options if they become Imperial
	---@type string[]
	self.base_imperial_units = tables.base_imperial_units or {}

	---@type string[]
	self.dead_leader_table = {}

	---@type table<string, integer>
	self.planet_values = require("PlanetValues")

	---@type string[]
	self.pending_integration_queue = {}

	self.became_imperial = false
	self.imperial_player = false
	for faction_name, _ in pairs(self.imperial_table) do
		if Find_Player(faction_name).Is_Human() then
			self.imperial_player = true
		end
	end

	--Dark Empire
	self.WinnerDetermined = false
	self.DarkEmpireAvailable = true
	if dark_empire == false then
		self.DarkEmpireAvailable = dark_empire
	end
	if self.StartingEra >= 4 then
		self.DarkEmpireAvailable = false
	end
	self.DarkEmpireUnlocked = false
	self.DarkEmpireStarted = false
	self.DarkEmpireEnded = false
	self.DarkEmpireFaction = "None"
	self.DarkEmpireRequireIntegrations = 2
	self.DarkEmpirePlanetBasedOnly = false
	
	---@class LegitimacyReward
	---@field unlocks string[]
	---@field text string
	---@field movie string
	---@field unlocked boolean
	---@field extra_dummy string?

	---@type LegitimacyReward[][]
	self.legitimacy_groups = require("eawx-mod-icw/LegitimacyRewardLibrary")

	---@type table<string, boolean>
	self.built_legitimacy_groups = {}

	self.HighestLegitimacy = "EMPIRE"
	self.LowestLegitimacy = "GREATER_MALDROOD"

	self.elapsed_weeks = 0
	self:first_week_setup()

	self.galactic_hero_killed_event = gc.Events.GalacticHeroKilled
	self.galactic_hero_killed_event:attach_listener(self.on_galactic_hero_killed, self)
	
	self.galactic_ssd_killed_event = gc.Events.GalacticSSDKilled
	self.galactic_ssd_killed_event:attach_listener(self.on_galactic_ssd_killed, self)

	self.planet_owner_changed_event = gc.Events.PlanetOwnerChanged
	self.planet_owner_changed_event:attach_listener(self.on_planet_owner_changed, self)

	self.production_finished_event = gc.Events.GalacticProductionFinished
	self.production_finished_event:attach_listener(self.on_construction_finished, self)

	self.Events = {}
	self.Events.FactionIntegrated = Observable()

	--Handle Extra_Dummy Swaps (Workaround)
	ExtraSwap(gc)

	--Setup Legitimacy Manager
	self:setup_options()
	self:setup_extra_dummies()

	---Detect objects from other submods
	-- Blue's LGHE submod
	self.submod_lghe = (Find_Object_Type("DUMMY_RECRUIT_GROUP_RYDONNI") ~= nil)
	-- Zsinj's Criminal Empire Submod
	self.submod_zce = (Find_Object_Type("DUMMY_RESEARCH_RAPTOR") ~= nil)
	-- Mboz's Imperial Heroes
	self.submod_mih = (Find_Object_Type("DUMMY_RECRUIT_GROUP_GHOSTWIRE") ~= nil)
end

---Legitimacy Manager options setup
function GovernmentEmpire:setup_options()
	--Logger:trace("entering GovernmentEmpire:setup_options")
	
	--Setup and unlock the legitimacy options
	for faction, content in pairs(self.imperial_table) do
		self:init_options(faction)
	end

	--Unlock these
	UnitUtil.SetLockList(self.human_faction, {
		"OPTION_INTEGRATE_ALL_LEGITIMACY",
		"OPTION_RESET_LEGITIMACY",
		"OPTION_LEGITIMACY_GROUP_2",
		"OPTION_LEGITIMACY_GROUP_3",
	}, true)
	
	--Unlock options that add factions to legitimacy system, if present
	for faction, content in pairs(self.add_imperial_options) do
		local num_planets = EvaluatePerception("Planet_Ownership", Find_Player(faction))
		if num_planets and num_planets > 0 then
			local option = string.upper("Option_Add_"..faction.."_Legitimacy")
			local option_obj = Find_Object_Type(option)
			if option_obj then
				content.add_option = option
				self.HumanPlayer.Unlock_Tech(option_obj)
			else
				StoryUtil.ShowScreenText("Error finding "..option, 10, nil, {r = 244, g = 200, b = 0})
				content.add_option = nil
			end
		end
	end
end

---For workaround to not edit Legitimacy_Heroes.xml
function GovernmentEmpire:setup_extra_dummies()
	--Logger:trace("entering GovernmentEmpire:setup_extra_dummies")
	
	for tier, groups_list in pairs(self.legitimacy_groups) do
		for group_number, group in pairs(groups_list) do
			for i, tech in pairs(group.unlocks) do
				if i == 1 then
					local extra_dummy = "Extra_"..tech
					if Find_Object_Type(extra_dummy) then
						self.legitimacy_groups[tier][group_number].extra_dummy = extra_dummy
					end
				else
					local reward_unit = "Reward_"..tech
					if Find_Object_Type(reward_unit) then
						table.insert(self.legitimacy_groups[tier][group_number].unlocks, reward_unit)
					end
				end
			end
		end
	end
end

---When starting a progressive game, integrate the already dead factions
function GovernmentEmpire:setup_dead_factions()
	if self.id ~= "PROGRESSIVE" then
		return
	end
	for faction, stats in pairs(self.imperial_table) do
		local num_planets = EvaluatePerception("Planet_Ownership", Find_Player(faction))
		if num_planets == 0 then
			self:check_add_integration_queue(faction, false, true)
		end
	end
end

---Spawn the fighter heroes from one faction to another faction on the map
---@param from_player string|PlayerObject|nil
---@param to_player string|PlayerObject|nil
function GovernmentEmpire:transfer_fighter_heroes(from_player, to_player)
	if type(from_player) == "string" then
        from_player = Find_Player(from_player)
    end
	if not from_player or not to_player then
		return
	end

	local spawn_list = {}
	for location_set, stats in pairs(Get_Hero_Entries()) do --Fighter hero entries.
		if stats.Hero_Squadron then
			local location_set_type = Find_Object_Type(location_set)
			local squadron_type = Find_Object_Type(stats.Hero_Squadron)
			if (stats.Faction and Find_Player(stats.Faction) == from_player) or
				(location_set_type and location_set_type.Is_Affiliated_With(from_player) and
				squadron_type and squadron_type.Is_Affiliated_With(from_player))
			then
				table.insert(spawn_list, stats.Hero_Squadron)
			end
		end
	end

	if table.getn(spawn_list) > 0 then
		StoryUtil.SpawnAtSafePlanet("", to_player, StoryUtil.GetSafePlanetTable(), spawn_list)
	end
end


---Moved from part of first_week_setup()
---@param faction_name string
function GovernmentEmpire:init_legitimacy(faction_name)
	--Logger:trace("entering GovernmentEmpire:init_legitimacy")
	if self.imperial_table[faction_name] then
		local added_legitimacy = EvaluatePerception("Planet_Ownership", Find_Player(faction_name))
		
		if added_legitimacy > 0 then
			self.imperial_table[faction_name].controls_planets = true
			self.StartingEmpires = self.StartingEmpires + 1
		end
		
		--Needs to be one under the value, since one point already comes from initial count.
		for planet_name, value in pairs(self.planet_values) do
			if TestValid(FindPlanet(planet_name)) and (FindPlanet(planet_name).Get_Owner() == Find_Player(faction_name)) then
				added_legitimacy = added_legitimacy + value - 1
			end
		end
		
		self.imperial_table[faction_name].legitimacy = self.imperial_table[faction_name].legitimacy + added_legitimacy

		if self.imperial_table[faction_name].controls_planets == false then
			self.imperial_table[faction_name].legitimacy = 0
		end
		
		if self.imperial_table[faction_name].legitimacy > self.imperial_table[self.HighestLegitimacy].legitimacy then
			self.HighestLegitimacy = faction_name
		end
	end
end

function GovernmentEmpire:first_week_setup()
	--Logger:trace("entering GovernmentEmpire:first_week_setup")

	self.StartingEmpires = 0
	for faction_name, _ in pairs(self.imperial_table) do
		self:init_legitimacy(faction_name)

		for faction, stats in pairs(self.imperial_table) do
			if faction_name ~= faction then
				UnitUtil.SetLockList(faction_name, stats.destruction_unlocks, false)
			end
		end
	end

	if self.StartingEmpires == 2 then
		self.DarkEmpireRequireIntegrations = 1
	elseif self.StartingEmpires <= 1 then
		self.DarkEmpirePlanetBasedOnly = true
	end

	self:calculate_percentile_legitimacy()
end

function GovernmentEmpire:Update()
	--Logger:trace("entering GovernmentEmpire:Update")
	self.elapsed_weeks = self.elapsed_weeks + 1

	if self.elapsed_weeks == 1 then
		if not self.imperial_player then
			crossplot:subscribe("UPDATE_GOVERNMENT", self.UpdateDisplay, self)
		end
		if self.human_faction == "EMPIREOFTHEHAND" then
			self.imperial_player = true
		end
	end
		
	if self.elapsed_weeks == 2 then
		for index=1, table.getn(self.legitimacy_groups) do
			for i, entry in pairs(self.legitimacy_groups[index]) do
				local swap_entry = Get_Swap_Entry(string.upper(entry.unlocks[1]))
				if swap_entry then
					for j, hero in pairs(swap_entry[2]) do
						local h = Find_First_Object(hero)
						if TestValid(h) then
							table.remove(self.legitimacy_groups[index], i)
							break
						end
					end
				end
			end
		end
		local z = Find_First_Object("URAI_FEN")
		if TestValid(z) then
			self.imperial_table["ZSINJ_EMPIRE"].zann_unlocked = true
		end
	end

	if self.elapsed_weeks == 2 then
		if self.DarkEmpireAvailable and not self.DarkEmpireUnlocked then
			self.HumanPlayer.Unlock_Tech(Find_Object_Type("DUMMY_DARK_EMPIRE"))
		end
		-- Integration of already dead factions
		self:setup_dead_factions()
	end
	
	for _, integrated_faction in pairs(self.pending_integration_queue) do
		--Logger:trace("entering GovernmentEmpire- integrate loop")
		local player_integrated_faction = Find_Player(integrated_faction)
		local player_highest_legitimacy = Find_Player(self.HighestLegitimacy)

		Faction_Total_Replace(player_integrated_faction,player_highest_legitimacy,1)

		-- Transfer the unused legitimacy reward groups
		self:transfer_groups(integrated_faction, self.HighestLegitimacy)

		self:transfer_fighter_heroes(integrated_faction, self.HighestLegitimacy)

		-- Zsinj's Criminal Empire Submod
		if self.HighestLegitimacy == "ZSINJ_EMPIRE" and player_integrated_faction == Find_Player("CORPORATE_SECTOR") then
            GlobalValue.Set("ZSINJ_SHIP_MARKET_UNLOCK", "TRUE")
        end

		--Logger:trace("entering GovernmentEmpire- integrate addons")
		if self.imperial_table[integrated_faction].destruction_unlocks then  
			UnitUtil.SetLockList(integrated_faction, self.imperial_table[integrated_faction].destruction_unlocks, false)
			UnitUtil.SetLockList(self.HighestLegitimacy, self.imperial_table[integrated_faction].destruction_unlocks)
			for _, unit in pairs(self.imperial_table[integrated_faction].destruction_unlocks) do
				table.insert(self.imperial_table[self.HighestLegitimacy].destruction_unlocks, unit)
			end
			for _, desc in pairs(self.imperial_table[integrated_faction].destruction_unlock_descs) do
				table.insert(self.imperial_table[self.HighestLegitimacy].destruction_unlock_descs, desc)
			end
			self.imperial_table[integrated_faction].destruction_unlocks = {}
			self.imperial_table[integrated_faction].destruction_unlock_descs = {}
			self.imperial_table[integrated_faction].legitimacy = 0
			self.imperial_table[integrated_faction].controls_planets = false
			self.imperial_table[self.HighestLegitimacy].factions_integrated = self.imperial_table[self.HighestLegitimacy].factions_integrated + self.imperial_table[integrated_faction].integrate_value + self.imperial_table[integrated_faction].factions_integrated
		end
	end
	
	---@type string[]
	self.pending_integration_queue = {}

	for faction_name, table in pairs(self.imperial_table) do
		if self.imperial_table[faction_name].controls_planets == true and EvaluatePerception("Planet_Ownership", Find_Player(faction_name)) == 0 then
			self.imperial_table[faction_name].controls_planets = false
		end
	end

	if self.DarkEmpireAvailable == true and self.DarkEmpireUnlocked == false then
		for faction_name, stats in pairs(self.imperial_table) do
			if self.imperial_table[faction_name].factions_integrated >= self.DarkEmpireRequireIntegrations then
				if self.imperial_table[faction_name].percentile_legitimacy > 60 then
					self:unlock_dark_empire(faction_name)
				end
			elseif self.DarkEmpirePlanetBasedOnly == true then 
				if EvaluatePerception("Planet_Ownership", Find_Player(faction_name)) > self.DarkEmpirePlanetBasedOnlyThreshold then
					self:unlock_dark_empire(faction_name)
				end
			end
		end
	end

	if self.StartingEra >= 4 and self.WinnerDetermined == false then
		for faction_name, stats in pairs(self.imperial_table) do
			if self.imperial_table[faction_name].factions_integrated >= 2 then
				if self.imperial_table[faction_name].percentile_legitimacy > 60 then
					self.WinnerDetermined = true
					GlobalValue.Set("IMPERIAL_REMNANT", faction_name)
				end
			end
		end
	end
end


---If not integrated, recompute the legitimacy for each faction
function GovernmentEmpire:reset_legitimacy()
	--Logger:trace("entering GovernmentEmpire:reset_legitimacy")

	-- Lock options and calculate legitimacy
	for faction, content in pairs(self.imperial_table) do
		self:lock_legitimacy_options(faction)
		if content.controls_planets and not content.is_integrated then
			content.legitimacy = 25
			self:init_legitimacy(faction)
		end
	end
	self:calculate_percentile_legitimacy()

	-- Unlock options and show legitimacy values
	for i, faction in ipairs(SortKeysByElement(self.imperial_table,"legitimacy","desc")) do
		local content = self.imperial_table[faction]
		if content.legitimacy > 0 then
			if i == 1 then
				self.HighestLegitimacy = faction
			else
				self:unlock_legitimacy_options(faction)
			end
			StoryUtil.ShowScreenText(
				Find_Player(faction).Get_Name()..": "..tostring(content.legitimacy).." = "..tostring(content.percentile_legitimacy).."%",
				7, nil, {r = 200, g = 200, b = 0}
			)
		end
	end
end

---The faction becomes imperial and all legitimacy rules apply
---@param faction string
function GovernmentEmpire:add_faction_to_legitimacy(faction)
	--Logger:trace("entering GovernmentEmpire:add_faction_to_legitimacy")
	local content = self.add_imperial_options[faction]
	if content and not self.imperial_table[faction] then
		local player = Find_Player(faction)
		if player and player.Is_Human() then
			self.became_imperial = true
		elseif Find_Object_Type("OPTION_INTEGRATE_ALL_LEGITIMACY") then
			self.HumanPlayer.Unlock_Tech(Find_Object_Type("OPTION_INTEGRATE_ALL_LEGITIMACY"))
		end
		self.imperial_table[faction] = content
		self:init_legitimacy(faction)
		self:calculate_percentile_legitimacy()
		self:init_options(faction)
		if player then
			StoryUtil.ShowScreenText(player.Get_Name().." added to legitimacy system", 10, nil, {r = 30, g = 190, b = 10})
		end
		UnitUtil.SetLockList(faction, self.base_imperial_units, true)
	end
end

---Will set the faction to be integrated to the highest, if valid
---@param faction string
function GovernmentEmpire:try_integrate_faction(faction)
	--Logger:trace("entering GovernmentEmpire:try_integrate_faction")
	if faction ~= self.HighestLegitimacy then
		if not Find_Player(faction).Is_Human() then
			self.imperial_table[faction].integrated_by_option = true
			self:lock_legitimacy_options(faction)
			self:check_add_integration_queue(faction, true)
		end
	else
		StoryUtil.ShowScreenText(
			"Operation cancelled. "..Find_Player(faction).Get_Name().." has the highest Legitimacy",
			7, nil, {r = 244, g = 180, b = 0}
		)
	end
end

---Will give large amounts of legitimacy to this faction, if valid
---@param faction string
function GovernmentEmpire:try_legitimized_faction(faction)
	--Logger:trace("entering GovernmentEmpire:try_legitimized_faction")
	content = self.imperial_table[faction]
	if not content.is_integrated then
		local amount = 1 + self.imperial_table[self.HighestLegitimacy].legitimacy - content.legitimacy
		if faction == self.HighestLegitimacy then
			local total_pts = content.legitimacy / (content.percentile_legitimacy / 100)
			amount = content.legitimacy - tonumber(Dirty_Floor(total_pts * 0.1))
		end
		self:adjust_legitimacy(faction, amount, true)
		self:lock_legitimacy_options(faction)
		
		StoryUtil.ShowScreenText(
			Find_Player(faction).Get_Name().." legitimized: "..tostring(content.legitimacy).." = "..tostring(content.percentile_legitimacy).."%",
			10, nil, {r = 40, g = 210, b = 0}
		)
	else
		StoryUtil.ShowScreenText("Operation cancelled. "..Find_Player(faction).Get_Name().." is being integrated", 7, nil, {r = 244, g = 180, b = 0})
	end
end

---Setup the instant max legitimacy option for this faction
---@param faction string
function GovernmentEmpire:init_option_legitimized(faction)
	--Logger:trace("entering GovernmentEmpire:init_option_legitimized")
	local option = string.upper("Option_Legitimized_"..faction)
	local option_obj = Find_Object_Type(option)
	if option_obj then
		self.imperial_table[faction].option_legitimized = option
	else
		StoryUtil.ShowScreenText("Warning: No option "..option, 10, nil, {r = 244, g = 200, b = 0})
		self.imperial_table[faction].option_legitimized = nil
	end
end

---Setup the instant integration option
---@param faction string
function GovernmentEmpire:init_option_integrate(faction)
	--Logger:trace("entering GovernmentEmpire:init_option_integrate")
	local option = string.upper("Option_Integrate_"..faction)
	local option_obj = Find_Object_Type(option)
	if option_obj then
		self.imperial_table[faction].option_integrate = option
	else
		StoryUtil.ShowScreenText("Warning: No option "..option, 10, nil, {r = 244, g = 200, b = 0})
		self.imperial_table[faction].option_integrate = nil
	end
end

---Setup the legitimacy options for this faction
---@param faction string
function GovernmentEmpire:init_options(faction)
	--Logger:trace("entering GovernmentEmpire:init_options")
	self:init_option_legitimized(faction)
	self:init_option_integrate(faction)
	self:unlock_legitimacy_options(faction)
	
	-- Human player can request legitimacy groups on demand.
	local player = Find_Player(faction)
	if player and player.Is_Human() then
		self:lock_group_options(false)
	end
end

---Lock or unlock options for human player to request legitimacy groups on demand.
---@param set_locked boolean
function GovernmentEmpire:lock_group_options(set_locked)
	for i = 1, 3 do
		local option_group = Find_Object_Type("OPTION_LEGITIMACY_GROUP_"..i)
		if option_group then
			if set_locked then
				self.HumanPlayer.Lock_Tech(option_group)
			else
				self.HumanPlayer.Unlock_Tech(option_group)
			end
		end
	end
end

---Unlock the legitimized and integrate options for this faction in the right conditions
---@param faction string
function GovernmentEmpire:unlock_legitimacy_options(faction)
	--Logger:trace("entering GovernmentEmpire:unlock_legitimacy_options")
	local content = self.imperial_table[faction]
	if content.controls_planets and faction ~= self.HighestLegitimacy and not content.is_integrated then
		if content.option_legitimized then
			self.HumanPlayer.Unlock_Tech(Find_Object_Type(content.option_legitimized))
		end
		if content.option_integrate and not Find_Player(faction).Is_Human() then
			self.HumanPlayer.Unlock_Tech(Find_Object_Type(content.option_integrate))
		end
	end
end

---Lock the legitimized and integrate options for this faction
---@param faction string
function GovernmentEmpire:lock_legitimacy_options(faction)
	--Logger:trace("entering GovernmentEmpire:lock_legitimacy_options")
	local content = self.imperial_table[faction]
	if content.option_legitimized then
		self.HumanPlayer.Lock_Tech(Find_Object_Type(content.option_legitimized))
	end
	if content.option_integrate then
		self.HumanPlayer.Lock_Tech(Find_Object_Type(content.option_integrate))
	end
end

---Replace the reward unit variant with the original unit type.
---Only works for space units.
---@param planet Planet
---@param object_type_name string
---@return boolean was_reward_unit
function check_reward_built(planet, object_type_name)
	if string.find(object_type_name, "^REWARD_") then
		local unit_type_name = string.gsub(object_type_name, "REWARD_", "")
		local unit_type = Find_Object_Type(unit_type_name)
		local reward_object = Find_First_Object(object_type_name)

		if TestValid(unit_type) and TestValid(reward_object) then
			reward_object.Despawn()
			SpawnList({unit_type_name}, planet:get_game_object(), planet:get_owner(), true, false)
		end
		return true
	end
	return false
end


---Check if options were built
---@param planet Planet
---@param object_type_name string
function GovernmentEmpire:on_construction_finished(planet, object_type_name)
	--Logger:trace("entering GovernmentEmpire:on_construction_finished")

	if check_reward_built(planet, object_type_name) then
		return
	end
	
	if object_type_name == "DUMMY_RECRUIT_GROUP_TAGGE_CSA" then
		self:tagge_handler(planet, object_type_name)
		return
	end

	-- Dark Empire Stuff
	if object_type_name == "DUMMY_DARK_EMPIRE" then
		self:unlock_dark_empire(self.HighestLegitimacy)
		return
	elseif object_type_name == "DUMMY_REGICIDE_PALPATINE" then
		self:enter_dark_empire()
		return
	elseif object_type_name == "DUMMY_REGICIDE_JAX" then
		self:dark_empire_tech(false)
		return
	end

	-- Zsinj's Criminal Empire Submod
	if object_type_name == "DUMMY_REGICIDE_REFUSE_PALPATINE" then 
        self:refuse_palpatine()
		return
    end

	-- Give group to Human or to HighestLegitimacy
	for i = 1, 3 do
		if object_type_name == "OPTION_LEGITIMACY_GROUP_"..i then
			local faction_name = self.HighestLegitimacy
			local num_groups = 1
			if i == 1 then
				faction_name = self.human_faction
			elseif i == 3 then
				num_groups = 10
			end
			for j = 1, num_groups do
				local group_found = self:group_joins(faction_name, true)
				if group_found == false then
					StoryUtil.ShowScreenText("No more legitimacy groups available. All groups unlocked", 15, nil, {r = 200, g = 244, b = 0})
					self:lock_group_options(true)
					break
				end
			end
			return
		end
	end
	
	-- Recompute the legitimacy for each faction
	if object_type_name == "OPTION_RESET_LEGITIMACY" then
		self:reset_legitimacy()
		return
	end
	
	-- Integrate all factions at the same time
	if object_type_name == "OPTION_INTEGRATE_ALL_LEGITIMACY" then
		self.HumanPlayer.Lock_Tech(Find_Object_Type("OPTION_INTEGRATE_ALL_LEGITIMACY"))
		for faction, content in pairs(self.imperial_table) do
			self:try_integrate_faction(faction)
		end
		return
	end
	
	-- Check the options for integrating specific factions
	for faction, content in pairs(self.imperial_table) do
		if content.option_integrate == object_type_name then
			self:try_integrate_faction(faction)
			return
		end
	end
	
	-- Check the options for instant legitimacy
	for faction, content in pairs(self.imperial_table) do
		if content.option_legitimized == object_type_name then
			self:try_legitimized_faction(faction)
			return
		end
	end

	-- Check the options for adding a faction to legitimacy
	for faction, content in pairs(self.add_imperial_options) do
		if object_type_name == content.add_option then
			self:add_faction_to_legitimacy(faction)
			return
		end
	end

	-- !!! This did not appear to work !!!
	-- Track groups that were built so duplicates will not be unlocked if this faction gets integrated.
	--[[
	local owner_name = planet:get_owner()
	if owner_name then
		local content = self.imperial_table[owner_name.Get_Faction_Name()]
		if content then
			for _, group in ipairs(content.joined_groups_detail) do
				if object_type_name == group.unlocks[1] or object_type_name == group.extra_dummy then
					group.is_complete = true
					return
				end
			end
		end
	end
	--]]
end


---@param planet Planet?
---@param object_type_name string?
function GovernmentEmpire:tagge_handler(planet, object_type_name)
	--Logger:trace("entering GovernmentEmpire:tagge_handler")

	-- In case they've unlocked it. Probably need to handle this differently since it'd be annoying to get the group and then lose it.
	for faction_name, _ in pairs(self.imperial_table) do
		UnitUtil.SetLockList(faction_name, {
			"DUMMY_RECRUIT_GROUP_TAGGE"
		}, false)
	end

	for i, entry in pairs(self.legitimacy_groups[4]) do
		if entry.text == "TEXT_GOVERNMENT_LEGITIMACY_GROUP_TAGGE" then
			table.remove(self.legitimacy_groups[4], i)
		end
	end
	local tagge_table = {{"CORPORATE_SECTOR","SHIP_MARKET","GENERIC_TAGGE_BATTLECRUISER_CSA",3}}
	
	crossplot:publish("ADJUST_MARKET_CHANCE", tagge_table)
	self.production_finished_event:detach_listener(self.tagge_handler, self)
end

---@param faction_name string
function GovernmentEmpire:unlock_dark_empire(faction_name)
	--Logger:trace("entering GovernmentEmpire:unlock_dark_empire")

	self.DarkEmpireUnlocked = true
	self.WinnerDetermined = true
	self.DarkEmpireFaction = faction_name
	GlobalValue.Set("IMPERIAL_REMNANT", faction_name)

	if Find_Player("local") == Find_Player(faction_name) then
		StoryUtil.Multimedia("TEXT_CONQUEST_EVENT_IR_PALPATINE_CONTACT", 15, nil, "Palpatine_Reborn_Loop", 0)
		Story_Event("PALPATINE_REQUEST_STARTED")
		Find_Player(faction_name).Unlock_Tech(Find_Object_Type("Dummy_Regicide_Palpatine"))
		if self.submod_zce then -- Zsinj's Criminal Empire Submod
			Find_Player(faction_name).Unlock_Tech(Find_Object_Type("Dummy_Regicide_Refuse_Palpatine"))
		end
	else 
		StoryUtil.Multimedia("TEXT_CONQUEST_EVENT_IR_PALPATINE_CONTACT_ENEMY", 15, nil, "Palpatine_Reborn_Loop", 0)
		self:enter_dark_empire()
	end
end

function GovernmentEmpire:enter_dark_empire()
	--Logger:trace("entering GovernmentEmpire:enter_dark_empire")
	if self.DarkEmpireUnlocked and self.WinnerDetermined and not self.DarkEmpireStarted then
		self.DarkEmpireStarted = true
		self:dark_empire_tech(true)
		crossplot:publish("STATE_TRANSITION", "DARK_EMPIRE_TRIGGER")
		crossplot:publish("IMPERIAL_REMNANT_DECIDED", "empty")
	end
end

---@param unlock boolean
function GovernmentEmpire:dark_empire_tech(unlock)
	if Find_Player(self.DarkEmpireFaction) and self.dark_empire_units then
		UnitUtil.SetLockList(self.DarkEmpireFaction, self.dark_empire_units, unlock)
	end
end

---@param hero_name string
---@param owner string
---@param killer string
function GovernmentEmpire:on_galactic_hero_killed(hero_name, owner, killer)
	--Logger:trace("entering GovernmentEmpire:on_galactic_hero_killed")
	if hero_name == "EMPEROR_PALPATINE_TEAM" or hero_name == "DARK_EMPIRE_CLONING_FACILITY" then
		self:dark_empire_tech(false)
	end

	for faction_name, _ in pairs(self.imperial_table) do
		if faction_name == owner then
			--all heroes
			self:adjust_legitimacy(owner, -1)

			--non-SSD leaders & warlords
			for leader_key, leader_value in pairs(self.leader_table) do
				if type(leader_value) ~= "table" then
					if hero_name == leader_value then
						self:adjust_legitimacy(owner, -4) --The 1 above adds to this
					end
				elseif hero_name == leader_key then
					self:adjust_legitimacy(owner, -4) --The 1 above adds to this
					table.insert(self.dead_leader_table,hero_name)
				end
			end
			
			--SSD heroes
			for unit, _ in pairs(self.Unit_List[1]) do
				if hero_name == unit then
					self:adjust_legitimacy(owner, -4) --The 1 above adds to this
				end
			end
		end

		if faction_name == killer then
			self.imperial_table[faction_name].heroes_killed_since_last_roll = self.imperial_table[faction_name].heroes_killed_since_last_roll + 1
		end
	end
end

---@param hero_name string
---@param owner string
---@param killer string
function GovernmentEmpire:on_galactic_ssd_killed(hero_name, owner, killer)
	--Logger:trace("entering GovernmentEmpire:on_galactic_hero_killed")
	for faction_name, _ in pairs(self.imperial_table) do
		if faction_name == owner then	
			--non-hero SSDs
			self:adjust_legitimacy(owner, -5)		
			break
		end		
	end	
end

---@param hero_team_name string
---@return boolean is_dead
function GovernmentEmpire:check_leader_dead(hero_team_name)
	--Logger:trace("entering GovernmentEmpire:check_leader_dead")
	if not next(self.dead_leader_table) then
		return false
	else
		for _,dead_team_name in pairs(self.dead_leader_table) do
			if hero_team_name == dead_team_name then
				return true
			end
		end
	end
	return false
end

---@param faction_name string
---@param hide_holo boolean?
---@return boolean|nil group_found true if a group was found, false if not, or nil if faction not imperial
function GovernmentEmpire:group_joins(faction_name, hide_holo)
	--Logger:trace("entering GovernmentEmpire:group_joins")
	if self.imperial_table[faction_name] then
		local level = self.imperial_table[faction_name].next_tier
		if self.imperial_table[faction_name].max_unlocked == true then
			-- levels 1 to 4 have three chances but level 5 has one
			level = tonumber(Dirty_Floor(GameRandom.Free_Random(3, 15)/3)) or GameRandom.Free_Random(1,4)
		else
			hide_holo = false
		end

		if faction_name == "ZSINJ_EMPIRE" then
			if not self.imperial_table["ZSINJ_EMPIRE"].zann_unlocked then

				if Find_Player("ZSINJ_EMPIRE").Is_Human() then
					StoryUtil.Multimedia("TEXT_GOVERNMENT_LEGITIMACY_GROUP_ZANN", 15, nil, "Tyber_Loop", 0) 
				end
				UnitUtil.SetLockList(faction_name, {"GENERIC_AGGRESSOR", "VENGEANCE_FRIGATE", "Dummy_Recruit_Group_Zann"})
				self.imperial_table["ZSINJ_EMPIRE"].zann_unlocked = true
				table.insert(self.imperial_table[faction_name].joined_groups, "Dummy_Recruit_Group_Zann")
				return true
			end
		end
	
		local search_start_level = level
		while table.getn(self.legitimacy_groups[level]) == 0 do
			level = level - 1
			if level == 0 then
				level = 5 -- try from max level
			end
			if level == search_start_level then
				return false
			end
		end
		local group_number = GameRandom.Free_Random(1, table.getn(self.legitimacy_groups[level]))
		local group = self.legitimacy_groups[level][group_number]

		self:unlock_group(faction_name, group, hide_holo)
		
		table.remove(self.legitimacy_groups[level], group_number)
		if level == 5 then
			self.imperial_table[faction_name].max_unlocked = true
		end
		if self.imperial_table[faction_name].next_tier < 5 then
			self.imperial_table[faction_name].next_tier = self.imperial_table[faction_name].next_tier + 1
		end
		return true
	end
	return nil
end

---@param faction_name string
---@param group LegitimacyReward
---@param hide_holo boolean?
function GovernmentEmpire:unlock_group(faction_name, group, hide_holo)
	if not self.imperial_table[faction_name] or not group then
		return
	end

	table.insert(self.imperial_table[faction_name].joined_groups, group.unlocks[1])
	table.insert(self.imperial_table[faction_name].joined_groups_detail, group) --So unused groups can be transfered later

	-- if group.is_complete then
	-- 	return
	-- end

	UnitUtil.SetLockList(faction_name, group.unlocks)
	if group.extra_dummy then
		UnitUtil.SetLockList(faction_name, {group.extra_dummy})
		UnitUtil.SetLockList(faction_name, {group.unlocks[1]}, false)
	end

	if group.text == "TEXT_GOVERNMENT_LEGITIMACY_GROUP_TAGGE" then
		UnitUtil.SetLockList("CORPORATE_SECTOR", {
			"DUMMY_RECRUIT_GROUP_TAGGE_CSA"
		}, false)
	end

	if Find_Player(faction_name).Is_Human() then
		if hide_holo or GlobalValue.Get("GOV_EMP_DISABLE_MULTIMEDIA_HOLO") == 1 then
			StoryUtil.Multimedia(group.text, 12, nil, nil, 0)
			GlobalValue.Set("GOV_EMP_DISABLE_MULTIMEDIA_HOLO", 0)
		else
			StoryUtil.Multimedia(group.text, 12, nil, group.movie, 0)
		end
	else
		StoryUtil.ShowScreenText(Find_Player(faction_name).Get_Name().." recieved %s",
			6, Find_Object_Type(group.unlocks[1]), {r = 244, g = 200, b = 0}
		)
	end
	-- StoryUtil.ShowScreenText(faction_name, 15)
	-- self.Events.FactionIntegrated:notify {
	--	 joined = Find_Player(faction_name)
	-- }
end

---@param from_faction string
---@param to_faction string
function GovernmentEmpire:transfer_groups(from_faction, to_faction)
	if not self.imperial_table[from_faction] or not self.imperial_table[to_faction] then
		return
	end
	for _, group in ipairs(self.imperial_table[from_faction].joined_groups_detail) do
		self:unlock_group(to_faction, group, true)
	end
end

---@param faction_name string
---@return boolean leader_alive
function GovernmentEmpire:faction_has_living_leaders(faction_name)
	--Logger:trace("entering GovernmentEmpire:faction_has_living_leaders")
	local leader_alive = 0
	local faction_player = Find_Player(faction_name)
	for leader_key, leader_value in pairs(self.leader_table) do
		if type(leader_value) ~= "table" then
			if Find_First_Object(leader_value) then
				if Find_First_Object(leader_value).Get_Owner() == faction_player then
					leader_alive = leader_alive + 1
				end
			end
		elseif not self:check_leader_dead(leader_key) then
			if Find_First_Object(leader_value[1]) then
				if Find_First_Object(leader_value[1]).Get_Owner() == faction_player then
					leader_alive = leader_alive + 1
				end
			end
		end
	end

	local ssd_alive = 0
	local object_list = {}
	for unit, _ in pairs(self.Unit_List[1]) do
		object_list = Find_All_Objects_Of_Type(unit, Find_Player(faction_name))
		ssd_alive = ssd_alive + table.getn(object_list)
	end

	if leader_alive == 0 and ssd_alive == 0 then
		return false
	end
	
	return true
end

---@param planet Planet
---@param new_owner_name string
---@param old_owner_name string
---@param bypass boolean?
function GovernmentEmpire:on_planet_owner_changed(planet, new_owner_name, old_owner_name, bypass)
	--Logger:trace("entering GovernmentEmpire:on_planet_owner_changed")
	if new_owner_name ~= "NEUTRAL" and old_owner_name ~= "NEUTRAL" then
		if self.imperial_table[old_owner_name] or self.imperial_table[new_owner_name] then
			local value = 1
			local name = planet:get_name()
			for important_planet, new_value in pairs(self.planet_values) do
				if name == important_planet then
					value = new_value
					break
				end
			end

			local no_group = false
			if self.imperial_table[old_owner_name] then
				no_group = self.imperial_table[old_owner_name].integrated_by_option

				self:adjust_legitimacy(old_owner_name, (0 - value), no_group)
			end
			
			if self.imperial_table[new_owner_name] then
				self:adjust_legitimacy(new_owner_name, value, no_group)
			end
		end
	end

	self:check_add_integration_queue(old_owner_name, bypass)
end

---@param old_owner_name string Faction to potentially add to the integration queue
---@param bypass boolean?
---@param hide_speech boolean?
function GovernmentEmpire:check_add_integration_queue(old_owner_name, bypass, hide_speech)
	--Check if old owner can be integrated to highest
	if self.imperial_table[old_owner_name] and
		not Find_Player(old_owner_name).Is_Human() and
		not self.imperial_table[old_owner_name].is_integrated and
		self.HighestLegitimacy ~= old_owner_name and
		self.imperial_table[self.HighestLegitimacy].controls_planets and
		not self.imperial_table[self.HighestLegitimacy].is_integrated
	then
		if bypass or ( --below planet threshold and leaders dead
			EvaluatePerception("Planet_Ownership", Find_Player(old_owner_name)) <= self.LegitimacyAbsorb and
			not self:faction_has_living_leaders(old_owner_name)
		) then
			StoryUtil.ChangeAIPlayer(old_owner_name, "None")
			if not hide_speech and (self.LegitimacyAbsorb > 0 or table.getn(self.imperial_table[old_owner_name].destruction_unlocks) > 0) then
				if GlobalValue.Get("GOV_EMP_DISABLE_MULTIMEDIA_HOLO") == 1 then
					StoryUtil.Multimedia("TEXT_GOVERNMENT_LEGITIMACY_ABSORB_SPEECH_"..tostring(old_owner_name), 15, nil, nil, 0, nil, {r = 255, g = 255, b = 100}) 
					GlobalValue.Set("GOV_EMP_DISABLE_MULTIMEDIA_HOLO", 0)
				else
					StoryUtil.Multimedia("TEXT_GOVERNMENT_LEGITIMACY_ABSORB_SPEECH_"..tostring(old_owner_name), 15, nil, "Imperial_Naval_Officer_Loop", 0, nil, {r = 255, g = 255, b = 100})
				end
			end
			--Need to have a way to turn this back on when factions re-emerge in the future.
			self.imperial_table[old_owner_name].is_integrated = true
			if self.imperial_table[old_owner_name].legitimacy > self.LegitimacyAbsorb then
				self.imperial_table[old_owner_name].legitimacy = self.LegitimacyAbsorb
			end
			table.insert(self.pending_integration_queue, old_owner_name)
		end
	end
end

---@param faction_name string
---@param added_legitimacy integer
---@param no_group boolean?
function GovernmentEmpire:adjust_legitimacy(faction_name, added_legitimacy, no_group)
	--Logger:trace("entering GovernmentEmpire:adjust_legitimacy")

	local old_legitimacy = self.imperial_table[faction_name].legitimacy
	self.imperial_table[faction_name].legitimacy = old_legitimacy + added_legitimacy
	if self.imperial_table[faction_name].legitimacy < 0 then
		self.imperial_table[faction_name].legitimacy = 0
	end

	if self.imperial_table[faction_name].legitimacy > self.imperial_table[self.HighestLegitimacy].legitimacy then
		local old_high_faction = self.HighestLegitimacy
		self.HighestLegitimacy = faction_name
		
		--Handle options when a different faction becomes the highest
		self:lock_legitimacy_options(faction_name)
		self:unlock_legitimacy_options(old_high_faction)
	end

	if self.imperial_table[faction_name].legitimacy < self.imperial_table[self.LowestLegitimacy].legitimacy then
		self.LowestLegitimacy = faction_name
	end

	self:calculate_percentile_legitimacy()
	
	if no_group then
		return
	end

	if old_legitimacy < self.imperial_table[faction_name].legitimacy  and self.elapsed_weeks >= 2 then
		local chance = GameRandom.Free_Random(1,40) + added_legitimacy + self.imperial_table[faction_name].heroes_killed_since_last_roll
		if self.imperial_table[faction_name].next_tier == 1 then
			chance = chance + 10
		end	
		if self.imperial_table[faction_name].next_tier == 2 then
			chance = chance + 5
		end	
		if chance >= 40 or self.imperial_table[faction_name].failed_rolls >= 15 then
			self.imperial_table[faction_name].failed_rolls = 0
			self:group_joins(faction_name)
			self.imperial_table[faction_name].heroes_killed_since_last_roll = 0
			self.imperial_table[faction_name].failed_rolls = self.imperial_table[faction_name].failed_rolls - 5
			if self.imperial_table[faction_name].failed_rolls < 0 then
				self.imperial_table[faction_name].failed_rolls = 0
			end
		else
			self.imperial_table[faction_name].failed_rolls = self.imperial_table[faction_name].failed_rolls + 1
		end
	end

end

function GovernmentEmpire:calculate_percentile_legitimacy()
	--Logger:trace("entering GovernmentEmpire:calculate_percentile_legitimacy")
	local total_legitimacy = 0
	for faction, _ in pairs(self.imperial_table) do
		total_legitimacy = total_legitimacy + self.imperial_table[faction].legitimacy
	end

	if total_legitimacy <= 0 then
		total_legitimacy = 1 
	end

	for faction, _ in pairs(self.imperial_table) do
		self.imperial_table[faction].percentile_legitimacy = tonumber(Dirty_Floor((self.imperial_table[faction].legitimacy / total_legitimacy)*100 )) or 0
	end

end

function GovernmentEmpire:UpdateDisplay()
	--Logger:trace("entering GovernmentEmpire:UpdateDisplay")
	local plot = Get_Story_Plot("Conquests\\Player_Agnostic_Plot.xml")
	local government_display_event = plot.Get_Event("Government_Display")
	if self.imperial_player == true then
		government_display_event.Clear_Dialog_Text()
		government_display_event.Set_Reward_Parameter(1, self.human_faction)
	else
		government_display_event.Add_Dialog_Text("TEXT_NONE")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_HEADER")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DESCRIPTION")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	end

	if true then
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_HEADER")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		for i,faction_name in ipairs(SortKeysByElement(self.imperial_table,"legitimacy","desc")) do
			if self.imperial_table[faction_name].controls_planets == true then
				government_display_event.Add_Dialog_Text(
					"%s".. ": "..tostring(self.imperial_table[faction_name].legitimacy).." ("..tostring(self.imperial_table[faction_name].percentile_legitimacy).."%%)",
					CONSTANTS.ALL_FACTION_TEXTS[string.upper(faction_name)]
				)
				if self:faction_has_living_leaders(faction_name) then
					government_display_event.Add_Dialog_Text("TEXT_NONE")
					government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LIVING_LEADERS")
					local faction_player = Find_Player(faction_name)
					--SSD heroes
					for hero_ssd, hero_ssd_text in pairs(self.hero_ssd_table) do
						if Find_First_Object(hero_ssd) then
							if Find_First_Object(hero_ssd).Get_Owner() == faction_player then
								government_display_event.Add_Dialog_Text(hero_ssd_text)
							end
						end
					end
					--Non-SSD leaders & warlords
					for leader_key, leader_value in pairs(self.leader_table) do
						if type(leader_value) ~= "table" then
							if Find_First_Object(leader_value) then
								if Find_First_Object(leader_value).Get_Owner() == faction_player then
									government_display_event.Add_Dialog_Text("%s",Find_Object_Type(leader_value))
								end
							end
						elseif not self:check_leader_dead(leader_key) then
							if Find_First_Object(leader_value[1]) then
								if Find_First_Object(leader_value[1]).Get_Owner() == faction_player then
									government_display_event.Add_Dialog_Text("%s",Find_Object_Type(leader_value[1]))
								end
							end
						end
					end		
					--Generic SSDs
					for unit, _ in pairs(self.Unit_List[1]) do
						if Find_First_Object(unit) then
							if Find_First_Object(unit).Get_Owner() == faction_player then
								if not self.hero_ssd_table[unit] then
									government_display_event.Add_Dialog_Text("%s",Find_Object_Type(unit))
								end
							end
						end
					end
				end
				if self.imperial_table[faction_name].destruction_unlock_descs[1] ~= nil then
					government_display_event.Add_Dialog_Text("TEXT_NONE")
					government_display_event.Add_Dialog_Text("Integration Rewards:")
					for k, desc in pairs(self.imperial_table[faction_name].destruction_unlock_descs) do
						government_display_event.Add_Dialog_Text(" "..tostring(k)..".  "..desc)
					end
				end
				if self.imperial_table[faction_name].factions_integrated ~= 0 then
					government_display_event.Add_Dialog_Text("TEXT_NONE")
					government_display_event.Add_Dialog_Text("Factions Integrated: " .. tostring(self.imperial_table[faction_name].factions_integrated))
				end
				if self.imperial_table[faction_name].joined_groups[1] ~= nil then
					government_display_event.Add_Dialog_Text("TEXT_NONE")
					government_display_event.Add_Dialog_Text("Minor Groups Integrated: " .. tostring(table.getn(self.imperial_table[faction_name].joined_groups)))
					for _, name in pairs(self.imperial_table[faction_name].joined_groups) do
						government_display_event.Add_Dialog_Text("%s",Find_Object_Type(name))
					end
				end

				government_display_event.Add_Dialog_Text("TEXT_NONE")
				government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
			end
		end
	end

	if self.imperial_player or self.became_imperial then
		government_display_event.Add_Dialog_Text("TEXT_NONE")
		
		if not self.became_imperial then
			government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_HEADER")
			government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
			government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DESCRIPTION")
		end
		
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_MOD_HEADER")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_BASE")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_MOD_CONQUEST1")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_MOD_CONQUEST2")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_MOD_PLUS3")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_MOD_PLUS5")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_MOD_PLUS10")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_MOD_DEAD_HERO")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_MOD_DEAD_LEADER")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_LEGITIMACY_MOD_RIVAL")
		
		government_display_event.Add_Dialog_Text("TEXT_NONE")
		
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_INTEGRATION_HEADER")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_INTEGRATION_DESCRIPTION", self.LegitimacyAbsorb)
		
		government_display_event.Add_Dialog_Text("TEXT_NONE")
		
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_HEADER")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_DESCRIPTION")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		government_display_event.Add_Dialog_Text("Requirements:")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")

		if self.DarkEmpireAvailable then
			if self.DarkEmpirePlanetBasedOnly == false then
				government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REQUIREMENT_1")
				government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REQUIREMENT_2", self.DarkEmpireRequireIntegrations)
			else
				government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REQUIREMENT_2", self.DarkEmpireRequireIntegrations)
			end
		else
			government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_UNAVAILABLE")
		end
			
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_HEADER")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_1")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_2")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_3")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_4")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_5")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_6")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_7")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_8")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_9")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_10")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_DARKEMPIRE_REWARD_11")
		
		government_display_event.Add_Dialog_Text("TEXT_NONE")
		
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMSON_EMPIRE_REWARD_HEADER")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMSON_EMPIRE_REWARD_REWARD_1")
		
		government_display_event.Add_Dialog_Text("TEXT_NONE")
		
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_REUNIFICATION_REWARD_HEADER")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_REUNIFICATION_REWARD_REWARD_1")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_REUNIFICATION_REWARD_REWARD_2")
		
		government_display_event.Add_Dialog_Text("TEXT_NONE")
		
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_FINAL_IMPERIAL_PUSH_REWARD_HEADER")
		government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
		
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_FINAL_IMPERIAL_PUSH_REWARD_REWARD_1")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_FINAL_IMPERIAL_PUSH_REWARD_REWARD_2")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_FINAL_IMPERIAL_PUSH_REWARD_REWARD_3")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_FINAL_IMPERIAL_PUSH_REWARD_REWARD_4")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_FINAL_IMPERIAL_PUSH_REWARD_REWARD_5")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_FINAL_IMPERIAL_PUSH_REWARD_REWARD_6")

		-- Zsinj's Criminal Empire Submod
		if self.human_faction == "ZSINJ_EMPIRE" and self.submod_zce then
			government_display_event.Add_Dialog_Text("TEXT_NONE")
			self:zsinj_display_text(government_display_event)
		end
		
		government_display_event.Add_Dialog_Text("TEXT_NONE")
		self:reward_display_text(government_display_event)
		
	end
	Story_Event("GOVERNMENT_DISPLAY")
end

---@param government_display_event StoryEventWrapper
function GovernmentEmpire:reward_display_text(government_display_event)
	if not government_display_event then
		return
	end

	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_REWARD_LIST")
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_1")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_1_REWARD_1")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_1_REWARD_2")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_1_REWARD_3")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_1_REWARD_4")

	if self.submod_lghe or self.submod_mih then
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_1_REWARD_5")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_1_REWARD_6")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_1_REWARD_7")
	end
	if self.submod_mih then
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_1_REWARD_8")
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_1_REWARD_9")
	end
	
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_1")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_2")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_3")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_4")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_5")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_6")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_7")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_8")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_9")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_10")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_11")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_12")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_13")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_14")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_15")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_16")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_17")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_18")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_19")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_20")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_21")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_22")

	if self.submod_mih or self.submod_lghe then
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_23")
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_24")
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_25")
	end
	if self.submod_lghe then
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_2_REWARD_26")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_7")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_7B")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_8")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_8B")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_8C")
	end
	
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_1")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_2")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_3")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_4")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_5")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_6")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_7")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_8")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_9")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_10")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_11")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_12")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_13")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_14")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_15")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_16")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_17")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_18")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_19")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_20")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_21")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_22")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_23")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_24")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_25")

	if self.submod_lghe or self.submod_mih then
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_26")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_27")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_28")
	end
	if self.submod_mih then
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_29")
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_30")
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_3_REWARD_31")
	end
	
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_1")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_2")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_3")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_4")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_5")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_6")

	if not self.submod_lghe then
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_7")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_8")
	end

	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_9")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_10")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_11")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_12")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_13")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_14")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_15")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_16")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_17")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_18")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_19")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_20")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_21")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_22")
	
	if self.submod_lghe or self.submod_mih then
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_23")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_24")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_25")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_26")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_27")
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_4_REWARD_28")
	end
	
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_1")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_2")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_3")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_4")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_5")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_6")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_7")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_8")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_9")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_10")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_11")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_12")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_13")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_14")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_15")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_16")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_17")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_18")

	if self.submod_mih then
		government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_19")
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_20")
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_21")
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_22")
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_23")
        government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_5_REWARD_24")
	end
	
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_SPECIAL")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_SPECIAL_REWARD_1")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_SPECIAL_REWARD_2")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_SPECIAL_REWARD_3")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_SPECIAL_REWARD_4")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_TIER_SPECIAL_REWARD_5")
end

-- Zsinj's Criminal Empire Submod
---@param government_display_event StoryEventWrapper
function GovernmentEmpire:zsinj_display_text(government_display_event)
	if not government_display_event then
		return
	end
		
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_HEADER")
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_DESCRIPTION")
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	government_display_event.Add_Dialog_Text("Requirements:")
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")

	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REQUIREMENT_2")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REQUIREMENT_1")
		
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_HEADER")
	government_display_event.Add_Dialog_Text("TEXT_DOCUMENTATION_BODY_SEPARATOR")
	
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_1")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_2")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_16")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_17")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_3")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_4")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_5")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_6")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_7")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_8")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_9")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_10")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_11")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_12")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_13")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_14")
	government_display_event.Add_Dialog_Text("TEXT_GOVERNMENT_EMPIRE_CRIMINALEMPIRE_REWARD_15")
end

-- Zsinj's Criminal Empire Submod
function GovernmentEmpire:refuse_palpatine()
	if self.HighestLegitimacy == "ZSINJ_EMPIRE" and
		self.imperial_table["HUTT_CARTELS"] and
		self.imperial_table["HUTT_CARTELS"].is_integrated == true
	then
		GlobalValue.Set("ZANN_CONTACTED", "TRUE")
	end
	
	local legitimacy_table = {
		{faction = "EMPIRE", legitimacy = self.imperial_table["EMPIRE"].legitimacy,
		},
		{faction = "PENTASTAR", legitimacy = self.imperial_table["PENTASTAR"].legitimacy,
		},
		{faction = "GREATER_MALDROOD", legitimacy = self.imperial_table["GREATER_MALDROOD"].legitimacy,
		},
		{faction = "ERIADU_AUTHORITY", legitimacy = self.imperial_table["ERIADU_AUTHORITY"].legitimacy,
		},
		{faction = "ZSINJ_EMPIRE", legitimacy = self.imperial_table["ZSINJ_EMPIRE"].legitimacy,
		},
	}
	
	table.sort(legitimacy_table, faction_legitimacy_ordering)
	local second_highest_legitimacy = table.remove(legitimacy_table, table.getn(legitimacy_table)-1)

	-- second highest legitimacy
	self.DarkEmpireFaction = second_highest_legitimacy.faction
	GlobalValue.Set("IMPERIAL_REMNANT", self.DarkEmpireFaction)
	self:enter_dark_empire()

	StoryUtil.Multimedia("TEXT_CONQUEST_EVENT_IR_PALPATINE_CONTACT_ENEMY", 15, nil, "Palpatine_Reborn_Loop", 0)
end

-- Zsinj's Criminal Empire Submod
---@param faction_swap1 table<string, string|integer>
---@param faction_swap2 table<string, string|integer>
---@return boolean ordered
function faction_legitimacy_ordering(faction_swap1, faction_swap2) 
    return faction_swap1.legitimacy < faction_swap2.legitimacy
end

return GovernmentEmpire
