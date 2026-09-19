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
            iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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
            button.UberUIBorderFrame:SetPoint("TOPLEFT", button.Icon or button, "TOPLEFT", -5, 5)
            button.UberUIBorderFrame:SetPoint("BOTTOMRIGHT", button.Icon or button, "BOTTOMRIGHT", 5, -5)
            button.UberUIBorderFrame:SetFrameLevel(button:GetFrameLevel() + 5)
            
            local tex = button.UberUIBorderFrame:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            tex:SetAtlas("ui-debuff-border-default-noicon")
            tex:SetDesaturated(true)
            button.UberUIBorderFrame.texture = tex
        end

        local showCustomBorder = false

        if button.auraType == "TempEnchant" then
            -- Native purple border is handled by Blizzard, but it's natively too tight (32x32)
            -- We stretch it out to cover the sharp square corners of the zoomed icon
            if button.TempEnchantBorder then
                button.TempEnchantBorder:ClearAllPoints()
                button.TempEnchantBorder:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -2, 2)
                button.TempEnchantBorder:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 2, -2)
            end
        elseif button.auraType == "Debuff" then
            local dtype = button.auraData and button.auraData.dispelName or button.debuffType
            if button.DebuffBorder then
                button.DebuffBorder:ClearAllPoints()
                button.DebuffBorder:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -5, 5)
                button.DebuffBorder:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 5, -5)
            end
        else
            -- It's a Buff! Show our custom desaturated dark border
            showCustomBorder = true
            button.UberUIBorderFrame.texture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        end

        if showCustomBorder then
            button.UberUIBorderFrame:Show()
        else
            button.UberUIBorderFrame:Hide()
        end
    else
        -- Only hide our custom additions, let Blizzard manage its own borders natively
        if button.NormalTexture then
            button.NormalTexture:Show()
        end
        if button.UberUIBorderFrame then
            button.UberUIBorderFrame:Hide()
        end
        if button.Icon then
            button.Icon:SetTexCoord(0, 1, 0, 1)
            UberUI.general:ApplyIconZoom(button.Icon, uuidb.general.zoomiconbuffs)
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
                    v.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    local dc = uuidb.general.darkencolor
                    if not v.UberUIBorderFrame then
                        v.UberUIBorderFrame = CreateFrame("Frame", nil, v)
                        v.UberUIBorderFrame:SetPoint("TOPLEFT", v.Icon or v, "TOPLEFT", -5, 5)
                        v.UberUIBorderFrame:SetPoint("BOTTOMRIGHT", v.Icon or v, "BOTTOMRIGHT", 5, -5)
                        v.UberUIBorderFrame:SetFrameLevel(v:GetFrameLevel() + 5)
                        
                        local tex = v.UberUIBorderFrame:CreateTexture(nil, "OVERLAY")
                        tex:SetAllPoints()
                        tex:SetAtlas("ui-debuff-border-default-noicon")
                        tex:SetDesaturated(true)
                        v.UberUIBorderFrame.texture = tex
                    end
                    
                    local r, g, b, a = dc.r, dc.g, dc.b, dc.a
                    local frameName = v.GetName and v:GetName() or ""
                    local showCustomBorder = false
                    
                    if (frameName:find("Debuff")) then
                        local dtype = v.debuffType
                        
                        if v.Border then
                            v.Border:ClearAllPoints()
                            v.Border:SetPoint("TOPLEFT", v.Icon, "TOPLEFT", -5, 5)
                            v.Border:SetPoint("BOTTOMRIGHT", v.Icon, "BOTTOMRIGHT", 5, -5)
                        end
                    elseif (frameName:find("Buff")) then
                        showCustomBorder = true
                        if v.isStealable or v.Stealable and v.Stealable:IsShown() then
                            -- Stealable buffs are highlighted white
                            r, g, b, a = 1, 1, 1, 1
                        end
                    end
                    
                    if showCustomBorder then
                        v.UberUIBorderFrame.texture:SetVertexColor(r, g, b, a)
                        v.UberUIBorderFrame:Show()
                    else
                        v.UberUIBorderFrame:Hide()
                    end
                else
                    if v.UberUIBorderFrame then
                        v.UberUIBorderFrame:Hide()
                    end
                    if v.Icon then
                        v.Icon:SetTexCoord(0, 1, 0, 1)
                        UberUI.general:ApplyIconZoom(v.Icon, uuidb.general.zoomicontarget)
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
