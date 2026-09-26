--[[--------------------------------------------------------------------
	Uber UI options -- Unit Frames page: Player, Target, Focus, Boss, Party
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

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

    -- Player
    opt.Header(page, "Player");

    opt.AddAuraOptions(page, {
        loc = "player", label = "Player", suffix = "Player", squareVarSuffix = "",
        buffKey = "aurastyle_playerbuffs", debuffKey = "aurastyle_playerdebuffs",
        refresh = opt.RefreshPlayerAuras,
        buffTooltip = "Border on Player buffs and weapon enchants. \"None\" is Blizzard's look: no border on buffs, Blizzard's purple border on weapon enchants.\n\nWith Zoom off and the Blizzard border choice, Uber UI leaves these auras entirely to Blizzard.",
        positionDetail = " The duration text moves out to make room.",
        shapeTooltip = "Rounded uses Blizzard's border art. Square draws a flat border of exact pixel thickness in the same colors.\n\n|cffff4040Square on Player auras loses debuff dispel coloring in combat:|r WoW hides your own debuffs' dispel types from addons during combat, so square Player debuff borders can't show Magic/Curse/Poison/etc. colors there. (Target, Focus, Boss and other frames are not affected.)\n\nHas no effect on auras Uber UI has handed back to Blizzard (Zoom off + Blizzard border).",
    });

    opt.AddCheckbox(page, {
        variable = "ccPlayerHealth", name = "Class Color Player",
        tooltip = "Class color player health bar",
        db = "playerframes", field = "classcolor", default = true,
        onChange = function() UberUI.playerframes:HealthBarColor() end,
    });

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "PlayerBarTextures", cbName = "Player Bar Textures", cbField = "playerbartextures",
        cbTooltip = "Retexture Player Frame Separately from All Bars texture",
        ddVariable = "PlayerTexture", ddName = "Player Bar Texture", ddField = "playerbartexture",
        ddTooltip = "Set your desired status bar texture for Player frame" .. opt.RELOAD_NOTE,
        cbOnChange = function() UberUI.playerframes:HealthManaBarTexture(true) end,
        ddOnChange = function() UberUI.playerframes:HealthManaBarTexture(true) end,
    });

    -- Target
    opt.Header(page, "Target");

    local function RefreshTargetAuras()
        opt.RefreshPlayerAuras();
        if UberUI.targetframes then
            UberUI.targetframes:UpdateAuras();
        end
    end

    opt.AddAuraOptions(page, {
        loc = "target", label = "Target", suffix = "Target",
        buffKey = "aurastyle_targetbuffs", debuffKey = "aurastyle_targetdebuffs",
        refresh = RefreshTargetAuras,
    });

    opt.AddCheckbox(page, {
        variable = "targetbuffsShowDispel", name = "Target Highlight Purgeable Buffs",
        tooltip = opt.DispelTooltip("Target"),
        db = "general", field = "targetbuffs_showdispel", default = true,
        onChange = function()
            if UberUI.targetframes then
                UberUI.targetframes:UpdateAuras();
            end
        end,
    });

    opt.AddCheckbox(page, {
        variable = "ccEnemyTarget", name = "Class Color Enemy Target",
        tooltip = "Class color target and target of target health bar of enemy players",
        db = "targetframes", field = "classcolorenemy", default = true,
        onChange = function() UberUI.targetframes:HealthBarColor() end,
    });

    opt.AddCheckbox(page, {
        variable = "ccFriendlyTarget", name = "Class Color Friendly Target",
        tooltip = "Class color target and target of target health bar of friendly players",
        db = "targetframes", field = "classcolorfriendly", default = true,
        onChange = function() UberUI.targetframes:HealthBarColor() end,
    });

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "TargetBarTextures", cbName = "Target Bar Textures", cbField = "targetbartextures",
        cbTooltip = "Retexture Target Frame Separately from All Bars texture",
        ddVariable = "TargetTexture", ddName = "Target Bar Texture", ddField = "targetbartexture",
        ddTooltip = "Set your desired status bar texture for Target frame",
        cbOnChange = function() UberUI.targetframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.targetframes:HealthManaBarTexture() end,
    });

    -- Focus
    opt.Header(page, "Focus");

    local function RefreshFocusAuras()
        if UberUI.focusframes and UberUI.focusframes.UpdateAuras then
            UberUI.focusframes:UpdateAuras();
        end
    end
    local function RefreshFocusAuraStyle()
        opt.RefreshPlayerAuras();
        RefreshFocusAuras();
    end

    opt.AddAuraOptions(page, {
        loc = "focus", label = "Focus", suffix = "Focus",
        buffKey = "aurastyle_focusbuffs", debuffKey = "aurastyle_focusdebuffs",
        refresh = RefreshFocusAuraStyle,
    });

    opt.AddCheckbox(page, {
        variable = "focusbuffsShowDispel", name = "Focus Highlight Purgeable Buffs",
        tooltip = opt.DispelTooltip("Focus"),
        db = "general", field = "focusbuffs_showdispel", default = true,
        onChange = RefreshFocusAuras,
    });

    if FocusFrame then
        opt.AddCheckbox(page, {
            variable = "ccEnemyFocus", name = "Class Color Enemy Focus",
            tooltip = "Class color focus and focus target health bar of enemy players",
            db = "focusframes", field = "classcolorenemy", default = true,
            onChange = function() UberUI.focusframes:HealthBarColor() end,
        });

        opt.AddCheckbox(page, {
            variable = "ccFriendlyFocus", name = "Class Color Friendly Focus",
            tooltip = "Class color focus and focus target health bar of friendly players",
            db = "focusframes", field = "classcolorfriendly", default = true,
            onChange = function() UberUI.focusframes:HealthBarColor() end,
        });
    end

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "FocusBarTextures", cbName = "Focus Bar Textures", cbField = "focusbartextures",
        cbTooltip = "Retexture Focus Frame Separately from All Bars texture",
        ddVariable = "FocusTexture", ddName = "Focus Bar Texture", ddField = "focusbartexture",
        ddTooltip = "Set your desired status bar texture for Focus frame",
        cbOnChange = function() UberUI.focusframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.focusframes:HealthManaBarTexture() end,
    });

    -- Boss
    opt.Header(page, "Boss");

    local function RefreshBossAuras()
        if UberUI.bossframes then
            UberUI.bossframes:UpdateAllAuras();
        end
    end

    opt.AddAuraOptions(page, {
        loc = "boss", label = "Boss", suffix = "Boss",
        buffKey = "aurastyle_bossbuffs", debuffKey = "aurastyle_bossdebuffs",
        refresh = RefreshBossAuras,
    });

    opt.AddCheckbox(page, {
        variable = "bossbuffsShowDispel", name = "Boss Highlight Purgeable Buffs",
        tooltip = opt.DispelTooltip("Boss"),
        db = "general", field = "bossbuffs_showdispel", default = true,
        onChange = RefreshBossAuras,
    });

    if Boss1TargetFrame then
        opt.AddCheckbox(page, {
            variable = "ccEnemyBoss", name = "Class Color Enemy Boss",
            tooltip = "Class color boss health bars of enemy players",
            db = "bossframes", field = "classcolorenemy", default = true,
            onChange = function() UberUI.bossframes:HealthBarColor() end,
        });

        opt.AddCheckbox(page, {
            variable = "ccFriendlyBoss", name = "Class Color Friendly Boss",
            tooltip = "Class color boss health bars of friendly players",
            db = "bossframes", field = "classcolorfriendly", default = true,
            onChange = function() UberUI.bossframes:HealthBarColor() end,
        });
    end

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "BossBarTextures", cbName = "Boss Bar Textures", cbField = "bossbartextures",
        cbTooltip = "Retexture Boss Frames Separately from All Bars texture",
        ddVariable = "BossTexture", ddName = "Boss Bar Texture", ddField = "bossbartexture",
        ddTooltip = "Set your desired status bar texture for Boss frames",
        cbOnChange = function() UberUI.bossframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.bossframes:HealthManaBarTexture() end,
    });

    -- Party (standard, non-compact party frames)
    opt.Header(page, "Party");

    -- Buffs never show directly on the classic (non-compact) party frame --
    -- only in the on-hover tooltip -- so Party Buffs styles the tooltip's
    -- buff icons.
    local function RefreshPartyAuraStyle()
        if UberUI.partyframes and UberUI.partyframes.RefreshAuraStyle then
            UberUI.partyframes:RefreshAuraStyle();
        end
    end

    opt.AddAuraOptions(page, {
        loc = "party", label = "Party", suffix = "Party",
        buffKey = "aurastyle_partybuffs", debuffKey = "aurastyle_partydebuffs",
        refresh = RefreshPartyAuraStyle,
        buffName = "Party Buff Border (Tooltip)",
        buffTooltip = "Border on party buffs. Standard party frames don't show buffs on the frame itself -- only in the tooltip when you hover a party member -- so this styles those tooltip icons. \"None\" is Blizzard's look.\n\nWith Zoom off and the Blizzard border choice, Uber UI leaves these auras entirely to Blizzard.",
    });

    opt.AddCheckbox(page, {
        variable = "ccPartyColor", name = "Class Color Party",
        tooltip = "Class color default blizzard party (non-raid) health bars",
        db = "partyframes", field = "classcolor", default = true,
        onChange = function()
            UberUI.partyframes:Color();
            UberUI.partyframes:HealthBarColor();
        end,
    });

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "PartyBarTextures", cbName = "Party Bar Textures", cbField = "partybartextures",
        cbTooltip = "Retexture Party Frame Separately from All Bars texture",
        ddVariable = "PartyTexture", ddName = "Party Bar Texture", ddField = "partybartexture",
        ddTooltip = "Set your desired status bar texture for Party frame",
        cbOnChange = function() UberUI.partyframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.partyframes:HealthManaBarTexture() end,
    });
end
