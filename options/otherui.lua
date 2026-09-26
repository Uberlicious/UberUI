--[[--------------------------------------------------------------------
	Uber UI options -- Other UI page: Action Bars, Cooldown Manager,
	Damage Meters
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

function opt.BuildOtherUI(page)
    opt.Header(page, "Action Bars");

    opt.AddCheckbox(page, {
        variable = "HideHotKeys", name = "Hide HotKeys",
        tooltip = "Hide hotkey text on actionbars",
        db = "general", field = "hidehotkeys", default = false,
        onChange = function() UberUI.actionbars:Color() end,
    });

    opt.AddCheckbox(page, {
        variable = "HideMacros", name = "Hide Macros",
        tooltip = "Hide macro text on actionbars",
        db = "general", field = "hidemacros", default = false,
        onChange = function() UberUI.actionbars:Color() end,
    });

    opt.Header(page, "Cooldown Manager");

    local function RefreshCooldownManager()
        if UberUI.cdManager then UberUI.cdManager:Refresh() end
    end

    opt.AddCheckbox(page, {
        variable = "CooldownBorders", name = "Cooldown Manager Icon Borders",
        tooltip = "Enable borders on Cooldown Viewer icons",
        db = "cooldown", field = "borders", regKey = "cooldownborders", default = true,
        onChange = RefreshCooldownManager,
    });

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.cooldown,
        cbVariable = "CooldownBarTextures", cbName = "Cooldown Bar Textures", cbField = "bartextures",
        cbTooltip = "Retexture Cooldown Viewer Bars Separately from All Bars texture\n\n|cffff0000Warning: Some textures may not work correctly due to tiling issues.|r",
        ddVariable = "CooldownTexture", ddName = "Cooldown Bar Texture", ddField = "bartexture",
        ddTooltip = "Set your desired status bar texture for Cooldown Viewer bars\n\n|cffff0000Warning: Some textures may not work correctly due to tiling issues.|r",
        cbOnChange = RefreshCooldownManager,
        ddOnChange = RefreshCooldownManager,
    });

    if DamageMeterSessionWindowMixin then
        opt.Header(page, "Damage Meters");

        local function RefreshDamageMeter()
            if UberUI.damageMeter then UberUI.damageMeter:ForceTexture() end
        end

        opt.AddCheckbox(page, {
            variable = "dmBackground", name = "Show Background",
            tooltip = "Show/Hide damage meter background",
            db = "damagemeters", field = "background", default = false,
            onChange = RefreshDamageMeter,
        });

        opt.AddSlider(page, {
            variable = "dmAlpha", name = "Background Alpha",
            tooltip = "Set damage meter background alpha",
            db = "damagemeters", field = "alpha", default = 50,
            min = 0, max = 100, step = 1,
            get = function()
                if (uuidb.damagemeters) then
                    return uuidb.damagemeters.alpha * 100;
                end
                return 50;
            end,
            set = function(value) uuidb.damagemeters.alpha = value / 100 end,
            onChange = RefreshDamageMeter,
        });

        opt.AddCheckbox(page, {
            variable = "dmHideOverlay", name = "Hide Overlay",
            tooltip = "Hide damage meter bar overlay (shine effect)",
            db = "damagemeters", field = "hideoverlay", default = false,
            onChange = RefreshDamageMeter,
        });

        opt.AddCheckbox(page, {
            variable = "dmHideBarBackground", name = "Hide Bar Background",
            tooltip = "Hide damage meter bar background texture",
            db = "damagemeters", field = "hidebarbackground", default = false,
            onChange = RefreshDamageMeter,
        });

        opt.AddBarTextureSetting(page, {
            dbTable = uuidb.general,
            cbVariable = "DamageMeterBarTextures", cbName = "Damage Meter Bar Textures", cbField = "damagemeterbartextures",
            cbTooltip = "Retexture Damage Meter Bars Separately from All Bars texture",
            ddVariable = "DamageMeterTexture", ddName = "Damage Meter Bar Texture", ddField = "damagemetertexture",
            ddTooltip = "Set your desired status bar texture for Damage Meter bars",
            cbOnChange = RefreshDamageMeter,
            ddOnChange = RefreshDamageMeter,
        });
    end
end
