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

    for i = 1, 12 do
        _G["ActionButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["ActionButton" .. i].RightDivider:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["MultiBarBottomLeftButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["MultiBarBottomRightButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["MultiBarRightButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["MultiBarLeftButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["MultiBar5Button" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["MultiBar6Button" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["MultiBar7Button" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        if (i < 11) then
            _G["StanceButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
            _G["PetActionButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        end

        if (uuidb.general.hidehotkeys) then
            _G["ActionButton" .. i .. "HotKey"]:Hide();
            _G["MultiBarBottomLeftButton" .. i .. "HotKey"]:Hide();
            _G["MultiBarBottomRightButton" .. i .. "HotKey"]:Hide();
            _G["MultiBarRightButton" .. i .. "HotKey"]:Hide();
            _G["MultiBarLeftButton" .. i .. "HotKey"]:Hide();
            _G["MultiBar5Button" .. i .. "HotKey"]:Hide();
            _G["MultiBar6Button" .. i .. "HotKey"]:Hide();
            _G["MultiBar7Button" .. i .. "HotKey"]:Hide();
            if (i < 11) then
                _G["StanceButton" .. i .. "HotKey"]:Hide();
                _G["PetActionButton" .. i .. "HotKey"]:Hide();
            end
        else
            _G["ActionButton" .. i .. "HotKey"]:Show();
            _G["MultiBarBottomLeftButton" .. i .. "HotKey"]:Show();
            _G["MultiBarBottomRightButton" .. i .. "HotKey"]:Show();
            _G["MultiBarRightButton" .. i .. "HotKey"]:Show();
            _G["MultiBarLeftButton" .. i .. "HotKey"]:Show();
            _G["MultiBar5Button" .. i .. "HotKey"]:Show();
            _G["MultiBar6Button" .. i .. "HotKey"]:Show();
            _G["MultiBar7Button" .. i .. "HotKey"]:Show();
            if (i < 11) then
                _G["StanceButton" .. i .. "HotKey"]:Show();
                _G["PetActionButton" .. i .. "HotKey"]:Show();
            end
        end

        if (uuidb.general.hidemacros) then
            _G["ActionButton" .. i .. "Name"]:Hide();
            _G["MultiBarBottomLeftButton" .. i .. "Name"]:Hide();
            _G["MultiBarBottomRightButton" .. i .. "Name"]:Hide();
            _G["MultiBarRightButton" .. i .. "Name"]:Hide();
            _G["MultiBarLeftButton" .. i .. "Name"]:Hide();
            _G["MultiBar5Button" .. i .. "Name"]:Hide();
            _G["MultiBar6Button" .. i .. "Name"]:Hide();
            _G["MultiBar7Button" .. i .. "Name"]:Hide();
            if (i < 11) then
                _G["StanceButton" .. i .. "Name"]:Hide();
                _G["PetActionButton" .. i .. "Name"]:Hide();
            end
        else
            _G["ActionButton" .. i .. "Name"]:Show();
            _G["MultiBarBottomLeftButton" .. i .. "Name"]:Show();
            _G["MultiBarBottomRightButton" .. i .. "Name"]:Show();
            _G["MultiBarRightButton" .. i .. "Name"]:Show();
            _G["MultiBarLeftButton" .. i .. "Name"]:Show();
            _G["MultiBar5Button" .. i .. "Name"]:Show();
            _G["MultiBar6Button" .. i .. "Name"]:Show();
            _G["MultiBar7Button" .. i .. "Name"]:Show();
            if (i < 11) then
                _G["StanceButton" .. i .. "Name"]:Show();
                _G["PetActionButton" .. i .. "Name"]:Show();
            end
        end
    end

    for _, border in pairs({ MainMenuBar.BorderArt:GetRegions() }) do
        border:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    end
end

UberUI.actionbars = actionbars
