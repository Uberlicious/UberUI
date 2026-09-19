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
        
        if not button.UberUIBorderFrame then
            button.UberUIBorderFrame = CreateFrame("Frame", nil, button)
            button.UberUIBorderFrame:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -5, 5)
            button.UberUIBorderFrame:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 5, -5)
            button.UberUIBorderFrame:SetFrameLevel(button:GetFrameLevel() + 5)
            
            local tex = button.UberUIBorderFrame:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            tex:SetAtlas("ui-debuff-border-default-noicon")
            tex:SetDesaturated(true)
            button.UberUIBorderFrame.texture = tex
        end
        
        local showCustomBorder = false
        -- Modern WoW templates use button.debuffType or button.auraData.dispelName
        local dtype = button.debuffType or (button.auraData and button.auraData.dispelName)
        local isDebuff = button.auraType == "Debuff" or dtype ~= nil or (button.Border and button.Border:IsShown()) or (button.DebuffBorder and button.DebuffBorder:IsShown())
        
        if isDebuff then
            local borderObj = button.DebuffBorder or button.Border
            if borderObj then
                borderObj:ClearAllPoints()
                borderObj:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -5, 5)
                borderObj:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 5, -5)
                
                if not dtype or dtype == "" or string.lower(dtype) == "none" then
                    borderObj:SetAlpha(0)
                    showCustomBorder = true
                else
                    borderObj:SetAlpha(1)
                end
            else
                showCustomBorder = true
            end
        elseif button.auraType == "TempEnchant" then
            if button.TempEnchantBorder then
                button.TempEnchantBorder:ClearAllPoints()
                button.TempEnchantBorder:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -2, 2)
                button.TempEnchantBorder:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 2, -2)
                button.TempEnchantBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
        else
            -- It's a buff
            showCustomBorder = true
        end
        
        if showCustomBorder then
            local r, g, b, a = dc.r, dc.g, dc.b, dc.a
            if button.isStealable or (button.Stealable and button.Stealable:IsShown()) then
                r, g, b, a = 1, 1, 1, 1
            end
            button.UberUIBorderFrame.texture:SetVertexColor(r, g, b, a)
            button.UberUIBorderFrame:Show()
        else
            button.UberUIBorderFrame:Hide()
        end
    else
        if button.UberUIBorderFrame then
            button.UberUIBorderFrame:Hide()
        end
        if button.Icon then
            button.Icon:SetTexCoord(0, 1, 0, 1)
            UberUI.general:ApplyIconZoom(button.Icon, uuidb.general.zoomiconbuffs)
        end
        local borderObj = button.DebuffBorder or button.Border
        if borderObj then
            borderObj:SetAlpha(1)
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

    local function HandleAuras(frame, depth)
        if not frame or depth > 5 then return end
        for _, v in pairs({ frame:GetChildren() }) do
            if v and v.GetObjectType then
                local isAura = false
                local objType = v:GetObjectType()
                if objType == "Frame" or objType == "Button" then
                    if v.Icon and v.Icon.GetObjectType and v.Icon:GetObjectType() == "Texture" then
                        if v.Count or v.Border or v.Cooldown or (v.GetName and not v:GetName()) or v.DebuffBorder then
                            isAura = true
                        end
                    end
                end
                
                if isAura then
                    if uuidb.general.buffauraborders then
                        v.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        local dc = uuidb.general.darkencolor
                        if not v.UberUIBorderFrame then
                            v.UberUIBorderFrame = CreateFrame("Frame", nil, v)
                            v.UberUIBorderFrame:SetPoint("TOPLEFT", v.Icon, "TOPLEFT", -5, 5)
                            v.UberUIBorderFrame:SetPoint("BOTTOMRIGHT", v.Icon, "BOTTOMRIGHT", 5, -5)
                            v.UberUIBorderFrame:SetFrameLevel(v:GetFrameLevel() + 5)
                            
                            local tex = v.UberUIBorderFrame:CreateTexture(nil, "OVERLAY")
                            tex:SetAllPoints()
                            tex:SetAtlas("ui-debuff-border-default-noicon")
                            tex:SetDesaturated(true)
                            v.UberUIBorderFrame.texture = tex
                        end
                        
                        local r, g, b, a = dc.r, dc.g, dc.b, dc.a
                        local frameName = v.GetName and v:GetName() or ""
                        local isDebuff = frameName:find("Debuff") ~= nil or (v.Border and v.Border:IsShown()) or (v.DebuffBorder and v.DebuffBorder:IsShown())
                        local isBuff = frameName:find("Buff") ~= nil or (not isDebuff)
                        local showCustomBorder = false
                        
                        if isDebuff then
                            local dtype = v.debuffType
                            
                            local borderObj = v.Border or v.DebuffBorder
                            if borderObj then
                                borderObj:ClearAllPoints()
                                borderObj:SetPoint("TOPLEFT", v.Icon, "TOPLEFT", -5, 5)
                                borderObj:SetPoint("BOTTOMRIGHT", v.Icon, "BOTTOMRIGHT", 5, -5)
                                
                                if not dtype or dtype == "" or string.lower(dtype) == "none" then
                                    borderObj:SetAlpha(0)
                                    showCustomBorder = true
                                else
                                    borderObj:SetAlpha(1)
                                end
                            end
                        elseif isBuff then
                            showCustomBorder = true
                            if v.isStealable or v.Stealable and v.Stealable:IsShown() then
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
                        if v.Border then
                            v.Border:SetAlpha(1)
                        end
                    end
                else
                    HandleAuras(v, depth + 1)
                end
            end
        end
    end

    HandleAuras(TargetFrame, 1);
    if FocusFrame and (not FocusFrame.smallSize) then
        HandleAuras(FocusFrame, 1);
    end
end

if AuraFrameMixin then
    hooksecurefunc(AuraFrameMixin, "UpdateAuraButtons", function(self)
        for _, button in ipairs(self.auraFrames) do
            UberUI.buffsandauras:StyleAuraButton(button)
        end
    end)
end

if AuraContainerMixin then
    hooksecurefunc(AuraContainerMixin, "UpdateGridLayout", function(self, auras)
        if type(auras) == "table" then
            for _, button in ipairs(auras) do
                UberUI.buffsandauras:StyleAuraButton(button)
            end
        end
    end)
end

UberUI.buffsandauras = buffsandauras
