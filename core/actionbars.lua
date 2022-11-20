---------------------------------------
-- VARIABLES
---------------------------------------

--get the addon namespace
local addon, ns = ...
local actionbars = {}

local classcolor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
local class = UnitClass("player")
local dominos = IsAddOnLoaded("Dominos")
local bartender4 = IsAddOnLoaded("Bartender4")


local actionbars = CreateFrame("frame")
actionbars:RegisterEvent("ADDON_LOADED")
actionbars:RegisterEvent("PLAYER_ENTERING_WORLD")
actionbars:SetScript("OnEvent", function(self, event)
    self:Color();
end)

function actionbars:Color()
    local dc = uuidb.general.darkencolor;

    --bartender4 styling
    if bartender4 then
        --print("Bartender4 found")
        for i = 1, 120 do
            if (_G["BT4Button" .. i]) then
                _G["BT4Button" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
            end
            if (_G["BT4PetButton" .. i]) then
                _G["BT4PetButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
            end

            if (_G["BT4StanceButton" .. i]) then
                _G["BT4StanceButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
            end
        end
    end

    local function modButton(button, secondaryBar)
        local action = button.action;
        local texture = nil;
        if (action) then
            texture = GetActionTexture(action);
        end

        button.NormalTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        if (uuidb.general.hidehotkeys) then
            button.HotKey:Hide();
        elseif (texture or secondaryBar) then
            button.HotKey:Show();
        end

        if (uuidb.general.hidemacros) then
            button.Name:Hide();
        else
            button.Name:Show();
        end
    end

    for i = 1, 12 do
        modButton(_G["ActionButton" .. i]);
        modButton(_G["MultiBarBottomLeftButton" .. i]);
        modButton(_G["MultiBarBottomRightButton" .. i]);
        modButton(_G["MultiBarRightButton" .. i]);
        modButton(_G["MultiBarLeftButton" .. i]);
        modButton(_G["MultiBar5Button" .. i]);
        modButton(_G["MultiBar6Button" .. i]);
        modButton(_G["MultiBar7Button" .. i]);
        if (i < 11) then
            modButton(_G["StanceButton" .. i]);
            modButton(_G["PetActionButton" .. i]);
        end

        _G["ActionButton" .. i].RightDivider:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    end

    for _, border in pairs({ MainMenuBar.BorderArt:GetRegions() }) do
        border:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    end
end

UberUI.actionbars = actionbars
