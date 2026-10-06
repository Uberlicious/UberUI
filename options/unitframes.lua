--[[--------------------------------------------------------------------
	Uber UI options -- Unit Frames page: Player, Target, Focus, Boss, Party

	Settings shared by every frame first, then one collapsible section per
	frame, each in the same order: Frame (colors, bar texture, frame
	layout), Auras (look), Aura Text (duration and stack count).
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

local function AddFrameClassColor(page, frameKey, o)
    return opt.AddCheckbox(page, {
        variable = o.variable, name = o.name, tooltip = o.tooltip,
        db = frameKey, field = o.field, default = true,
        onChange = o.onChange,
    });
end

local function ToTDropdown(page, variable, label, frameKey, module)
    opt.AddDropdown(page, {
        variable = variable, name = "Target of Target",
        tooltip = "Where the target-of-target frame goes relative to the " .. label .. " aura rows.\n\nNarrow Auras: Blizzard's behavior -- while the target-of-target frame is showing, the aura rows get narrower so they don't run under it.\n\nMove ToT Aside: shifts the target-of-target frame to the right so the aura rows keep their full width.\n\nThe target-of-target frame can only be moved out of combat; a change made in combat applies when combat ends.",
        default = "narrow",
        values = { { "narrow", "Narrow Auras" }, { "aside", "Move ToT Aside" } },
        get = function() return (uuidb[frameKey] and uuidb[frameKey].totplacement) or "narrow" end,
        set = function(value) uuidb[frameKey].totplacement = value end,
        onChange = function() if UberUI[module] then UberUI[module]:ApplyToTPlacement() end end,
    });
end

local function CastBarIconBorder(page, variable, label, field, module)
    opt.AddCheckbox(page, {
        variable = variable, name = "Cast Bar Icon Border",
        tooltip = "Give the spell icon on the " .. label .. " cast bar a border, in the " .. label .. " aura border style (Border Shape, Thickness and Position under Auras) and the darkness color, with the icon zoomed like aura icons.",
        db = "general", field = field, default = true,
        onChange = function() if UberUI[module] then UberUI[module]:StyleCastBarIcon() end end,
    });
end

local function PurgeableBuffs(page, variable, label, field, onChange)
    opt.AddCheckbox(page, {
        variable = variable, name = "Highlight Purgeable Buffs",
        tooltip = opt.DispelTooltip(label),
        db = "general", field = field, default = true,
        onChange = onChange,
    });
end

local function DurationToggle(label, variable, field, onChange)
    return {
        variable = variable, field = field, onChange = onChange,
        tooltip = "Show the time left on " .. label .. " auras as a number in the middle of the icon, sized to the icon. The settings under it set how it looks. With White Outlined Text off it uses the duration colors on the Nameplates page.",
    };
end

function opt.BuildUnitFrames(page)
    opt.Header(page, "All Unit Frames");

    opt.AddCheckbox(page, {
        variable = "HideHonor", name = "Hide PvP Badge",
        tooltip = "Hide the entire PvP badge (icon, background, and Prestige art) on the Player, Target, Focus, and Party frames",
        db = "general", field = "hidehonor", default = false,
        onChange = function() UberUI.general:RefreshHideHonor() end,
    });

    opt.AddCheckbox(page, {
        variable = "HideRepColor", name = "Hide Reputation Color",
        tooltip = "Hide colored bar at the top of the Target, Focus, and Boss frames",
        db = "general", field = "hiderepcolor", default = false,
        onChange = function()
            UberUI.targetframes:Color();
            UberUI.focusframes:Color();
            if UberUI.bossframes then UberUI.bossframes:Color() end
        end,
    });

    -- Blizzard's own CVar noBuffDebuffFilterOnTarget (default off), not an
    -- Uber UI setting. One CVar governs Target, Focus, and Boss (all three
    -- share Blizzard's TargetFrameTemplate aura container), so it's a single
    -- checkbox here. Our own containers follow the same rule
    -- (aurakit.ApplyOtherDebuffFilter), so it applies either way.
    opt.AddCheckbox(page, {
        variable = "showAllTargetFocusDebuffs", name = "Show All Debuffs on Target/Focus/Boss",
        tooltip = "Blizzard's own setting (noBuffDebuffFilterOnTarget), shared by the Target, Focus, and Boss frames. Off (the default): on enemy and neutral NPCs, other players' and pets' debuffs are hidden, except ones Blizzard flags to always show; yours and the NPC's own debuffs still show, and players, pets and friendly units show every debuff. On: every debuff shows everywhere.\n\nA change may not show up until the next time the frame's auras update (e.g. re-targeting).",
        default = false,
        regKey = "showAllTargetFocusDebuffs", regTable = {},
        get = function() return CVarCallbackRegistry:GetCVarValueBool("noBuffDebuffFilterOnTarget") end,
        set = function(value) C_CVar.SetCVar("noBuffDebuffFilterOnTarget", value and "1" or "0") end,
        onChange = function()
            if UberUI.targetframes then UberUI.targetframes:UpdateAuras() end
            if UberUI.focusframes and UberUI.focusframes.UpdateAuras then UberUI.focusframes:UpdateAuras() end
            if UberUI.bossframes and UberUI.bossframes.UpdateAllAuras then UberUI.bossframes:UpdateAllAuras() end
        end,
    });

    ---------------------------------------------------------------------------
    -- Player
    ---------------------------------------------------------------------------
    opt.Section(page, "Player", "unitframes_player");

    opt.SubHeader(page, "Frame");
    AddFrameClassColor(page, "playerframes", {
        variable = "ccPlayerHealth", name = "Class Color", field = "classcolor",
        tooltip = "Class color player health bar",
        onChange = function() UberUI.playerframes:HealthBarColor() end,
    });
    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "PlayerBarTextures", cbName = "Bar Textures", cbField = "playerbartextures",
        cbTooltip = "Retexture Player Frame Separately from All Bars texture",
        ddVariable = "PlayerTexture", ddName = "Bar Texture", ddField = "playerbartexture",
        ddTooltip = "Set your desired status bar texture for Player frame" .. opt.RELOAD_NOTE,
        cbOnChange = function() UberUI.playerframes:HealthManaBarTexture(true) end,
        ddOnChange = function() UberUI.playerframes:HealthManaBarTexture(true) end,
    });
    if UberUI.util.IsForeverClient() then
        opt.AddCheckbox(page, {
            variable = "gamepadCastBarIconBorder", name = "Gamepad Cast Bar Icon Border",
            tooltip = "Give the spell icon on the gamepad UI's cast bar a border, in the Player aura border style (Border Shape, Thickness and Position under Auras) and the darkness color, with the icon zoomed like aura icons.",
            db = "general", field = "gamepadcastbariconborder", default = true,
            onChange = function() UberUI.playerframes:StyleGamepadCastBarIcon() end,
        });
    end

    opt.AddAuraOptions(page, {
        loc = "player", label = "Player", suffix = "Player", squareVarSuffix = "",
        buffKey = "aurastyle_playerbuffs", debuffKey = "aurastyle_playerdebuffs",
        refresh = opt.RefreshPlayerAuras,
        styleHeader = "Auras", textHeader = "Aura Text",
        buffTooltip = "Border on Player buffs and weapon enchants. \"None\" is Blizzard's look: no border on buffs, Blizzard's purple border on weapon enchants.\n\nWith Zoom off and the Blizzard border choice, Uber UI leaves these auras entirely to Blizzard.",
        positionDetail = " The duration text moves out to make room.",
        shapeTooltip = "Rounded uses Blizzard's border art. Square draws a flat border of exact pixel thickness in the same colors.\n\nWith Square, Uber UI shows your debuffs itself, following your Edit Mode Debuff Frame layout, so their dispel colors stay correct in combat. Buffs and weapon enchants stay on Blizzard's frame.\n\nHas no effect on auras Uber UI has handed back to Blizzard (Zoom off + Blizzard border).",
        afterStyle = function()
            opt.AddCheckbox(page, {
                variable = "playerTempEnchantColor", name = "Weapon Enchant Border Color",
                tooltip = "Give weapon enchants (sharpening stones, oils, poisons, imbues) Blizzard's purple enchant border, whatever the Player Buff Border choice. With Square borders it's drawn as a purple square border. Off: weapon enchants get the same border as your other buffs, and no purple border at all when Buff Border is None.",
                db = "general", field = "playertempenchantcolor", default = true,
                onChange = opt.RefreshPlayerAuras,
            });
        end,
    });

    ---------------------------------------------------------------------------
    -- Target
    ---------------------------------------------------------------------------
    opt.Section(page, "Target", "unitframes_target");

    local function RefreshTargetAuras()
        opt.RefreshPlayerAuras();
        if UberUI.targetframes then
            UberUI.targetframes:UpdateAuras();
        end
    end

    opt.SubHeader(page, "Frame");
    AddFrameClassColor(page, "targetframes", {
        variable = "ccEnemyTarget", name = "Class Color Enemy", field = "classcolorenemy",
        tooltip = "Class color target and target of target health bar of enemy players",
        onChange = function() UberUI.targetframes:HealthBarColor() end,
    });
    AddFrameClassColor(page, "targetframes", {
        variable = "ccFriendlyTarget", name = "Class Color Friendly", field = "classcolorfriendly",
        tooltip = "Class color target and target of target health bar of friendly players",
        onChange = function() UberUI.targetframes:HealthBarColor() end,
    });
    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "TargetBarTextures", cbName = "Bar Textures", cbField = "targetbartextures",
        cbTooltip = "Retexture Target Frame Separately from All Bars texture",
        ddVariable = "TargetTexture", ddName = "Bar Texture", ddField = "targetbartexture",
        ddTooltip = "Set your desired status bar texture for Target frame",
        cbOnChange = function() UberUI.targetframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.targetframes:HealthManaBarTexture() end,
    });
    ToTDropdown(page, "TargetToTPlacement", "Target", "targetframes", "targetframes");
    CastBarIconBorder(page, "targetCastBarIconBorder", "Target", "targetcastbariconborder", "targetframes");

    opt.AddAuraOptions(page, {
        loc = "target", label = "Target", suffix = "Target",
        buffKey = "aurastyle_targetbuffs", debuffKey = "aurastyle_targetdebuffs",
        refresh = RefreshTargetAuras,
        styleHeader = "Auras", textHeader = "Aura Text",
        afterStyle = function()
            PurgeableBuffs(page, "targetbuffsShowDispel", "Target", "targetbuffs_showdispel", function()
                if UberUI.targetframes then UberUI.targetframes:UpdateAuras() end
            end);
        end,
        durationToggle = DurationToggle("Target", "targetAuraDuration", "targetauraduration", RefreshTargetAuras),
    });

    ---------------------------------------------------------------------------
    -- Focus
    ---------------------------------------------------------------------------
    opt.Section(page, "Focus", "unitframes_focus");

    local function RefreshFocusAuras()
        if UberUI.focusframes and UberUI.focusframes.UpdateAuras then
            UberUI.focusframes:UpdateAuras();
        end
    end
    local function RefreshFocusAuraStyle()
        opt.RefreshPlayerAuras();
        RefreshFocusAuras();
    end

    opt.SubHeader(page, "Frame");
    if FocusFrame then
        AddFrameClassColor(page, "focusframes", {
            variable = "ccEnemyFocus", name = "Class Color Enemy", field = "classcolorenemy",
            tooltip = "Class color focus and focus target health bar of enemy players",
            onChange = function() UberUI.focusframes:HealthBarColor() end,
        });
        AddFrameClassColor(page, "focusframes", {
            variable = "ccFriendlyFocus", name = "Class Color Friendly", field = "classcolorfriendly",
            tooltip = "Class color focus and focus target health bar of friendly players",
            onChange = function() UberUI.focusframes:HealthBarColor() end,
        });
    end
    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "FocusBarTextures", cbName = "Bar Textures", cbField = "focusbartextures",
        cbTooltip = "Retexture Focus Frame Separately from All Bars texture",
        ddVariable = "FocusTexture", ddName = "Bar Texture", ddField = "focusbartexture",
        ddTooltip = "Set your desired status bar texture for Focus frame",
        cbOnChange = function() UberUI.focusframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.focusframes:HealthManaBarTexture() end,
    });
    ToTDropdown(page, "FocusToTPlacement", "Focus", "focusframes", "focusframes");
    CastBarIconBorder(page, "focusCastBarIconBorder", "Focus", "focuscastbariconborder", "focusframes");

    opt.AddAuraOptions(page, {
        loc = "focus", label = "Focus", suffix = "Focus",
        buffKey = "aurastyle_focusbuffs", debuffKey = "aurastyle_focusdebuffs",
        refresh = RefreshFocusAuraStyle,
        styleHeader = "Auras", textHeader = "Aura Text",
        afterStyle = function()
            PurgeableBuffs(page, "focusbuffsShowDispel", "Focus", "focusbuffs_showdispel", RefreshFocusAuras);
        end,
        durationToggle = DurationToggle("Focus", "focusAuraDuration", "focusauraduration", RefreshFocusAuras),
    });

    ---------------------------------------------------------------------------
    -- Boss
    ---------------------------------------------------------------------------
    opt.Section(page, "Boss", "unitframes_boss");

    local function RefreshBossAuras()
        if UberUI.bossframes then
            UberUI.bossframes:UpdateAllAuras();
        end
    end

    opt.SubHeader(page, "Frame");
    if Boss1TargetFrame then
        AddFrameClassColor(page, "bossframes", {
            variable = "ccEnemyBoss", name = "Class Color Enemy", field = "classcolorenemy",
            tooltip = "Class color boss health bars of enemy players",
            onChange = function() UberUI.bossframes:HealthBarColor() end,
        });
        AddFrameClassColor(page, "bossframes", {
            variable = "ccFriendlyBoss", name = "Class Color Friendly", field = "classcolorfriendly",
            tooltip = "Class color boss health bars of friendly players",
            onChange = function() UberUI.bossframes:HealthBarColor() end,
        });
    end
    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "BossBarTextures", cbName = "Bar Textures", cbField = "bossbartextures",
        cbTooltip = "Retexture Boss Frames Separately from All Bars texture",
        ddVariable = "BossTexture", ddName = "Bar Texture", ddField = "bossbartexture",
        ddTooltip = "Set your desired status bar texture for Boss frames",
        cbOnChange = function() UberUI.bossframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.bossframes:HealthManaBarTexture() end,
    });

    opt.AddAuraOptions(page, {
        loc = "boss", label = "Boss", suffix = "Boss",
        buffKey = "aurastyle_bossbuffs", debuffKey = "aurastyle_bossdebuffs",
        refresh = RefreshBossAuras,
        styleHeader = "Auras", textHeader = "Aura Text",
        afterStyle = function()
            PurgeableBuffs(page, "bossbuffsShowDispel", "Boss", "bossbuffs_showdispel", RefreshBossAuras);
        end,
    });

    ---------------------------------------------------------------------------
    -- Party (standard, non-compact party frames)
    ---------------------------------------------------------------------------
    opt.Section(page, "Party", "unitframes_party");

    -- Buffs never show directly on the classic (non-compact) party frame --
    -- only in the on-hover tooltip -- so Party Buffs styles the tooltip's
    -- buff icons.
    local function RefreshPartyAuraStyle()
        if UberUI.partyframes and UberUI.partyframes.RefreshAuraStyle then
            UberUI.partyframes:RefreshAuraStyle();
        end
    end

    opt.SubHeader(page, "Frame");
    AddFrameClassColor(page, "partyframes", {
        variable = "ccPartyColor", name = "Class Color", field = "classcolor",
        tooltip = "Class color default blizzard party (non-raid) health bars",
        onChange = function()
            UberUI.partyframes:Color();
            UberUI.partyframes:HealthBarColor();
        end,
    });
    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "PartyBarTextures", cbName = "Bar Textures", cbField = "partybartextures",
        cbTooltip = "Retexture Party Frame Separately from All Bars texture",
        ddVariable = "PartyTexture", ddName = "Bar Texture", ddField = "partybartexture",
        ddTooltip = "Set your desired status bar texture for Party frame",
        cbOnChange = function() UberUI.partyframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.partyframes:HealthManaBarTexture() end,
    });

    opt.AddAuraOptions(page, {
        loc = "party", label = "Party", suffix = "Party",
        buffKey = "aurastyle_partybuffs", debuffKey = "aurastyle_partydebuffs",
        refresh = RefreshPartyAuraStyle,
        styleHeader = "Auras", textHeader = "Aura Text",
        buffName = "Buff Border (Tooltip)",
        buffTooltip = "Border on party buffs. Standard party frames don't show buffs on the frame itself -- only in the tooltip when you hover a party member -- so this styles those tooltip icons. \"None\" is Blizzard's look.\n\nWith Zoom off and the Blizzard border choice, Uber UI leaves these auras entirely to Blizzard.",
    });
end
