require("deepcore/std/plugintargets")
require("eawx-plugins/world-devastator-galactic/WorldDevastatorGalactic")

return {
    type = "plugin",
    target = PluginTargets.weekly(),
    dependencies = {"ui/galactic-display"},
    init = function(self, ctx, galactic_display)
        return WorldDevastatorGalactic(galactic_display, ctx.galactic_conquest)
    end
}
