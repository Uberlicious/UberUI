--[[--------------------------------------------------------------------
	Uber UI
	Darkens default UI
	Maintained by Uberlicious
----------------------------------------------------------------------]]

local addon, ns = ...
uuiopt = {}

local SOUND_OFF = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
local SOUND_ON = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON

local strtobool = { ["0"] = false, ["1"] = true };

local settingsLoaded = false;
local function commitValue()
    UberUI:Save();
end

if (settingsLoaded) then return end --make sure we're only initializing settings once
local category, layout = Settings.RegisterVerticalLayoutCategory("Uber UI");
Settings.RegisterAddOnCategory(category);

-- DarknessLevel
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

-- BarTexture
local variable, name = "BarTextures", "Health Bar Textures";
local tooltip = "Set your desired status bar texture for health & mana bars\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
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
ddInit = Settings.CreateDropDown(category, setting, GetOptions, tooltip);

-- Raid Bar Textures
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

local cbsetting = Settings.RegisterAddOnSetting(category, cbname, cbvariable, Settings.VarType.Boolean, defaultValue)
cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;
-- drop down
local ddvariable, ddname = "RaidTexture", "Raid Bar Texture";
local ddtooltip = "Set your desired status bar texture for secondary bars\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
local function ddGetOptions()
    local ddcontainer = Settings.CreateControlTextContainer();
    local c = 0;
    for bar in pairs(UberUI:GetDefaults().statusbars) do
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

local ddsetting = Settings.RegisterAddOnSetting(category, ddname, ddvariable, Settings.VarType.Number, dddefaultValue)
ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

local cbdd = CreateSettingsCheckBoxDropDownInitializer(cbsetting, cbname, cbtooltip, ddsetting, GetOptions,
    ddname, ddtooltip)
layout:AddInitializer(cbdd);

-- Secondary Bar Textures
local cbvariable, cbname = "SecondaryBarTextures", "Secondary Bar Textures";
local cbtooltip = "Enable changing secondary bar textures independently ex. AbsorbBar, HealingPredictionBar\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload"
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

local cbsetting = Settings.RegisterAddOnSetting(category, cbname, cbvariable, Settings.VarType.Boolean, defaultValue)
cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;
-- drop down
local ddvariable, ddname = "SecondaryTexture", "Secondary Bar Texture";
local ddtooltip = "Set your desired status bar texture for secondary bars\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";
local function ddGetOptions()
    local ddcontainer = Settings.CreateControlTextContainer();
    local c = 0;
    for bar in pairs(UberUI:GetDefaults().statusbars) do
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

local ddsetting = Settings.RegisterAddOnSetting(category, ddname, ddvariable, Settings.VarType.Number, dddefaultValue)
ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

local cbdd = CreateSettingsCheckBoxDropDownInitializer(cbsetting, cbname, cbtooltip, ddsetting, GetOptions,
    ddname, ddtooltip)
layout:AddInitializer(cbdd);

-- Arena Nameplate Numbers
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
local tooltip = "Force hide default blizzard arena frames"
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
    UberUI.arenaframes:HideArena();
end

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

-- Hide HotKeys
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

-- Hide Macros
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

-- Hide Honor
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

-- Hide Rep Color
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

-- Hide Nameplate Selection Glow
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

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);


local header = CreateSettingsListSectionHeaderInitializer("Health Bar Color Options");
layout:AddInitializer(header);

-- local function buttonClick1(self)
--     uiButton1 = self;
--     print('click1', self:GetParent());

--     local name = "Color By Hostility";
--     SettingsPanel:GetSettingsList().ScrollBox:ScrollToElementDataByPredicate(function(elementData)
--         local data = securecallfunction(rawget, elementData, "data");
--         local elementName = securecallfunction(rawget, data, "name");
--         return elementName == name;
--     end)

--     edata = SettingsPanel:GetSettingsList().ScrollBox:FindFrameByPredicate(function(elementData)
--         local data = securecallfunction(rawget, elementData, "data");
--         local elementName = securecallfunction(rawget, data, "name");
--         return elementName == name;
--     end)

--     print(UberuiDB.general.hostilitycolor);
--     print('set', edata:SetValue(true));
--     UberuiDB.general.hostilitycolor = true;

--     UberUI.playerframes.classcolor = true;
--     print(UberUI.playerframes.classcolor)
--     UberUI.targetframes.classcolorenemy = true;
--     UberUI.targetframes.classcolorfriendly = true;
--     UberUI.focusframes.classccolorenemy = true;
--     UberUI.focusframes.classccolorfriendly = true;
--     UberUI.arenaframes.classcolor = true;
--     UberUI.partyframes.classcolor = true;
--     UberUI.general.ccpersonalresources = true;
--     UberUI.misc:AllFramesHealthColor();
--     commitValue();
-- end

-- local function buttonClick2(self)
--     print('click2');
--     UberUI.playerframes.classcolor = false;
--     print(UberUI.playerframes.classcolor);
--     UberUI.targetframes.classcolorenemy = false;
--     UberUI.targetframes.classcolorfriendly = false;
--     UberUI.focusframes.classccolorenemy = false;
--     UberUI.focusframes.classccolorfriendly = false;
--     UberUI.arenaframes.classcolor = false;
--     UberUI.partyframes.classcolor = false;
--     UberUI.general.ccpersonalresources = false;
--     UberUI.misc:AllFramesHealthColor();
-- end

-- local initializer = CreateSettingsButtonWithButtonInitializer(
--     "Class Color All Health Bars",
--     "Enable All",
--     buttonClick1,
--     "Disable All",
--     buttonClick2,
--     "Enable or disable all class color options"
-- )
-- layout:AddInitializer(initializer);

-- Hostility Color
local variable, name = "HostilityColor", "Color By Hostility";
local tooltip = "Color all healthbars according to hostility \n\n|cffff0000Enemy\n|cff00ff00Friendly\n|cffffff00Neutral\n\n|cffff0000This setting will be overwritten in respective frames that have class colring enabled when targeting an player";
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

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, uuisetValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

-- Class Color Player Health
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

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

-- Class Color Enemy Target
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

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

-- Class Color Friendly Target
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

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);


-- Class Color Enemy Focus
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

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

-- Class Color Friendly Focus
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

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

-- Class Color Friendly Nameplates
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
local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

-- Class Color Enemy Nameplates
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
local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

-- Class Color Personal Resource
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

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

-- Class Color Arena
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

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

-- Class Color Party
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
    print(self);
    uuidb.partyframes.classcolor = value;
    UberUI.partyframes:Color();
end

local setting = Settings.RegisterAddOnSetting(category, name, variable, Settings.VarType.Boolean, defaultValue)
setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
Settings.CreateCheckBox(category, setting, tooltip);

hooksecurefunc(SettingsPanel, "DisplayCategory", function(self, category)
    local header = SettingsPanel.Container.SettingsList.Header;
    if (category:GetName() == "Uber UI" and not header.UUI_Reload) then
        header.UUI_Reload = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
        header.UUI_Reload:SetPoint("RIGHT", header.DefaultsButton, "LEFT", -5, 0);
        header.UUI_Reload:SetSize(header.DefaultsButton:GetSize());
        header.UUI_Reload:SetFrameStrata("HIGH");
        header.UUI_Reload:SetText("Reload UI");

        header.UUI_Reload:SetScript("OnClick", function(self, button, down)
            SettingsPanel:Hide();
            ReloadUI();
        end)
    elseif (category:GetName() == "Uber UI" and header.UUI_Reload) then
        header.UUI_Reload:Show();
    elseif (header.UUI_Reload) then
        header.UUI_Reload:Hide();
    end
end)

settingsLoaded = true;

-- ---------------------------
-- SLASH COMMAND
-- ---------------------------

SlashCmdList.UBERUI = function(msg)
    SettingsPanel:OpenToCategory(category.ID, "DarknessLevel");
end

SLASH_UBERUI1 = "/uui"
Slash_UBERUI2 = "/uberui"
