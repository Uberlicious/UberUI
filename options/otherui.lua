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
            cbVariable = "DamageMeterBarTextures", cbName = "Bar Textures", cbField = "damagemeterbartextures",
            cbTooltip = "Retexture Damage Meter Bars Separately from All Bars texture",
            ddVariable = "DamageMeterTexture", ddName = "Bar Texture", ddField = "damagemetertexture",
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
            variable = "darkenSwingTimers", name = "Darken",
            tooltip = "Darken the frame around the main hand, off hand and ranged swing timer bars.",
            db = "general", field = "darkenswingtimers", default = true,
            onChange = RefreshSwingTimers,
        });

        opt.AddCheckbox(page, {
            variable = "swingTimerLabelShadow", name = "Label Shadow",
            tooltip = "Show the dark shadow behind the Main Hand / Off Hand / Ranged label on the left of each swing timer bar.",
            db = "general", field = "swingtimerlabelshadow", default = true,
            onChange = RefreshSwingTimers,
        });

        local swingShapeInit = opt.AddDropdown(page, {
            variable = "SwingTimerBorderShape", name = "Border",
            tooltip = "Rounded is Blizzard's swing timer frame. Square draws a flat border of exact pixel thickness around each bar, dark when Darken Swing Timers is on (or silver with Darken Swing Timers off).",
            default = "rounded",
            values = { { "rounded", "Rounded" }, { "square", "Square" } },
            get = function() return (uuidb.general and uuidb.general.swingtimersquareborder) and "square" or "rounded" end,
            set = function(value) uuidb.general.swingtimersquareborder = (value == "square") end,
            onChange = RefreshSwingTimers,
        });

        opt.DependsOn(opt.AddSlider(page, {
            variable = "SwingTimerBorderThickness", name = "Border Thickness",
            tooltip = "Thickness of the square swing timer border, in screen pixels.",
            db = "general", field = "swingtimersquareborder_thickness", default = 1,
            min = 1, max = 4, step = 1,
            onChange = RefreshSwingTimers,
        }), swingShapeInit, function() return uuidb.general and uuidb.general.swingtimersquareborder end);

        opt.AddBarTextureSetting(page, {
            dbTable = uuidb.general,
            cbVariable = "SwingTimerBarTextures", cbName = "Bar Textures", cbField = "swingtimerbartextures",
            cbTooltip = "Retexture the swing timer bars. The All Bars texture never applies to them -- they're timers, not health or power bars.",
            ddVariable = "SwingTimerTexture", ddName = "Bar Texture", ddField = "swingtimerbartexture",
            ddTooltip = "Set your desired status bar texture for the swing timer bars",
            cbOnChange = RefreshSwingTimers,
            ddOnChange = RefreshSwingTimers,
        });

        local swingColorInit = opt.AddDropdown(page, {
            variable = "SwingTimerBarColor", name = "Bar Color",
            tooltip = "None keeps Blizzard's built-in bar colors (a custom bar texture is left untinted). Custom tints each bar with the colors below; Class tints all bars with your class color. Tinting keeps Blizzard's bar art unless Bar Textures is on.",
            db = "general", field = "swingtimerbarcolor", default = "none",
            values = { { "none", "None" }, { "custom", "Custom" }, { "class", "Class" } },
            onChange = RefreshSwingTimers,
        });

        for _, c in ipairs({
            { "swingtimermainhandcolor", "SwingTimerMainHandColor", "Main Hand Color", "ffffc21a" },
            { "swingtimeroffhandcolor",  "SwingTimerOffHandColor",  "Off Hand Color",  "ff3d9eff" },
            { "swingtimerrangedcolor",   "SwingTimerRangedColor",   "Ranged Color",    "ff5cd65c" },
        }) do
            opt.DependsOn(opt.AddColorSwatch(page, {
                variable = c[2], name = c[3],
                tooltip = "Fill color of this swing timer bar when Bar Color is Custom.",
                db = "general", field = c[1], default = c[4],
                onChange = RefreshSwingTimers,
            }), swingColorInit, function() return uuidb.general and uuidb.general.swingtimerbarcolor == "custom" end);
        end
    end

    opt.Header(page, "Minimap");

    opt.AddCheckbox(page, {
        variable = "DarkenAddonMinimapButtons", name = "Darken Addon Minimap Buttons",
        tooltip = "Darken the ring around other addons' minimap buttons to match the minimap border. The addons' own icons keep their colors.\n\nButtons that use their own custom ring art are left alone.",
        db = "general", field = "darkenaddonminimapbuttons", default = true,
        onChange = function() if UberUI.minimap then UberUI.minimap.DarkenAddonButtons() end end,
    });

    opt.Header(page, "Cursor Ring");

    local function RefreshCursorRing()
        if UberUI.cursorring then UberUI.cursorring:Refresh() end
    end
    local function RingOn() return uuidb.general and uuidb.general.cursorring == true end

    opt.AddPreview(page, {
        name = "Preview",
        tooltip = "The cursor ring at its on-screen size around the cursor, with the GCD ring (when it's on) sweeping as if you'd just cast.",
        height = 82,
        create = function(parent)
            if not (UberUI.cursorring and UberUI.cursorring.CreatePreview) then return nil end
            return UberUI.cursorring.CreatePreview(parent)
        end,
    });

    local ringInit = opt.AddCheckbox(page, {
        variable = "CursorRing", name = "Show Cursor Ring",
        tooltip = "Show a ring around your mouse cursor, to keep track of it in busy fights.",
        db = "general", field = "cursorring", default = false,
        onChange = RefreshCursorRing,
    });

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "CursorRingStyle", name = "Style",
        tooltip = "Normal or Thin ring.",
        default = "normal",
        values = { { "normal", "Normal" }, { "thin", "Thin" } },
        get = function() return uuidb.general.cursorringstyle == "thin" and "thin" or "normal" end,
        set = function(value) uuidb.general.cursorringstyle = value end,
        onChange = RefreshCursorRing,
    }), ringInit, RingOn);

    opt.DependsOn(opt.AddSlider(page, {
        variable = "CursorRingSize", name = "Size",
        tooltip = "Size of the cursor ring.",
        db = "general", field = "cursorringsize", default = 30,
        min = 20, max = 100, step = 2,
        onChange = RefreshCursorRing,
    }), ringInit, RingOn);

    local ringClassInit = opt.AddCheckbox(page, {
        variable = "CursorRingClassColor", name = "Use Class Color",
        tooltip = "Color the cursor ring in your character's class color instead of the color below.",
        db = "general", field = "cursorringclasscolor", default = true,
        onChange = RefreshCursorRing,
    });
    opt.DependsOn(ringClassInit, ringInit, RingOn);

    opt.DependsOn(opt.AddColorSwatch(page, {
        variable = "CursorRingColor", name = "Color",
        tooltip = "Color of the cursor ring, unless Use Class Color is on.",
        db = "general", field = "cursorringcolor", default = "ffffffff",
        onChange = RefreshCursorRing,
    }), ringClassInit, function() return RingOn() and uuidb.general.cursorringclasscolor == false end);

    opt.DependsOn(opt.AddCheckbox(page, {
        variable = "CursorRingCombatOnly", name = "In Combat Only",
        tooltip = "Only show the cursor ring while you're in combat.",
        db = "general", field = "cursorringcombatonly", default = false,
        onChange = RefreshCursorRing,
    }), ringInit, RingOn);

    opt.DependsOn(opt.AddCheckbox(page, {
        variable = "CursorRingWhileHidden", name = "Show While Cursor Is Hidden",
        tooltip = "Keep the ring on screen while the cursor is hidden, like when you hold a mouse button to turn the camera. It stays where the cursor was.",
        db = "general", field = "cursorringwhilehidden", default = true,
        onChange = RefreshCursorRing,
    }), ringInit, RingOn);

    local gcdInit = opt.AddCheckbox(page, {
        variable = "CursorRingGCD", name = "Cursor Ring: GCD Ring",
        tooltip = "A ring just inside the cursor ring that sweeps away as your global cooldown runs.",
        db = "general", field = "cursorringgcd", default = false,
        onChange = RefreshCursorRing,
    });
    opt.DependsOn(gcdInit, ringInit, RingOn);

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "CursorRingGCDStyle", name = "GCD Ring Style",
        tooltip = "Normal or Thin GCD ring, separately from the cursor ring.",
        default = "normal",
        values = { { "normal", "Normal" }, { "thin", "Thin" } },
        get = function() return uuidb.general.cursorringgcdstyle == "thin" and "thin" or "normal" end,
        set = function(value) uuidb.general.cursorringgcdstyle = value end,
        onChange = RefreshCursorRing,
    }), gcdInit, function() return RingOn() and uuidb.general.cursorringgcd == true end);

    opt.DependsOn(opt.AddColorSwatch(page, {
        variable = "CursorRingGCDColor", name = "GCD Ring Color",
        tooltip = "Color of the GCD ring.",
        db = "general", field = "cursorringgcdcolor", default = "ffffffff",
        onChange = RefreshCursorRing,
    }), gcdInit, function() return RingOn() and uuidb.general.cursorringgcd == true end);
end
