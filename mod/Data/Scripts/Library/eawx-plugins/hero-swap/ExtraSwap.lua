---@License: MIT

require("deepcore/std/class")
require("eawx-util/StoryUtil")
require("PGSpawnUnits")
require("UnitSwitcherLibrary")
require("SetFighterResearch")

---Based on HeroSwap
---@class ExtraSwap
ExtraSwap = class()

---This is for the LGHE workaround
---@param gc GalacticConquest
function ExtraSwap:new(gc)
    self.gc = gc
    self.gc.Events.GalacticProductionFinished:attach_listener(self.on_production_finished, self)

    self:check_and_unlock_extra_swaps()
    self:check_reward_variant_unlocks()
end

---Swaps "Extra_Dummy_..." but uses "Dummy_..." for entry lookup.
---@param planet Planet
---@param object_type_name string
function ExtraSwap:on_production_finished(planet, object_type_name)
    if not string.find(object_type_name, "^EXTRA_") then
        return
    end
    local sub_obj = string.gsub(object_type_name, "^EXTRA_", "") -- Removes "EXTRA_" from string

    -- Below is the original HeroSwap code, but using sub_obj for the swap entry lookup instead of object_type_name

    local swap_entry = StoryUtil.Get_Swap_Entry(sub_obj)

    if swap_entry ~= nil then
        local old_unit = swap_entry[1]
        local new_unit = swap_entry[2]

        local SwapDummy = Find_First_Object(object_type_name)

        if SwapDummy == nil then
            return
        end

        local SwapOwner = SwapDummy.Get_Owner()
        local SwapLocation = SwapDummy.Get_Planet_Location()

        if old_unit == nil then
            SpawnList(new_unit, SwapLocation, SwapOwner,true,false)

            local unlocks = swap_entry.Unlocks
            if unlocks ~= nil then
                for _, unlock in pairs(unlocks) do
                    SwapOwner.Unlock_Tech(Find_Object_Type(unlock))
                    self:unlock_reward_variant(SwapOwner, unlock)
                end
            end
        else
            local checkObject = nil

            if swap_entry.location_check then
                local checkArray = Find_All_Objects_Of_Type(old_unit)

                for _, checks in pairs(checkArray) do
                    if checks.Get_Planet_Location() == SwapLocation then
                        checkObject = checks
                        break
                    end
                end
            else
                checkObject = Find_First_Object(old_unit)
            end

            if TestValid(checkObject) or swap_entry.old_unit_optional then
                spawn_list_new = {new_unit}
                SpawnList(spawn_list_new, SwapLocation, SwapOwner,true,false)
                Transfer_Fighter_Hero(string.upper(old_unit), string.upper(new_unit))
            end

            if TestValid(checkObject) then
                checkObject.Despawn()
            end

        end

        SwapDummy.Despawn()
    end
end

---Unlocks the reward variant for a unit if it exists.
---@param player PlayerObject
---@param unit_name string
function ExtraSwap:unlock_reward_variant(player, unit_name)
    local reward_type = Find_Object_Type("Reward_"..unit_name)
    if player and TestValid(reward_type) then
        player.Unlock_Tech(reward_type)
    end
end

---Finds and unlocks all valid extra swaps for the human player.
---This inludes ship swaps and ship upgrades for heroes.
function ExtraSwap:check_and_unlock_extra_swaps()
    local UnitSwitcherLibrary = require("UnitSwitcherLibrary")
    local human_player = Find_Player("local")

    for swap_name, swap_entry in pairs(UnitSwitcherLibrary) do
        local old_unit = swap_entry[1]
        if old_unit then
            local swap_type = Find_Object_Type(swap_name)
            if TestValid(swap_type) then
                local extra_swap = "Extra_"..swap_name
                local extra_swap_type = Find_Object_Type(extra_swap)
                if TestValid(extra_swap_type) then
                    human_player.Unlock_Tech(extra_swap_type)
                else
                    local message = "Warning: Extra swap not found for "..swap_name
                    StoryUtil.ShowScreenText(message, 10, nil, {r = 244, g = 200, b = 0})
                end
            else
                local message = "Error: Swap type not found for "..swap_name
                StoryUtil.ShowScreenText(message, 10, nil, {r = 244, g = 0, b = 0})
            end
        end
    end
end

---If swap entries have unlocks, check that their reward variants exist.
---Excludes unlocks containing "_Location_Set" in their name.
function ExtraSwap:check_reward_variant_unlocks()
    local UnitSwitcherLibrary = require("UnitSwitcherLibrary")

    for _, swap_entry in pairs(UnitSwitcherLibrary) do
        local unlocks = swap_entry.Unlocks
        if unlocks then
            for _, unit_name in pairs(unlocks) do
                local reward_type = Find_Object_Type("Reward_"..unit_name)
                if not TestValid(reward_type) and not string.find(unit_name, "_Location_Set") then
                    local message = "Warning: Reward variant not found for "..unit_name
                    StoryUtil.ShowScreenText(message, 10, nil, {r = 244, g = 200, b = 0})
                end
            end
        end
    end
end
