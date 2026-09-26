--[[--------------------------------------------------------------------
	Uber UI options -- main page: settings that apply everywhere
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

function opt.BuildGeneral(page)
    opt.Header(page, "General");

    opt.AddSlider(page, {
        variable = "DarknessLevel", name = "Darkness Level", tooltip = "Set your desired level of darkness",
        min = 0, max = 100, step = 5, default = 40,
        regKey = "darkencolor", regTable = { darkencolor = uuidb.general and uuidb.general.darkencolor.r * 100 or 40 },
        get = function()
            if (uuidb.general) then
                return uuidb.general.darkencolor.r * 100;
            end
            return 40;
        end,
        set = function(value)
            local dc = uuidb.general.darkencolor;
            local adjusted = value / 100;
            dc.r = adjusted;
            dc.g = adjusted;
            dc.b = adjusted;
        end,
        onChange = function() UberUI.misc:AllFramesColor() end,
    });

    opt.Header(page, "Health Bars");

    opt.AddCheckbox(page, {
        variable = "HostilityColor", name = "Color By Hostility",
        tooltip = "Color all healthbars according to hostility \n\n|cffff0000Enemy\n|cff00ff00Friendly\n|cffffff00Neutral\n\n|cffff0000This setting will be overwritten in respective frames that have class coloring enabled when targeting a player",
        db = "general", field = "hostilitycolor", default = false,
        onChange = function() UberUI.misc:AllFramesHealthColor() end,
    });

    opt.Header(page, "Bar Textures");

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "BarTexture", cbName = "All Bar Textures", cbField = "allbartextures",
        cbTooltip = "Apply texture to all bars (can be overridden per frame on the Unit Frames, Raid & Group Frames, Nameplates and Other UI pages)",
        ddVariable = "AllBarsTexture", ddName = "All Bars Texture", ddField = "texture",
        ddTooltip = "Set your desired status bar texture for all bars (can be overridden per frame on the other Uber UI pages)" .. opt.RELOAD_NOTE,
        ddOnChange = function()
            UberUI.misc:AllFramesHealthManaTexture();
            if UberUI.damageMeter then
                UberUI.damageMeter:ForceTexture();
            end
        end,
    });

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "SecondaryBarTextures", cbName = "Secondary Bar Textures", cbField = "secondarybartextures",
        cbTooltip = "Enable changing secondary bar textures independently ex. AbsorbBar, HealingPredictionBar" .. opt.RELOAD_NOTE,
        ddVariable = "SecondaryTexture", ddName = "Secondary Bar Texture", ddField = "secondarybartexture",
        ddTooltip = "Set your desired status bar texture for secondary bars" .. opt.RELOAD_NOTE,
        cbOnChange = function() UberUI.misc:AllFramesHealthManaTexture() end,
        ddOnChange = function() UberUI.misc:AllFramesHealthManaTexture() end,
    });

    -- One-time copy of aura settings into every location (see
    -- opt.AddAllAurasOptions); per-location settings stay on their own pages.
    opt.Header(page, "All Auras  |cffff4040(overwrites every frame's aura settings)|r");
    opt.AddAllAurasOptions(page);
end
