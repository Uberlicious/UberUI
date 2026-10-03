--[[--------------------------------------------------------------------
	Uber UI options -- Nameplates page (+ Personal Resource Display)
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

function opt.BuildNameplates(page)
    opt.Header(page, "Nameplates");

    opt.AddNameplateBarPreview(page);

    opt.AddCheckbox(page, {
        variable = "HideNPSelctionGlow", name = "Hide Selection Glow",
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
        cbVariable = "NameplateBarTextures", cbName = "Bar Textures", cbField = "nameplatebartextures",
        cbTooltip = "Retexture Nameplate Frames Separately from All Bars texture",
        ddVariable = "NameplateTexture", ddName = "Bar Texture", ddField = "nameplatebartexture",
        ddTooltip = "Set your desired status bar texture for Nameplate frames",
        cbOnChange = function() UberUI.nameplates:ForceNameplateTexture() end,
        ddOnChange = function(value) UberUI.nameplates:ForceNameplateTexture(value) end,
    });

    local function RefreshNameplateBars()
        if UberUI.nameplates then UberUI.nameplates:ForceNameplateTexture() end
    end

    local shapeInit = opt.AddDropdown(page, {
        variable = "NameplateHealthBorderShape", name = "Health Bar Border",
        tooltip = "Rounded is Blizzard's nameplate border. Square draws a flat border of exact pixel thickness around the health bar, in the darkness color, with a square bar.",
        default = "rounded",
        values = { { "rounded", "Rounded" }, { "square", "Square" } },
        get = function() return (uuidb.general and uuidb.general.nameplatesquareborder) and "square" or "rounded" end,
        set = function(value) uuidb.general.nameplatesquareborder = (value == "square") end,
        onChange = RefreshNameplateBars,
    });

    opt.DependsOn(opt.AddSlider(page, {
        variable = "NameplateHealthBorderThickness", name = "Health Bar Border Thickness",
        tooltip = "Thickness of the square nameplate health bar border, in screen pixels.",
        db = "general", field = "nameplatesquareborder_thickness", default = 1,
        min = 1, max = 4, step = 1,
        onChange = RefreshNameplateBars,
    }), shapeInit, function() return uuidb.general and uuidb.general.nameplatesquareborder end);

    opt.Header(page, "Nameplate Auras");

    local function RefreshNameplateAuraStyle()
        if UberUI.nameplateauras then UberUI.nameplateauras:RefreshStyle() end
    end

    local function RefreshNameplateAuras()
        if UberUI.nameplateauras then UberUI.nameplateauras:Refresh() end
    end

    local nameplateAurasInit = opt.AddCheckbox(page, {
        variable = "NameplateAuras", name = "Uber UI Nameplate Auras",
        tooltip = "Show nameplate buffs, debuffs and crowd control in Uber UI's own aura icons, styled with the options below, in the same places and following the same Blizzard nameplate settings as Blizzard's own icons. The loss-of-control icon on players stays Blizzard's.\n\nThe icons are built ahead of time behind the loading screen, so this may slightly increase loading screen times.",
        db = "general", field = "nameplateauras", default = false,
        onChange = RefreshNameplateAuras,
    });
    local function NameplateAurasOn() return uuidb.general and uuidb.general.nameplateauras == true end

    opt.AddAuraOptions(page, {
        loc = "nameplate", label = "Nameplate", suffix = "Nameplate",
        buffKey = "aurastyle_nameplatebuffs", debuffKey = "aurastyle_nameplatedebuffs",
        refresh = RefreshNameplateAuraStyle,
        -- The text options only apply to Uber UI's nameplate auras.
        textParent = nameplateAurasInit, textParentOn = NameplateAurasOn,
    });

    opt.DependsOn(opt.AddSlider(page, {
        variable = "NameplateEnemyBuffIcons", name = "Enemy Buff Icons",
        tooltip = "How many buff icons an enemy nameplate can show.\n\nThis applies to each category on its own (important, purgeable), because the game no longer lets addons count auras, so one shared total across them isn't possible. At 1 each the worst case is 2 icons, which is Blizzard's own limit.\n\nThe row never wraps, so raising this makes it wider, not taller.",
        db = "general", field = "nameplatebuffbudget", default = 1,
        min = 1, max = 4, step = 1,
        onChange = RefreshNameplateAuras,
    }), nameplateAurasInit, NameplateAurasOn);

    opt.DependsOn(opt.AddCheckbox(page, {
        variable = "NameplateEnemyBuffsImportant", name = "Enemy Buffs: Show Important",
        tooltip = "Show the buffs the game flags as important on enemy nameplates -- offensive cooldowns and the like. This is the same set Blizzard shows.",
        db = "general", field = "nameplatebuffsimportant", default = true,
        onChange = RefreshNameplateAuras,
    }), nameplateAurasInit, NameplateAurasOn);

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "NameplateEnemyBuffsPurgeable", name = "Enemy Buffs: Show Purgeable",
        tooltip = "Which purgeable buffs to show on enemy nameplates.\n\nMy Group Can Purge: only auras someone in your party or raid can actually remove -- just you when you're on your own.\n\nAny Purgeable: everything the game flags as dispellable, whether or not anyone present can remove it. This is Blizzard's own rule.",
        default = "group",
        values = { { "group", "My Group Can Purge" }, { "any", "Any Purgeable" }, { "off", "Off" } },
        get = function()
            local v = uuidb.general and uuidb.general.nameplatebuffspurgeable
            return (v == "any" or v == "off") and v or "group"
        end,
        set = function(value) uuidb.general.nameplatebuffspurgeable = value end,
        onChange = RefreshNameplateAuras,
    }), nameplateAurasInit, NameplateAurasOn);

    opt.AddCheckbox(page, {
        variable = "nameplatebuffsShowDispel", name = "Highlight Purgeable Buffs",
        tooltip = "Show a thin white border on enemy nameplate buffs your class can Purge, Dispel or Spellsteal, whichever Border Shape is chosen (Blizzard's larger glow would run onto the health bar). Only shown if your class actually has a way to remove it.",
        db = "general", field = "nameplatebuffs_showdispel", default = true,
        onChange = RefreshNameplateAuraStyle,
    });

    opt.AddColorSwatch(page, {
        variable = "nameplateDurationColor", name = "Duration Color",
        tooltip = "Color of the countdown number on nameplate auras.\n\nUsed on nameplate, target, focus and raid frame auras where White Outlined Text is off.",
        db = "general", field = "nameplatedurationcolor", default = "ffffffff",
        onChange = RefreshNameplateAuraStyle,
    });

    opt.AddColorSwatch(page, {
        variable = "nameplateDurationExpiringColor", name = "Expiring Duration Color",
        tooltip = "Color of the countdown number once an aura has less time left than the Expiring Duration Threshold below.\n\nUsed on nameplate, target, focus and raid frame auras where White Outlined Text is off.",
        db = "general", field = "nameplatedurationexpiringcolor", default = "ffff3333",
        onChange = RefreshNameplateAuraStyle,
    });

    opt.AddSlider(page, {
        variable = "nameplateDurationThreshold", name = "Expiring Duration Threshold",
        tooltip = "Seconds left at which a nameplate aura's countdown switches to the Expiring Duration Color.\n\nUsed on nameplate, target, focus and raid frame auras where White Outlined Text is off.",
        db = "general", field = "nameplatedurationthreshold", default = 5,
        min = 1, max = 10, step = 1,
        format = function(value) return string.format("%d s", value) end,
        onChange = RefreshNameplateAuraStyle,
    });

    local pandemicStyleSetting
    local pandemicInit = opt.AddCheckbox(page, {
        variable = "nameplatePandemic", name = "Pandemic Highlight",
        tooltip = "Highlight your nameplate debuffs while they're in their pandemic window: the last stretch where recasting adds the remaining time onto the new one instead of losing it. Only auras that work that way light up (the game decides, so it's exact even in combat).",
        db = "general", field = "nameplatepandemic", default = true,
        onChange = function()
            RefreshNameplateAuraStyle()
            -- Rows under the style dropdown re-check their greyed-out state
            -- when it changes, not when this checkbox does.
            if pandemicStyleSetting then pandemicStyleSetting:TriggerValueChanged(pandemicStyleSetting:GetValue()) end
        end,
    });
    local function PandemicOn() return uuidb.general and uuidb.general.nameplatepandemic ~= false end

    local pandemicStyleInit
    pandemicStyleInit, pandemicStyleSetting = opt.AddDropdown(page, {
        variable = "nameplatePandemicStyle", name = "Pandemic Highlight Style",
        tooltip = "Border: the debuff's border in the highlight color, in the Border Shape (rounded or square).\n\nProc Glow: Blizzard's animated action button proc glow.\n\nMarching Ants: Blizzard's animated rotation-helper border.\n\nPixel Glow: thin dashes marching around the icon.",
        default = "border",
        values = { { "border", "Border" }, { "glow", "Proc Glow" }, { "ants", "Marching Ants" }, { "pixel", "Pixel Glow" } },
        get = function() return uuidb.general.nameplatepandemicstyle or "border" end,
        set = function(value) uuidb.general.nameplatepandemicstyle = value end,
        onChange = RefreshNameplateAuraStyle,
    });
    opt.DependsOn(pandemicStyleInit, pandemicInit, PandemicOn);

    -- Under the style dropdown, so picking Pixel Glow enables it.
    opt.DependsOn(opt.AddDropdown(page, {
        variable = "nameplatePixelGlowPosition", name = "Pixel Glow Position",
        tooltip = "Inside draws the Pixel Glow dashes over the debuff icon's edge. Outside draws them just past it.",
        default = "inside",
        values = { { "inside", "Inside" }, { "outside", "Outside" } },
        get = function() return uuidb.general.nameplatepixelposition == "outside" and "outside" or "inside" end,
        set = function(value) uuidb.general.nameplatepixelposition = value end,
        onChange = RefreshNameplateAuraStyle,
    }), pandemicStyleInit, function() return PandemicOn() and uuidb.general.nameplatepandemicstyle == "pixel" end);

    local nameplatePandemicClassInit = opt.AddCheckbox(page, {
        variable = "nameplatePandemicClassColor", name = "Pandemic: Use Class Color",
        tooltip = "Color the pandemic highlight (Border, Proc Glow and Marching Ants) in your character's class color instead of the color below.",
        db = "general", field = "nameplatepandemicclasscolor", default = false,
        onChange = RefreshNameplateAuraStyle,
    });
    opt.DependsOn(nameplatePandemicClassInit, pandemicInit, PandemicOn);

    opt.DependsOn(opt.AddColorSwatch(page, {
        variable = "nameplatePandemicColorHex", name = "Pandemic Highlight Color",
        tooltip = "Color of the pandemic highlight (border or glow), unless Use Class Color is on.",
        db = "general", field = "nameplatepandemiccolor", default = "ffff3030",
        -- An early build stored preset names here; anything that isn't a
        -- hex color reads as the default.
        get = function()
            local v = uuidb.general.nameplatepandemiccolor
            return (type(v) == "string" and v:match("^%x%x%x%x%x%x%x%x$")) and v or "ffff3030"
        end,
        onChange = RefreshNameplateAuraStyle,
    }), nameplatePandemicClassInit, function()
        return PandemicOn() and not (uuidb.general and uuidb.general.nameplatepandemicclasscolor)
    end);

    opt.AddNameplatePandemicPreview(page, {
        loc = "nameplate", label = "Nameplate",
        buffKey = "aurastyle_nameplatebuffs", debuffKey = "aurastyle_nameplatedebuffs",
    });

    opt.Header(page, "Friendly Name Health");

    local function RefreshNameHealth()
        if UberUI.namehealth then UberUI.namehealth:Refresh() end
    end
    local function NameHealthStyle()
        local v = uuidb.general and uuidb.general.namehealthstyle
        return (v == "underline" or v == "dot" or v == "name") and v or "off"
    end

    local nameHealthInit = opt.AddDropdown(page, {
        variable = "NameHealthStyle", name = "Style",
        tooltip = "Show friendly players' health on name-only nameplates, colored from red (low) through orange and yellow to green (full).\n\nUnderline: a thin health bar under (or above) the name.\n\nDot: a small dot beside the name.\n\nName Color: tints the name itself; at full health it's the class color.\n\nOnly works outside instances -- Blizzard locks friendly nameplates in dungeons and raids.",
        default = "off",
        values = { { "off", "Off" }, { "underline", "Underline" }, { "dot", "Dot" }, { "name", "Name Color" } },
        get = NameHealthStyle,
        set = function(value) uuidb.general.namehealthstyle = value end,
        onChange = RefreshNameHealth,
    });

    opt.AddPreview(page, {
        name = "Preview",
        tooltip = "Sample names at full, half and low health, drawn with the settings in this section.",
        height = 88,
        create = function(parent)
            local nh = UberUI.namehealth
            if not nh then return nil end
            nh.preview = nh.preview or nh.CreatePreview(parent)
            return nh.preview
        end,
    });

    opt.DependsOn(opt.AddCheckbox(page, {
        variable = "NameHealthHideFull", name = "Hide at Full Health",
        tooltip = "Hide the underline or dot while the player is at full health.",
        db = "general", field = "namehealthhidefull", default = true,
        onChange = RefreshNameHealth,
    }), nameHealthInit, function() local s = NameHealthStyle() return s == "underline" or s == "dot" end);

    opt.DependsOn(opt.AddSlider(page, {
        variable = "NameHealthUnderlineThickness", name = "Underline Thickness",
        tooltip = "Thickness of the health underline, in screen pixels.",
        db = "general", field = "namehealthunderlinethickness", default = 1,
        min = 1, max = 6, step = 1,
        onChange = RefreshNameHealth,
    }), nameHealthInit, function() return NameHealthStyle() == "underline" end);

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "NameHealthUnderlineSide", name = "Underline Position",
        tooltip = "Whether the health bar sits under or above the name.",
        default = "BELOW",
        values = { { "BELOW", "Under Name" }, { "ABOVE", "Above Name" } },
        get = function() return uuidb.general and uuidb.general.namehealthunderlineside == "ABOVE" and "ABOVE" or "BELOW" end,
        set = function(value) uuidb.general.namehealthunderlineside = value end,
        onChange = RefreshNameHealth,
    }), nameHealthInit, function() return NameHealthStyle() == "underline" end);

    opt.DependsOn(opt.AddSlider(page, {
        variable = "NameHealthUnderlineOffset", name = "Underline Offset",
        tooltip = "Extra space between the name and the health bar, in screen pixels. Negative values tuck the bar into the name's outline.",
        db = "general", field = "namehealthunderlineoffset", default = 0,
        min = -2, max = 8, step = 1,
        onChange = RefreshNameHealth,
    }), nameHealthInit, function() return NameHealthStyle() == "underline" end);

    opt.DependsOn(opt.AddSlider(page, {
        variable = "NameHealthDotSize", name = "Dot Size",
        tooltip = "Size of the health dot, in screen pixels.",
        db = "general", field = "namehealthdotsize", default = 8,
        min = 2, max = 16, step = 1,
        onChange = RefreshNameHealth,
    }), nameHealthInit, function() return NameHealthStyle() == "dot" end);

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "NameHealthDotSide", name = "Dot Position",
        tooltip = "Which side of the name the health dot sits on. Above and Below center it over or under the name.",
        default = "LEFT",
        values = { { "LEFT", "Left" }, { "RIGHT", "Right" }, { "TOP", "Above" }, { "BOTTOM", "Below" } },
        get = function()
            local v = uuidb.general and uuidb.general.namehealthdotside
            return (v == "RIGHT" or v == "TOP" or v == "BOTTOM") and v or "LEFT"
        end,
        set = function(value) uuidb.general.namehealthdotside = value end,
        onChange = RefreshNameHealth,
    }), nameHealthInit, function() return NameHealthStyle() == "dot" end);

    opt.DependsOn(opt.AddSlider(page, {
        variable = "NameHealthDotOffset", name = "Dot Offset",
        tooltip = "Extra space between the name and the health dot, in screen pixels. Negative values pull the dot in toward the name.",
        db = "general", field = "namehealthdotoffset", default = 0,
        min = -3, max = 8, step = 1,
        onChange = RefreshNameHealth,
    }), nameHealthInit, function() return NameHealthStyle() == "dot" end);

    opt.Header(page, "Friendly Raid Target Icons");

    opt.AddSlider(page, {
        variable = "FriendlyNameplateRaidTargetScale", name = "Scale",
        tooltip = "Scale of the raid target icon on friendly nameplates",
        db = "general", field = "nameplateraidtargetscale", default = 1,
        min = 0.5, max = 10, step = 0.1,
        format = function(value) return string.format("%.1f", value) end,
        onChange = function() UberUI.nameplates:UpdateAllNameplateRaidTargetScale() end,
    });

    opt.AddCheckbox(page, {
        variable = "AnchorFriendlyRaidIconTop", name = "Anchor to Top",
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
            variable = "darkenpersonalresourceborder", name = "Darken Border",
            tooltip = "Darkens the border texture of the Personal Resource Display",
            db = "general", field = "darkenpersonalresourceborder", default = true,
            onChange = RefreshPersonalResource,
        });

        opt.AddBarTextureSetting(page, {
            dbTable = uuidb.general,
            cbVariable = "PersonalResourceBarTextures", cbName = "Bar Textures", cbField = "personalresourcebartextures",
            cbTooltip = "Retexture Personal Resource Display Separately from All Bars texture",
            ddVariable = "PersonalResourceTexture", ddName = "Bar Texture", ddField = "personalresourcebartexture",
            ddTooltip = "Set your desired status bar texture for Personal Resource Display",
            cbOnChange = RefreshPersonalResource,
            ddOnChange = RefreshPersonalResource,
        });
    end
end
