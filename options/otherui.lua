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

    local cdmKeys = UberUI.squareborders.Keys("cdm");
    local function CdmSquare() return uuidb.general and uuidb.general[cdmKeys[1]] end

    local cdmShapeInit = opt.AddDropdown(page, {
        variable = "CooldownIconShape", name = "Cooldown Manager Icon Shape",
        tooltip = "Rounded is Blizzard's Cooldown Manager icon. Square shows the icons square (zoomed slightly to crop the icon's built-in edge) with a flat border of exact pixel thickness in the darkness color, when Cooldown Manager Icon Borders is on. Applies to Essential, Utility and tracked buff icons, and the icons on tracked buff bars.",
        default = "rounded",
        values = { { "rounded", "Rounded" }, { "square", "Square" } },
        get = function() return CdmSquare() and "square" or "rounded" end,
        set = function(value) uuidb.general[cdmKeys[1]] = (value == "square") end,
        onChange = RefreshCooldownManager,
    });

    opt.DependsOn(opt.AddSlider(page, {
        variable = "CooldownIconBorderThickness", name = "Cooldown Manager Border Thickness",
        tooltip = "Thickness of the square Cooldown Manager icon border, in screen pixels.",
        db = "general", field = cdmKeys[2], default = 1,
        min = 1, max = 8, step = 1,
        onChange = RefreshCooldownManager,
    }), cdmShapeInit, CdmSquare);

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "CooldownIconBorderPosition", name = "Cooldown Manager Border Position",
        tooltip = "Inside Icon draws the square border over the icon's outer edge, so icons keep their size and spacing. Outside Icon draws it around the icon (with Edit Mode icon padding at 0, neighboring borders touch).",
        default = "inside",
        values = { { "inside", "Inside Icon" }, { "outside", "Outside Icon" } },
        get = function() return (uuidb.general and uuidb.general[cdmKeys[3]] == false) and "outside" or "inside" end,
        set = function(value) uuidb.general[cdmKeys[3]] = (value ~= "outside") end,
        onChange = RefreshCooldownManager,
    }), cdmShapeInit, CdmSquare);

    opt.AddDropdown(page, {
        variable = "CooldownDebuffBorder", name = "Cooldown Manager Debuff Border",
        tooltip = "Border on harmful auras you track in the Tracked Buffs section (e.g. your damage over time effects). Dispel Color is Blizzard's look: the aura's dispel-type color, red when it has none. Dark gives them the same border as every other icon.",
        default = "dispel",
        values = { { "dispel", "Dispel Color" }, { "dark", "Dark" } },
        get = function() return uuidb.cooldown.debuffborder or "dispel" end,
        set = function(value) uuidb.cooldown.debuffborder = value end,
        onChange = RefreshCooldownManager,
    });

    local cdmPandemicInit = opt.AddDropdown(page, {
        variable = "CooldownPandemicStyle", name = "Cooldown Manager Pandemic Highlight",
        tooltip = "What an icon shows while its aura is in the pandemic window (refreshing it now keeps the remaining time -- the game decides).\n\nBlizzard: Blizzard's own rounded animation.\n\nBorder: the icon's border in the highlight color, square with Square icons.\n\nProc Glow / Marching Ants: Blizzard's animated glows, tinted.",
        default = "blizzard",
        values = { { "blizzard", "Blizzard" }, { "border", "Border" }, { "glow", "Proc Glow" }, { "ants", "Marching Ants" } },
        get = function() return uuidb.cooldown.pandemicstyle or "blizzard" end,
        set = function(value) uuidb.cooldown.pandemicstyle = value end,
        onChange = RefreshCooldownManager,
    });

    opt.DependsOn(opt.AddColorSwatch(page, {
        variable = "CooldownPandemicColor", name = "Cooldown Manager Pandemic Color",
        tooltip = "Color of the Cooldown Manager pandemic highlight (Border, Proc Glow and Marching Ants).",
        db = "cooldown", field = "pandemiccolor", default = "ffff2626",
        get = function()
            local v = uuidb.cooldown.pandemiccolor
            return (type(v) == "string" and v:match("^%x%x%x%x%x%x%x%x$")) and v or "ffff2626"
        end,
        onChange = RefreshCooldownManager,
    }), cdmPandemicInit, function() return (uuidb.cooldown.pandemicstyle or "blizzard") ~= "blizzard" end);

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
            tooltip = "Rounded is Blizzard's swing timer frame. Square draws a flat border of exact pixel thickness around each bar, in the darkness color (or black with Darken Swing Timers off).",
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
