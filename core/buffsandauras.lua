local addon, ns = ...
local buffsandauras = {}

function buffsandauras:StyleAuraButton(button)
    if not button or not button.Icon then
        return
    end

    if button.isAuraAnchor then return end

    if uuidb.general.buffauraborders and button:IsShown() then
        local iconTexture = button.Icon
        if not iconTexture then
            for _, region in pairs({ button:GetRegions() }) do
                if region:IsObjectType("Texture") then
                    iconTexture = region
                    break
                end
            end
        end
        if iconTexture then
            UberUI.general:ApplyIconZoom(iconTexture, uuidb.general.zoomiconbuffs)
        end

        local dc = uuidb.general.darkencolor
        
        -- In modern WoW, AuraButtonTemplate is used for both buffs and debuffs.
        -- We must let Blizzard natively manage the visibility of DebuffBorder and TempEnchantBorder.
        if button.DebuffBorder then
            local r, g, b, a = button.DebuffBorder:GetVertexColor()
            local noneColor = DebuffTypeColor and DebuffTypeColor["none"] or {r=0, g=0, b=0}
            -- If it is a generic debuff (natively colored red), we tint it to the darkencolor
            if r == noneColor.r and g == noneColor.g and b == noneColor.b then
                button.DebuffBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
        end
        if button.TempEnchantBorder then
            button.TempEnchantBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        end

        -- Create a custom border if one doesn't exist
        if not button.UberUIBorderFrame then
            button.UberUIBorderFrame = CreateFrame("Frame", nil, button)
            button.UberUIBorderFrame:SetSize(button.Icon:GetWidth() + 6, button.Icon:GetHeight() + 6)
            button.UberUIBorderFrame:SetPoint("CENTER", button.Icon or button, "CENTER", 0, 0)
            button.UberUIBorderFrame:SetFrameLevel(button:GetFrameLevel() + 5)
            
            local tex = button.UberUIBorderFrame:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            local tx = MultiBarBottomRightButton1NormalTexture and MultiBarBottomRightButton1NormalTexture:GetAtlas()
            if tx then
                tex:SetAtlas(tx)
            else
                tex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            end
            button.UberUIBorderFrame.texture = tex
        end
        button.UberUIBorderFrame.texture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        button.UberUIBorderFrame:Show()
    else
        -- Only hide our custom additions, let Blizzard manage its own borders natively
        if button.NormalTexture then
            button.NormalTexture:Hide()
        end
        if button.UberUIBorderFrame then
            button.UberUIBorderFrame:Hide()
        end
    end
end

function buffsandauras:Refresh()
    if BuffFrame then
        if BuffFrame.auraFrames then
            for _, button in ipairs(BuffFrame.auraFrames) do
                self:StyleAuraButton(button)
            end
        else
            for i = 1, 32 do
                local btn = _G["BuffButton"..i]
                if btn then self:StyleAuraButton(btn) end
            end
        end
    end

    if DebuffFrame then
        if DebuffFrame.auraFrames then
            for _, button in ipairs(DebuffFrame.auraFrames) do
                self:StyleAuraButton(button)
            end
        else
            for i = 1, 16 do
                local btn = _G["DebuffButton"..i]
                if btn then self:StyleAuraButton(btn) end
            end
        end
    end

    self:ColorAuras(true)
end

function buffsandauras:ColorAuras(force)
    local dc = uuidb.general.darkencolor;
    local tx = MultiBarBottomRightButton1NormalTexture and MultiBarBottomRightButton1NormalTexture:GetAtlas()

    local function HandleAuras(frame)
        if not frame then return end
        local frameName = frame:GetName();
        for _, v in pairs({ frame:GetChildren() }) do
            if (force) then
                v.styled = nil;
            end

            if not v.styled and v.Icon then
                if uuidb.general.buffauraborders then
                    local dc = uuidb.general.darkencolor
                    if not v.UberUIBorderFrame then
                        v.UberUIBorderFrame = CreateFrame("Frame", nil, v)
                        v.UberUIBorderFrame:SetSize(v.Icon:GetWidth() + 6, v.Icon:GetHeight() + 6)
                        v.UberUIBorderFrame:SetPoint("CENTER", v.Icon or v, "CENTER", 0, 0)
                        v.UberUIBorderFrame:SetFrameLevel(v:GetFrameLevel() + 5)
                        
                        local tex = v.UberUIBorderFrame:CreateTexture(nil, "OVERLAY")
                        tex:SetAllPoints()
                        local tx = MultiBarBottomRightButton1NormalTexture and MultiBarBottomRightButton1NormalTexture:GetAtlas()
                        if tx then
                            tex:SetAtlas(tx)
                        else
                            tex:SetTexture("Interface\\Buttons\\UI-Quickslot2")
                        end
                        v.UberUIBorderFrame.texture = tex
                    end
                    v.UberUIBorderFrame.texture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                    v.UberUIBorderFrame:Show()
                else
                    if v.UberUIBorderFrame then
                        v.UberUIBorderFrame:Hide()
                    end
                end
                v.styled = true;
            end
        end
    end

    HandleAuras(TargetFrame);

    if FocusFrame and (not FocusFrame.smallSize) then
        HandleAuras(FocusFrame);
    end
end

if AuraFrameMixin then
    hooksecurefunc(AuraFrameMixin, "UpdateAuraButtons", function(self)
        for _, button in ipairs(self.auraFrames) do
            UberUI.buffsandauras:StyleAuraButton(button)
        end
    end)
end

UberUI.buffsandauras = buffsandauras
