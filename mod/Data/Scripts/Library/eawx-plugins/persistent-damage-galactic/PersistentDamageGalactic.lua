require("deepcore/std/class")
require("deepcore/crossplot/crossplot")
require("eawx-util/StoryUtil")

---@class PersistentDamageGalactic
PersistentDamageGalactic = class()

function PersistentDamageGalactic:new(gc)
	self.persistent_damage_library = require("hardpoint-lists/PersistentDamageLibrary")
	self.display_name_library = require("DisplayNameLibrary")

	--SSDs cannot leave tactical with health in the range [90, 100)
	self.autoheal_threshold = 90

	for i,unit_globalvalue in pairs(self.persistent_damage_library[2]) do
		GlobalValue.Set(unit_globalvalue,100)
	end

	gc.Events.GalacticProductionFinished:attach_listener(self.on_production_finished, self)
end

function PersistentDamageGalactic:update()
	--Logger:trace("entering PersistentDamageGalactic:update")
	for object_name,repair_data in pairs(self.persistent_damage_library[1]) do
		local objects = Find_All_Objects_Of_Type(object_name)
		if table.getn(objects) > 0 then
			for _,object in pairs(objects) do
				local p_owner = object.Get_Owner()
				if p_owner ~= nil then
					local unit_globalvalue = object_name.."_"..p_owner.Get_Faction_Name()
					local unit_globalvalue_value = GlobalValue.Get(unit_globalvalue)
					if unit_globalvalue_value == nil then
						GlobalValue.Set(unit_globalvalue,100)
						unit_globalvalue_value = 100
					end
					local current_health = unit_globalvalue_value

					if current_health < 100 then
						local heal_amt = repair_data.AMOUNT
						if heal_amt == nil then
							heal_amt = 10 --default 10% repair per cycle
						end
						local heal_fee = repair_data.COST
						if heal_fee == nil then
							heal_fee = -tonumber(Dirty_Floor(Find_Object_Type(object_name).Get_Build_Cost() * heal_amt / 200)) --default 2% repair for 1% cost
						end
						local short_name = self.display_name_library[object_name]

						if p_owner.Get_Credits() >= heal_fee then
							local new_health = current_health + heal_amt
							if new_health >= self.autoheal_threshold then
								new_health = 100
							end
							GlobalValue.Set(unit_globalvalue,new_health)
							p_owner.Give_Money(heal_fee)
							if p_owner.Is_Human() then
								crossplot:publish("GALACTIC_SSD_REPAIRED", short_name, new_health, heal_fee)
							end
						end
					end
				end
			end
		end
	end
end

function PersistentDamageGalactic:on_production_finished(planet, game_object_type_name)
	--Logger:trace("entering PersistentDamageGalactic:on_production_finished")
	--DebugMessage("In PersistentDamageGalactic:on_production_finished")
	if not self.persistent_damage_library[3] then
		return
	end

	for _,object_name in pairs(self.persistent_damage_library[3]) do
		if game_object_type_name == object_name then
			local owner_name = planet:get_owner().Get_Faction_Name()
			local unit_globalvalue = game_object_type_name.."_"..owner_name
			GlobalValue.Set(unit_globalvalue,100)
		end
	end
end

return PersistentDamageGalactic
