--[[--------------------------------------------------------------------
	Uber UI options -- Cooldown Manager page: Icon borders, square icons,
	debuff coloring, pandemic highlights, countdown coloring,
	and bar textures
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

function opt.BuildCooldownManager(page)
    local function RefreshCooldownManager()
        if UberUI.cdManager then UberUI.cdManager:Refresh() end
    end

    opt.Header(page, "Cooldown Manager Icons");

    opt.AddCDMIconPreview(page);

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
        tooltip = "Rounded is Blizzard's Cooldown Manager icon. Square shows the icons square (zoomed slightly to crop the icon's built-in edge) with a flat border of exact pixel thickness in the darkness color, when Cooldown Manager Icon Borders is on. Applies to Essential, Utility and tracked buff icons, and the icons on tracked buff bars.\n\nNote: every border is dark -- tracked debuffs (e.g. your damage over time effects) no longer get dispel-type colored borders.",
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

    local cdmPandemicInit = opt.AddDropdown(page, {
        variable = "CooldownPandemicStyle", name = "Cooldown Manager Pandemic Highlight",
        tooltip = "Essential, Utility and Tracked Buffs icons (Tracked Bars have their own setting below). What an icon shows while its aura is in the pandemic window (refreshing it now keeps the remaining time -- the game decides).\n\nBlizzard: Blizzard's own rounded animation.\n\nBorder: the icon's border in the highlight color, square with Square icons.\n\nProc Glow / Marching Ants: Blizzard's animated glows, tinted.\n\nPixel Glow: thin dashes marching around the icon.\n\nNone: no pandemic highlight at all (Blizzard's is hidden too).",
        default = "blizzard",
        values = { { "blizzard", "Blizzard" }, { "border", "Border" }, { "glow", "Proc Glow" }, { "ants", "Marching Ants" },
                   { "pixel", "Pixel Glow" }, { "none", "None" } },
        get = function() return uuidb.cooldown.pandemicstyle or "blizzard" end,
        set = function(value) uuidb.cooldown.pandemicstyle = value end,
        onChange = RefreshCooldownManager,
    });

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "CooldownPixelGlowPosition", name = "Pixel Glow Position",
        tooltip = "Inside draws the Pixel Glow dashes over the icon's edge. Outside draws them just past it.",
        default = "inside",
        values = { { "inside", "Inside" }, { "outside", "Outside" } },
        get = function() return uuidb.cooldown.pixelposition == "outside" and "outside" or "inside" end,
        set = function(value) uuidb.cooldown.pixelposition = value end,
        onChange = RefreshCooldownManager,
    }), cdmPandemicInit, function() return uuidb.cooldown.pandemicstyle == "pixel" end);

    -- One of our own highlights (not Blizzard's, not None).
    local function CustomPandemic()
        local style = uuidb.cooldown.pandemicstyle or "blizzard"
        return style ~= "blizzard" and style ~= "none"
    end

    local cdmPandemicClassInit = opt.AddCheckbox(page, {
        variable = "CooldownPandemicClassColor", name = "Pandemic Highlight: Use Class Color",
        tooltip = "Color the pandemic highlight (Border, Proc Glow, Marching Ants and Pixel Glow) in your character's class color instead of the color below.",
        db = "cooldown", field = "pandemicclasscolor", default = false,
        onChange = RefreshCooldownManager,
    });
    opt.DependsOn(cdmPandemicClassInit, cdmPandemicInit, CustomPandemic);

    opt.DependsOn(opt.AddColorSwatch(page, {
        variable = "CooldownPandemicColor", name = "Cooldown Manager Pandemic Color",
        tooltip = "Color of the Cooldown Manager pandemic highlight (Border, Proc Glow, Marching Ants and Pixel Glow), unless Use Class Color is on.",
        db = "cooldown", field = "pandemiccolor", default = "ffff3030",
        get = function()
            local v = uuidb.cooldown.pandemiccolor
            return (type(v) == "string" and v:match("^%x%x%x%x%x%x%x%x$")) and v or "ffff3030"
        end,
        onChange = RefreshCooldownManager,
    }), cdmPandemicClassInit, function() return CustomPandemic() and not uuidb.cooldown.pandemicclasscolor end);

    opt.Header(page, "Cooldown Manager Countdown Text");

    local countdownInit = opt.AddCheckbox(page, {
        variable = "CooldownDurationColors", name = "Color Countdown Text",
        tooltip = "Color the countdown numbers on Cooldown Manager icons and bars with the colors below. Off keeps Blizzard's own countdown text.",
        db = "cooldown", field = "durationcolors", default = false,
        onChange = RefreshCooldownManager,
    });
    local function CountdownOn() return uuidb.cooldown.durationcolors == true end

    opt.DependsOn(opt.AddColorSwatch(page, {
        variable = "CooldownDurationColor", name = "Cooldown Duration Color",
        tooltip = "Color of the countdown number on Cooldown Manager icons and bars.",
        db = "cooldown", field = "durationcolor", default = "ffffffff",
        onChange = RefreshCooldownManager,
    }), countdownInit, CountdownOn);

    opt.DependsOn(opt.AddColorSwatch(page, {
        variable = "CooldownDurationExpiringColor", name = "Expiring Duration Color",
        tooltip = "Color of the countdown number once an aura or cooldown has less time left than the Expiring Duration Threshold below.",
        db = "cooldown", field = "durationexpiringcolor", default = "ffff3333",
        onChange = RefreshCooldownManager,
    }), countdownInit, CountdownOn);

    opt.DependsOn(opt.AddSlider(page, {
        variable = "CooldownDurationThreshold", name = "Expiring Duration Threshold",
        tooltip = "Seconds left at which a Cooldown Manager countdown switches to the Expiring Duration Color.",
        db = "cooldown", field = "durationthreshold", default = 5,
        min = 1, max = 10, step = 1,
        format = function(value) return string.format("%d s", value) end,
        onChange = RefreshCooldownManager,
    }), countdownInit, CountdownOn);

    opt.Header(page, "Cooldown Manager Bars");

    opt.AddCDMBarPreview(page);

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.cooldown,
        cbVariable = "CooldownBarTextures", cbName = "Cooldown Bar Textures", cbField = "bartextures",
        cbTooltip = "Retexture Cooldown Viewer Bars Separately from All Bars texture\n\n|cffff0000Warning: Some textures may not work correctly due to tiling issues.|r",
        ddVariable = "CooldownTexture", ddName = "Cooldown Bar Texture", ddField = "bartexture",
        ddTooltip = "Set your desired status bar texture for Cooldown Viewer bars\n\n|cffff0000Warning: Some textures may not work correctly due to tiling issues.|r",
        cbOnChange = RefreshCooldownManager,
        ddOnChange = RefreshCooldownManager,
    });

    opt.AddCheckbox(page, {
        variable = "CooldownDarkenBars", name = "Darken Tracked Bars",
        tooltip = "Darken the background and border art around Tracked Bars. Square bars replace that art with their own dark border.",
        db = "cooldown", field = "darkenbars", default = true,
        onChange = RefreshCooldownManager,
    });

    opt.AddDropdown(page, {
        variable = "CooldownBarShape", name = "Tracked Bars Shape",
        tooltip = "Rounded is Blizzard's Tracked Bars look. Square draws a flat border of exact pixel thickness around each bar (the Cooldown Manager Border Thickness), in the darkness color, over a flat dark background.\n\nSquare bars need a flat texture: Blizzard's stock bar texture is rounded, so Square uses \"Blizzard_Flat\" unless you pick another bar texture.",
        default = "rounded",
        values = { { "rounded", "Rounded" }, { "square", "Square" } },
        get = function() return uuidb.cooldown.squarebars and "square" or "rounded" end,
        set = function(value) uuidb.cooldown.squarebars = (value == "square") end,
        onChange = RefreshCooldownManager,
    });

    local barPandemicInit = opt.AddDropdown(page, {
        variable = "CooldownBarPandemicStyle", name = "Tracked Bars Pandemic Highlight",
        tooltip = "What a Tracked Bar shows while its aura is in the pandemic window.\n\nBlizzard: Blizzard's own bar animation.\n\nBorder: a border in the highlight color.\n\nBar Glow: Blizzard's bar glow, tinted.\n\nPixel Glow: thin dashes marching around the bar.\n\nBar Fill Color: the bar itself fills in the highlight color.\n\nNone: no pandemic highlight at all (Blizzard's is hidden too).",
        default = "blizzard",
        values = { { "blizzard", "Blizzard" }, { "border", "Border" }, { "glow", "Bar Glow" },
                   { "pixel", "Pixel Glow" }, { "fill", "Bar Fill Color" }, { "none", "None" } },
        -- Bars' old "Marching Ants" was always drawn as these dashes.
        get = function()
            local v = uuidb.cooldown.barpandemicstyle or "blizzard"
            return v == "ants" and "pixel" or v
        end,
        set = function(value) uuidb.cooldown.barpandemicstyle = value end,
        onChange = RefreshCooldownManager,
    });
    local function BarPandemicStyle() return uuidb.cooldown.barpandemicstyle or "blizzard" end

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "CooldownBarPixelGlowPosition", name = "Tracked Bars Pixel Glow Position",
        tooltip = "Inside draws the Pixel Glow dashes over the bar's (or its icon's) edge. Outside draws them just past it.",
        default = "inside",
        values = { { "inside", "Inside" }, { "outside", "Outside" } },
        get = function() return uuidb.cooldown.barpixelposition == "outside" and "outside" or "inside" end,
        set = function(value) uuidb.cooldown.barpixelposition = value end,
        onChange = RefreshCooldownManager,
    }), barPandemicInit, function()
        local style = BarPandemicStyle()
        return style == "pixel" or style == "ants"
    end);
    local function BarPandemicColored()
        local style = BarPandemicStyle()
        return style ~= "blizzard" and style ~= "none"
    end

    local barPandemicClassInit = opt.AddCheckbox(page, {
        variable = "CooldownBarPandemicClassColor", name = "Tracked Bars Pandemic: Use Class Color",
        tooltip = "Color the Tracked Bars pandemic highlight in your character's class color instead of the color below.",
        db = "cooldown", field = "barpandemicclasscolor", default = false,
        onChange = RefreshCooldownManager,
    });
    opt.DependsOn(barPandemicClassInit, barPandemicInit, BarPandemicColored);

    opt.DependsOn(opt.AddColorSwatch(page, {
        variable = "CooldownBarPandemicColor", name = "Tracked Bars Pandemic Color",
        tooltip = "Color of the Tracked Bars pandemic highlight, unless Use Class Color is on.",
        db = "cooldown", field = "barpandemiccolor", default = "ffff3030",
        get = function()
            local v = uuidb.cooldown.barpandemiccolor
            return (type(v) == "string" and v:match("^%x%x%x%x%x%x%x%x$")) and v or "ffff3030"
        end,
        onChange = RefreshCooldownManager,
    }), barPandemicClassInit, function() return BarPandemicColored() and not uuidb.cooldown.barpandemicclasscolor end);

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "CooldownBarPandemicTarget", name = "Tracked Bars Pandemic Highlight On",
        tooltip = "Where the Border, Bar Glow or Pixel Glow highlight goes: around the bar (Blizzard's placement) or around the bar's icon.",
        default = "bar",
        values = { { "bar", "Bar" }, { "icon", "Icon" } },
        get = function() return uuidb.cooldown.barpandemic or "bar" end,
        set = function(value) uuidb.cooldown.barpandemic = value end,
        onChange = RefreshCooldownManager,
    }), barPandemicInit, function()
        local style = BarPandemicStyle()
        return style == "border" or style == "glow" or style == "ants"
    end);

    opt.AddCheckbox(page, {
        variable = "CooldownBarIconToBar", name = "Scale Tracked Bar Icon to Bar Height",
        tooltip = "Shrink each Tracked Bar's spell icon to the height of its bar, so icon and bar line up.",
        db = "cooldown", field = "baricontobar", default = false,
        onChange = RefreshCooldownManager,
    });

    opt.Header(page, "Cooldown Manager Layout");

    -- One alignment choice per viewer. Which items show at all (inactive
    -- buffs) stays Blizzard's Edit Mode "Hide When Inactive" setting.
    local ALIGN_VALUES = {
        { "blizzard", "Blizzard Default" },
        { "pack", "Packed" },
        { "center", "Centered" },
    }
    local ALIGN_TOOLTIP = "Blizzard Default leaves the layout alone. Packed and Centered pack the shown %s together with no gaps -- from the Edit Mode edge (following its direction setting), or centered in the container. Whether inactive %s show at all is Blizzard's Edit Mode \"Hide When Inactive\" setting. With Icon Padding at 0 and square icons, neighboring icons share one border line.\n\nSwitching back to Blizzard Default takes effect on the next reload or Edit Mode change."
    local function AddAlign(variable, name, field, default, noun)
        opt.AddDropdown(page, {
            variable = variable, name = name,
            tooltip = string.format(ALIGN_TOOLTIP, noun, noun),
            default = default,
            values = ALIGN_VALUES,
            get = function() return uuidb.cooldown[field] or default end,
            set = function(value) uuidb.cooldown[field] = value end,
            onChange = RefreshCooldownManager,
        });
    end

    AddAlign("CooldownEssentialAlign", "Essential Cooldowns Alignment", "essential_align", "blizzard", "icons");
    AddAlign("CooldownUtilityAlign", "Utility Cooldowns Alignment", "utility_align", "blizzard", "icons");
    AddAlign("CooldownBuffIconAlign", "Tracked Buffs Alignment", "bufficon_align", "blizzard", "icons");
    AddAlign("CooldownBuffBarAlign", "Tracked Bars Alignment", "buffbar_align", "blizzard", "bars");
end
