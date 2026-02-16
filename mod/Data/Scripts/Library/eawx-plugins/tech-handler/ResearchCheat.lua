---@License: MIT

require("deepcore/std/class")
require("eawx-util/UnitUtil")

---@class ResearchCheat
ResearchCheat = class()

---@param gc GalacticConquest
function ResearchCheat:new(gc)
    self.gc = gc
    self.HumanPlayer = Find_Player("local")
    self.human_faction = self.HumanPlayer.Get_Faction_Name()

    local factions_with_research = {
        ["REBEL"] = true,
        ["ERIADU_AUTHORITY"] = true,
        ["GREATER_MALDROOD"] = true,
        ["ZSINJ_EMPIRE"] = true,
    }
    if not factions_with_research[self.human_faction] then
        -- No research tech to unlock for this faction
        return
    end

    UnitUtil.SetLockList(self.human_faction, {"CHEAT_UNLOCK_ALL_RESEARCH_TECH"}, true)

    self.gc.Events.GalacticProductionFinished:attach_listener(self.on_production_finished, self)
end

function ResearchCheat:destroy()
    self.gc.Events.GalacticProductionFinished:detach_listener(self.on_production_finished, self)
end

---@param planet Planet
---@param object_type_name string
function ResearchCheat:on_production_finished(planet, object_type_name)
    if object_type_name == "CHEAT_UNLOCK_ALL_RESEARCH_TECH" then
        self:publish_all_techhandler()
        self:unlock_all_research_tech()
        self:destroy()
    end
end

---Publish all TechHandler GenericResearch events to crossplot
function ResearchCheat:publish_all_techhandler()
    crossplot:publish("REPUBLIC_STAR_DESTROYER_RESEARCH", "empty")
    crossplot:publish("NCMP1_RESEARCH", "empty")
    crossplot:publish("NCMP2_RESEARCH", "empty")
    crossplot:publish("AAC3_RESEARCH", "empty")
    crossplot:publish("CORONA_RESEARCH", "empty")
    crossplot:publish("GORATH_RESEARCH", "empty")
    crossplot:publish("TEMPEST_RESEARCH", "empty")
    crossplot:publish("VISCOUNT_RESEARCH", "empty")
    crossplot:publish("MEDIATOR_RESEARCH", "empty")
    crossplot:publish("MC_HEAVY_CARRIER_RESEARCH", "empty")
end

---Manually unlock all research tech dummies
function ResearchCheat:unlock_all_research_tech()
    local research_dummies = {
        "Dummy_NewClass",
        "Dummy_NewClass_PhaseTwo",
        "Dummy_RepublicSD",
        "Dummy_AAC3",
        "Dummy_Viscount",
        "Wedge_Lusankya_Dummy",
        "Ackbar_Guardian_Dummy",
        "Dummy_Mediator",
        "Dummy_MC_Heavy_Carrier",
        "Dummy_Research_Fighters_Unshielded",
        "Dummy_Research_Gorath",
        "Dummy_Research_Corona",
    }
    UnitUtil.SetLockList(self.human_faction, research_dummies, true)
    UnitUtil.SetLockList(self.human_faction, {"CHEAT_UNLOCK_ALL_RESEARCH_TECH"}, false)
end

return ResearchCheat
