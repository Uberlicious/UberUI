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

    opt.Header(page, "Cooldown Manager Countdown Text");

    opt.AddColorSwatch(page, {
        variable = "CooldownDurationColor", name = "Cooldown Duration Color",
        tooltip = "Color of the countdown number on Cooldown Manager icons and bars.",
        db = "cooldown", field = "durationcolor", default = "ffffffff",
        onChange = RefreshCooldownManager,
    });

    opt.AddColorSwatch(page, {
        variable = "CooldownDurationExpiringColor", name = "Expiring Duration Color",
        tooltip = "Color of the countdown number once an aura or cooldown has less time left than the Expiring Duration Threshold below.",
        db = "cooldown", field = "durationexpiringcolor", default = "ffff3333",
        onChange = RefreshCooldownManager,
    });

    opt.AddSlider(page, {
        variable = "CooldownDurationThreshold", name = "Expiring Duration Threshold",
        tooltip = "Seconds left at which a Cooldown Manager countdown switches to the Expiring Duration Color.",
        db = "cooldown", field = "durationthreshold", default = 5,
        min = 1, max = 10, step = 1,
        format = function(value) return string.format("%d s", value) end,
        onChange = RefreshCooldownManager,
    });

    opt.Header(page, "Cooldown Manager Bars");

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.cooldown,
        cbVariable = "CooldownBarTextures", cbName = "Cooldown Bar Textures", cbField = "bartextures",
        cbTooltip = "Retexture Cooldown Viewer Bars Separately from All Bars texture\n\n|cffff0000Warning: Some textures may not work correctly due to tiling issues.|r",
        ddVariable = "CooldownTexture", ddName = "Cooldown Bar Texture", ddField = "bartexture",
        ddTooltip = "Set your desired status bar texture for Cooldown Viewer bars\n\n|cffff0000Warning: Some textures may not work correctly due to tiling issues.|r",
        cbOnChange = RefreshCooldownManager,
        ddOnChange = RefreshCooldownManager,
    });
end
