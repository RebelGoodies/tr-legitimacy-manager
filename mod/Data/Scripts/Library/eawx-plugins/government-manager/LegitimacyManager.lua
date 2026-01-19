require("deepcore/std/class")
require("eawx-plugins/hero-swap/RewardSwap")
require("eawx-plugins/tech-handler/ResearchCheat")
require("eawx-util/StoryUtil")
require("eawx-util/UnitUtil")

---@type table<string, any>
CONSTANTS = ModContentLoader.get("GameConstants")

---@class LegitimacyManager
LegitimacyManager = class()

---@param GovEmpire GovernmentEmpire
---@param gc GalacticConquest
---@param id string
function LegitimacyManager:new(GovEmpire, gc, id)
    self.gc = gc
    self.id = id
    self.GovEmpire = GovEmpire

    self.HumanPlayer = Find_Player("local")
    self.human_faction = self.HumanPlayer.Get_Faction_Name()
    self.human_became_imperial = false

    self.option_reset_values = "OPTION_RESET_LEGITIMACY"
    self.option_integrate_all = "OPTION_INTEGRATE_ALL_LEGITIMACY"
    self.option_cheat_dark_empire = "CHEAT_DARK_EMPIRE"

    require("ImperialTables")
    ---@type ImperialTables
    local tables = GetImperialTables()

    ---Added to Imperial legitimacy system if option selected.
    ---  add_imperial_options = {["FACTION"] = {...}}
    ---@type table<string, ImperialTable>
    self.add_imperial_options = tables.add_imperial_options or {}

    ---For factions in add_imperial_options if they get Dark Empire.
    ---@type string[]
    self.dark_empire_units = tables.dark_empire_units or {}

    ---For factions in add_imperial_options if they become Imperial
    ---@type string[]
    self.base_imperial_units = tables.base_imperial_units or {}

    if not self.GovEmpire.imperial_table then
        local message = "Warning: No imperial_table found in GovEmpire."
        StoryUtil.ShowScreenText(message, 10, nil, {r = 244, g = 200, b = 0})
        self.GovEmpire.imperial_table = tables.imperial_table or {}
    end

    self.production_finished_event = gc.Events.GalacticProductionFinished
    self.production_finished_event:attach_listener(self.on_production_finished, self)

    self.init_event = GovEmpire.Events.InitializedLegitimacy
    self.init_event:attach_listener(self.on_init, self)

    self.highest_legitimacy_changed_event = GovEmpire.Events.HighestLegitimacyChanged
    self.highest_legitimacy_changed_event:attach_listener(self.on_highest_legitimacy_changed, self)

    if self.id == "PROGRESSIVE" then
        crossplot:subscribe("STATE_TRANSITION", self.on_state_transition, self)
    end

    -- Handle Reward_Unit Swaps (Optional)
    RewardSwap(gc)
    -- Handle Research Cheat (Optional)
    ResearchCheat(gc)
end

---Call from GovernmentEmpire:initialize_legitimacy()
function LegitimacyManager:on_init()
    if self.initialized then
        return
    end
    self.initialized = true

    -- Setup Legitimacy Manager
    self:setup_unit_reward_variants()
    self:setup_options()
	self:integrate_dead_factions()
    self:set_lock_dark_empire(self.GovEmpire.DarkEmpireUnlocked)
    -- self:transfer_fighter_heroes("EMPIRE", self.human_faction) -- For testing
end

---Event handler for when highest legitimacy faction changes
---@param event_info table{old_highest: string, new_highest: string}
function LegitimacyManager:on_highest_legitimacy_changed(event_info)
    local old_high_faction = event_info.old_highest
    local new_high_faction = event_info.new_highest

    local message = string.format(
        "Highest legitimacy changed from %s to %s.",
        Find_Player(old_high_faction).Get_Name(),
        Find_Player(new_high_faction).Get_Name()
    )
    local color = CONSTANTS.FACTION_COLORS[new_high_faction]
    -- StoryUtil.ShowScreenText(message, 7, nil, color)

    -- Handle options when a different faction becomes the highest
    self:lock_legitimacy_options(new_high_faction)
    self:unlock_legitimacy_options(old_high_faction, new_high_faction)
end

---Event handler for state transitions
---@param state_id string
function LegitimacyManager:on_state_transition(state_id)
    if state_id == "STATE_TRANSITION_DARK_EMPIRE" then
        self:set_lock_dark_empire(true)
    else
        self:set_lock_dark_empire(false)
    end
end

---Legitimacy Manager options setup
function LegitimacyManager:setup_options()
    -- Setup and unlock the legitimacy options for Imperial factions
    for faction, content in pairs(self.GovEmpire.imperial_table) do
        self:init_options(faction)
    end

    -- Unlock these
    UnitUtil.SetLockList(self.human_faction, {
        self.option_reset_values,
        self.option_integrate_all,
    }, true)

    -- Unlock options that add factions to legitimacy system, if present
    for faction, content in pairs(self.add_imperial_options) do
        local num_planets = EvaluatePerception("Planet_Ownership", Find_Player(faction))
        if num_planets and num_planets > 0 then
            local option = string.upper("Option_Add_Imperial_"..faction)
            local option_obj = Find_Object_Type(option)
            if option_obj then
                content.add_option = option
                self.HumanPlayer.Unlock_Tech(option_obj)
            else
                StoryUtil.ShowScreenText("Warning: Error finding "..option, 15, nil, {r = 244, g = 200, b = 0})
                content.add_option = nil
            end
        end
    end
end

---When starting a progressive game, integrate the already dead factions
function LegitimacyManager:integrate_dead_factions()
    if self.id ~= "PROGRESSIVE" then
        return
    end
    for faction, _ in pairs(self.GovEmpire.imperial_table) do
        local num_planets = EvaluatePerception("Planet_Ownership", Find_Player(faction))
        if num_planets == 0 and faction ~= "IMPERIAL_PROTEUS" then
            self.GovEmpire:check_for_integration(faction, false, true)
        end
    end
end

---Extended update to handle legitimacy integration queue
---Called from GovernmentEmpire:update()
function LegitimacyManager:update()
    if not self.inited then
        self.inited = true
		if self.GovEmpire.human_is_imperial == false then
            if self.HumanPlayer == Find_Player("EmpireoftheHand") then
                crossplot:subscribe("UPDATE_RESOURCES", self.GovEmpire.UpdateDisplay, self.GovEmpire)
            else
			    crossplot:subscribe("UPDATE_GOVERNMENT", self.GovEmpire.UpdateDisplay, self.GovEmpire)
            end
		end
	end

    -- Extended integration process (assuming GovEmpire processes after this)
    local highest_legit_faction = self.GovEmpire.HighestLegitimacy
    for victim_name, imptable in pairs(self.GovEmpire.imperial_table) do
        if imptable.pending_integration then
            -- Transfer the legitimacy reward groups and fighter heroes
            self:transfer_groups(victim_name, highest_legit_faction)
            self:transfer_fighter_heroes(victim_name, highest_legit_faction)
        end
    end
end

---Check if options were built
---@param planet Planet the planet where the unit was built
---@param object_type_name string the built unit type name
function LegitimacyManager:on_production_finished(planet, object_type_name)
    if object_type_name == self.option_cheat_dark_empire then
        self:cheat_dark_empire()
        return
    end

    -- Recompute the legitimacy for each faction
    if object_type_name == self.option_reset_values then
        self:reset_legitimacy()
        return
    end

    -- Check the options for adding a faction to legitimacy
    for faction, content in pairs(self.add_imperial_options) do
        if object_type_name == content.add_option then
            self:add_faction_to_legitimacy(faction)
            return
        end
    end

    -- Integrate all factions at the same time
    if object_type_name == self.option_integrate_all then
        UnitUtil.SetLockList(self.human_faction, {self.option_integrate_all}, false)
        for faction, content in pairs(self.GovEmpire.imperial_table) do
            self:try_integrate_faction(faction)
        end
        return
    end

    -- Check the options for integrating specific factions
    for faction, content in pairs(self.GovEmpire.imperial_table) do
        if content.option_integrate == object_type_name then
            self:try_integrate_faction(faction)
            return
        end
    end

    -- Check the options for instant legitimacy
    for faction, content in pairs(self.GovEmpire.imperial_table) do
        if content.option_legitimized == object_type_name then
            self:try_legitimized_faction(faction)
            return
        end
    end
end

---Check if the faction is valid for legitimacy operations.
---The faction must control planets and not be integrating or integrated.
---@param faction_imp_table ImperialTable the faction's imperial table entry
---@return boolean is_valid true if valid for legitimacy operations
function LegitimacyManager:is_valid_for_legitimacy(faction_imp_table)
    return faction_imp_table and
        faction_imp_table.controls_planets and
        not faction_imp_table.is_integrated and
        not faction_imp_table.pending_integration
end

---If not integrated, recompute the legitimacy for each faction
function LegitimacyManager:reset_legitimacy()
    -- Lock options and calculate legitimacy
    for faction, content in pairs(self.GovEmpire.imperial_table) do
        self:lock_legitimacy_options(faction)
        if self:is_valid_for_legitimacy(content) then
            content.legitimacy = 25
            self.GovEmpire:init_faction_legitimacy(faction)
        end
    end
    self.GovEmpire:calculate_percentile_legitimacy()

    -- Unlock options and show legitimacy values
    for i, faction in ipairs(SortKeysByElement(self.GovEmpire.imperial_table,"legitimacy","desc")) do
        local content = self.GovEmpire.imperial_table[faction]
        if content.legitimacy > 0 then
            if i == 1 then
                self.GovEmpire.HighestLegitimacy = faction
            else
                self:unlock_legitimacy_options(faction)
            end
            local message = string.format(
                "Legitimacy reset: %s = %s%% for %s",
                tostring(content.legitimacy),
                tostring(content.percentile_legitimacy),
                Find_Player(faction).Get_Name()
            )
            local color = CONSTANTS.FACTION_COLORS[faction]
            StoryUtil.ShowScreenText(message, 7, nil, color)
        end
    end
end

---The faction becomes imperial and all legitimacy rules apply
---@param faction string
function LegitimacyManager:add_faction_to_legitimacy(faction)
    local content = self.add_imperial_options[faction]
    if not content then
        return
    end

    if self.GovEmpire.imperial_table[faction] then
        local message = Find_Player(faction).Get_Name().." is already part of the legitimacy system."
        StoryUtil.ShowScreenText(message, 7, nil, {r = 244, g = 180, b = 0})
        return
    end

    self.GovEmpire.imperial_table[faction] = content
    self.GovEmpire:init_faction_legitimacy(faction)
    self.GovEmpire:calculate_percentile_legitimacy()

    self:init_options(faction)
    UnitUtil.SetLockList(faction, self.base_imperial_units, true)
    UnitUtil.SetLockList(self.human_faction, {self.option_integrate_all}, true)

    local player = Find_Player(faction)
    if player then
        local readable_name = player.Get_Name()
        local color = CONSTANTS.FACTION_COLORS[faction]
        StoryUtil.ShowScreenText(readable_name.." added to legitimacy system.", 10, nil, color)

        if player.Is_Human() then
            self.human_became_imperial = true
        elseif CONSTANTS.ALL_FACTIONS_AI[faction] == "None" then
            StoryUtil.ChangeAIPlayer(faction, "WarlordAI")
            StoryUtil.ShowScreenText(readable_name.." AI set to WarlordAI.", 10, nil, color)
        end
        if CONSTANTS.ALL_FACTION_NAMES[faction] then
            crossplot:publish("FACTION_DISPLAY_NAME_CHANGE", faction, "Imperial "..readable_name)
        end
    end

    -- Intended for GroupSelector: Human player can request groups for self.
    self.GovEmpire.Events.FactionBecameImperial:notify(faction)
end

---Will set the faction to be integrated to the highest, if valid
---@param faction string
function LegitimacyManager:try_integrate_faction(faction)
    if Find_Player(faction).Is_Human() then
        return
    end
    if faction ~= self.GovEmpire.HighestLegitimacy then
        self.GovEmpire.imperial_table[faction].integrated_by_option = true
        self:lock_legitimacy_options(faction)
        self.GovEmpire:check_for_integration(faction, true)
    else
        local message = "Operation cancelled. "..Find_Player(faction).Get_Name().." has the highest legitimacy."
        StoryUtil.ShowScreenText(message, 7, nil, {r = 244, g = 180, b = 0})
    end
end

---Will give large amounts of legitimacy to this faction, if valid
---@param faction string
function LegitimacyManager:try_legitimized_faction(faction)
    local highest_legit_faction = self.GovEmpire.HighestLegitimacy
    content = self.GovEmpire.imperial_table[faction]
    if self:is_valid_for_legitimacy(content) then
        local amount = 1 + self.GovEmpire.imperial_table[highest_legit_faction].legitimacy - content.legitimacy
        if faction == highest_legit_faction then
            local total_pts = content.legitimacy / (content.percentile_legitimacy / 100)
            amount = content.legitimacy - tonumber(Dirty_Floor(total_pts * 0.1))
        end
        self.GovEmpire:adjust_legitimacy(faction, amount, true)
        self:lock_legitimacy_options(faction)

        local messeage = string.format(
            "%s legitimized: %s = %s%%",
            Find_Player(faction).Get_Name(),
            tostring(content.legitimacy),
            tostring(content.percentile_legitimacy)
        )
        local color = CONSTANTS.FACTION_COLORS[faction]
        StoryUtil.ShowScreenText(messeage, 7, nil, color)
    else
        local message = "Operation cancelled. "..Find_Player(faction).Get_Name().." is being integrated."
        StoryUtil.ShowScreenText(message, 7, nil, {r = 244, g = 180, b = 0})
    end
end

---Setup the legitimacy options for this faction
---@param faction string
function LegitimacyManager:init_options(faction)
    self:init_option_legitimized(faction)
    self:init_option_integrate(faction)
    self:unlock_legitimacy_options(faction)
end

---Setup the instant max legitimacy option for this faction
---@param faction string
function LegitimacyManager:init_option_legitimized(faction)
    local option = string.upper("Option_Legitimized_"..faction)
    local option_obj = Find_Object_Type(option)
    if option_obj then
        self.GovEmpire.imperial_table[faction].option_legitimized = option
    else
        StoryUtil.ShowScreenText("Warning: No option "..option, 15, nil, {r = 244, g = 200, b = 0})
        self.GovEmpire.imperial_table[faction].option_legitimized = nil
    end
end

---Setup the instant integration option
---@param faction string
function LegitimacyManager:init_option_integrate(faction)
    local option = string.upper("Option_Integrate_"..faction)
    local option_obj = Find_Object_Type(option)
    if option_obj then
        self.GovEmpire.imperial_table[faction].option_integrate = option
    else
        StoryUtil.ShowScreenText("Warning: No option "..option, 15, nil, {r = 244, g = 200, b = 0})
        self.GovEmpire.imperial_table[faction].option_integrate = nil
    end
end

---Instantly unlock the Dark Empire for an Imperial faction
function LegitimacyManager:cheat_dark_empire()
    if self.GovEmpire.DarkEmpireUnlocked or not self.GovEmpire.DarkEmpireAvailable then
        local message = "Dark Empire is unavailable in this map, or has already formed."
        StoryUtil.ShowScreenText(message, 7, nil, {r = 244, g = 200, b = 0})
        return
    end

    local human_included = false
    local sorted_factions = SortKeysByElement(self.GovEmpire.imperial_table, "legitimacy", "desc")
    local faction_list = {}
    for i, faction in ipairs(sorted_factions) do
        local content = self.GovEmpire.imperial_table[faction]
        if self:is_valid_for_legitimacy(content) and
            CONSTANTS.ALL_FACTIONS_CAPITALS[faction].STRUCTURE -- regime-palpatine has crash bug for nil structure
        then
            table.insert(faction_list, faction)
            if faction == self.human_faction then
                human_included = true
            end
        end
        if i >= 8 then
            -- POPUPEVENT only supports up to 8 choices
            break
        end
    end

    -- Ensure the human player is included in the choices
    if not human_included and self.human_became_imperial then
        faction_list[table.getn(faction_list)] = self.human_faction
    end

    StoryUtil.ShowScreenText("Choose an Imperial faction to host the Dark Empire.", 15, nil, {r = 217, g = 2, b = 125}, false)
    crossplot:publish("POPUPEVENT", "DARK_EMPIRE_CHEAT_CHOICE", faction_list, "DARK_EMPIRE_CHEAT_CHOICE_MADE")
end

---Lock or unlock dark empire units for the imperial regime host
---@param lock_status boolean true to unlock, false to lock
function LegitimacyManager:set_lock_dark_empire(lock_status)
    if not self.GovEmpire.DarkEmpireAvailable then
        return
    end

    -- Always lock the cheat options if unlocking units
    if lock_status or not self.GovEmpire.DarkEmpireUnlocked then
        UnitUtil.SetLockList(self.human_faction, {self.option_cheat_dark_empire}, not lock_status)
        UnitUtil.SetLockList(self.human_faction, {"CHEAT_GOVERNMENT"}, false)
    end

    local dark_empire_faction = GlobalValue.Get("IMPERIAL_REGIME_HOST")
    if CONSTANTS.ALL_FACTION_NAMES[dark_empire_faction] then
        UnitUtil.SetLockList(dark_empire_faction, self.dark_empire_units, lock_status)
    end
end

---Unlock the legitimized and integrate options for this faction in the right conditions
---@param faction string the faction to unlock options for
---@param highest_faction string? the current highest legitimacy faction (defaults to GovEmpire.HighestLegitimacy)
function LegitimacyManager:unlock_legitimacy_options(faction, highest_faction)
    if not highest_faction then
        highest_faction = self.GovEmpire.HighestLegitimacy
    end

    local content = self.GovEmpire.imperial_table[faction]
    if self:is_valid_for_legitimacy(content) and faction ~= highest_faction then
        UnitUtil.SetLockList(self.human_faction, {content.option_legitimized}, true)
        if not Find_Player(faction).Is_Human() then
            UnitUtil.SetLockList(self.human_faction, {content.option_integrate}, true)
        end
    else
        local message = string.format(
            "Warning: Cannot unlock legitimacy options for %s.",
            Find_Player(faction).Get_Name()
        )
        -- StoryUtil.ShowScreenText(message, 10, nil, {r = 244, g = 200, b = 0})
    end
end

---Lock the legitimized and integrate options for this faction
---@param faction string
function LegitimacyManager:lock_legitimacy_options(faction)
    local content = self.GovEmpire.imperial_table[faction]
    if not content then
        return
    end
    UnitUtil.SetLockList(self.human_faction, {
        content.option_legitimized,
        content.option_integrate
    }, false)
end

---Spawn the fighter heroes from one faction to another faction on the map
---@param from_player string|PlayerObject|nil
---@param to_player string|PlayerObject|nil
function LegitimacyManager:transfer_fighter_heroes(from_player, to_player)
    if type(from_player) == "string" then
        from_player = Find_Player(from_player)
    end
    if type(to_player) == "string" then
        to_player = Find_Player(to_player)
    end
    if not from_player or not to_player then
        return
    end

    require("HeroFighterLibrary")
    local spawn_list = {}
    for location_set, stats in pairs(Get_Hero_Entries()) do --Fighter hero entries.
        if stats.Hero_Squadron then
            local location_set_type = Find_Object_Type(location_set)
            
            -- Handle Hero_Squadron being either a string or a table (take first entry if table)
            local squadron_name = stats.Hero_Squadron
            if type(squadron_name) == "table" then
                squadron_name = squadron_name[1]
            end
            
            local squadron_type = Find_Object_Type(squadron_name)
            
            if (stats.Faction and Find_Player(stats.Faction) == from_player) or
                (location_set_type and location_set_type.Is_Affiliated_With(from_player) and
                squadron_type and squadron_type.Is_Affiliated_With(from_player))
            then
                table.insert(spawn_list, squadron_name)
            end
        end
    end

    if table.getn(spawn_list) > 0 then
        StoryUtil.SpawnAtSafePlanet("", to_player, StoryUtil.GetSafePlanetTable(), spawn_list)
    end
end

---Transfer unused legitimacy groups from one faction to another
---@param from_faction string
---@param to_faction string
function LegitimacyManager:transfer_groups(from_faction, to_faction)
    local from_content = self.GovEmpire.imperial_table[from_faction]
    local to_content = self.GovEmpire.imperial_table[to_faction]
    if not from_content or not to_content or not from_content.joined_groups_detail then
        return
    end
    for _, group in ipairs(from_content.joined_groups_detail) do
        self.GovEmpire:unlock_group(to_faction, group, nil, true)
    end
end

---Append reward/extra unit type variants to the table where they exist
---@param unit_list string[] table of unit type XML string names
---@param hide_warnings boolean? true to hide warnings about missing reward variants
---@return string[] modified_list new table with reward variants appended
function LegitimacyManager:add_reward_variants(unit_list, hide_warnings)
    if not unit_list then
        return {}
    end

    local modified_list = {}
    for _, unit_name in ipairs(unit_list) do
        local unit_type = Find_Object_Type(unit_name)
        if TestValid(unit_type) then
            table.insert(modified_list, unit_name)

            local reward_name = "Reward_"..unit_name
            local reward_type = Find_Object_Type(reward_name)
            if not TestValid(reward_type) then
                reward_name = "Extra_"..unit_name
                reward_type = Find_Object_Type(reward_name)
            end
            if TestValid(reward_type) then
                table.insert(modified_list, reward_name)
            elseif not hide_warnings then
                local message = "Warning: Reward variant not found for "..unit_name
                StoryUtil.ShowScreenText(message, 10, nil, {r = 244, g = 200, b = 0})
            end
        else
            local message = "Error: Unit type not found for "..unit_name
            StoryUtil.ShowScreenText(message, 10, nil, {r = 244, g = 0, b = 0})
        end
    end

    return modified_list
end

---Update all legitimacy group reward unit unlocks in string[] with reward variants
---@deprecated Unlocks are now in UnitSwitcherLibrary and handled by ExtraSwap
function LegitimacyManager:setup_group_reward_variants()
    if not self.GovEmpire.legitimacy_groups then
        return
    end
    for tier, groups_list in pairs(self.GovEmpire.legitimacy_groups) do
        for group_number, group in pairs(groups_list) do
            if group.unlocks and table.getn(group.unlocks) > 0 then
                -- Add reward variants for all unlocks
                self.GovEmpire.legitimacy_groups[tier][group_number].unlocks = self:add_reward_variants(group.unlocks)
            end
        end
    end
end

---Update all units in string[] tables with reward variants
function LegitimacyManager:setup_unit_reward_variants()
    -- Update LegitimacyManager tables
    self.dark_empire_units = self:add_reward_variants(self.dark_empire_units)
    self.base_imperial_units = self:add_reward_variants(self.base_imperial_units)

    -- Update add_imperial_options entries if they have unit lists
    for faction, content in pairs(self.add_imperial_options) do
        if content.destruction_unlocks then
            self.add_imperial_options[faction].destruction_unlocks = self:add_reward_variants(content.destruction_unlocks)
        end
    end

    if not self.GovEmpire.imperial_table then
        return
    end

    -- Update imperial_table entries if they have unit lists
    for faction, content in pairs(self.GovEmpire.imperial_table) do
        if content.destruction_unlocks then
            self.GovEmpire.imperial_table[faction].destruction_unlocks = self:add_reward_variants(content.destruction_unlocks)
        end
    end
end

---Get the plot name for gov display, different for Empire of the Hand
---Call from GovernmentEmpire:UpdateDisplay()
---@return string plot_name the plot name for gov display
function LegitimacyManager:get_display_plot_name()
    if self.HumanPlayer == Find_Player("EmpireoftheHand") then
        return "Resource_Display"
    else
        return "Government_Display"
    end
end

---Update the story event gov display differently for Empire of the Hand
---Call from GovernmentEmpire:UpdateDisplay()
function LegitimacyManager:update_story_event()
    if self.HumanPlayer == Find_Player("EmpireoftheHand") then
        Story_Event("RESOURCE_DISPLAY")
    else
        Story_Event("GOVERNMENT_DISPLAY")
    end
end
