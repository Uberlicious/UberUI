--[[--------------------------------------------------------------------
	Uber mUI
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

        local proxy = { darkencolor = getValue() }
        local setting = Settings.RegisterAddOnSetting(category, variable, "darkencolor", proxy,
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
                local val = uuidb.general.texture;
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.texture = value;
            UberUI.misc:AllFramesHealthManaTexture();
            if UberUI.damageMeter then
                UberUI.damageMeter:ForceTexture();
            end
        end

        local proxy = { ["texture"] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "texture", proxy,
            Settings.VarType.String,
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
                local val = uuidb.general.playerbartexture;
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.playerbartexture = value;
            UberUI.playerframes:HealthManaBarTexture(true);
        end

        local proxy = { ["playerbartexture"] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "playerbartexture", proxy,
            Settings.VarType.String,
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
        cbdd:AddShownPredicate(function() return uuidb.general.showExtendedBarTextures end);
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
                local val = uuidb.general.targetbartexture;
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.targetbartexture = value;
            UberUI.targetframes:HealthManaBarTexture();
        end

        local proxy = { ["targetbartexture"] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "targetbartexture", proxy,
            Settings.VarType.String,
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
        cbdd:AddShownPredicate(function() return uuidb.general.showExtendedBarTextures end);
        layout:AddInitializer(cbdd);
    end

    -- Focus Bar Textures

    -- Party Bar Textures
    do
        local cbvariable, cbname = "PartyBarTextures", "Party Bar Textures";
        local cbtooltip = "Retexture Party Frame Separately from All Bars texture"
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.partybartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.partybartextures = value;
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "partybartextures", uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local ddvariable, ddname = "PartyTexture", "Party Bar Texture";
        local ddtooltip =
        "Set your desired status bar texture for Party frame\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
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
                local val = uuidb.general.partybartexture;
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.partybartexture = value;
            UberUI.partyframes:HealthManaBarTexture();
        end

        local proxy = { ["partybartexture"] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "partybartexture", proxy,
            Settings.VarType.String,
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
        cbdd:AddShownPredicate(function() return uuidb.general.showExtendedBarTextures end);
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
                local val = uuidb.general.nameplatebartexture;
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.nameplatebartexture = value;
            UberUI.nameplates:ForceNameplateTexture(value);
        end

        local proxy = { ["nameplatebartexture"] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "nameplatebartexture", proxy,
            Settings.VarType.String,
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
        cbdd:AddShownPredicate(function() return uuidb.general.showExtendedBarTextures end);
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
                local val = uuidb.general.raidbartexture;
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.raidbartexture = value;
            UberUI.misc:AllFramesHealthManaTexture();
        end

        local proxy = { ["raidbartexture"] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "raidbartexture", proxy,
            Settings.VarType.String,
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
        cbdd:AddShownPredicate(function() return uuidb.general.showExtendedBarTextures end);
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
                local val = uuidb.general.secondarybartexture;
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.secondarybartexture = value;
            UberUI.misc:AllFramesHealthManaTexture();
        end

        local proxy = { ["secondarybartexture"] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "secondarybartexture", proxy,
            Settings.VarType.String,
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
        cbdd:AddShownPredicate(function() return uuidb.general.showExtendedBarTextures end);
        layout:AddInitializer(cbdd);
    end

    -- Damage Meter Bar Textures
    do
        local cbvariable, cbname = "DamageMeterBarTextures", "Damage Meter Bar Textures";
        local cbtooltip = "Retexture Damage Meter Bars Separately from All Bars texture"
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.damagemeterbartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.damagemeterbartextures = value;
            if UberUI.damageMeter then
                UberUI.damageMeter:ForceTexture()
            end
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "damagemeterbartextures", uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local ddvariable, ddname = "DamageMeterTexture", "Damage Meter Bar Texture";
        local ddtooltip =
        "Set your desired status bar texture for Damage Meter bars\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
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
                local val = uuidb.general.damagemetertexture;
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.damagemetertexture = value;
            if UberUI.damageMeter then
                UberUI.damageMeter:ForceTexture()
            end
        end

        local proxy = { ["damagemetertexture"] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "damagemetertexture", proxy,
            Settings.VarType.String,
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
        cbdd:AddShownPredicate(function() return uuidb.general.showExtendedBarTextures end);
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
            if (uuidb.cooldown) then
                return uuidb.cooldown.bartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.cooldown.bartextures = value;
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "cooldownbartextures", uuidb.cooldown,
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
            if (uuidb.cooldown) then
                local val = uuidb.cooldown.bartexture;
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.cooldown.bartexture = value;
            UberUI.cdManager:Refresh();
        end

        local proxy = { ["cooldownbartexture"] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "cooldownbartexture", proxy,
            Settings.VarType.String,
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

    -- Sub-group for other frames
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Aura Styling - Other Frames (Coming Soon)"));

    -- Party Buffs
    CreateAuraStyleDropdown("Party Buffs", "aurastyle_partybuffs", "Choose how to style standard party buffs", false);

    -- Party Debuffs
    CreateAuraStyleDropdown("Party Debuffs", "aurastyle_partydebuffs", "Choose how to style standard party debuffs", false);

    -- Compact Raid/Party Buffs
    CreateAuraStyleDropdown("Compact Raid/Party Buffs", "aurastyle_compactbuffs", "Choose how to style compact raid and party buffs", false);

    -- Compact Raid/Party Debuffs
    CreateAuraStyleDropdown("Compact Raid/Party Debuffs", "aurastyle_compactdebuffs", "Choose how to style compact raid and party debuffs", false);

    -- Nameplate Buffs
    CreateAuraStyleDropdown("Nameplate Buffs", "aurastyle_nameplatebuffs", "Choose how to style nameplate buffs", false);

    -- Nameplate Debuffs
    CreateAuraStyleDropdown("Nameplate Debuffs", "aurastyle_nameplatedebuffs", "Choose how to style nameplate debuffs", false);

if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
    -- Arena Buffs
    CreateAuraStyleDropdown("Arena Buffs", "aurastyle_arenabuffs", "Choose how to style arena buffs", false);

    -- Arena Debuffs
    CreateAuraStyleDropdown("Arena Debuffs", "aurastyle_arenadebuffs", "Choose how to style arena debuffs", false);
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

    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer("Nameplates"));

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
            UberUI.misc:UpdateNameplateSize();
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
        local tooltip = "Darkens the border texture of the Personal Resource Display\n\n|cffff0000Requires reload";
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
    do
        local cbvariable, cbname = "PersonalResourceBarTextures", "Personal Resource Bar Textures";
        local cbtooltip = "Retexture Personal Resource Display Separately from All Bars texture"
        -- checkbox
        local defaultValue = false;
        local function cbgetValue()
            if (uuidb.general) then
                return uuidb.general.personalresourcebartextures;
            else
                return defaultValue;
            end
        end

        local function cbsetValue(self, value)
            uuidb.general.personalresourcebartextures = value;
            if UberUI.personalresource then UberUI.personalresource:ForceTexture() end
        end

        local cbsetting = Settings.RegisterAddOnSetting(category, cbvariable, "personalresourcebartextures",
            uuidb.general,
            Settings.VarType.Boolean,
            cbname, defaultValue)
        cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

        -- drop down
        local ddvariable, ddname = "PersonalResourceTexture", "Personal Resource Bar Texture";
        local ddtooltip =
        "Set your desired status bar texture for Personal Resource Display\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
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
                local val = uuidb.general.personalresourcebartexture;
                return val and gsub(val, "_", " ") or dddefaultValue;
            else
                return dddefaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.personalresourcebartexture = value;
            if UberUI.personalresource then UberUI.personalresource:ForceTexture() end
        end

        local proxy = { ["personalresourcebartexture"] = ddgetValue() }
        local ddsetting = Settings.RegisterAddOnSetting(category, ddvariable, "personalresourcebartexture", proxy,
            Settings.VarType.String,
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
        -- REMOVED predicate so it's always visible
        layout:AddInitializer(cbdd);
    end
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

    -- Class Color Friendly Nameplates
    do
        local variable, name = "ccFriendlyNameplate", "Class Color Friendly Nameplates";
        local tooltip = "Class color friendly nameplates"
        local defaultValue = true;
        local cvar = "nameplateShowFriendlyClassColor";
        local function getValue()
            return strtobool[GetCVar(cvar)];
        end

        local function setValue(self, value)
            SetCVar(cvar, value);
            UberUI.misc:AllFramesHealthColor();
        end

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
        local cvar = "nameplateShowEnemyClassColor";
        local function getValue()
            return strtobool[GetCVar(cvar)];
        end

        local function setValue(self, value)
            SetCVar(cvar, value);
            UberUI.misc:AllFramesHealthColor();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, cvar, uuidb.general,
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
            UberUI.arenaframes:LoopFrames();
        end

        local setting = Settings.RegisterAddOnSetting(category, variable, "classcolor", uuidb.general,
            Settings.VarType.Boolean, name, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckbox(category, setting, tooltip);
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

SlashCmdList.UUITEST = function()
    local dbg = {}
    dbg.time = date("%Y-%m-%d %H:%M:%S")
    dbg.targetExists = UnitExists("target")
    dbg.targetName = UnitName("target")

    -- Check Blizzard_AuraContainer availability
    dbg.hasAuraContainerAddon = C_AddOns and C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer")
    dbg.isAuraContainerLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer")
    local okLoad, resLoad = pcall(function()
        if C_AddOns and C_AddOns.LoadAddOn then
            return C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        end
    end)
    dbg.loadAuraContainerResult = okLoad and tostring(resLoad) or "pcall failed"

    local okCreate, testContainer = pcall(function()
        return CreateFrame("AuraContainer", "UUITestContainer", UIParent, "CustomAuraContainerTemplate")
    end)
    dbg.createContainerOk = okCreate
    if okCreate and testContainer then
        dbg.containerType = testContainer:GetObjectType()
        testContainer:Hide()
    else
        dbg.containerErr = tostring(testContainer)
    end

    -- Check TargetFrame structure
    dbg.hasTargetFrame = TargetFrame ~= nil
    dbg.hasTargetContent = TargetFrame and TargetFrame.TargetFrameContent ~= nil
    dbg.hasContextual = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual ~= nil
    local targetAuras = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual and TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras
    dbg.hasTargetAuras = targetAuras ~= nil
    if targetAuras then
        dbg.targetAurasType = targetAuras.GetObjectType and targetAuras:GetObjectType()
        dbg.hasBuffAuraGroup = targetAuras.buffAuraGroup ~= nil
        dbg.hasDebuffAuraGroup = targetAuras.debuffAuraGroup ~= nil
        dbg.hasAuraPools = targetAuras.auraPools ~= nil
        if targetAuras.buffAuraGroup and targetAuras.buffAuraGroup.GetFramesByIndex then
            local bf = targetAuras.buffAuraGroup:GetFramesByIndex()
            dbg.buffAuraGroupCount = bf and #bf or 0
        end
        if targetAuras.debuffAuraGroup and targetAuras.debuffAuraGroup.GetFramesByIndex then
            local df = targetAuras.debuffAuraGroup:GetFramesByIndex()
            dbg.debuffAuraGroupCount = df and #df or 0
        end
    end

    if targetAuras then
        local childNames = {}
        for _, ch in pairs({ targetAuras:GetChildren() }) do
            local cn = (ch.GetName and ch:GetName()) or ("(anon " .. ch:GetObjectType() .. ")")
            table.insert(childNames, cn)
        end
        dbg.targetAurasChildren = table.concat(childNames, ", ")
    end

    -- Hover check: inspect whatever frame is under the mouse cursor right now!
    local mouseFrames = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
    local hoverChain = {}
    for _, mf in ipairs(mouseFrames) do
        if mf and mf ~= WorldFrame then
            local chain = {}
            local cur = mf
            while cur and cur ~= UIParent do
                local cname = cur.GetName and cur:GetName() or ("(anon " .. cur:GetObjectType() .. ")")
                table.insert(chain, cname)
                cur = cur.GetParent and cur:GetParent()
            end
            table.insert(hoverChain, table.concat(chain, " -> "))
        end
    end

    -- Inspect aura functions on TargetFrame
    local tfFuncs = {}
    if TargetFrame then
        for k, v in pairs(TargetFrame) do
            if type(k) == "string" and (k:lower():find("aura") or k:lower():find("buff")) and type(v) == "function" then
                table.insert(tfFuncs, k)
            end
        end
        table.sort(tfFuncs)
    end

    -- Inspect fields on targetAuras
    local taFields = {}
    if targetAuras then
        for k, v in pairs(targetAuras) do
            if type(k) == "string" and not k:find("^_") then
                table.insert(taFields, k .. " (" .. type(v) .. ")")
            end
        end
        table.sort(taFields)
    end

    -- Inspect ALL shown children of TargetFrame (up to depth 3)
    local shownTree = {}
    local function DumpShown(parent, depth, prefix)
        if not parent or depth > 3 then return end
        for _, ch in pairs({ parent:GetChildren() }) do
            if ch and ch.IsShown and ch:IsShown() then
                local cn = ch.GetName and ch:GetName() or ("(anon " .. ch:GetObjectType() .. ")")
                local hasIcon = (ch.Icon or ch.icon) ~= nil
                table.insert(shownTree, string.format("%s%s [%s, icon=%s]", prefix, cn, ch:GetObjectType(), tostring(hasIcon)))
                DumpShown(ch, depth + 1, prefix .. "  ")
            end
        end
    end
    if TargetFrame then
        DumpShown(TargetFrame, 1, "  ")
    end

    local function SafeDim(val)
        local out = "?"
        pcall(function()
            if issecretvalue and issecretvalue(val) then out = "sec" return end
            if type(val) == "number" then out = tostring(math.floor(val + 0.5)) end
        end)
        return out
    end

    -- Inspect TargetAuras configuration
    local taConfig = {}
    if targetAuras then
        local function SafeCall(fn, ...)
            if not fn then return "nil" end
            local ok, res1, res2, res3, res4 = pcall(fn, targetAuras, ...)
            if ok then
                return tostring(res1) .. (res2 and (", " .. tostring(res2)) or "") .. (res3 and (", " .. tostring(res3)) or "") .. (res4 and (", " .. tostring(res4)) or "")
            end
            return "err: " .. tostring(res1)
        end

        table.insert(taConfig, "BuffTemplate: " .. SafeCall(targetAuras.GetBuffTemplate))
        table.insert(taConfig, "DebuffTemplate: " .. SafeCall(targetAuras.GetDebuffTemplate))
        table.insert(taConfig, "BuffFilter: " .. SafeCall(targetAuras.GetBuffFilterString))
        table.insert(taConfig, "DebuffFilter: " .. SafeCall(targetAuras.GetDebuffFilterString))
        table.insert(taConfig, "AnchorPoint: " .. SafeCall(targetAuras.GetFlowLayoutAnchorPoint))
        table.insert(taConfig, "Growth: " .. SafeCall(targetAuras.GetFlowLayoutGrowthDirection))
        table.insert(taConfig, "MaxLineSize: " .. SafeCall(targetAuras.GetFlowLayoutMaximumLineSize))
        table.insert(taConfig, "Spacing: " .. SafeCall(targetAuras.GetFlowLayoutSpacing))
        table.insert(taConfig, "Padding: " .. SafeCall(targetAuras.GetFlowLayoutPadding))
        table.insert(taConfig, "SmallSize: " .. SafeCall(targetAuras.GetSmallAuraSize))
        table.insert(taConfig, "LargeSize: " .. SafeCall(targetAuras.GetLargeAuraSize))
        table.insert(taConfig, "MaxBuffs: " .. SafeCall(targetAuras.GetMaxBuffs))
        table.insert(taConfig, "MaxDebuffs: " .. SafeCall(targetAuras.GetMaxDebuffs))
        local okPt, ptStr = pcall(function()
            local p1, rf, p2, x, y = targetAuras:GetPoint(1)
            if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then
                return tostring(p1) .. " to " .. tostring(rf and rf:GetName() or "anon") .. " " .. tostring(p2) .. " (secret offsets)"
            end
            return string.format("%s to %s %s (x=%s, y=%s)", tostring(p1), tostring(rf and rf:GetName() or "anon"), tostring(p2), tostring(x), tostring(y))
        end)
        if okPt and ptStr and not (issecretvalue and issecretvalue(ptStr)) then
            table.insert(taConfig, "Points: " .. ptStr)
        end
    end

    local lines = {}
    local function SafeAdd(str)
        if issecretvalue and issecretvalue(str) then
            table.insert(lines, "<secret>")
        else
            table.insert(lines, tostring(str))
        end
    end

    SafeAdd("[UberUI /uuitest] Report:")
    SafeAdd(string.format("  Target: %s (exists=%s)", tostring(dbg.targetName), tostring(dbg.targetExists)))
    SafeAdd("  TargetAuras Config:")
    for _, cfg in ipairs(taConfig) do
        SafeAdd("    " .. tostring(cfg))
    end
    SafeAdd(string.format("  TargetFrame Aura Funcs: %s", #tfFuncs > 0 and table.concat(tfFuncs, ", ") or "none"))
    SafeAdd(string.format("  TargetAuras Fields: %s", #taFields > 0 and table.concat(taFields, ", ") or "none"))
    SafeAdd(string.format("  TargetAuras Children: %s", tostring(dbg.targetAurasChildren or "none")))
    SafeAdd("  TargetFrame Visible Children Tree:")
    for _, item in ipairs(shownTree) do
        SafeAdd("  " .. tostring(item))
    end

    local fullText = table.concat(lines, "\n")
    UberuiDB.debug_target_auras_report = fullText

    -- Print to chat as well
    print("|cff00ff00[UberUI /uuitest]|r Report generated (popup opened - press Ctrl+C to copy):")
    for _, l in ipairs(lines) do
        print(l)
    end

    -- Create/Show popup copy window
    local f = _G["UUICopyDialog"]
    if not f then
        f = CreateFrame("Frame", "UUICopyDialog", UIParent, "DialogBoxFrame")
        f:SetSize(620, 480)
        f:SetPoint("CENTER")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")

        local scroll = CreateFrame("ScrollFrame", "UUICopyScroll", f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -30)
        scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 40)

        local edit = CreateFrame("EditBox", "UUICopyEdit", scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(540)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit)
        f.edit = edit
    end
    f.edit:SetText(fullText)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end
SLASH_UUITEST1 = "/uuitest"
