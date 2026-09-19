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
            button.UberUIBorderFrame:SetSize(button.Icon:GetWidth() + 10, button.Icon:GetHeight() + 10)
            button.UberUIBorderFrame:SetPoint("CENTER", button.Icon or button, "CENTER", 0, 0)
            button.UberUIBorderFrame:SetFrameLevel(button:GetFrameLevel() + 5)
            
            local tex = button.UberUIBorderFrame:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            tex:SetAtlas("ui-debuff-border-default-noicon")
            tex:SetDesaturated(true)
            button.UberUIBorderFrame.texture = tex
        end

        local showCustomBorder = false

        if button.auraType == "TempEnchant" then
            -- Native purple border is handled by Blizzard
        elseif button.auraType == "Debuff" then
            local dtype = button.auraData and button.auraData.dispelName or button.debuffType or "none"
            dtype = string.lower(dtype)
            local color = DebuffTypeColor and DebuffTypeColor[dtype]
            
            if button.DebuffBorder then
                if dtype == "none" or dtype == "" or not color then
                    -- Typeless debuff: desaturate the native border and tint it custom dark
                    button.DebuffBorder:SetDesaturated(true)
                    button.DebuffBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                else
                    -- Typed debuff: restore saturation so Blizzard's native color works
                    button.DebuffBorder:SetDesaturated(false)
                end
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
                        v.UberUIBorderFrame:SetSize(v.Icon:GetWidth() + 10, v.Icon:GetHeight() + 10)
                        v.UberUIBorderFrame:SetPoint("CENTER", v.Icon or v, "CENTER", 0, 0)
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
                        local dtype = v.debuffType or "none"
                        dtype = string.lower(dtype)
                        local color = DebuffTypeColor and DebuffTypeColor[dtype]
                        
                        if v.Border then
                            if dtype == "none" or dtype == "" or not color then
                                -- Typeless debuff: desaturate the native border and tint it custom dark
                                v.Border:SetDesaturated(true)
                                v.Border:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                            else
                                -- Typed debuff: let Blizzard color the native border!
                                v.Border:SetDesaturated(false)
                                if color then
                                    v.Border:SetVertexColor(color.r, color.g, color.b, 1)
                                end
                            end
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
