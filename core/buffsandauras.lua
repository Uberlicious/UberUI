---------------------------------------
-- VARIABLES
---------------------------------------

--get the addon namespace
local addon, ns = ...
local actionbars = {}

local buffsandauras = CreateFrame("frame")
buffsandauras:RegisterEvent("ADDON_LOADED")
buffsandauras:RegisterEvent("PLAYER_ENTERING_WORLD")
buffsandauras:RegisterEvent("PLAYER_TARGET_CHANGED")
buffsandauras:RegisterEvent("PLAYER_FOCUS_CHANGED")
buffsandauras:RegisterEvent("UNIT_AURA")
buffsandauras:SetScript("OnEvent", function(self, event)
    self:ColorBuffs();
    self:ColorAuras();
end)

function buffsandauras:ColorBuffs()
    local dc = uuidb.general.darkencolor;
    local iconSize = 35;
    local iconPadding = BuffFrame.AuraContainer.iconPadding;
    local tx = MultiBarBottomRightButton1NormalTexture:GetAtlas()
    for _, v in ipairs({ BuffFrame.AuraContainer:GetChildren() }) do
        if not v.styled and v.Icon then
            iconSize = v.Icon:GetSize() + 1;
            v.NormalTexture = CreateFrame("Frame", "BuffAuraBorder", v)
            v.NormalTexture:SetSize(iconSize + iconPadding, iconSize + iconPadding)
            v.NormalTexture:SetPoint("TOPLEFT", v, "TOPLEFT", -1, 1);
            v.NormalTexture.texture = v.NormalTexture:CreateTexture("BuffNormalTexture", "OVERLAY");
            v.NormalTexture.texture:SetAllPoints()
            v.NormalTexture.texture:SetAtlas(tx)
            v.NormalTexture.texture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            v.styled = true;
        end
    end
end

function buffsandauras:ColorAuras()
    local dc = uuidb.general.darkencolor;
    local tx = MultiBarBottomRightButton1NormalTexture:GetAtlas()

    local function AddBorderAndTexture(frame)
        local frameName = frame:GetName();
        for _, v in pairs({ frame:GetChildren() }) do
            if not v.styled and v.Icon then
                local iconSize = v.Icon:GetSize();
                v.NormalTexture = CreateFrame("Frame", frameName .. "AuraBorder", v);
                v.NormalTexture:SetSize(iconSize + 4, iconSize + 4);
                if (v:GetName() == frameName .. "SpellBar") then
                    v.NormalTexture:SetPoint("RIGHT", v, "LEFT", 2, -7);
                else
                    v.NormalTexture:SetPoint("TOPLEFT", v, "TOPLEFT", 0, 0);
                    v.NormalTexture:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", 3, -3);
                end
                if (v.Count) then
                    v.Count:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", 1, 0);
                end
                v.NormalTexture.texture = v.NormalTexture:CreateTexture(nil, "OVERLAY");
                v.NormalTexture.texture:SetAtlas(tx);
                v.NormalTexture.texture:SetAllPoints();
                v.NormalTexture.texture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
                v.styled = true;
            elseif ((v.styled and v.Stealable and v.Stealable:IsShown()) or
                (v.styled and v.Border and v.Border:IsShown())) then
                v.NormalTexture:Hide();
            elseif (v.styled) then
                v.NormalTexture:Show()
                local iconSize = v.Icon:GetSize();
                v.NormalTexture:SetSize(iconSize + 4, iconSize + 4);
            end
        end
    end

    AddBorderAndTexture(TargetFrame);

    if (not FocusFrame.smallSize) then
        AddBorderAndTexture(FocusFrame);
    end
end

UberUI.buffsandauras = buffsandauras
