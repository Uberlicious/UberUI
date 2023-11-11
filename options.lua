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

        local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Number, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateSlider(category, setting, options, tooltip);
    end

    -- BarTexture
    do
        local variable, name = "BarTextures", "Health Bar Textures";
        local tooltip =
        "Set your desired status bar texture for health & mana bars\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
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

        local defaultValue = "Blizzard";
        local function getValue()
            if (uuidb.general) then
                return gsub(uuidb.general.texture, "_", " ");
            else
                return defaultValue;
            end
        end

        local function setValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.texture = value;
            UberUI.misc:AllFramesHealthManaTexture();
            UberUI.playerframes:HealthManaBarTexture(true);
        end

        local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Number, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateDropDown(category, setting, GetOptions, tooltip);
    end

    -- -- Raid Bar Textures
    do
        local cbvariable, cbname = "RaidBarTextures", "Raid Bar Textures";
        local cbtooltip = "Retexture Raid & Raid Party Frames Separately from general texture"
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

        local cbsetting = Settings.RegisterAddOnSetting(category, cbname, cbvariable, Settings.VarType.Boolean,
            defaultValue)
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
                return defaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.raidbartexture = value;
            UberUI.misc:AllFramesHealthManaTexture();
        end

        local ddsetting = Settings.RegisterAddOnSetting(category, ddname, ddvariable, Settings.VarType.Number,
            dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        local cbdd = CreateSettingsCheckBoxDropDownInitializer(cbsetting, cbname, cbtooltip, ddsetting, GetOptions,
            ddname, ddtooltip)
        layout:AddInitializer(cbdd);
    end

    -- -- Secondary Bar Textures
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

        local cbsetting = Settings.RegisterAddOnSetting(category, cbname, cbvariable, Settings.VarType.Boolean,
            defaultValue)
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
                return defaultValue;
            end
        end

        local function ddsetValue(self, value)
            value = gsub(value, " ", "_");
            uuidb.general.secondarybartexture = value;
            UberUI.misc:AllFramesHealthManaTexture();
        end

        local ddsetting = Settings.RegisterAddOnSetting(category, ddname, ddvariable, Settings.VarType.Number,
            dddefaultValue)
        ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

        local cbdd = CreateSettingsCheckBoxDropDownInitializer(cbsetting, cbname, cbtooltip, ddsetting, GetOptions,
            ddname, ddtooltip)
        layout:AddInitializer(cbdd);
    end

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

        local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(category, setting, tooltip);

        -- HideArenaFrames
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

        local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(category, setting, tooltip);
    end

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

        local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(category, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(category, setting, tooltip);
    end

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

        local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(category, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(category, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue);
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(category, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue);
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(category, setting, tooltip);
    end

    -- Color options
    local subcategory, layout = Settings.RegisterVerticalLayoutSubcategory(category, "Health Bar Color Options");

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

        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, uuisetValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
    end

    -- -- Class Color Friendly Focus
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

        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
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
        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
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
        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
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

        local setting = Settings.RegisterAddOnSetting(subcategory, name, variable, Settings.VarType.Boolean, defaultValue)
        setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
        Settings.CreateCheckBox(subcategory, setting, tooltip);
    end

    Settings.RegisterAddOnCategory(subcategory);
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
