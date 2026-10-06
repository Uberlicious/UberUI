--[[--------------------------------------------------------------------
	Uber UI options -- Nameplates page (+ Personal Resource Display)

	Health bar first; then Nameplate Auras (collapsible): the on/off toggle
	with everything else indented under it -- Appearance, Enemy Buffs,
	Pandemic Highlight, Aura Text. The duration colors shared with the other
	locations are on the main page.
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
        repair = true,
    });
    local function SquareBar() return uuidb.general and uuidb.general.nameplatesquareborder end

    local barThicknessInit = opt.AddSlider(page, {
        variable = "NameplateHealthBorderThickness", name = "Health Bar Border Thickness",
        tooltip = "Thickness of the square nameplate health bar border, in screen pixels.",
        db = "general", field = "nameplatesquareborder_thickness", default = 1,
        min = 1, max = 4, step = 1,
        onChange = RefreshNameplateBars,
    });
    opt.DependsOn(barThicknessInit, shapeInit, SquareBar);
    opt.ShowWhen(barThicknessInit, SquareBar);

    ---------------------------------------------------------------------------
    -- Nameplate Auras
    ---------------------------------------------------------------------------
    opt.Section(page, "Nameplate Auras", "nameplates_auras");

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
        onChange = function()
            RefreshNameplateAuras()
            -- Rows nested two levels down (under a style dropdown) re-check
            -- their greyed-out state when their own parent changes, not this.
            opt.RepairDisplay()
        end,
    });
    local function NameplateAurasOn() return uuidb.general and uuidb.general.nameplateauras == true end
    local function Under(init, isEnabled)
        opt.DependsOn(init, nameplateAurasInit, isEnabled or NameplateAurasOn);
        return init;
    end

    local function AddEnemyBuffs()
        opt.SubHeader(page, "Enemy Buffs");

        Under(opt.AddSlider(page, {
            variable = "NameplateEnemyBuffIcons", name = "Enemy Buff Icons",
            tooltip = "How many buff icons an enemy nameplate can show.\n\nThis applies to each category on its own (important, purgeable), because the game no longer lets addons count auras, so one shared total across them isn't possible. At 1 each the worst case is 2 icons, which is Blizzard's own limit.\n\nThe row never wraps, so raising this makes it wider, not taller.",
            db = "general", field = "nameplatebuffbudget", default = 1,
            min = 1, max = 4, step = 1,
            onChange = RefreshNameplateAuras,
        }));

        Under(opt.AddCheckbox(page, {
            variable = "NameplateEnemyBuffsImportant", name = "Enemy Buffs: Show Important",
            tooltip = "Show the buffs the game flags as important on enemy nameplates -- offensive cooldowns and the like. This is the same set Blizzard shows.",
            db = "general", field = "nameplatebuffsimportant", default = true,
            onChange = RefreshNameplateAuras,
        }));

        Under(opt.AddDropdown(page, {
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
        }));

        Under(opt.AddCheckbox(page, {
            variable = "nameplatebuffsShowDispel", name = "Highlight Purgeable Buffs",
            tooltip = "Show a thin white border on enemy nameplate buffs your class can Purge, Dispel or Spellsteal, whichever Border Shape is chosen (Blizzard's larger glow would run onto the health bar). Only shown if your class actually has a way to remove it.",
            db = "general", field = "nameplatebuffs_showdispel", default = true,
            onChange = RefreshNameplateAuraStyle,
        }));
    end

    local function AddPandemic()
        opt.SubHeader(page, "Pandemic Highlight");

        local pandemicStyleSetting
        local pandemicInit = Under(opt.AddCheckbox(page, {
            variable = "nameplatePandemic", name = "Pandemic Highlight",
            tooltip = "Highlight your nameplate debuffs while they're in their pandemic window: the last stretch where recasting adds the remaining time onto the new one instead of losing it. Only auras that work that way light up (the game decides, so it's exact even in combat).",
            db = "general", field = "nameplatepandemic", default = true,
            onChange = function()
                RefreshNameplateAuraStyle()
                -- Rows under the style dropdown re-check their greyed-out state
                -- when it changes, not when this checkbox does.
                if pandemicStyleSetting then pandemicStyleSetting:TriggerValueChanged(pandemicStyleSetting:GetValue()) end
            end,
        }));
        local function PandemicOn()
            return NameplateAurasOn() and uuidb.general and uuidb.general.nameplatepandemic ~= false
        end

        local pandemicStyleInit
        pandemicStyleInit, pandemicStyleSetting = opt.AddDropdown(page, {
            variable = "nameplatePandemicStyle", name = "Highlight Style",
            tooltip = "Border: the debuff's border in the highlight color, in the Border Shape (rounded or square).\n\nProc Glow: Blizzard's animated action button proc glow.\n\nMarching Ants: Blizzard's animated rotation-helper border.\n\nPixel Glow: thin dashes marching around the icon.",
            default = "border",
            values = { { "border", "Border" }, { "glow", "Proc Glow" }, { "ants", "Marching Ants" }, { "pixel", "Pixel Glow" } },
            get = function() return uuidb.general.nameplatepandemicstyle or "border" end,
            set = function(value) uuidb.general.nameplatepandemicstyle = value end,
            onChange = RefreshNameplateAuraStyle,
            repair = true,
        });
        opt.DependsOn(pandemicStyleInit, pandemicInit, PandemicOn);

        -- Pixel Glow only: under the style, hidden for the other styles.
        local function PixelGlow() return uuidb.general.nameplatepandemicstyle == "pixel" end
        local pixelInit = opt.AddDropdown(page, {
            variable = "nameplatePixelGlowPosition", name = "Pixel Glow Position",
            tooltip = "Inside draws the Pixel Glow dashes over the debuff icon's edge. Outside draws them just past it.",
            default = "inside",
            values = { { "inside", "Inside" }, { "outside", "Outside" } },
            get = function() return uuidb.general.nameplatepixelposition == "outside" and "outside" or "inside" end,
            set = function(value) uuidb.general.nameplatepixelposition = value end,
            onChange = RefreshNameplateAuraStyle,
        });
        opt.DependsOn(pixelInit, pandemicStyleInit, function() return PandemicOn() and PixelGlow() end);
        opt.ShowWhen(pixelInit, PixelGlow);

        local classInit = opt.AddCheckbox(page, {
            variable = "nameplatePandemicClassColor", name = "Use Class Color",
            tooltip = "Color the pandemic highlight (Border, Proc Glow and Marching Ants) in your character's class color instead of the color below.",
            db = "general", field = "nameplatepandemicclasscolor", default = false,
            onChange = RefreshNameplateAuraStyle,
        });
        opt.DependsOn(classInit, pandemicInit, PandemicOn);

        opt.DependsOn(opt.AddColorSwatch(page, {
            variable = "nameplatePandemicColorHex", name = "Highlight Color",
            tooltip = "Color of the pandemic highlight (border or glow), unless Use Class Color is on.",
            db = "general", field = "nameplatepandemiccolor", default = "ffff3030",
            -- An early build stored preset names here; anything that isn't a
            -- hex color reads as the default.
            get = function()
                local v = uuidb.general.nameplatepandemiccolor
                return (type(v) == "string" and v:match("^%x%x%x%x%x%x%x%x$")) and v or "ffff3030"
            end,
            onChange = RefreshNameplateAuraStyle,
        }), classInit, function()
            return PandemicOn() and not (uuidb.general and uuidb.general.nameplatepandemicclasscolor)
        end);

        opt.AddNameplatePandemicPreview(page, {
            loc = "nameplate", label = "Nameplate",
            buffKey = "aurastyle_nameplatebuffs", debuffKey = "aurastyle_nameplatedebuffs",
        });
    end

    -- Everything below only applies to Uber UI's nameplate auras, so it's
    -- indented under the toggle.
    opt.AddAuraOptions(page, {
        loc = "nameplate", label = "Nameplate", suffix = "Nameplate",
        buffKey = "aurastyle_nameplatebuffs", debuffKey = "aurastyle_nameplatedebuffs",
        refresh = RefreshNameplateAuraStyle,
        styleHeader = "Appearance", textHeader = "Aura Text",
        parent = nameplateAurasInit, parentOn = NameplateAurasOn,
        afterStyle = function()
            AddEnemyBuffs()
            AddPandemic()
        end,
    });

    ---------------------------------------------------------------------------
    -- Friendly Name Health
    ---------------------------------------------------------------------------
    opt.Section(page, "Friendly Name Health", "nameplates_namehealth");
    local function RefreshNameHealth()
        if UberUI.namehealth then UberUI.namehealth:Refresh() end
    end
    local function NameHealthStyle()
        local v = uuidb.general and uuidb.general.namehealthstyle
        return (v == "underline" or v == "dot" or v == "name") and v or "off"
    end
    local function IsUnderline() return NameHealthStyle() == "underline" end
    local function IsDot() return NameHealthStyle() == "dot" end
    local function IsMarker() return IsUnderline() or IsDot() end

    local nameHealthInit = opt.AddDropdown(page, {
        variable = "NameHealthStyle", name = "Style",
        tooltip = "Show friendly players' health on name-only nameplates, colored from red (low) through orange and yellow to green (full).\n\nUnderline: a thin health bar under (or above) the name.\n\nDot: a small dot beside the name.\n\nName Color: tints the name itself; at full health it's the class color.\n\nOnly works outside instances -- Blizzard locks friendly nameplates in dungeons and raids.",
        default = "off",
        values = { { "off", "Off" }, { "underline", "Underline" }, { "dot", "Dot" }, { "name", "Name Color" } },
        get = NameHealthStyle,
        set = function(value) uuidb.general.namehealthstyle = value end,
        onChange = RefreshNameHealth,
        repair = true,
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

    -- Only the chosen style's rows show, indented under Style.
    local function ForStyle(init, isShown)
        opt.DependsOn(init, nameHealthInit, isShown);
        opt.ShowWhen(init, isShown);
    end

    ForStyle(opt.AddCheckbox(page, {
        variable = "NameHealthHideFull", name = "Hide at Full Health",
        tooltip = "Hide the underline or dot while the player is at full health.",
        db = "general", field = "namehealthhidefull", default = true,
        onChange = RefreshNameHealth,
    }), IsMarker);

    local borderInit = opt.AddCheckbox(page, {
        variable = "NameHealthBorder", name = "Border",
        tooltip = "Draw a black border around the underline or dot, so it stands out against bright ground. The underline's border spans its full width, so missing health shows as black.",
        db = "general", field = "namehealthborder", default = false,
        onChange = RefreshNameHealth,
        repair = true,
    });
    ForStyle(borderInit, IsMarker);
    local function BorderOn()
        return IsMarker() and uuidb.general and uuidb.general.namehealthborder == true
    end
    local borderThicknessInit = opt.AddSlider(page, {
        variable = "NameHealthBorderThickness", name = "Border Thickness",
        tooltip = "Thickness of the border around the underline or dot, in screen pixels.",
        db = "general", field = "namehealthborderthickness", default = 1,
        min = 1, max = 3, step = 1,
        onChange = RefreshNameHealth,
    });
    opt.DependsOn(borderThicknessInit, borderInit, BorderOn);
    opt.ShowWhen(borderThicknessInit, BorderOn);

    ForStyle(opt.AddSlider(page, {
        variable = "NameHealthUnderlineThickness", name = "Underline Thickness",
        tooltip = "Thickness of the health underline, in screen pixels.",
        db = "general", field = "namehealthunderlinethickness", default = 1,
        min = 1, max = 6, step = 1,
        onChange = RefreshNameHealth,
    }), IsUnderline);

    ForStyle(opt.AddDropdown(page, {
        variable = "NameHealthUnderlineSide", name = "Underline Position",
        tooltip = "Whether the health bar sits under or above the name.",
        default = "BELOW",
        values = { { "BELOW", "Under Name" }, { "ABOVE", "Above Name" } },
        get = function() return uuidb.general and uuidb.general.namehealthunderlineside == "ABOVE" and "ABOVE" or "BELOW" end,
        set = function(value) uuidb.general.namehealthunderlineside = value end,
        onChange = RefreshNameHealth,
    }), IsUnderline);

    ForStyle(opt.AddSlider(page, {
        variable = "NameHealthUnderlineOffset", name = "Underline Offset",
        tooltip = "Extra space between the name and the health bar, in screen pixels. Negative values tuck the bar into the name's outline.",
        db = "general", field = "namehealthunderlineoffset", default = 0,
        min = -2, max = 8, step = 1,
        onChange = RefreshNameHealth,
    }), IsUnderline);

    ForStyle(opt.AddSlider(page, {
        variable = "NameHealthDotSize", name = "Dot Size",
        tooltip = "Size of the health dot, in screen pixels.",
        db = "general", field = "namehealthdotsize", default = 8,
        min = 2, max = 16, step = 1,
        onChange = RefreshNameHealth,
    }), IsDot);

    ForStyle(opt.AddDropdown(page, {
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
    }), IsDot);

    ForStyle(opt.AddSlider(page, {
        variable = "NameHealthDotOffset", name = "Dot Offset",
        tooltip = "Extra space between the name and the health dot, in screen pixels. Negative values pull the dot in toward the name.",
        db = "general", field = "namehealthdotoffset", default = 0,
        min = -3, max = 8, step = 1,
        onChange = RefreshNameHealth,
    }), IsDot);

    ---------------------------------------------------------------------------
    -- Friendly Raid Target Icons
    ---------------------------------------------------------------------------
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
            tooltip = "Darkens the bar borders of the Personal Resource Display (Blizzard's art, or the square border in Square shape) and its class resource backgrounds (combo points, holy power, soul shards, chi)",
            db = "general", field = "darkenpersonalresourceborder", default = true,
            onChange = RefreshPersonalResource,
        });

        local prdKeys = UberUI.squareborders.Keys("prd");
        local function PRDSquare() return uuidb.general and uuidb.general[prdKeys[1]] end

        local prdShapeInit = opt.AddDropdown(page, {
            variable = "PersonalResourceBarShape", name = "Bar Shape",
            tooltip = "Rounded is Blizzard's look. Square gives the health, power and extra bars flat fills with a square border of exact pixel thickness in the darkness color. With Edit Mode's bar padding at 0 the bars touch and share one border line between them.\n\nSquare bars need a flat texture: Blizzard's bar is rounded, so Square uses \"Blizzard_Flat\" unless you pick another bar texture.",
            default = "rounded",
            values = { { "rounded", "Rounded" }, { "square", "Square" } },
            get = function() return PRDSquare() and "square" or "rounded" end,
            set = function(value) uuidb.general[prdKeys[1]] = (value == "square") end,
            onChange = RefreshPersonalResource,
            repair = true,
        });

        local prdThicknessInit = opt.AddSlider(page, {
            variable = "PersonalResourceBorderThickness", name = "Border Thickness",
            tooltip = "Thickness of the square Personal Resource Display border, in screen pixels.",
            db = "general", field = prdKeys[2], default = 1,
            min = 1, max = 4, step = 1,
            onChange = RefreshPersonalResource,
        });
        opt.DependsOn(prdThicknessInit, prdShapeInit, PRDSquare);
        opt.ShowWhen(prdThicknessInit, PRDSquare);

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
