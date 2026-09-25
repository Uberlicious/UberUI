--[[--------------------------------------------------------------------
	Uber mUI
	Darkens default UI
	Created and Maintained by Uberlicious
----------------------------------------------------------------------]]

local addon, ns = ...
uuiopt = {}

local function commitValue()
    UberUI:Save();
end

local function Register()
    local category, layout = Settings.RegisterVerticalLayoutCategory("Uber UI");
    Settings.UBERUI_CATEGORY_ID = category:GetID();

    -- Helper function to create dropdown with texture previews
    local function CreateDropdownWithTextures(category, setting, getOptionsFunc, tooltip)
        local initializer = Settings.CreateDropdownInitializer(setting, getOptionsFunc, tooltip)

        -- Hook the options function to add texture previews
        local originalGetOptions = getOptionsFunc
        local function getOptionsWithTextures()
            local options = originalGetOptions()
            local statusbars = UberUI:GetDefaults().statusbars
            if statusbars then
                for _, option in ipairs(options) do
                    local textureName = gsub(option.value, " ", "_")
                    local texturePath = statusbars[textureName]
                    if texturePath then
                        local iconString = CreateTextureMarkup(texturePath, 64, 16, 60, 12, 0, 1, 0, 1)
                        option.label = iconString .. " " .. option.label
                    end
                end
            end
            return options
        end

        initializer = Settings.CreateDropdownInitializer(setting, getOptionsWithTextures, tooltip)
        layout:AddInitializer(initializer)
    end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("General"));

    -- DarknessLevel
    do
        local variable, name, tooltip = "DarknessLevel", "Darkness Level", "Set your desired level of darkness";
        local minValue, maxValue, step = 0, 100, 5;
        local options = Settings.CreateSliderOptions(minValue, maxValue, step);
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right);
        local defaultValue = 40;

        local function getValue()
            if (uuidb.general) then
                return uuidb.general.darkencolor.r * 100;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            local dc = uuidb.general.darkencolor;
            local adjusted = value / 100;
            dc.r = adjusted;
            dc.g = adjusted;
            dc.b = adjusted;
            UberUI.misc:AllFramesColor()
        end

        local proxy = { darkencolor = getValue() }
        local setting = Settings.RegisterAddOnSetting(category, variable, "darkencolor", proxy,
            Settings.VarType.Number, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateSlider(category, setting, options, tooltip);
    end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Bar Textures"));

    -- Shared helper for the per-frame "Bar Textures" checkbox+dropdown pairs below.
    local function GetBarTextureOptionsWithTextures()
        local container = Settings.CreateControlTextContainer();
        for bar in pairs(UberUI:GetDefaults().statusbars) do
            bar = gsub(bar, "_", " ");
            container:Add(bar, bar);
        end
        local options = container:GetData();
        local statusbars = UberUI:GetDefaults().statusbars
        if statusbars then
            for _, option in ipairs(options) do
                local textureName = gsub(option.value, " ", "_")
                local texturePath = statusbars[textureName]
                if texturePath then
                    local iconString = CreateTextureMarkup(texturePath, 64, 16, 60, 12, 0, 1, 0, 1)
                    option.label = iconString .. " " .. option.label
                end
            end
        end
        return options
    end

    -- opts: dbTable, cbVariable/cbName/cbTooltip/cbField, ddVariable/ddName/ddTooltip/ddField,
    -- cbOnChange()/ddOnChange(value) refresh callbacks, showExtendedOnly (default true)
    local function CreateBarTextureSetting(opts)
        local dbTable = opts.dbTable;
        local cbfield, ddfield = opts.cbField, opts.ddField;
        local cbOnChange = opts.cbOnChange or function() end;
        local ddOnChange = opts.ddOnChange or function() end;
        local showExtendedOnly = opts.showExtendedOnly;
        if showExtendedOnly == nil then showExtendedOnly = true end

        -- checkbox
        local cbdefaultValue = false;
        local function cbgetValue()
            if (dbTable) then return dbTable[cbfield]
            else return cbdefaultValue end
        end
        local function cbsetValue(self, value)
            dbTable[cbfield] = value;
            cbOnChange();
        end
        local cbsetting = Settings.RegisterAddOnSetting(category, opts.cbVariable, cbfield, dbTable,
            Settings.VarType.Boolean, opts.cbName, cbdefaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local dddefaultValue = "Blizzard";
        local function ddgetValue()
            if (dbTable) then
                local val = dbTable[ddfield];
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end
        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            dbTable[ddfield] = value;
            ddOnChange(value);
        end
        local proxy = { [ddfield] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, opts.ddVariable, ddfield, proxy,
            Settings.VarType.String, opts.ddName, dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        local cbdd = CreateSettingsCheckboxDropdownInitializer(cbsetting, opts.cbName, opts.cbTooltip, ddsetting,
            GetBarTextureOptionsWithTextures, opts.ddName, opts.ddTooltip);
        if showExtendedOnly then
            cbdd:AddShownPredicate(function() return uuidb.general.showExtendedBarTextures end);
        end
        layout:AddInitializer(cbdd);
        return cbsetting, ddsetting;
    end

    -- All Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "BarTexture", cbName = "All Bar Textures", cbField = "allbartextures",
        cbTooltip = "Apply texture to all bars (can be overridden by individual frame settings below)",
        ddVariable = "AllBarsTexture", ddName = "All Bars Texture", ddField = "texture",
        ddTooltip = "Set your desired status bar texture for all bars (can be overridden by individual frame settings below)\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload",
        ddOnChange = function()
            UberUI.misc:AllFramesHealthManaTexture();
            if UberUI.damageMeter then
                UberUI.damageMeter:ForceTexture();
            end
        end,
        showExtendedOnly = false,
    })

    -- Show Extended Bar Textures
    do
        local variable, name = "ShowExtendedBarTextures", "Show Extended Bar Textures";
        local tooltip = "Show additional options for setting individual frame textures";
        local defaultValue = false;

        local function getValue()
            if (uuidb.general) then
                return uuidb.general.showExtendedBarTextures;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.showExtendedBarTextures = value;
            if SettingsPanel:IsShown() and SettingsPanel:GetCurrentCategory():GetID() == Settings.UBERUI_CATEGORY_ID then
                SettingsPanel.Container.SettingsList:RepairDisplay(layout);
            end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "showExtendedBarTextures", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Player Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "PlayerBarTextures", cbName = "Player Bar Textures", cbField = "playerbartextures",
        cbTooltip = "Retexture Player Frame Separately from All Bars texture",
        ddVariable = "PlayerTexture", ddName = "Player Bar Texture", ddField = "playerbartexture",
        ddTooltip = "Set your desired status bar texture for Player frame\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload",
        cbOnChange = function() UberUI.playerframes:HealthManaBarTexture(true) end,
        ddOnChange = function() UberUI.playerframes:HealthManaBarTexture(true) end,
    })

    -- Target Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "TargetBarTextures", cbName = "Target Bar Textures", cbField = "targetbartextures",
        cbTooltip = "Retexture Target Frame Separately from All Bars texture",
        ddVariable = "TargetTexture", ddName = "Target Bar Texture", ddField = "targetbartexture",
        ddTooltip = "Set your desired status bar texture for Target frame",
        cbOnChange = function() UberUI.targetframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.targetframes:HealthManaBarTexture() end,
    })

    -- Focus Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "FocusBarTextures", cbName = "Focus Bar Textures", cbField = "focusbartextures",
        cbTooltip = "Retexture Focus Frame Separately from All Bars texture",
        ddVariable = "FocusTexture", ddName = "Focus Bar Texture", ddField = "focusbartexture",
        ddTooltip = "Set your desired status bar texture for Focus frame",
        cbOnChange = function() UberUI.focusframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.focusframes:HealthManaBarTexture() end,
    })

    -- Boss Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "BossBarTextures", cbName = "Boss Bar Textures", cbField = "bossbartextures",
        cbTooltip = "Retexture Boss Frames Separately from All Bars texture",
        ddVariable = "BossTexture", ddName = "Boss Bar Texture", ddField = "bossbartexture",
        ddTooltip = "Set your desired status bar texture for Boss frames",
        cbOnChange = function() UberUI.bossframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.bossframes:HealthManaBarTexture() end,
    })

    -- Party Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "PartyBarTextures", cbName = "Party Bar Textures", cbField = "partybartextures",
        cbTooltip = "Retexture Party Frame Separately from All Bars texture",
        ddVariable = "PartyTexture", ddName = "Party Bar Texture", ddField = "partybartexture",
        ddTooltip = "Set your desired status bar texture for Party frame",
        cbOnChange = function() UberUI.partyframes:HealthManaBarTexture() end,
        ddOnChange = function() UberUI.partyframes:HealthManaBarTexture() end,
    })

    -- Nameplate Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "NameplateBarTextures", cbName = "Nameplate Bar Textures", cbField = "nameplatebartextures",
        cbTooltip = "Retexture Nameplate Frames Separately from All Bars texture",
        ddVariable = "NameplateTexture", ddName = "Nameplate Bar Texture", ddField = "nameplatebartexture",
        ddTooltip = "Set your desired status bar texture for Nameplate frames",
        cbOnChange = function() UberUI.nameplates:ForceNameplateTexture() end,
        ddOnChange = function(value) UberUI.nameplates:ForceNameplateTexture(value) end,
    })

    -- Raid Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "RaidBarTextures", cbName = "Raid Bar Textures", cbField = "raidbartextures",
        cbTooltip = "Retexture Raid & Raid Party Frames Separately from All Bars texture",
        ddVariable = "RaidTexture", ddName = "Raid Bar Texture", ddField = "raidbartexture",
        ddTooltip = "Set your desired status bar texture for Raid & Raid Party frames\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload",
        cbOnChange = function() UberUI.misc:AllFramesHealthManaTexture() end,
        ddOnChange = function() UberUI.misc:AllFramesHealthManaTexture() end,
    })

    -- Secondary Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "SecondaryBarTextures", cbName = "Secondary Bar Textures", cbField = "secondarybartextures",
        cbTooltip = "Enable changing secondary bar textures independently ex. AbsorbBar, HealingPredictionBar\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload",
        ddVariable = "SecondaryTexture", ddName = "Secondary Bar Texture", ddField = "secondarybartexture",
        ddTooltip = "Set your desired status bar texture for secondary bars\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload",
        cbOnChange = function() UberUI.misc:AllFramesHealthManaTexture() end,
        ddOnChange = function() UberUI.misc:AllFramesHealthManaTexture() end,
    })

    -- Damage Meter Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "DamageMeterBarTextures", cbName = "Damage Meter Bar Textures", cbField = "damagemeterbartextures",
        cbTooltip = "Retexture Damage Meter Bars Separately from All Bars texture",
        ddVariable = "DamageMeterTexture", ddName = "Damage Meter Bar Texture", ddField = "damagemetertexture",
        ddTooltip = "Set your desired status bar texture for Damage Meter bars",
        cbOnChange = function() if UberUI.damageMeter then UberUI.damageMeter:ForceTexture() end end,
        ddOnChange = function() if UberUI.damageMeter then UberUI.damageMeter:ForceTexture() end end,
    })

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Cooldown Manager"));

    -- Cooldown Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.cooldown,
        cbVariable = "CooldownBarTextures", cbName = "Cooldown Bar Textures", cbField = "bartextures",
        cbTooltip = "Retexture Cooldown Viewer Bars Separately from All Bars texture\n\n|cffff0000Warning: Some textures may not work correctly due to tiling issues.|r",
        ddVariable = "CooldownTexture", ddName = "Cooldown Bar Texture", ddField = "bartexture",
        ddTooltip = "Set your desired status bar texture for Cooldown Viewer bars\n\n|cffff0000Warning: Some textures may not work correctly due to tiling issues.|r",
        cbOnChange = function() if UberUI.cdManager then UberUI.cdManager:Refresh() end end,
        ddOnChange = function() if UberUI.cdManager then UberUI.cdManager:Refresh() end end,
        showExtendedOnly = false,
    })

    -- Cooldown Borders
    do
        local variable, name = "CooldownBorders", "Cooldown Manager Icon Borders";
        local tooltip = "Enable borders on Cooldown Viewer icons"
        local defaultValue = true;
        local function getValue()
            if (uuidb.cooldown) then
                return uuidb.cooldown.borders;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.cooldown.borders = value;
            if UberUI.cdManager then
                UberUI.cdManager:Refresh();
            end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "cooldownborders", uuidb.cooldown,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Damage Meters
if DamageMeterSessionWindowMixin then
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Damage Meters"));

    -- Background
    do
        local variable, name = "dmBackground", "Show Background";
        local tooltip = "Show/Hide damage meter background";
        local defaultValue = false;
        local function getValue()
            if (uuidb.damagemeters) then
                return uuidb.damagemeters.background;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.damagemeters.background = value;
            UberUI.damageMeter:ForceTexture();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "background", uuidb.damagemeters,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Alpha
    do
        local variable, name = "dmAlpha", "Background Alpha";
        local tooltip = "Set damage meter background alpha";
        local defaultValue = 50;
        local minValue, maxValue, step = 0, 100, 1;
        local function getValue()
            if (uuidb.damagemeters) then
                return uuidb.damagemeters.alpha * 100;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.damagemeters.alpha = value / 100;
            UberUI.damageMeter:ForceTexture();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "alpha", uuidb.damagemeters,
            Settings.VarType.Number, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;

        local options = Settings.CreateSliderOptions(minValue, maxValue, step);
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right);
        Settings.CreateSlider(category, setting, options, tooltip);
    end

    -- Hide Overlay
    do
        local variable, name = "dmHideOverlay", "Hide Overlay";
        local tooltip = "Hide damage meter bar overlay (shine effect)";
        local defaultValue = false;
        local function getValue()
            if (uuidb.damagemeters) then
                return uuidb.damagemeters.hideoverlay;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.damagemeters.hideoverlay = value;
            UberUI.damageMeter:ForceTexture();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hideoverlay", uuidb.damagemeters,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Hide Bar Background
    do
        local variable, name = "dmHideBarBackground", "Hide Bar Background";
        local tooltip =
        "Hide damage meter bar background texture";
        local defaultValue = false;
        local function getValue()
            if (uuidb.damagemeters) then
                return uuidb.damagemeters.hidebarbackground;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.damagemeters.hidebarbackground = value;
            UberUI.damageMeter:ForceTexture();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hidebarbackground", uuidb.damagemeters,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end
end

    -- Aura Styling
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Aura Styling"));

    local function GetAuraStyleOptions()
        local container = Settings.CreateControlTextContainer();
        container:Add("both", "Zoom & Dark Border");
        container:Add("border", "Dark Border Only");
        container:Add("zoom", "Zoom Only");
        container:Add("none", "None");
        return container:GetData();
    end

    local function CreateAuraStyleDropdown(name, variableKey, tooltip, isEnabled, onSetCallback)
        local variable = variableKey .. "_dropdown";
        local defaultValue = variableKey:find("debuff") and "zoom" or "both";
        local function getValue()
            if uuidb.general and uuidb.general[variableKey] ~= nil then
                return uuidb.general[variableKey];
            else
                return defaultValue;
            end
        end

        local proxy = { [variableKey] = getValue() };
        local function setValue(self, value)
            if not isEnabled then return end
            if uuidb.general then
                uuidb.general[variableKey] = value;
            end
            proxy[variableKey] = value;
            if onSetCallback then
                onSetCallback(value);
            end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, proxy,
            Settings.VarType.String, name, defaultValue);
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;

        local fullTooltip = tooltip;
        if not isEnabled then
            fullTooltip = fullTooltip .. "\n\n|cffff8000(Currently disabled - in development)|r";
        end

        local initializer = Settings.CreateDropdownInitializer(setting, GetAuraStyleOptions, fullTooltip);
        if not isEnabled and initializer.AddEnabledPredicate then
            initializer:AddEnabledPredicate(function() return false end);
        end
        layout:AddInitializer(initializer);
    end

    -- Player Buffs
    CreateAuraStyleDropdown("Player Buffs", "aurastyle_playerbuffs", "Choose how to style player buffs", true, function()
        if UberUI.buffsandauras then
            UberUI.buffsandauras:Refresh();
        end
    end);

    -- Player Debuffs
    CreateAuraStyleDropdown("Player Debuffs", "aurastyle_playerdebuffs", "Choose how to style player debuffs", true, function()
        if UberUI.buffsandauras then
            UberUI.buffsandauras:Refresh();
        end
    end);

    -- Target Buffs
    CreateAuraStyleDropdown("Target Buffs", "aurastyle_targetbuffs", "Choose how to style target buffs", true, function()
        if UberUI.buffsandauras then
            UberUI.buffsandauras:Refresh();
        end
        if UberUI.targetframes then
            UberUI.targetframes:UpdateAuras();
        end
    end);

    -- Target Debuffs
    CreateAuraStyleDropdown("Target Debuffs", "aurastyle_targetdebuffs", "Choose how to style target debuffs", true, function()
        if UberUI.buffsandauras then
            UberUI.buffsandauras:Refresh();
        end
        if UberUI.targetframes then
            UberUI.targetframes:UpdateAuras();
        end
    end);

    -- Show Dispels for Target Buffs
    do
        local variable, name = "targetbuffsShowDispel", "Show Dispels for Target Buffs";
        local tooltip =
        "Show a white border on enemy buffs your class can Purge/Dispel/Spellsteal, layered on top of whichever Target Buffs style is chosen above (including Dark/Both, which otherwise hides it). Matches stock Blizzard behavior: only shown if your class actually has a way to remove it.";
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.targetbuffs_showdispel;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.targetbuffs_showdispel = value;
            if UberUI.targetframes then
                UberUI.targetframes:UpdateAuras();
            end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "targetbuffs_showdispel", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Focus Buffs
    CreateAuraStyleDropdown("Focus Buffs", "aurastyle_focusbuffs", "Choose how to style focus buffs", true, function()
        if UberUI.buffsandauras then
            UberUI.buffsandauras:Refresh();
        end
        if UberUI.focusframes and UberUI.focusframes.UpdateAuras then
            UberUI.focusframes:UpdateAuras();
        end
    end);

    -- Focus Debuffs
    CreateAuraStyleDropdown("Focus Debuffs", "aurastyle_focusdebuffs", "Choose how to style focus debuffs", true, function()
        if UberUI.buffsandauras then
            UberUI.buffsandauras:Refresh();
        end
        if UberUI.focusframes and UberUI.focusframes.UpdateAuras then
            UberUI.focusframes:UpdateAuras();
        end
    end);

    -- Show Dispels for Focus Buffs
    do
        local variable, name = "focusbuffsShowDispel", "Show Dispels for Focus Buffs";
        local tooltip =
        "Show a white border on enemy buffs your class can Purge/Dispel/Spellsteal, layered on top of whichever Focus Buffs style is chosen above (including Dark/Both, which otherwise hides it). Matches stock Blizzard behavior: only shown if your class actually has a way to remove it.";
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.focusbuffs_showdispel;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.focusbuffs_showdispel = value;
            if UberUI.focusframes and UberUI.focusframes.UpdateAuras then
                UberUI.focusframes:UpdateAuras();
            end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "focusbuffs_showdispel", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Boss Buffs
    CreateAuraStyleDropdown("Boss Buffs", "aurastyle_bossbuffs", "Choose how to style boss buffs", true, function()
        if UberUI.bossframes then
            UberUI.bossframes:UpdateAllAuras();
        end
    end);

    -- Boss Debuffs
    CreateAuraStyleDropdown("Boss Debuffs", "aurastyle_bossdebuffs", "Choose how to style boss debuffs", true, function()
        if UberUI.bossframes then
            UberUI.bossframes:UpdateAllAuras();
        end
    end);

    -- Show Dispels for Boss Buffs
    do
        local variable, name = "bossbuffsShowDispel", "Show Dispels for Boss Buffs";
        local tooltip =
        "Show a white border on enemy buffs your class can Purge/Dispel/Spellsteal, layered on top of whichever Boss Buffs style is chosen above (including Dark/Both, which otherwise hides it). Matches stock Blizzard behavior: only shown if your class actually has a way to remove it.";
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.bossbuffs_showdispel;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.bossbuffs_showdispel = value;
            if UberUI.bossframes then
                UberUI.bossframes:UpdateAllAuras();
            end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "bossbuffs_showdispel", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    -- Compact Raid/Party frames. "None" hands that aura type back to
    -- Blizzard's native display (restores the raid frame option we turned
    -- off), so each of these doubles as the on/off switch for testing.
    local function RefreshCompactAuras()
        if UberUI.compactauras and UberUI.compactauras.Refresh then
            UberUI.compactauras:Refresh();
        end
    end

    -- Compact Raid/Party Buffs
    CreateAuraStyleDropdown("Compact Raid/Party Buffs", "aurastyle_compactbuffs",
        "Choose how to style compact raid and party buffs.\n\n\"None\" turns off Uber UI's buffs and restores Blizzard's own.",
        true, RefreshCompactAuras);

    -- Compact Raid/Party Debuffs
    CreateAuraStyleDropdown("Compact Raid/Party Debuffs", "aurastyle_compactdebuffs",
        "Choose how to style compact raid and party debuffs, including private boss debuffs.\n\n\"None\" turns off Uber UI's debuffs and restores Blizzard's own.",
        true, RefreshCompactAuras);

    -- Compact Big Defensive
    do
        local variable, name = "compactBigDefensive", "Style Compact Raid/Party Big Defensive";
        local tooltip =
        "Replace the large defensive cooldown icon in the center of compact raid and party frames with Uber UI's, styled like Compact Raid/Party Buffs. Size follows Blizzard's Edit Mode Big Defensive size.\n\nWhen off, Blizzard's own icon is restored.";
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.compactbigdefensive;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.compactbigdefensive = value;
            RefreshCompactAuras();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "compactbigdefensive", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end
end

    -- Party Buffs. Buffs never show directly on the classic (non-compact)
    -- party frame -- only in the on-hover tooltip -- so this styles the
    -- tooltip's buff icons.
    local function RefreshPartyAuraStyle()
        if UberUI.partyframes and UberUI.partyframes.RefreshAuraStyle then
            UberUI.partyframes:RefreshAuraStyle();
        end
    end

    CreateAuraStyleDropdown("Party Buffs", "aurastyle_partybuffs",
        "Choose how to style standard (non-compact) party buffs, shown when hovering a party member's buff tooltip.",
        true, RefreshPartyAuraStyle);

    -- Party Debuffs
    CreateAuraStyleDropdown("Party Debuffs", "aurastyle_partydebuffs",
        "Choose how to style standard (non-compact) party debuffs.",
        true, RefreshPartyAuraStyle);

if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
    local function RefreshArenaAuraStyle()
        if UberUI.arenaframes then
            UberUI.arenaframes:RefreshAuraStyle();
        end
    end

    -- Arena Buffs. Arena frames never show general buffs at all -- Blizzard
    -- hardcodes ignore-buffs=true for PvP-classified frames, so there's
    -- nothing native to suppress or replace. Until there's a real custom
    -- arena buff display, this styles the Diminishing Returns tracker
    -- instead, which doesn't warrant its own dedicated dropdown.
    CreateAuraStyleDropdown("Arena Buffs", "aurastyle_arenabuffs",
        "Arena frames don't show general buffs. For now this styles the Diminishing Returns tracker instead.",
        true, RefreshArenaAuraStyle);

    -- Arena Debuffs. Arena frames' native debuff display is the same
    -- forbidden private-aura renderer party/raid have, except Blizzard
    -- hardcodes it permanently on for PvP frames with no CVar to suppress
    -- it, so this styles the addon-visible widget arena frames actually
    -- expose instead: the CC (Loss of Control) tracker.
    CreateAuraStyleDropdown("Arena Debuffs", "aurastyle_arenadebuffs",
        "Choose how to style the arena Crowd Control tracker.",
        true, RefreshArenaAuraStyle);
end

if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Arena"));

    -- Arena Nameplate Numbers
    do
        local variable, name = "ArenaNameplateNumbers", "Arena Nameplate Numbers";
        local tooltip = "Change name on arena nameplate frames to target number"
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.arenanumbers;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.arenanumbers = value;
            UberUI.arenaframes:NameplateNumbers();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "arenanumbers", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- HideArenaFrames
    do
        local variable, name = "HideArenaFrames", "Hide Arena Frames";
        local tooltip = "Force hide default blizzard arena frames."
        local defaultValue = false;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.hidearenaframes;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.hidearenaframes = value;
            UberUI.arenaframes:SetVisibility();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hidearenaframes", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end
end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Raid Frames"));

    -- Hide Raid Frame Titles
    do
        local variable, name = "HideRaidFrameTitles", "Hide Raid Frame Titles";
        local tooltip = "Hide the title text on raid frames e.g. 'Group 1'"
        local defaultValue = false;
        local function getValue()
            if (uuidb.cuf) then
                return uuidb.cuf.hideRaidTitle;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.cuf.hideRaidTitle = value;
            UberUI.cuf:HideRaidFrameTitles();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hideRaidTitle", uuidb.cuf,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Action Bars"));

    -- Hide HotKeys
    do
        local variable, name = "HideHotKeys", "Hide HotKeys";
        local tooltip = "Hide hotkey text on actionbars"
        local defaultValue = false;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.hidehotkeys;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.hidehotkeys = value;
            UberUI.actionbars:Color();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hidehotkeys", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Hide Macros
    do
        local variable, name = "HideMacros", "Hide Macros";
        local tooltip = "Hide macro text on actionbars"
        local defaultValue = false;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.hidemacros;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.hidemacros = value;
            UberUI.actionbars:Color();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hidemacros", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Misc"));

    -- Hide Honor
    do
        local variable, name = "HideHonor", "Hide Honor";
        local tooltip = "Hide the entire PvP badge (icon, background, and Prestige art) on the Player, Target, Focus, and Party frames"
        local defaultValue = false;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.hidehonor;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.hidehonor = value;
            UberUI.general:RefreshHideHonor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hidehonor", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Hide Rep Color
    do
        local variable, name = "HideRepColor", "Hide Target Reputation Color";
        local tooltip = "Hide colored bar at the top of the Target, Focus, and Boss frames"
        local defaultValue = false;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.hiderepcolor;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.hiderepcolor = value;
            UberUI.targetframes:Color();
            UberUI.focusframes:Color();
            if UberUI.bossframes then UberUI.bossframes:Color() end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hiderepcolor", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Nameplates"));

    -- Hide Nameplate Selection Glow
    do
        local variable, name = "HideNPSelctionGlow", "Hide Nameplate Selection Glow";
        local tooltip = "Hide the inner glow on selected nameplate"
        local defaultValue = false;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.hidenameplateglow;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.hidenameplateglow = value;
            if UberUI.nameplates then UberUI.nameplates:ForceNameplateTexture() end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hidenameplateglow", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue);
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Small Friendly Nameplates
    do
        local variable, name = "SmallFriendlyNampelates", "Small Friendly Nameplates";
        local tooltip = "Make friendly nameplates half the size"
        local defaultValue = false;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.smallfriendlynameplate;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.smallfriendlynameplate = value;
            if UberUI.nameplates then UberUI.nameplates:UpdateNameplateSize() end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "smallfriendlynameplate", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue);
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Friendly Nameplate Raid Target Scale
    do
        local variable, name, tooltip = "FriendlyNameplateRaidTargetScale", "Friendly Nameplate Raid Target Scale",
            "Scale of the raid target icon on friendly nameplates";
        local minValue, maxValue, step = 0.5, 10, 0.1;
        local options = Settings.CreateSliderOptions(minValue, maxValue, step);
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return string.format("%.1f", value)
        end);
        local defaultValue = 1;

        local function getValue()
            if (uuidb.general) then
                return uuidb.general.nameplateraidtargetscale or defaultValue;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.nameplateraidtargetscale = value;
            UberUI.nameplates:UpdateAllNameplateRaidTargetScale();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "nameplateraidtargetscale", uuidb.general,
            Settings.VarType.Number, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateSlider(category, setting, options, tooltip);
    end

    -- Anchor Friendly Raid Icon Top
    do
        local variable, name = "AnchorFriendlyRaidIconTop", "Anchor Friendly Raid Icon Top";
        local tooltip = "Anchor the raid icon to the top center of the nameplate";
        local defaultValue = false;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.nameplateraidtargettopanchor;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.nameplateraidtargettopanchor = value;
            UberUI.nameplates:UpdateAllNameplateRaidTargetScale();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "nameplateraidtargettopanchor", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue);
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

if PersonalResourceDisplayMixin then
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Personal Resource Display"));

    -- Darken Personal Resource Border
    do
        local variable, name = "darkenpersonalresourceborder", "Darken Personal Resource Border";
        local tooltip = "Darkens the border texture of the Personal Resource Display";
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.darkenpersonalresourceborder;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.darkenpersonalresourceborder = value;
            if UberUI.personalresource then UberUI.personalresource:ForceTexture() end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "darkenpersonalresourceborder", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Personal Resource Bar Textures
    CreateBarTextureSetting({
        dbTable = uuidb.general,
        cbVariable = "PersonalResourceBarTextures", cbName = "Personal Resource Bar Textures", cbField = "personalresourcebartextures",
        cbTooltip = "Retexture Personal Resource Display Separately from All Bars texture",
        ddVariable = "PersonalResourceTexture", ddName = "Personal Resource Bar Texture", ddField = "personalresourcebartexture",
        ddTooltip = "Set your desired status bar texture for Personal Resource Display",
        cbOnChange = function() if UberUI.personalresource then UberUI.personalresource:ForceTexture() end end,
        ddOnChange = function() if UberUI.personalresource then UberUI.personalresource:ForceTexture() end end,
        -- REMOVED predicate so it's always visible
        showExtendedOnly = false,
    })
end

    -- Color options
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Health Bar Color Options"));

    -- Hostility Color
    do
        local variable, name = "HostilityColor", "Color By Hostility";
        local tooltip =
        "Color all healthbars according to hostility \n\n|cffff0000Enemy\n|cff00ff00Friendly\n|cffffff00Neutral\n\n|cffff0000This setting will be overwritten in respective frames that have class colring enabled when targeting an player";
        local defaultValue = false;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.hostilitycolor;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.hostilitycolor = value;
            UberUI.misc:AllFramesHealthColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hostilitycolor", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Class Color Player Health
    do
        local variable, name = "ccPlayerHealth", "Class Color Player";
        local tooltip = "Class color player health bar"
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.playerframes.classcolor;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.playerframes.classcolor = value;
            UberUI.playerframes:HealthBarColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "classcolor", uuidb.playerframes,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Class Color Enemy Target
    do
        local variable, name = "ccEnemyTarget", "Class Color Enemy Target";
        local tooltip = "Class color target and target of target health bar of enemy players"
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.targetframes.classcolorenemy;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.targetframes.classcolorenemy = value;
            UberUI.targetframes:HealthBarColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "classcolorenemy", uuidb.targetframes,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Class Color Friendly Target
    do
        local variable, name = "ccFriendlyTarget", "Class Color Friendly Target";
        local tooltip = "Class color target and target of target health bar of friendly players"
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.targetframes.classcolorfriendly;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.targetframes.classcolorfriendly = value;
            UberUI.targetframes:HealthBarColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "classcolorfriendly", uuidb.targetframes,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end


if FocusFrame then
    -- Class Color Enemy Focus
    do
        local variable, name = "ccEnemyFocus", "Class Color Enemy Focus";
        local tooltip = "Class color focus and focus target of target health bar of friendly players"
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.focusframes.classcolorenemy;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.focusframes.classcolorenemy = value;
            UberUI.focusframes:HealthBarColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "classcolorenemy", uuidb.focusframes,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Class Color Friendly Focus
    do
        local variable, name = "ccFriendlyFocus", "Class Color Friendly Focus";
        local tooltip = "Class color focus and focus target of target health bar of friendly players"
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.focusframes.classcolorfriendly;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.focusframes.classcolorfriendly = value;
            UberUI.focusframes:HealthBarColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "classcolorfriendly", uuidb.focusframes,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end
end

if Boss1TargetFrame then
    -- Class Color Enemy Boss
    do
        local variable, name = "ccEnemyBoss", "Class Color Enemy Boss";
        local tooltip = "Class color boss health bars of enemy players"
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.bossframes.classcolorenemy;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.bossframes.classcolorenemy = value;
            UberUI.bossframes:HealthBarColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "classcolorenemy", uuidb.bossframes,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Class Color Friendly Boss
    do
        local variable, name = "ccFriendlyBoss", "Class Color Friendly Boss";
        local tooltip = "Class color boss health bars of friendly players"
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.bossframes.classcolorfriendly;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.bossframes.classcolorfriendly = value;
            UberUI.bossframes:HealthBarColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "classcolorfriendly", uuidb.bossframes,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end
end

    -- Class Color Party
    do
        local variable, name = "ccPartyColor", "Class Color Party Health";
        local tooltip = "Class color default blizzard party (non-raid) health bars";
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.partyframes.classcolor;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.partyframes.classcolor = value;
            UberUI.partyframes:Color();
            UberUI.partyframes:HealthBarColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "classcolor", uuidb.partyframes,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    Settings.RegisterAddOnCategory(category);
end

SettingsRegistrar:AddRegistrant(Register)

hooksecurefunc(SettingsPanel, "DisplayCategory", function(self, category)
    local header = SettingsPanel.Container.SettingsList.Header;
    if ((category:GetID() == Settings.UBERUI_CATEGORY_ID or
                (category:HasParentCategory() and category:GetParentCategory():GetID() == Settings.UBERUI_CATEGORY_ID))
            and not header.UUI_Reload) then
        header.UUI_Reload = UberUI:CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
        header.UUI_Reload:SetPoint("RIGHT", header.DefaultsButton, "LEFT", -5, 0);
        header.UUI_Reload:SetSize(header.DefaultsButton:GetSize()); header.UUI_Reload:SetFrameStrata("HIGH");
        header.UUI_Reload:SetText("Reload UI");

        header.UUI_Reload:SetScript("OnClick", function(self)
            if C_UI and C_UI.Reload then
                C_UI.Reload()
            elseif ReloadUI then
                ReloadUI()
            elseif ConsoleExec then
                ConsoleExec("reloadui")
            end
        end)
    elseif ((category:GetID() == Settings.UBERUI_CATEGORY_ID or
                (category:HasParentCategory() and category:GetParentCategory():GetID() == Settings.UBERUI_CATEGORY_ID))
            and header.UUI_Reload) then
        header.UUI_Reload:Show();
    elseif (header.UUI_Reload) then
        header.UUI_Reload:Hide();
    end
end)

-- for addon compartment (in .toc)
function OpenUUISettings()
    Settings.OpenToCategory(Settings.UBERUI_CATEGORY_ID);
end

-- ---------------------------
-- SLASH COMMAND
-- ---------------------------

SlashCmdList.UBERUI = function()
    Settings.OpenToCategory(Settings.UBERUI_CATEGORY_ID);
end

SLASH_UBERUI1 = "/uui"
Slash_UBERUI2 = "/uberui"
