---------------------------------------
-- VARIABLES
---------------------------------------

--get the addon namespace
local addon, ns = ...
local actionbars = {}

local buffsandauras = UberUI:CreateFrame("frame")
buffsandauras:RegisterEvent("ADDON_LOADED")
buffsandauras:RegisterEvent("PLAYER_ENTERING_WORLD")
buffsandauras:RegisterEvent("PLAYER_TARGET_CHANGED")
buffsandauras:RegisterEvent("PLAYER_FOCUS_CHANGED")
buffsandauras:RegisterEvent("UNIT_AURA")
buffsandauras:SetScript("OnEvent", function(self, event)
    self:ColorBuffs();
    self:ColorAuras();
end)

function buffsandauras:Refresh()
    self:ColorBuffs(true);
    self:ColorAuras(true);
end

function buffsandauras:ColorBuffs(force)
    local dc = uuidb.general.darkencolor;
    local iconPadding = BuffFrame.AuraContainer.iconPadding;
    local tx = MultiBarBottomRightButton1NormalTexture:GetAtlas()
    for _, v in ipairs({ BuffFrame.AuraContainer:GetChildren() }) do
        if (force) then
            v.styled = nil;
        end

        if not v.originalSize and v.Icon then
            v.originalSize = v.Icon:GetSize();
        end

        if (not v.styled or force) and v.Icon and v.originalSize then
            if uuidb.general.buffauraborders then
                -- v.Icon:SetSize(v.originalSize - 2.2, v.originalSize - 2.2);
                -- v.Icon:SetTexCoord(.05, .95, .05, .95);
                v.NormalTexture = v.NormalTexture or UberUI:CreateFrame("Frame", "BuffAuraBorder", v)
                v.NormalTexture:SetSize(v.originalSize + 1 + iconPadding, v.originalSize + 1 + iconPadding)
                v.NormalTexture:SetPoint("CENTER", v.Icon, "CENTER", 2, -2);
                v.NormalTexture.texture = v.NormalTexture.texture or
                    v.NormalTexture:CreateTexture("BuffNormalTexture", "OVERLAY");
                v.NormalTexture.texture:SetAllPoints()
                v.NormalTexture.texture:SetAtlas(tx)
                v.NormalTexture.texture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            else
                if v.NormalTexture then
                    v.NormalTexture:Hide();
                end
                -- v.Icon:SetSize(v.originalSize, v.originalSize);
                v.Icon:SetTexCoord(0, 1, 0, 1);
            end
            v.styled = true;
        end

        if v.NormalTexture then
            if uuidb.general.buffauraborders then
                v.NormalTexture:Show();
            else
                v.NormalTexture:Hide();
            end
        end
    end
end

function buffsandauras:ColorAuras(force)
    local dc = uuidb.general.darkencolor;
    local tx = MultiBarBottomRightButton1NormalTexture:GetAtlas()

    local function HandleAuras(frame)
        local frameName = frame:GetName();
        for _, v in pairs({ frame:GetChildren() }) do
            if (force) then
                v.styled = nil;
            end

            if not v.styled and v.Icon then
                if uuidb.general.buffauraborders then
                    local iconSize = v.Icon:GetSize();
                    v.NormalTexture = v.NormalTexture or UberUI:CreateFrame("Frame", frameName .. "AuraBorder", v);
                    -- v.NormalTexture:SetSize(iconSize + 4, iconSize + 4);
                    if (v:GetName() == frameName .. "SpellBar") then
                        v.NormalTexture:SetPoint("RIGHT", v, "LEFT", 2, -7);
                    else
                        v.NormalTexture:SetPoint("TOPLEFT", v, "TOPLEFT", 0, 0);
                        v.NormalTexture:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", 3, -3);
                    end
                    if (v.Count) then
                        v.Count:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", 1, 0);
                    end
                    v.NormalTexture.texture = v.NormalTexture.texture or v.NormalTexture:CreateTexture(nil, "OVERLAY");
                    v.NormalTexture.texture:SetAllPoints();
                    v.NormalTexture.texture:SetAtlas(tx);
                    v.NormalTexture.texture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
                else
                    if v.NormalTexture then
                        v.NormalTexture:Hide();
                    end
                end
                v.styled = true;
            end
        end
    end

    HandleAuras(TargetFrame);

    if (not FocusFrame.smallSize) then
        HandleAuras(FocusFrame);
    end
end

UberUI.buffsandauras = buffsandauras
