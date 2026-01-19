require("deepcore/std/plugintargets")
require("eawx-plugins/world-devastator-galactic/WorldDevastatorGalactic")

return {
    type = "plugin",
    target = PluginTargets.weekly(),
    dependencies = {"ui/galactic-display"},
    init = function(self, ctx, galactic_display)
        ---@type WorldDevastatorGalactic
        local WDG = WorldDevastatorGalactic(galactic_display, ctx.galactic_conquest)

        if type(WDG.on_battle_end) == "function" then
            ---@type table<string, any>
            local CONSTANTS = ModContentLoader.get("GameConstants")

            ---@type string
            local human_fation = ctx.galactic_conquest.HumanPlayer.Get_Faction_Name()

            -- Attach the battle_end listener for non Imperial factions
            if CONSTANTS.ALIASES[human_fation] ~= "IMPERIAL" then
                --StoryUtil.ShowScreenText("world_devastator_galactic_plugin_enabled", 10, nil, {r = 126, g = 192, b = 0})
                ctx.galactic_conquest.Events.TacticalBattleEnded:attach_listener(WDG.on_battle_end, WDG)
            end
        end
        return WDG
    end
}
