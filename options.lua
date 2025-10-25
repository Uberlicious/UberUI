--[[--------------------------------------------------------------------
	Uber UI
	Darkens default UI
	Created and Maintained by Uberlicious
----------------------------------------------------------------------]]

local addon, ns = ...
uuiopt = {}

local strtobool = { ["0"] = false, ["1"] = true };

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

        local setting = Settings.RegisterAddOnSetting(category, variable, "darkencolor", uuidb.general,
            Settings.VarType.Number, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateSlider(category, setting, options, tooltip);
    end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Bar Textures"));

    -- BarTexture
    do
        local cbvariable, cbname = "BarTextures", "All Bar Textures";
        local cbtooltip = "Apply texture to all bars (can be overridden by individual frame settings below)"
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.allbartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.allbartextures = value;
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "allbartextures", uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local ddvariable, ddname = "AllBarsTexture", "All Bars Texture";
        local ddtooltip =
        "Set your desired status bar texture for all bars (can be overridden by individual frame settings below)\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
        local function GetOptions()
            local container = Settings.CreateControlTextContainer();
            local c = 0;
            for bar in pairs(UberUI:GetDefaults().statusbars) do
                bar = gsub(bar, "_", " ");
                container:Add(bar, bar);
                c = c + 1;
            end
            return container:GetData();
        end

        local dddefaultValue = "Blizzard";
        local function ddgetValue()
            if (uuidb.general) then
                return gsub(uuidb.general.texture, "_", " ");
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.texture = value;
            UberUI.misc:AllFramesHealthManaTexture();
            UberUI.playerframes:HealthManaBarTexture(true);
        end

        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "texture", uuidb.general,
            Settings.VarType.Number,
            ddname, dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        -- Custom initializer with texture previews
        local function CustomGetOptions()
            local options = GetOptions()
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

        local cbdd = CreateSettingsCheckboxDropdownInitializer(cbsetting, cbname, cbtooltip, ddsetting, CustomGetOptions,
            ddname, ddtooltip);
        layout:AddInitializer(cbdd);
    end

    -- Player Bar Textures
    do
        local cbvariable, cbname = "PlayerBarTextures", "Player Bar Textures";
        local cbtooltip = "Retexture Player Frame Separately from All Bars texture"
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.playerbartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.playerbartextures = value;
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "playerbartextures", uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local ddvariable, ddname = "PlayerTexture", "Player Bar Texture";
        local ddtooltip =
        "Set your desired status bar texture for Player frame\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
        local function GetOptions()
            local container = Settings.CreateControlTextContainer();
            local c = 0;
            for bar in pairs(UberUI:GetDefaults().statusbars) do
                bar = gsub(bar, "_", " ");
                container:Add(bar, bar);
                c = c + 1;
            end
            return container:GetData();
        end

        local dddefaultValue = "Blizzard";
        local function ddgetValue()
            if (uuidb.general) then
                return gsub(uuidb.general.playerbartexture, "_", " ");
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.playerbartexture = value;
            UberUI.playerframes:HealthManaBarTexture(true);
        end

        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "playerbartexture", uuidb.general,
            Settings.VarType.Number,
            ddname, dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        -- Custom initializer with texture previews
        local function CustomGetOptions()
            local options = GetOptions()
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

        local cbdd = CreateSettingsCheckboxDropdownInitializer(cbsetting, cbname, cbtooltip, ddsetting, CustomGetOptions,
            ddname, ddtooltip);
        layout:AddInitializer(cbdd);
    end

    -- Target Bar Textures
    do
        local cbvariable, cbname = "TargetBarTextures", "Target Bar Textures";
        local cbtooltip = "Retexture Target Frame Separately from All Bars texture"
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.targetbartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.targetbartextures = value;
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "targetbartextures", uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local ddvariable, ddname = "TargetTexture", "Target Bar Texture";
        local ddtooltip =
        "Set your desired status bar texture for Target frame\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
        local function GetOptions()
            local container = Settings.CreateControlTextContainer();
            local c = 0;
            for bar in pairs(UberUI:GetDefaults().statusbars) do
                bar = gsub(bar, "_", " ");
                container:Add(bar, bar);
                c = c + 1;
            end
            return container:GetData();
        end

        local dddefaultValue = "Blizzard";
        local function ddgetValue()
            if (uuidb.general) then
                return gsub(uuidb.general.targetbartexture, "_", " ");
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.targetbartexture = value;
            UberUI.targetframes:HealthManaBarTexture();
        end

        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "targetbartexture", uuidb.general,
            Settings.VarType.Number,
            ddname, dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        -- Custom initializer with texture previews
        local function CustomGetOptions()
            local options = GetOptions()
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

        local cbdd = CreateSettingsCheckboxDropdownInitializer(cbsetting, cbname, cbtooltip, ddsetting, CustomGetOptions,
            ddname, ddtooltip);
        layout:AddInitializer(cbdd);
    end

    -- Focus Bar Textures
    do
        local cbvariable, cbname = "FocusBarTextures", "Focus Bar Textures";
        local cbtooltip = "Retexture Focus Frame Separately from All Bars texture"
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.focusbartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.focusbartextures = value;
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "focusbartextures", uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local ddvariable, ddname = "FocusTexture", "Focus Bar Texture";
        local ddtooltip =
        "Set your desired status bar texture for Focus frame\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
        local function GetOptions()
            local container = Settings.CreateControlTextContainer();
            local c = 0;
            for bar in pairs(UberUI:GetDefaults().statusbars) do
                bar = gsub(bar, "_", " ");
                container:Add(bar, bar);
                c = c + 1;
            end
            return container:GetData();
        end

        local dddefaultValue = "Blizzard";
        local function ddgetValue()
            if (uuidb.general) then
                return gsub(uuidb.general.focusbartexture, "_", " ");
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.focusbartexture = value;
            UberUI.focusframes:HealthManaBarTexture();
        end

        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "focusbartexture", uuidb.general,
            Settings.VarType.Number,
            ddname, dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        -- Custom initializer with texture previews
        local function CustomGetOptions()
            local options = GetOptions()
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

        local cbdd = CreateSettingsCheckboxDropdownInitializer(cbsetting, cbname, cbtooltip, ddsetting, CustomGetOptions,
            ddname, ddtooltip);
        layout:AddInitializer(cbdd);
    end

    -- Nameplate Bar Textures
    do
        local cbvariable, cbname = "NameplateBarTextures", "Nameplate Bar Textures";
        local cbtooltip = "Retexture Nameplate Frames Separately from All Bars texture"
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.nameplatebartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.nameplatebartextures = value;
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "nameplatebartextures", uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local ddvariable, ddname = "NameplateTexture", "Nameplate Bar Texture";
        local ddtooltip =
        "Set your desired status bar texture for Nameplate frames\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
        local function GetOptions()
            local container = Settings.CreateControlTextContainer();
            local c = 0;
            for bar in pairs(UberUI:GetDefaults().statusbars) do
                bar = gsub(bar, "_", " ");
                container:Add(bar, bar);
                c = c + 1;
            end
            return container:GetData();
        end

        local dddefaultValue = "Blizzard";
        local function ddgetValue()
            if (uuidb.general) then
                return gsub(uuidb.general.nameplatebartexture, "_", " ");
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.nameplatebartexture = value;
            UberUI.misc:NameplateTexture();
        end

        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "nameplatebartexture", uuidb.general,
            Settings.VarType.Number,
            ddname, dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        -- Custom initializer with texture previews
        local function CustomGetOptions()
            local options = GetOptions()
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

        local cbdd = CreateSettingsCheckboxDropdownInitializer(cbsetting, cbname, cbtooltip, ddsetting, CustomGetOptions,
            ddname, ddtooltip);
        layout:AddInitializer(cbdd);
    end

    -- Raid Bar Textures
    do
        local cbvariable, cbname = "RaidBarTextures", "Raid Bar Textures";
        local cbtooltip = "Retexture Raid & Raid Party Frames Separately from All Bars texture"
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.raidbartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.raidbartextures = value;
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "raidbartextures", uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local ddvariable, ddname = "RaidTexture", "Raid Bar Texture";
        local ddtooltip =
        "Set your desired status bar texture for secondary bars\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
        local function GetOptions()
            local container = Settings.CreateControlTextContainer();
            local c = 0;
            for bar in pairs(UberUI:GetDefaults().statusbars) do
                bar = gsub(bar, "_", " ");
                container:Add(bar, bar);
                c = c + 1;
            end
            return container:GetData();
        end

        local dddefaultValue = "Blizzard";
        local function ddgetValue()
            if (uuidb.general) then
                return gsub(uuidb.general.raidbartexture, "_", " ");
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.raidbartexture = value;
            UberUI.misc:AllFramesHealthManaTexture();
        end

        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "raidbartexture", uuidb.general,
            Settings.VarType.Number,
            ddname, dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        -- Custom initializer with texture previews
        local function CustomGetOptions()
            local options = GetOptions()
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

        local cbdd = CreateSettingsCheckboxDropdownInitializer(cbsetting, cbname, cbtooltip, ddsetting, CustomGetOptions,
            ddname, ddtooltip)
        layout:AddInitializer(cbdd);
    end

    -- Secondary Bar Textures
    do
        local cbvariable, cbname = "SecondaryBarTextures", "Secondary Bar Textures";
        local cbtooltip =
        "Enable changing secondary bar textures independently ex. AbsorbBar, HealingPredictionBar\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload"
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.secondarybartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.secondarybartextures = value;
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "secondarybartextures", uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;
        -- drop down
        local ddvariable, ddname = "SecondaryTexture", "Secondary Bar Texture";
        local ddtooltip =
        "Set your desired status bar texture for secondary bars\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
        local function GetOptions()
            local container = Settings.CreateControlTextContainer();
            local c = 0;
            for bar in pairs(UberUI:GetDefaults().statusbars) do
                bar = gsub(bar, "_", " ");
                container:Add(bar, bar);
                c = c + 1;
            end
            return container:GetData();
        end

        local dddefaultValue = "Blizzard";
        local function ddgetValue()
            if (uuidb.general) then
                return gsub(uuidb.general.secondarybartexture, "_", " ");
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.secondarybartexture = value;
            UberUI.misc:AllFramesHealthManaTexture();
        end

        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "secondarybartexture", uuidb.general,
            Settings.VarType.Number,
            ddname, dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        -- Custom initializer with texture previews
        local function CustomGetOptions()
            local options = GetOptions()
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

        local cbdd = CreateSettingsCheckboxDropdownInitializer(cbsetting, cbname, cbtooltip, ddsetting, CustomGetOptions,
            ddname, ddtooltip)
        layout:AddInitializer(cbdd);
    end

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Cooldown Manager"));

    -- Cooldown Bar Textures
    do
        local cbvariable, cbname = "CooldownBarTextures", "Cooldown Bar Textures";
        local cbtooltip =
        "Retexture Cooldown Viewer Bars Separately from All Bars texture\n\n|cffff0000Warning: Some textures may not work correctly due to tiling issues.|r";
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.cooldownbartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.cooldownbartextures = value;
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "cooldownbartextures", uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local ddvariable, ddname = "CooldownTexture", "Cooldown Bar Texture";
        local ddtooltip =
        "Set your desired status bar texture for Cooldown Viewer bars\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload\n\n|cffff0000Warning: Some textures may not work correctly due to tiling issues.|r";
        local function GetOptions()
            local container = Settings.CreateControlTextContainer();
            local c = 0;
            for bar in pairs(UberUI:GetDefaults().statusbars) do
                bar = gsub(bar, "_", " ");
                container:Add(bar, bar);
                c = c + 1;
            end
            return container:GetData();
        end

        local dddefaultValue = "Blizzard";
        local function ddgetValue()
            if (uuidb.general) then
                return gsub(uuidb.general.cooldownbartexture, "_", " ");
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.cooldownbartexture = value;
            UberUI.cdManager:Refresh();
        end

        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "cooldownbartexture", uuidb.general,
            Settings.VarType.Number,
            ddname, dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        -- Custom initializer with texture previews
        local function CustomGetOptions()
            local options = GetOptions()
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

        local cbdd = CreateSettingsCheckboxDropdownInitializer(cbsetting, cbname, cbtooltip, ddsetting, CustomGetOptions,
            ddname, ddtooltip);
        layout:AddInitializer(cbdd);
    end

    -- Cooldown Borders
    do
        local variable, name = "CooldownBorders", "Cooldown Manager Icon Borders";
        local tooltip = "Enable borders on Cooldown Viewer icons"
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.cooldownborders;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.cooldownborders = value;
            if UberUI.cdManager then
                UberUI.cdManager:Refresh();
            end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "cooldownborders", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

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
        local tooltip = "Force hide default blizzard arena frames.\n\n|cffff0000Requires reload on unhiding"
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
        local tooltip = "Hide macro text on actionbars"
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
            UberUI.playerframes:PvPIcon(value);
            UberUI.targetframes:PvPIcon(value);
            UberUI.focusframes:PvPIcon(value);
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hidehonor", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Hide Rep Color
    do
        local variable, name = "HideRepColor", "Hide Target Reputation Color";
        local tooltip = "Hide colored bar at the top of the target frame"
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
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hiderepcolor", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Hide Nameplate Selection Glow
    do
        local variable, name = "HideNPSelctionGlow", "Hide Nameplate Selection Glow";
        local tooltip = "Hide the inner glow on selected nameplate\n\n|cffff0000Requires reload"
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
            UberUI.misc:NameplateTexture();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hidenameplateglow", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue);
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Hide Nameplate Selection Glow
    do
        local variable, name = "SmallFriendlyNampelates", "Small Friendly Nameplates";
        local tooltip = "Make friendly nameplates half the size\n\n|cffff0000Requires reload on disable"
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
            UberUI.misc:SetFriendlyNameplateSize(not value);
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "smallfriendlynameplate", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue);
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Buff and Aura Borders
    do
        local variable, name = "BuffAuraBorders", "Buff and Aura Borders";
        local tooltip = "Enable borders on Buffs and Auras"
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.buffauraborders;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.buffauraborders = value;
            if UberUI.buffsandauras then
                UberUI.buffsandauras:Refresh();
            end
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "buffauraborders", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
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

        function uuisetValue(self, value)
            uuidb.general.hostilitycolor = value;
            UberUI.misc:AllFramesHealthColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "hostilitycolor", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, uuisetValue, commitValue;
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

    -- Class Color Friendly Nameplates
    do
        local variable, name = "ccFriendlyNameplate", "Class Color Friendly Nameplates";
        local tooltip = "Class color friendly nameplates"
        local defaultValue = true;
        local cvar = "ShowClassColorInFriendlyNameplate";
        local function getValue()
            return strtobool[GetCVar(cvar)];
        end

        local function setValue(self, value)
            SetCVar(cvar, value);
            UberUI.misc:AllFramesHealthColor();
        end

        -- Class Color Enemy Nameplates
        local setting = Settings.RegisterAddOnSetting(category, variable, cvar, uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Class Color Enemy Nameplates
    do
        local variable, name = "ccEnemyNameplate", "Class Color Enemy Nameplates";
        local tooltip = "Class color enemy nameplates"
        local defaultValue = true;
        local cvar = "ShowClassColorInNameplate";
        local function getValue()
            return strtobool[GetCVar(cvar)];
        end

        local function setValue(self, value)
            SetCVar(cvar, value);
            UberUI.misc:AllFramesHealthColor();
        end

        -- Class Color Friendly Nameplates
        local setting = Settings.RegisterAddOnSetting(category, variable, "ShowClassColorInNameplate", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Class Color Personal Resource
    do
        local variable, name = "ccPersonalResource", "Class Color Personal Resource";
        local tooltip = "Class colors the personal resource health bar\n\n|cffff0000Requires reload";
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.general.ccpersonalresource;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.general.ccpersonalresource = value;
            UberUI.misc:NameplateTexture();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "ccpersonalresource", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Class Color Arena
    do
        local variable, name = "ccArenaColor", "Class Color Arena Targets";
        local tooltip = "Class color default blizzard arena health bars";
        local defaultValue = true;
        local function getValue()
            if (uuidb.general) then
                return uuidb.arenaframes.classcolor;
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            uuidb.arenaframes.classcolor = value;
            UberUI.arenaframes:Loop();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "classcolor", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
    end

    -- Class Color Party
    do
        local variable, name = "ccPartyColor", "Class Color Party Targets";
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
        header.UUI_Reload = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
        header.UUI_Reload:SetPoint("RIGHT", header.DefaultsButton, "LEFT", -5, 0);
        header.UUI_Reload:SetSize(header.DefaultsButton:GetSize());
        header.UUI_Reload:SetFrameStrata("HIGH");
        header.UUI_Reload:SetText("Reload UI");

        header.UUI_Reload:SetScript("OnClick", function(self, button, down)
            SettingsPanel:Hide();
            ReloadUI();
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
