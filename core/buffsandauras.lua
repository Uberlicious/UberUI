local addon, ns = ...
local buffsandauras = {}

if not buffsandauras.borderFrames then
    buffsandauras.borderFrames = setmetatable({}, {__mode = "k"})
end

function buffsandauras:StyleAuraButton(button)
    if not button or type(button) ~= "table" or not button.GetObjectType or button:GetObjectType() ~= "Button" and button:GetObjectType() ~= "Frame" then
        return
    end

    local iconTex = button.Icon or button.icon
    if not iconTex then
        return
    end

    if button.isAuraAnchor then return end

    if uuidb.general.buffauraborders and button:IsShown() then
        local iconTexture = iconTex
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
        
        local borderFrame = buffsandauras.borderFrames[button]
        if not borderFrame then
            borderFrame = CreateFrame("Frame", nil, button:GetParent() or UIParent)
            borderFrame:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -5, 5)
            borderFrame:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 5, -5)
            
            -- Safely attempt to set frame level, fallback to a high number if button is restricted
            local ok, level = pcall(function() return button:GetFrameLevel() end)
            if ok and level then
                borderFrame:SetFrameLevel(level + 5)
            else
                borderFrame:SetFrameLevel(100)
            end
            
            local tex = borderFrame:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            tex:SetAtlas("ui-debuff-border-default-noicon")
            tex:SetDesaturated(true)
            borderFrame.texture = tex
            buffsandauras.borderFrames[button] = borderFrame
        end
        
        local showCustomBorder = false
        -- Modern WoW templates use button.debuffType or button.auraData.dispelName
        local dtype = button.debuffType or (button.auraData and button.auraData.dispelName)
        if not dtype and button.auraInstanceID then
            local p = button:GetParent()
            local unit = button.unit or (p and p.GetUnit and p:GetUnit()) or "target"
            if unit then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, button.auraInstanceID)
                if aura then
                    dtype = aura.dispelName
                end
            end
        end
        
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
            borderFrame.texture:SetVertexColor(r, g, b, a)
            borderFrame:Show()
        else
            borderFrame:Hide()
        end
    else
        local borderFrame = buffsandauras.borderFrames[button]
        if borderFrame then
            borderFrame:Hide()
        end
        local iconTex = button.Icon or button.icon
        if iconTex then
            iconTex:SetTexCoord(0, 1, 0, 1)
            UberUI.general:ApplyIconZoom(iconTex, uuidb.general.zoomiconbuffs)
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
        if not frame or depth > 10 then return end
        for _, v in pairs({ frame:GetChildren() }) do
            if v and v.GetObjectType then
                local isAura = false
                local objType = v:GetObjectType()
                if objType == "Frame" or objType == "Button" then
                    local iconObj = v.Icon or v.icon
                    if iconObj and iconObj.GetObjectType and iconObj:GetObjectType() == "Texture" then
                        if v.Count or v.count or v.Border or v.border or v.Cooldown or v.cooldown or (v.GetName and not v:GetName()) or v.DebuffBorder then
                            isAura = true
                        end
                    end
                end
                
                if isAura then
                    if uuidb.general.buffauraborders then
                        v.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        local r, g, b, a = dc.r, dc.g, dc.b, dc.a
                        
                        local borderFrame = buffsandauras.borderFrames[v]
                        if not borderFrame then
                            borderFrame = CreateFrame("Frame", nil, v:GetParent() or UIParent)
                            borderFrame:SetPoint("TOPLEFT", v.Icon, "TOPLEFT", -5, 5)
                            borderFrame:SetPoint("BOTTOMRIGHT", v.Icon, "BOTTOMRIGHT", 5, -5)
                            
                            local ok, level = pcall(function() return v:GetFrameLevel() end)
                            if ok and level then
                                borderFrame:SetFrameLevel(level + 5)
                            else
                                borderFrame:SetFrameLevel(100)
                            end
                            
                            local tex = borderFrame:CreateTexture(nil, "OVERLAY")
                            tex:SetAllPoints()
                            tex:SetAtlas("ui-debuff-border-default-noicon")
                            tex:SetDesaturated(true)
                            borderFrame.texture = tex
                            buffsandauras.borderFrames[v] = borderFrame
                        end
                        
                        local frameName = v.GetName and v:GetName() or ""
                        local isDebuff = frameName:find("Debuff") ~= nil or (v.Border and v.Border:IsShown()) or (v.DebuffBorder and v.DebuffBorder:IsShown())
                        local isBuff = frameName:find("Buff") ~= nil or (not isDebuff)
                        local showCustomBorder = false
                        
                        if isDebuff then
                            local dtype = v.debuffType or (v.auraData and v.auraData.dispelName)
                            if not dtype and v.auraInstanceID then
                                local p = v:GetParent()
                                local unit = v.unit or (p and p.GetUnit and p:GetUnit())
                                if unit then
                                    local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, v.auraInstanceID)
                                    if aura then
                                        dtype = aura.dispelName
                                    end
                                end
                            end
                            
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
                            borderFrame.texture:SetVertexColor(r, g, b, a)
                            borderFrame:Show()
                        else
                            borderFrame:Hide()
                        end
                    else
                        local borderFrame = buffsandauras.borderFrames[v]
                        if borderFrame then
                            borderFrame:Hide()
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
    if TargetFrame and TargetFrame.auraPools then
        for pool in TargetFrame.auraPools:EnumeratePools() do
            for frame in pool:EnumerateActive() do
                self:StyleAuraButton(frame)
            end
        end
    end
    
    local aurasContainer = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual and TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras
    if aurasContainer and aurasContainer.GetAuraGroupFrameCount then
        for _, groupKey in ipairs({"HELPFUL", "HARMFUL", "Buffs", "Debuffs", "buffs", "debuffs"}) do
            local count = aurasContainer:GetAuraGroupFrameCount(groupKey) or 0
            for i = 1, count do
                local auraFrame = aurasContainer:GetAuraGroupFrame(groupKey, i)
                if auraFrame then
                    self:StyleAuraButton(auraFrame)
                end
            end
        end
    end
    
    -- Fallback for global frames (Classic/Older retail)
    for i = 1, 40 do
        local b = _G["TargetFrameBuff"..i]
        if b then self:StyleAuraButton(b) end
        local d = _G["TargetFrameDebuff"..i]
        if d then self:StyleAuraButton(d) end
    end
    
    if FocusFrame and (not FocusFrame.smallSize) then
        HandleAuras(FocusFrame, 1);
        if FocusFrame.auraPools then
            for pool in FocusFrame.auraPools:EnumeratePools() do
                for frame in pool:EnumerateActive() do
                    self:StyleAuraButton(frame)
                end
            end
        end
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

local ticker = C_Timer.NewTicker(1, function()
    if UberUI.buffsandauras then
        UberUI.buffsandauras:ColorAuras(false)
    end
end)

-- Catch any elusive buffs when the user hovers over them for a tooltip
hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, unit)
    local owner = self:GetOwner()
    if owner and UberUI.buffsandauras then
        UberUI.buffsandauras:StyleAuraButton(owner)
    end
end)
hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, unit)
    local owner = self:GetOwner()
    if owner and UberUI.buffsandauras then
        UberUI.buffsandauras:StyleAuraButton(owner)
    end
end)
if GameTooltip.SetUnitBuffByAuraInstanceID then
    hooksecurefunc(GameTooltip, "SetUnitBuffByAuraInstanceID", function(self, unit)
        local owner = self:GetOwner()
        if owner and UberUI.buffsandauras then
            UberUI.buffsandauras:StyleAuraButton(owner)
        end
    end)
    hooksecurefunc(GameTooltip, "SetUnitDebuffByAuraInstanceID", function(self, unit)
        local owner = self:GetOwner()
        if owner and UberUI.buffsandauras then
            UberUI.buffsandauras:StyleAuraButton(owner)
        end
    end)
end

UberUI.buffsandauras = buffsandauras
