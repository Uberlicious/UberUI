--[[--------------------------------------------------------------------
	Uber UI options -- registration (load last among options\ files)

	Settings layout: a main "Uber UI" page for settings that apply
	everywhere, plus one sub-page per area of the UI. Each page's contents
	live in its own file (general.lua, unitframes.lua, ...); this file only
	creates the pages, in display order, and calls their builders.
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

local function Register()
    local mainCategory, mainLayout = Settings.RegisterVerticalLayoutCategory("Uber UI");
    Settings.UBERUI_CATEGORY_ID = mainCategory:GetID();

    local function NewPage(name)
        local category, layout = Settings.RegisterVerticalLayoutSubcategory(mainCategory, name);
        return { category = category, layout = layout };
    end

    opt.BuildGeneral({ category = mainCategory, layout = mainLayout });
    opt.BuildUnitFrames(NewPage("Unit Frames"));
    opt.BuildGroupFrames(NewPage("Raid & Group Frames"));
    if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
        opt.BuildArena(NewPage("Arena"));
    end
    opt.BuildNameplates(NewPage("Nameplates"));
    if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC and opt.BuildCooldownManager then
        opt.BuildCooldownManager(NewPage("Cooldown Manager"));
    end
    opt.BuildOtherUI(NewPage("Other UI"));

    Settings.RegisterAddOnCategory(mainCategory);
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

local openPending = false
local combatWatcher

local function SafeOpenSettings()
    if InCombatLockdown() then
        if not openPending then
            openPending = true
            print("|cffff0000Uber UI:|r Cannot open settings during combat. Will open automatically once combat ends.")
            if not combatWatcher then
                combatWatcher = CreateFrame("Frame")
                combatWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
                combatWatcher:SetScript("OnEvent", function(self)
                    if openPending then
                        openPending = false
                        C_Timer.After(0.1, function()
                            if not InCombatLockdown() then
                                Settings.OpenToCategory(Settings.UBERUI_CATEGORY_ID)
                            end
                        end)
                    end
                end)
            end
        end
        return
    end
    Settings.OpenToCategory(Settings.UBERUI_CATEGORY_ID)
end

-- for addon compartment (in .toc)
function OpenUUISettings()
    SafeOpenSettings()
end

-- ---------------------------
-- SLASH COMMAND
-- ---------------------------

SlashCmdList.UBERUI = function()
    SafeOpenSettings()
end

SLASH_UBERUI1 = "/uui"
SLASH_UBERUI2 = "/uberui"
