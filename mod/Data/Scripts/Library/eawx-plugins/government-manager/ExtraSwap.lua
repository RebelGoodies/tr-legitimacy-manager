require("deepcore/std/class")
require("eawx-util/StoryUtil")
require("PGStateMachine")
require("PGSpawnUnits")
require("UnitSwitcherLibrary")

---Copy based on HeroSwap
---@class ExtraSwap
ExtraSwap = class()

---This is for the LGHE workaround
---@param gc GalacticConquest
function ExtraSwap:new(gc)
    self.gc = gc
    self.gc.Events.GalacticProductionFinished:attach_listener(self.on_production_finished, self)
end

---Swaps "Extra_Dummy_..." but uses "Dummy_..." for entry lookup
---@param planet Planet
---@param object_type_name string
function ExtraSwap:on_production_finished(planet, object_type_name)
	local sub_obj = string.sub(object_type_name, 7) -- Removes first 6 chars from string
	local swap_entry = Get_Swap_Entry(string.upper(sub_obj))
	
	if swap_entry ~= nil then
		local old_unit = swap_entry[1]
		local new_unit = swap_entry[2]
		
		local SwapDummy = Find_First_Object(object_type_name)
		if not SwapDummy then
			return
		end

		local SwapOwner = SwapDummy.Get_Owner()
        local SwapLocation = SwapDummy.Get_Planet_Location()
		
		if old_unit == nil then
			ReplaceSpawn = SpawnList(new_unit, SwapLocation, SwapOwner, true, false)
		else
			local checkObject
			
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
			
			if TestValid(checkObject) then
				checkObject.Despawn()
				spawn_list_new = { new_unit }
				ReplaceSpawn = SpawnList(spawn_list_new, SwapLocation, SwapOwner,true,false)
				Transfer_Fighter_Hero(string.upper(old_unit), string.upper(new_unit))
			end
		end

		SwapDummy.Despawn()
	end
end