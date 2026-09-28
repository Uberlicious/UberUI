--[[--------------------------------------------------------------------
	Uber UI options -- Nameplates page (+ Personal Resource Display)
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

function opt.BuildNameplates(page)
    opt.Header(page, "Nameplates");

    opt.AddCheckbox(page, {
        variable = "HideNPSelctionGlow", name = "Hide Nameplate Selection Glow",
        tooltip = "Hide the inner glow on selected nameplate",
        db = "general", field = "hidenameplateglow", default = false,
        onChange = function()
            if UberUI.nameplates then UberUI.nameplates:ForceNameplateTexture() end
        end,
    });

    opt.AddCheckbox(page, {
        variable = "SmallFriendlyNampelates", name = "Small Friendly Nameplates",
        tooltip = "Make friendly nameplates half the size",
        db = "general", field = "smallfriendlynameplate", default = false,
        onChange = function()
            if UberUI.nameplates then UberUI.nameplates:UpdateNameplateSize() end
        end,
    });

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "NameplateBarTextures", cbName = "Nameplate Bar Textures", cbField = "nameplatebartextures",
        cbTooltip = "Retexture Nameplate Frames Separately from All Bars texture",
        ddVariable = "NameplateTexture", ddName = "Nameplate Bar Texture", ddField = "nameplatebartexture",
        ddTooltip = "Set your desired status bar texture for Nameplate frames",
        cbOnChange = function() UberUI.nameplates:ForceNameplateTexture() end,
        ddOnChange = function(value) UberUI.nameplates:ForceNameplateTexture(value) end,
    });

    local function RefreshNameplateBars()
        if UberUI.nameplates then UberUI.nameplates:ForceNameplateTexture() end
    end

    local shapeInit = opt.AddDropdown(page, {
        variable = "NameplateHealthBorderShape", name = "Nameplate Health Bar Border",
        tooltip = "Rounded is Blizzard's nameplate border. Square draws a flat border of exact pixel thickness around the health bar, in the darkness color, with a square bar.",
        default = "rounded",
        values = { { "rounded", "Rounded" }, { "square", "Square" } },
        get = function() return (uuidb.general and uuidb.general.nameplatesquareborder) and "square" or "rounded" end,
        set = function(value) uuidb.general.nameplatesquareborder = (value == "square") end,
        onChange = RefreshNameplateBars,
    });

    opt.DependsOn(opt.AddSlider(page, {
        variable = "NameplateHealthBorderThickness", name = "Nameplate Health Bar Border Thickness",
        tooltip = "Thickness of the square nameplate health bar border, in screen pixels.",
        db = "general", field = "nameplatesquareborder_thickness", default = 1,
        min = 1, max = 4, step = 1,
        onChange = RefreshNameplateBars,
    }), shapeInit, function() return uuidb.general and uuidb.general.nameplatesquareborder end);

    opt.Header(page, "Nameplate Auras");

    local function RefreshNameplateAuraStyle()
        if UberUI.nameplateauras then UberUI.nameplateauras:RefreshStyle() end
    end

    opt.AddCheckbox(page, {
        variable = "NameplateAuras", name = "Uber UI Nameplate Auras",
        tooltip = "Show nameplate buffs, debuffs and crowd control in Uber UI's own aura icons, styled with the options below, in the same places and following the same Blizzard nameplate settings as Blizzard's own icons. The loss-of-control icon on players stays Blizzard's.\n\nThe icons are built ahead of time behind the loading screen, so this may slightly increase loading screen times.",
        db = "general", field = "nameplateauras", default = false,
        onChange = function()
            if UberUI.nameplateauras then UberUI.nameplateauras:Refresh() end
        end,
    });

    opt.AddAuraOptions(page, {
        loc = "nameplate", label = "Nameplate", suffix = "Nameplate",
        buffKey = "aurastyle_nameplatebuffs", debuffKey = "aurastyle_nameplatedebuffs",
        refresh = RefreshNameplateAuraStyle,
    });

    opt.AddCheckbox(page, {
        variable = "nameplatebuffsShowDispel", name = "Nameplate Highlight Purgeable Buffs",
        tooltip = "Show a thin white border on enemy nameplate buffs your class can Purge, Dispel or Spellsteal, whichever Nameplate Border Shape is chosen (Blizzard's larger glow would run onto the health bar). Only shown if your class actually has a way to remove it.",
        db = "general", field = "nameplatebuffs_showdispel", default = true,
        onChange = RefreshNameplateAuraStyle,
    });

    opt.AddColorSwatch(page, {
        variable = "nameplateDurationColor", name = "Nameplate Duration Color",
        tooltip = "Color of the countdown number on nameplate auras.",
        db = "general", field = "nameplatedurationcolor", default = "ffffffff",
        onChange = RefreshNameplateAuraStyle,
    });

    opt.AddColorSwatch(page, {
        variable = "nameplateDurationExpiringColor", name = "Nameplate Expiring Duration Color",
        tooltip = "Color of the countdown number once an aura has less time left than the Expiring Duration Threshold below.",
        db = "general", field = "nameplatedurationexpiringcolor", default = "ffff3333",
        onChange = RefreshNameplateAuraStyle,
    });

    opt.AddSlider(page, {
        variable = "nameplateDurationThreshold", name = "Expiring Duration Threshold",
        tooltip = "Seconds left at which a nameplate aura's countdown switches to the Expiring Duration Color.",
        db = "general", field = "nameplatedurationthreshold", default = 5,
        min = 1, max = 10, step = 1,
        format = function(value) return string.format("%d s", value) end,
        onChange = RefreshNameplateAuraStyle,
    });

    local pandemicInit = opt.AddCheckbox(page, {
        variable = "nameplatePandemic", name = "Nameplate Pandemic Highlight",
        tooltip = "Highlight your nameplate debuffs while they're in their pandemic window: the last stretch where recasting adds the remaining time onto the new one instead of losing it. Only auras that work that way light up (the game decides, so it's exact even in combat).",
        db = "general", field = "nameplatepandemic", default = true,
        onChange = RefreshNameplateAuraStyle,
    });
    local function PandemicOn() return uuidb.general and uuidb.general.nameplatepandemic ~= false end

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "nameplatePandemicStyle", name = "Pandemic Highlight Style",
        tooltip = "Border: the debuff's border in the highlight color, in the Nameplate Border Shape (rounded or square).\n\nProc Glow: Blizzard's animated action button proc glow.\n\nMarching Ants: Blizzard's animated rotation-helper border.",
        default = "border",
        values = { { "border", "Border" }, { "glow", "Proc Glow" }, { "ants", "Marching Ants" } },
        get = function() return uuidb.general.nameplatepandemicstyle or "border" end,
        set = function(value) uuidb.general.nameplatepandemicstyle = value end,
        onChange = RefreshNameplateAuraStyle,
    }), pandemicInit, PandemicOn);

    opt.DependsOn(opt.AddColorSwatch(page, {
        variable = "nameplatePandemicColorHex", name = "Pandemic Highlight Color",
        tooltip = "Color of the pandemic highlight (border or glow).",
        db = "general", field = "nameplatepandemiccolor", default = "ffff3030",
        -- An early build stored preset names here; anything that isn't a
        -- hex color reads as the default.
        get = function()
            local v = uuidb.general.nameplatepandemiccolor
            return (type(v) == "string" and v:match("^%x%x%x%x%x%x%x%x$")) and v or "ffff3030"
        end,
        onChange = RefreshNameplateAuraStyle,
    }), pandemicInit, PandemicOn);

    opt.Header(page, "Friendly Raid Target Icons");

    opt.AddSlider(page, {
        variable = "FriendlyNameplateRaidTargetScale", name = "Friendly Nameplate Raid Target Scale",
        tooltip = "Scale of the raid target icon on friendly nameplates",
        db = "general", field = "nameplateraidtargetscale", default = 1,
        min = 0.5, max = 10, step = 0.1,
        format = function(value) return string.format("%.1f", value) end,
        onChange = function() UberUI.nameplates:UpdateAllNameplateRaidTargetScale() end,
    });

    opt.AddCheckbox(page, {
        variable = "AnchorFriendlyRaidIconTop", name = "Anchor Friendly Raid Icon Top",
        tooltip = "Anchor the raid icon to the top center of the nameplate",
        db = "general", field = "nameplateraidtargettopanchor", default = false,
        onChange = function() UberUI.nameplates:UpdateAllNameplateRaidTargetScale() end,
    });

    if PersonalResourceDisplayMixin then
        opt.Header(page, "Personal Resource Display");

        local function RefreshPersonalResource()
            if UberUI.personalresource then UberUI.personalresource:ForceTexture() end
        end

        opt.AddCheckbox(page, {
            variable = "darkenpersonalresourceborder", name = "Darken Personal Resource Border",
            tooltip = "Darkens the border texture of the Personal Resource Display",
            db = "general", field = "darkenpersonalresourceborder", default = true,
            onChange = RefreshPersonalResource,
        });

        opt.AddBarTextureSetting(page, {
            dbTable = uuidb.general,
            cbVariable = "PersonalResourceBarTextures", cbName = "Personal Resource Bar Textures", cbField = "personalresourcebartextures",
            cbTooltip = "Retexture Personal Resource Display Separately from All Bars texture",
            ddVariable = "PersonalResourceTexture", ddName = "Personal Resource Bar Texture", ddField = "personalresourcebartexture",
            ddTooltip = "Set your desired status bar texture for Personal Resource Display",
            cbOnChange = RefreshPersonalResource,
            ddOnChange = RefreshPersonalResource,
        });
    end
end
