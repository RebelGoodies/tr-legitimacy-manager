require("deepcore/std/class")
require("eawx-plugins/hero-swap/ExtraSwap")
require("eawx-util/StoryUtil")
require("eawx-util/UnitUtil")

---@type table<string, any>
CONSTANTS = ModContentLoader.get("GameConstants")

---@class GroupSelector
GroupSelector = class()

---@param GovEmpire GovernmentEmpire
---@param gc GalacticConquest
function GroupSelector:new(GovEmpire, gc)
    self.gc = gc
    self.GovEmpire = GovEmpire

    self.HumanPlayer = Find_Player("local")
    self.human_faction = self.HumanPlayer.Get_Faction_Name()

    ---Groups locked by time restrictions, only available in selectable mode
    ---Mirrors GovEmpire.legitimacy_groups structure
    ---@type LegitimacyReward[][]
    self.time_locked_groups = {{}, {}, {}, {}, {}}

    -- Track which system is active
    self.selectable_mode = false

    ---@type integer|nil
    self.current_unlocked_level = nil

    ---@type string[]
    self.random_options = {
        "OPTION_LEGITIMACY_GROUP_1", -- Single random group to self (human)
        "OPTION_LEGITIMACY_GROUP_2", -- Single random group to highest legitimacy
        "OPTION_LEGITIMACY_GROUP_3", -- Ten random groups to highest legitimacy
    }

    ---Tier options mapping where level (1-5) is inverse of tier (5-1)
    ---@type table<integer, string>
    self.tier_options = {
        [1] = "OPTION_SELECT_TIER_5",
        [2] = "OPTION_SELECT_TIER_4",
        [3] = "OPTION_SELECT_TIER_3",
        [4] = "OPTION_SELECT_TIER_2",
        [5] = "OPTION_SELECT_TIER_1"
    }
    self.toggle_option = "OPTION_TOGGLE_GROUP_SYSTEM"

    -- Special Zann group hire handling for other factions
    self.zann_hire = "DUMMY_RECRUIT_GROUP_ZANN"
    self.extra_zann_hire = "EXTRA_"..self.zann_hire
    self.zann_group_unlocks = {
        "AGGRESSOR_STAR_DESTROYER",
        "VENGEANCE_FRIGATE",
        "DEFILER_COMPANY",
        "REWARD_AGGRESSOR_STAR_DESTROYER",
        "REWARD_VENGEANCE_FRIGATE",
        "REWARD_DEFILER_COMPANY",
    }
    -- Set true when Zann group unlocked by human or built by AI
    self.zann_active = false

    self.production_finished_event = gc.Events.GalacticProductionFinished
    self.production_finished_event:attach_listener(self.on_production_finished, self)

    self.init_event = GovEmpire.Events.InitializedLegitimacy
    self.init_event:attach_listener(self.on_init, self)

    self.faction_absorbed_event = GovEmpire.Events.FactionAbsorbed
    self.faction_absorbed_event:attach_listener(self.on_faction_absorbed, self)

    self.all_groups_claimed_event = GovEmpire.Events.AllGroupsClaimed
    self.all_groups_claimed_event:attach_listener(self.on_all_groups_claimed, self)

    self.group_time_locked_event = GovEmpire.Events.GroupTimeLocked
    self.group_time_locked_event:attach_listener(self.on_group_time_locked, self)

    self.faction_became_imperial_event = GovEmpire.Events.FactionBecameImperial
    self.faction_became_imperial_event:attach_listener(self.on_faction_became_imperial, self)

    -- Handle Extra_Dummy Swaps (Compatibility Workaround)
    ExtraSwap(gc)

    self:setup_extra_group_dummies()
end

---Disable the GroupSelector and detach event listeners
function GroupSelector:destroy()
    self.selectable_mode = false
    self:lock_all_tier_options()
    self:set_lock_random_group_options(false)
    self:set_lock_toggle_option(false)

    -- self.production_finished_event:detach_listener(self.on_production_finished, self) -- Keep for Zann hire
    self.init_event:detach_listener(self.on_init, self)
    -- self.faction_absorbed_event:detach_listener(self.on_faction_absorbed, self) -- Keep to handle Zann absorption
    self.all_groups_claimed_event:detach_listener(self.on_all_groups_claimed, self)
    self.group_time_locked_event:detach_listener(self.on_group_time_locked, self)
    self.faction_became_imperial_event:detach_listener(self.on_faction_became_imperial, self)
end

---Get the tier number from the level (inverse of 1-5)
---@param level integer the level (1-5)
---@return integer tier the tier number (5-1)
function GroupSelector:get_tier_number(level)
    return 6 - level
end

---Get the hire dummy unit type name for a legitimacy group
---@param group table the legitimacy group data
---@return string hire_dummy the group hire dummy unit type name
function GroupSelector:get_group_hire(group)
    local hire_dummy = group.unlocks[1]
    if group.extra_dummy then
        hire_dummy = group.extra_dummy
    end
    return string.upper(hire_dummy)
end

---Get the total count of regular and time-locked groups for a tier
---@param level integer the level (1-5)
---@param include_time_locked boolean? defaults to selectable_mode state
---@return integer total_count sum of available legitimacy group
function GroupSelector:get_tier_group_count(level, include_time_locked)
    if include_time_locked == nil then
        include_time_locked = self.selectable_mode
    end

    local regular_count = 0
    if self.GovEmpire.legitimacy_groups[level] then
        regular_count = table.getn(self.GovEmpire.legitimacy_groups[level])
    end

    local time_locked_count = 0
    if include_time_locked and self.time_locked_groups[level] then
        time_locked_count = table.getn(self.time_locked_groups[level])
    end

    return regular_count + time_locked_count
end

---Call from GovernmentEmpire:initialize_legitimacy()
function GroupSelector:on_init()
    if self.initialized then
        return
    end
    self.initialized = true

    self:disable_selectable_mode()
    self:set_lock_toggle_option(true)
end

---Call from GovernmentEmpire:pending_integration_queue()
---@param victim_name string the absorbed faction name
---@param absorber_name string the absorbing faction name
function GroupSelector:on_faction_absorbed(victim_name, absorber_name)
    local victim_table = self.GovEmpire.imperial_table[victim_name]
    local absorber_table = self.GovEmpire.imperial_table[absorber_name]
    if not victim_table or not absorber_table then
        return
    end

    -- Transfer Zann group status and unlock when human is absorber
    if not absorber_table.zann_unlocked then
        absorber_table.zann_unlocked = victim_table.zann_unlocked
    end
    if absorber_table.zann_unlocked and absorber_name == self.human_faction then
        self:set_lock_zann_hire(true)
        self.zann_active = true -- Must set after unlocking
    end
end

---Call from GovernmentEmpire:group_joins()
function GroupSelector:on_all_groups_claimed()
    local message = "No more legitimacy groups available. All groups unlocked."
    StoryUtil.ShowScreenText(message, 15, nil, {r = 200, g = 255, b = 0})
    self:destroy()
end

---Call from GovernmentEmpire:initialize_legitimacy when a group is time-locked
function GroupSelector:on_group_time_locked(level, group)
    if group["maxstartyear"] or group["minstartyear"] then
        -- StoryUtil.ShowScreenText(group.name, 7, nil, {r = 200, g = 200, b = 64})
        table.insert(self.time_locked_groups[level], group)
    else
        local message = "Error: "..group.name.." marked as time-locked."
        StoryUtil.ShowScreenText(message, 15, nil, {r = 255, g = 64, b = 64})
    end
end

-- Call from LegitimacyManager when a faction becomes imperial
function GroupSelector:on_faction_became_imperial(faction_name)
    if faction_name == self.human_faction then
        self:set_lock_random_group_options(true)
    end
    self:set_lock_toggle_option(true)
end

---Check if options were built
---@param planet Planet the planet where the unit was built
---@param object_type_name string the built unit type name
function GroupSelector:on_production_finished(planet, object_type_name)
    -- Handle toggle between random and selectable modes
    if object_type_name == self.toggle_option then
        self:toggle_group_system()
        return
    end

    -- Give group to Human or to HighestLegitimacy
    if self:check_random_option_built(object_type_name) then
        return
    end

    -- Handle tier selection
    for level, option_name in pairs(self.tier_options) do
        if object_type_name == option_name then
            self:select_tier_group_hires(level)
            return
        end
    end

    -- Handle group hire builds (when player builds a specific group dummy)
    if self:check_zann_hire_built(object_type_name) or
        self:check_group_hire_built(object_type_name)
    then
        return
    end
end

---Toggle between random and selectable group systems
function GroupSelector:toggle_group_system()
    self.selectable_mode = not self.selectable_mode

    if self.selectable_mode then
        self:enable_selectable_mode()
    else
        self:disable_selectable_mode()
    end
end

---Enable selectable mode: unlock tier options, block random groups
function GroupSelector:enable_selectable_mode()
    self.selectable_mode = true
    self:set_lock_random_group_options(false)
    self:unlock_available_tier_options()

    local message = "Group selection mode enabled. Use the tier options to select specific groups."
    StoryUtil.ShowScreenText(message, 7, nil, {r = 64, g = 255, b = 64})
end

---Disable selectable mode: lock tier options, unblock random groups
function GroupSelector:disable_selectable_mode()
    self.selectable_mode = false
    self:lock_all_tier_options()
    self:set_lock_random_group_options(true)

    local message = "Random group mode enabled. Groups will be randomly assigned through legitimacy gains."
    StoryUtil.ShowScreenText(message, 7, nil, {r = 255, g = 255, b = 64})
end

---Lock all tier options and reset current unlocked tier
function GroupSelector:lock_all_tier_options()
    -- Reset current tier tracking
    self.current_unlocked_level = nil
    for level, option_name in pairs(self.tier_options) do
        self:set_lock_tier_hires(level, false)
        UnitUtil.SetLockList(self.human_faction, {option_name}, false)
    end
    self:set_lock_zann_hire(false)
end

---Unlock tier options that have available groups (except the current level)
function GroupSelector:unlock_available_tier_options()
    for level, option_name in pairs(self.tier_options) do
        if level ~= self.current_unlocked_level then
            -- Only unlock if tier has groups available
            if self:get_tier_group_count(level) > 0 then
                UnitUtil.SetLockList(self.human_faction, {option_name}, true)
            end
        end
    end
    self:set_lock_zann_hire(true)
end

---Lock or unlock the toggle option for human player
---@param lock_status boolean true to unlock, false to lock
function GroupSelector:set_lock_toggle_option(lock_status)
    if lock_status and not self.GovEmpire.imperial_table[self.human_faction] then
        return
    end
    UnitUtil.SetLockList(self.human_faction, {self.toggle_option}, lock_status)
end

---Lock or unlock options for human player to request random legitimacy groups on demand.
---@param lock_status boolean true to unlock, false to lock
function GroupSelector:set_lock_random_group_options(lock_status)
    if lock_status and self.selectable_mode then
        return
    end
    UnitUtil.SetLockList(self.human_faction, self.random_options, lock_status)
    if lock_status and not self.GovEmpire.imperial_table[self.human_faction] then
        -- Lock the random groups to self option if human is not imperial
        UnitUtil.SetLockList(self.human_faction, {self.random_options[1]}, false)
    end
end

---Lock or unlock all group hires in a specific tier
---@param level integer the level to lock/unlock (1-5)
---@param lock_status boolean true to unlock, false to lock
---@return boolean success whether the operation was successful
function GroupSelector:set_lock_tier_hires(level, lock_status)
    if lock_status and not self.selectable_mode then
        StoryUtil.ShowScreenText("Error: Not in selectable mode.", 7, nil, {r = 255, g = 64, b = 64})
        return false
    end

    -- Check if there are groups available in this tier
    if lock_status and self:get_tier_group_count(level) <= 0 then
        local message = string.format("Tier %d has no available groups.", level)
        StoryUtil.ShowScreenText(message, 7, nil, {r = 255, g = 200, b = 0})
        UnitUtil.SetLockList(self.human_faction, {self.tier_options[level]}, false)
        return false
    end

    -- Lock or unlock all group HIRES in this tier (not the actual groups)
    for _, group in ipairs(self.GovEmpire.legitimacy_groups[level]) do
        UnitUtil.SetLockList(self.human_faction, {self:get_group_hire(group)}, lock_status)
    end

    -- In selectable mode, also include time-locked groups
    for _, group in ipairs(self.time_locked_groups[level]) do
        UnitUtil.SetLockList(self.human_faction, {self:get_group_hire(group)}, lock_status)
    end
    return true
end

---Lock or unlock special Zann group hire unless human is Zsinj's Empire.
---@param lock_status boolean true to unlock, false to lock
function GroupSelector:set_lock_zann_hire(lock_status)
    if Find_Player("ZSINJ_EMPIRE").Is_Human() or self.zann_active then
        return
    end
    UnitUtil.SetLockList(self.human_faction, {self.zann_hire}, false) -- Zsinj only
    UnitUtil.SetLockList(self.human_faction, {self.extra_zann_hire}, lock_status)
end

---Unlock all group hires in a specific level (doesn't unlock the groups themselves)
---@param level integer the level to unlock (1-5)
function GroupSelector:select_tier_group_hires(level)
    -- Lock the previously unlocked hires and tier if it exists
    if self.current_unlocked_level then
        local prev_option = self.tier_options[self.current_unlocked_level]
        UnitUtil.SetLockList(self.human_faction, {prev_option}, false)
        self:set_lock_tier_hires(self.current_unlocked_level, false)
    end

    -- Unlock all group HIRES in this level (not the actual groups)
    if not self:set_lock_tier_hires(level, true) then
        self:unlock_available_tier_options()
        return
    end

    -- Update the current unlocked tier
    self.current_unlocked_level = level

    -- Hide this tier option and unlock others
    UnitUtil.SetLockList(self.human_faction, {self.tier_options[level]}, false)
    self:unlock_available_tier_options()

    local hires_available = self:get_tier_group_count(level)
    local message = string.format("Tier %d has %d groups available to hire.", level, hires_available)
    StoryUtil.ShowScreenText(message, 10, nil, {r = 64, g = 255, b = 64})
end

---Check if a random option was built and assign groups accordingly
---@param object_type_name string the built unit type name
---@return boolean was_random_option true if a random option was built and handled
function GroupSelector:check_random_option_built(object_type_name)
    for i = 1, 3 do
        if object_type_name == self.random_options[i] then
            local faction_name = self.GovEmpire.HighestLegitimacy
            local num_groups = 1
            if i == 1 then
                faction_name = self.human_faction
            elseif i == 3 then
                num_groups = 10
            end
            for j = 1, num_groups do
                self.GovEmpire:group_joins(faction_name, true)
            end
            return true
        end
    end
    return false
end

---Check if the Zann hire was built and unlock the actual group
---@param object_type_name string the built unit type name
---@return boolean was_zann_hire true if the Zann hire was built and handled
function GroupSelector:check_zann_hire_built(object_type_name)
    if object_type_name == self.extra_zann_hire then
        self:set_lock_zann_hire(false)

        -- Based on part of GovernmentEmpire:group_joins()
        StoryUtil.Multimedia("TEXT_GOVERNMENT_LEGITIMACY_GROUP_ZANN", 15, nil, "Tyber_Loop", 0)
        UnitUtil.SetLockList(self.human_faction, self.zann_group_unlocks)
        UnitUtil.SetLockList("ZSINJ_EMPIRE", {self.zann_hire}, false)
        self.GovEmpire.imperial_table["ZSINJ_EMPIRE"].zann_unlocked = true
        table.insert(self.GovEmpire.imperial_table[self.human_faction].joined_groups, self.zann_hire)
        return true
    elseif object_type_name == self.zann_hire then
        self:set_lock_zann_hire(false)
        self.zann_active = true -- Must set after locking
        return true
    end
    return false
end

---Check if a group hire was built and unlock the actual group
---@param object_type_name string the built unit type name
---@return boolean was_group_hire true if a group hire was built and handled
function GroupSelector:check_group_hire_built(object_type_name)
    -- Search all tiers for matching group hire
    for level, groups_list in pairs(self.GovEmpire.legitimacy_groups) do
        for i, group in ipairs(groups_list) do
            local hire_name = self:get_group_hire(group)

            -- Check if this is the hire that was built and unlock
            if object_type_name == hire_name then
                self.GovEmpire:unlock_group(self.human_faction, group, level, true)
                table.remove(self.GovEmpire.legitimacy_groups[level], i)
                return true
            end
        end
    end

    -- Also search time-locked groups in selectable mode
    for level, groups_list in pairs(self.time_locked_groups) do
        for i, group in ipairs(groups_list) do
            local hire_name = self:get_group_hire(group)

            -- Check if this is the hire that was built and unlock
            if object_type_name == hire_name then
                StoryUtil.ShowScreenText(group.name, 10, nil, {r = 64, g = 255, b = 64})
                self.GovEmpire:unlock_group(self.human_faction, group, level, true)
                table.remove(self.time_locked_groups[level], i)
                return true
            end
        end
    end
    return false
end

---Setup Extra_ dummy unit types for legitimacy groups if they exist
function GroupSelector:setup_extra_group_dummies()
    if not self.GovEmpire.legitimacy_groups then
        return
    end
    for tier, groups_list in pairs(self.GovEmpire.legitimacy_groups) do
        for group_number, group in pairs(groups_list) do
            if group.unlocks and table.getn(group.unlocks) > 0 then
                -- Check for Extra_ dummy on first unlock
                local first_tech = group.unlocks[1]
                local extra_dummy = "Extra_"..first_tech
                if Find_Object_Type(extra_dummy) then
                    self.GovEmpire.legitimacy_groups[tier][group_number].extra_dummy = extra_dummy
                end
            end
        end
    end
end

return GroupSelector
