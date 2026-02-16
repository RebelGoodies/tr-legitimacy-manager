---@License: MIT

require("deepcore/std/class")
require("eawx-util/StoryUtil")
require("PGSpawnUnits")

---@class RewardSwap
RewardSwap = class()

---@param gc GalacticConquest
function RewardSwap:new(gc)
    self.gc = gc
    self.gc.Events.GalacticProductionFinished:attach_listener(self.on_production_finished, self)
end

---Attempts to replace the reward unit with the original unit type.
---@param planet Planet the planet where the reward unit was built
---@param object_type_name string the built reward unit type name
function RewardSwap:on_production_finished(planet, object_type_name)
    if not string.find(object_type_name, "^REWARD_") then
        return
    end

    local reward_object = Find_First_Object(object_type_name)
    if not TestValid(reward_object) then
        return
    end

    ---Despawning the unit directly only works for space units.
    local unit_type_name = string.gsub(object_type_name, "^REWARD_", "")
    local unit_type = Find_Object_Type(unit_type_name)
    if TestValid(unit_type) then
        SpawnList({unit_type_name}, planet:get_game_object(), planet:get_owner(), true, false)
        if reward_object then
            reward_object.Despawn()
        end
    end
end
