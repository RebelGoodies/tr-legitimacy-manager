--**************************************************************************************************
--*    _______ __                                                                                  *
--*   |_     _|  |--.----.---.-.--.--.--.-----.-----.                                              *
--*     |   | |     |   _|  _  |  |  |  |     |__ --|                                              *
--*     |___| |__|__|__| |___._|________|__|__|_____|                                              *
--*    ______                                                                                      *
--*   |   __ \.-----.--.--.-----.-----.-----.-----.                                                *
--*   |      <|  -__|  |  |  -__|     |  _  |  -__|                                                *
--*   |___|__||_____|\___/|_____|__|__|___  |_____|                                                *
--*                                   |_____|                                                      *
--*                                                                                                *
--*                                                                                                *
--*       File:              BoardingListener.lua                                                  *
--*       File Created:      Monday, 2nd March 2020 13:51                                          *
--*       Author:            [TR] Corey                                                            *
--*       Last Modified:     Tuesday, 5th May 2020 01:41                                           *
--*       Modified By:       [TR] Corey                                                            *
--*       Copyright:         Thrawns Revenge Development Team                                      *
--*       License:           This code may not be used without the author's explicit permission    *
--**************************************************************************************************

require("deepcore/std/class")
require("deepcore/crossplot/crossplot")
require("eawx-util/GalacticUtil")
StoryUtil = require("eawx-util/StoryUtil")

---@class UnitTracker
UnitTracker = class()

function UnitTracker:new(gc)

    self.Unit_List = require("hardpoint-lists/PersistentLibrary")
    if not self.Unit_List[3] then
        self.Unit_List[3] = {}
    end
   
    for _, id in pairs(self.Unit_List[2]) do
        GlobalValue.Set(id, 1.0)
    end

    for unit, specs in pairs(self.Unit_List[1]) do
        local reward_unit = "REWARD_"..unit
        if TestValid(Find_Object_Type(reward_unit)) then
            self.Unit_List[1][reward_unit] = specs
            table.insert(self.Unit_List[3], reward_unit)
        end
    end

    if self.Unit_List[3][1] ~= nil then
        gc.Events.GalacticProductionFinished:attach_listener(self.on_production_finished, self)
    end
end

function UnitTracker:update()
    --Logger:trace("entering UnitTracker:update")
    for unit, specs in pairs(self.Unit_List[1]) do
        local objects = Find_All_Objects_Of_Type(unit)
        if table.getn(objects) > 0 then
            for _,object in pairs(objects) do
                local player = object.Get_Owner()
                if player then
                    local id = unit.."_"..tostring(player.Get_Faction_Name())
                    local current_damage = GlobalValue.Get(id)
                    if current_damage then
                        if (current_damage < 1.0) and (player.Get_Credits() >= specs[2]) then
                            local new_damage = current_damage + specs[1]
                            if new_damage > 0.89 then
                                new_damage = 1.0
                            end
                            GlobalValue.Set(id, new_damage)
                            player.Give_Money(specs[2])
                            if player.Is_Human() then
                                StoryUtil.ShowScreenText(specs[3].." has been repaired to "..tostring(Dirty_Floor(new_damage * 100)).."% hull for "..tostring(specs[2]).." Credits", 10)
                            end
                        end
                    else
                        --StoryUtil.ShowScreenText("Debug: No valid ID for supership ".. id, 10)
                        GlobalValue.Set(id, 1.0)
                    end
                end
            end
        end
    end
    
end

function UnitTracker:on_production_finished(planet, game_object_type_name)
	--Logger:trace("entering UnitTracker:on_production_finished")
    DebugMessage("In UnitTracker:on_production_finished")

    for _, unit_name in pairs(self.Unit_List[3]) do
        if game_object_type_name == unit_name then
            local owner_tag = planet:get_owner().Get_Faction_Name()
            local id = game_object_type_name.."_"..owner_tag
            GlobalValue.Set(id, 1.0)
        end
    end
end

return UnitTracker
