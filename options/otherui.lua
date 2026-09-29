--[[--------------------------------------------------------------------
	Uber UI options -- Other UI page: Action Bars, Damage Meters,
	Swing Timers, Minimap
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

    -- WoW Forever only: retail has no native swing timer.
    if C_SwingTimer then
        opt.Header(page, "Swing Timers");

        local function RefreshSwingTimers()
            if UberUI.swingtimers then UberUI.swingtimers:Apply() end
        end

        opt.AddCheckbox(page, {
            variable = "darkenSwingTimers", name = "Darken Swing Timers",
            tooltip = "Darken the frame around the main hand, off hand and ranged swing timer bars.",
            db = "general", field = "darkenswingtimers", default = true,
            onChange = RefreshSwingTimers,
        });

        opt.AddCheckbox(page, {
            variable = "swingTimerLabelShadow", name = "Swing Timer Label Shadow",
            tooltip = "Show the dark shadow behind the Main Hand / Off Hand / Ranged label on the left of each swing timer bar.",
            db = "general", field = "swingtimerlabelshadow", default = true,
            onChange = RefreshSwingTimers,
        });

        local swingShapeInit = opt.AddDropdown(page, {
            variable = "SwingTimerBorderShape", name = "Swing Timer Border",
            tooltip = "Rounded is Blizzard's swing timer frame. Square draws a flat border of exact pixel thickness around each bar, dark when Darken Swing Timers is on (or silver with Darken Swing Timers off).",
            default = "rounded",
            values = { { "rounded", "Rounded" }, { "square", "Square" } },
            get = function() return (uuidb.general and uuidb.general.swingtimersquareborder) and "square" or "rounded" end,
            set = function(value) uuidb.general.swingtimersquareborder = (value == "square") end,
            onChange = RefreshSwingTimers,
        });

        opt.DependsOn(opt.AddSlider(page, {
            variable = "SwingTimerBorderThickness", name = "Swing Timer Border Thickness",
            tooltip = "Thickness of the square swing timer border, in screen pixels.",
            db = "general", field = "swingtimersquareborder_thickness", default = 1,
            min = 1, max = 4, step = 1,
            onChange = RefreshSwingTimers,
        }), swingShapeInit, function() return uuidb.general and uuidb.general.swingtimersquareborder end);

        opt.AddBarTextureSetting(page, {
            dbTable = uuidb.general,
            cbVariable = "SwingTimerBarTextures", cbName = "Swing Timer Bar Textures", cbField = "swingtimerbartextures",
            cbTooltip = "Retexture the swing timer bars. The All Bars texture never applies to them -- they're timers, not health or power bars.",
            ddVariable = "SwingTimerTexture", ddName = "Swing Timer Bar Texture", ddField = "swingtimerbartexture",
            ddTooltip = "Set your desired status bar texture for the swing timer bars",
            cbOnChange = RefreshSwingTimers,
            ddOnChange = RefreshSwingTimers,
        });

        for _, c in ipairs({
            { "swingtimermainhandcolor", "SwingTimerMainHandColor", "Main Hand Swing Timer Color", "ffffc21a" },
            { "swingtimeroffhandcolor",  "SwingTimerOffHandColor",  "Off Hand Swing Timer Color",  "ff3d9eff" },
            { "swingtimerrangedcolor",   "SwingTimerRangedColor",   "Ranged Swing Timer Color",    "ff5cd65c" },
        }) do
            opt.AddColorSwatch(page, {
                variable = c[2], name = c[3],
                tooltip = "Fill color of this swing timer bar when it uses a custom bar texture (Blizzard's own bar art has its color built in).",
                db = "general", field = c[1], default = c[4],
                onChange = RefreshSwingTimers,
            });
        end
    end

    opt.Header(page, "Minimap");

    opt.AddCheckbox(page, {
        variable = "DarkenAddonMinimapButtons", name = "Darken Addon Minimap Buttons",
        tooltip = "Darken the ring around other addons' minimap buttons to match the minimap border. The addons' own icons keep their colors.\n\nButtons that use their own custom ring art are left alone.",
        db = "general", field = "darkenaddonminimapbuttons", default = true,
        onChange = function() if UberUI.minimap then UberUI.minimap.DarkenAddonButtons() end end,
    });
end
