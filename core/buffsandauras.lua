local addon, ns = ...
local buffsandauras = {}

if not buffsandauras.borderFrames then
    buffsandauras.borderFrames = setmetatable({}, {__mode = "k"})
end

local function GetAuraInfo(button)
    local isPlayer = false
    local isDebuff = false
    local btnName = (button.GetName and button:GetName()) or ""
    local isTempEnchant = false
    pcall(function()
        isTempEnchant = (button.isTempEnchant == true)
            or (button.auraType == "TempEnchant")
            or (button.buttonInfo and button.buttonInfo.auraType == "TempEnchant")
            or (btnName ~= "" and btnName:find("^TempEnchant") ~= nil)
            or (button.TempEnchantBorder and button.TempEnchantBorder.IsShown and button.TempEnchantBorder:IsShown())
    end)

    if isTempEnchant then
        isPlayer = true
    end

    if button.isDebuff ~= nil then
        pcall(function()
            if not (issecretvalue and issecretvalue(button.isDebuff)) then
                isDebuff = (button.isDebuff == true)
            end
        end)
    end

    local cur = button
    while cur do
        if cur == DebuffFrame then
            isPlayer = true
            isDebuff = true
            break
        elseif cur == BuffFrame or cur == TemporaryEnchantFrame then
            isPlayer = true
            break
        end
        local curName = cur.GetName and cur:GetName() or ""
        if curName:find("DebuffFrame") or curName:find("^DebuffButton") then
            isPlayer = true
            isDebuff = true
            break
        elseif curName:find("BuffFrame") or curName:find("^BuffButton") or curName:find("^TempEnchant") then
            isPlayer = true
            break
        end
        cur = cur.GetParent and cur:GetParent()
    end

    if button.isDebuff == nil then
        if DebuffFrame and DebuffFrame.auraFrames then
            for _, af in ipairs(DebuffFrame.auraFrames) do
                if af == button then
                    isPlayer = true
                    isDebuff = true
                    break
                end
            end
        end

        if not isPlayer and BuffFrame and BuffFrame.auraFrames then
            for _, af in ipairs(BuffFrame.auraFrames) do
                if af == button then
                    isPlayer = true
                    break
                end
            end
        end

        if button.auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
            local p = button.GetParent and button:GetParent()
            local unit = button.unit or (p and p.GetUnit and p:GetUnit()) or (isPlayer and "player") or "target"
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, button.auraInstanceID)
            if aura then
                if aura.isHarmful then
                    isDebuff = true
                elseif aura.isHelpful then
                    isDebuff = false
                end
            end
        end

        if not isDebuff then
            if button.GetAuraInstance then
                local ok, unitToken, auraData = pcall(button.GetAuraInstance, button)
                if ok and auraData and auraData.isHarmful then
                    isDebuff = true
                end
            elseif button.auraType == "Debuff" then
                isDebuff = true
            elseif button.buttonInfo and button.buttonInfo.auraType == "Debuff" then
                isDebuff = true
            elseif button.filter == "HARMFUL" or (button.buttonInfo and button.buttonInfo.filter == "HARMFUL") then
                isDebuff = true
            elseif button.auraData and button.auraData.isHarmful then
                isDebuff = true
            elseif button.DispelBorder and button.DispelBorder.IsShown and button.DispelBorder:IsShown() then
                isDebuff = true
            elseif button.DebuffBorder and button.DebuffBorder.IsShown and button.DebuffBorder:IsShown() then
                isDebuff = true
            end
        end
    end

    return isPlayer, isDebuff, isTempEnchant
end

function buffsandauras:StyleAuraButton(button)
    if not button or type(button) ~= "table" or not button.GetObjectType then
        return
    end

    local objType = button:GetObjectType()
    if objType ~= "Button" and objType ~= "Frame" and objType ~= "AuraButton" then
        return
    end

    if button.isAuraAnchor then return end

    local btnName = (button.GetName and button:GetName()) or ""
    local iconTexture = button.Icon or button.icon or (btnName ~= "" and _G[btnName .. "Icon"])
    if not iconTexture then
        for _, region in pairs({ button:GetRegions() }) do
            if region:IsObjectType("Texture") then
                if region ~= button.DebuffBorder and region ~= button.TempEnchantBorder and region ~= button.Border then
                    iconTexture = region
                    break
                end
            end
        end
    end
    if not iconTexture then return end

    local isPlayer, isDebuff, isTempEnchant = GetAuraInfo(button)

    -- Determine debuff type
    local dtype = button.debuffType or (button.auraData and button.auraData.dispelName)
    if not dtype and button.buttonInfo and button.buttonInfo.debuffType then
        dtype = button.buttonInfo.debuffType
    end
    if not dtype and button.auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        local p = button:GetParent()
        local unit = button.unit or (p and p.GetUnit and p:GetUnit()) or (isPlayer and "player") or "target"
        local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, button.auraInstanceID)
        if aura then
            dtype = aura.dispelName
        end
    end

    local isTypeless = true
    if dtype then
        local ok, lowerDtype = pcall(string.lower, dtype)
        if ok and lowerDtype and lowerDtype ~= "" and lowerDtype ~= "none" then
            isTypeless = false
        elseif not ok then
            -- Secret string: Indicates a typed debuff passed from protected code
            isTypeless = false
        end
    end

    local style = "both"
    if uuidb and uuidb.general then
        if isPlayer then
            if isDebuff then
                style = uuidb.general.aurastyle_playerdebuffs or "zoom"
            else
                style = uuidb.general.aurastyle_playerbuffs or "both"
            end
        else
            if isDebuff then
                style = uuidb.general.aurastyle_targetdebuffs or "zoom"
            else
                style = uuidb.general.aurastyle_targetbuffs or "both"
            end
        end
    end

    local borderEnabled = (style == "both" or style == "border")
    local zoomEnabled = (style == "both" or style == "zoom")

    -- Handle icon zoom
    if zoomEnabled then
        iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        iconTexture:SetTexCoord(0, 1, 0, 1)
    end

    local borderObj = button.DispelBorder or button.DebuffBorder or button.Border or (btnName ~= "" and _G[btnName .. "Border"])
    local teBorder = button.TempEnchantBorder or (isTempEnchant and (button.Border or (btnName ~= "" and _G[btnName .. "Border"])))
    local borderFrame = buffsandauras.borderFrames[button]

    if borderEnabled and button:IsShown() then
        local dc = uuidb.general.darkencolor
        
        if not borderFrame then
            borderFrame = CreateFrame("Frame", nil, button)
            borderFrame:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -5, 5)
            borderFrame:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 5, -5)
            
            local tex = borderFrame:CreateTexture(nil, "OVERLAY")
            tex:SetAllPoints()
            tex:SetAtlas("ui-debuff-border-default-noicon")
            tex:SetDesaturated(true)
            borderFrame.texture = tex
            buffsandauras.borderFrames[button] = borderFrame
        elseif borderFrame:GetParent() ~= button then
            borderFrame:SetParent(button)
        end

        -- Safely attempt to set frame level, fallback to a high number if button is restricted
        local ok, level = pcall(function() return button:GetFrameLevel() end)
        if ok and level then
            borderFrame:SetFrameLevel(level + 5)
        else
            borderFrame:SetFrameLevel(100)
        end
        
        local pad = isPlayer and 5 or 4
        pcall(function()
            local iconWidth = iconTexture.GetWidth and iconTexture:GetWidth()
            if issecretvalue and issecretvalue(iconWidth) then return end
            if type(iconWidth) == "number" and iconWidth > 0 then
                pad = math.max(2, math.floor(iconWidth * (5 / 30) + 0.5))
            end
        end)
        borderFrame:ClearAllPoints()
        borderFrame:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -pad, pad)
        borderFrame:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", pad, -pad)

        local showCustomBorder = false
        if isDebuff then
            if borderObj then
                borderObj:ClearAllPoints()
                borderObj:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -pad, pad)
                borderObj:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", pad, -pad)
                borderObj:SetAlpha(0)
            end
            showCustomBorder = true
        elseif isTempEnchant then
            if teBorder then
                teBorder:ClearAllPoints()
                teBorder:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -pad, pad)
                teBorder:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", pad, -pad)
                teBorder:SetAlpha(0)
            end
            showCustomBorder = true
        else
            -- It's a buff
            if borderObj then
                borderObj:ClearAllPoints()
                borderObj:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -pad, pad)
                borderObj:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", pad, -pad)
                borderObj:SetAlpha(0)
            end
            showCustomBorder = true
        end
        
        if showCustomBorder then
            local r, g, b, a = dc.r, dc.g, dc.b, dc.a
            local isStealable = false
            pcall(function()
                if button.isStealable then isStealable = true end
                if button.Stealable and button.Stealable.IsShown and button.Stealable:IsShown() then isStealable = true end
                if button.StealableBorder and button.StealableBorder.IsShown and button.StealableBorder:IsShown() then isStealable = true end
            end)
            if isStealable then
                r, g, b, a = 1, 1, 1, 1
            end
            borderFrame.texture:SetVertexColor(r, g, b, a)
            borderFrame:Show()
        else
            if borderFrame then
                borderFrame:Hide()
            end
        end
    else
        if borderFrame then
            borderFrame:Hide()
        end

        if borderObj and not isTempEnchant then
            local pad = zoomEnabled and (isPlayer and 5 or 4) or 0
            pcall(function()
                local iconWidth = iconTexture.GetWidth and iconTexture:GetWidth()
                if issecretvalue and issecretvalue(iconWidth) then return end
                if type(iconWidth) == "number" and iconWidth > 0 then
                    local basePad = math.max(2, math.floor(iconWidth * (5 / 30) + 0.5))
                    pad = zoomEnabled and basePad or 0
                end
            end)
            borderObj:SetAlpha(1)
            borderObj:ClearAllPoints()
            borderObj:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -pad, pad)
            borderObj:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", pad, -pad)
            borderObj:Show()
        end

        if isTempEnchant and teBorder then
            teBorder:ClearAllPoints()
            if zoomEnabled then
                teBorder:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -2, 2)
                teBorder:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 2, -2)
            else
                teBorder:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", 0, 0)
                teBorder:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", 0, 0)
            end
            teBorder:SetAlpha(1)
            teBorder:SetVertexColor(1, 1, 1, 1)
            teBorder:Show()
        end
    end

    if not button.uberUIHookedHide and button.HookScript then
        button:HookScript("OnHide", function(self)
            local bf = buffsandauras.borderFrames[self]
            if bf then bf:Hide() end
        end)
        button.uberUIHookedHide = true
    end
end

function buffsandauras:Refresh()
    if BuffFrame then
        if BuffFrame.auraFrames then
            for _, button in ipairs(BuffFrame.auraFrames) do
                button.isDebuff = false
                self:StyleAuraButton(button)
            end
        else
            for i = 1, 32 do
                local btn = _G["BuffButton"..i]
                if btn then
                    btn.isDebuff = false
                    self:StyleAuraButton(btn)
                end
            end
        end

        if BuffFrame.GetChildren then
            for _, child in pairs({ BuffFrame:GetChildren() }) do
                if child and child.GetObjectType and (child:GetObjectType() == "Button" or child:GetObjectType() == "Frame") then
                    local cName = (child.GetName and child:GetName()) or ""
                    if cName:find("^TempEnchant") then
                        child.isDebuff = false
                        child.isTempEnchant = true
                        self:StyleAuraButton(child)
                    end
                end
            end
        end
    end

    for i = 1, 3 do
        local te = _G["TempEnchant"..i]
        if te then
            te.isDebuff = false
            te.isTempEnchant = true
            self:StyleAuraButton(te)
        end
    end

    if TemporaryEnchantFrame and TemporaryEnchantFrame.GetChildren then
        for _, child in pairs({ TemporaryEnchantFrame:GetChildren() }) do
            if child and child.GetObjectType and (child:GetObjectType() == "Button" or child:GetObjectType() == "Frame") then
                child.isDebuff = false
                child.isTempEnchant = true
                self:StyleAuraButton(child)
            end
        end
    end

    if DebuffFrame then
        if DebuffFrame.auraFrames then
            for _, button in ipairs(DebuffFrame.auraFrames) do
                button.isDebuff = true
                self:StyleAuraButton(button)
            end
        else
            for i = 1, 16 do
                local btn = _G["DebuffButton"..i]
                if btn then
                    btn.isDebuff = true
                    self:StyleAuraButton(btn)
                end
            end
        end

        if DebuffFrame.GetChildren then
            for _, child in pairs({ DebuffFrame:GetChildren() }) do
                if child and child.GetObjectType and (child:GetObjectType() == "Button" or child:GetObjectType() == "Frame") then
                    local cName = child.GetName and child:GetName()
                    if child.Icon or child.icon or (cName and _G[cName.."Icon"]) then
                        child.isDebuff = true
                        self:StyleAuraButton(child)
                    elseif child.GetChildren then
                        for _, grandchild in pairs({ child:GetChildren() }) do
                            if grandchild and grandchild.GetObjectType and (grandchild:GetObjectType() == "Button" or grandchild:GetObjectType() == "Frame") then
                                local gcName = grandchild.GetName and grandchild:GetName()
                                if grandchild.Icon or grandchild.icon or (gcName and _G[gcName.."Icon"]) then
                                    grandchild.isDebuff = true
                                    self:StyleAuraButton(grandchild)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    self:ColorAuras(true)
end

function buffsandauras:ColorAuras(force)
    local dc = uuidb.general.darkencolor;
    local tx = MultiBarBottomRightButton1NormalTexture and MultiBarBottomRightButton1NormalTexture:GetAtlas()

    local function IsSecret(v)
        return (issecretvalue and issecretvalue(v))
    end

    local function HandleAuras(frame, depth)
        if not frame or depth > 10 or IsSecret(frame) then return end
        local okF, isForbid = pcall(frame.IsForbidden, frame)
        if (okF and not IsSecret(isForbid) and isForbid) or not frame.GetChildren then return end
        local fName = (frame.GetName and not IsSecret(frame.GetName) and frame:GetName()) or ""
        if IsSecret(fName) or fName:find("UberUI_Target") or fName:find("AuraContainer") or fName:find("TargetAuras") then return end

        local okKids, kids = pcall(function() return { frame:GetChildren() } end)
        if not okKids or not kids or IsSecret(kids) then return end

        for _, v in pairs(kids) do
            if not IsSecret(v) then
                local okVForbid, vForbid = pcall(function() return v.IsForbidden and v:IsForbidden() end)
                if okVForbid and not IsSecret(vForbid) and not vForbid and v and v.GetObjectType then
                    local okType, objType = pcall(v.GetObjectType, v)
                    if okType and objType and not IsSecret(objType) then
                        local isAura = false
                        local vName = (v.GetName and v:GetName()) or ""
                        if objType == "Frame" or objType == "Button" or objType == "AuraButton" then
                            local iconObj = v.Icon or v.icon or (vName ~= "" and _G[vName .. "Icon"])
                            local okIconType, iconType = pcall(function() return iconObj and iconObj.GetObjectType and iconObj:GetObjectType() end)
                            if okIconType and iconType == "Texture" then
                                if v.Count or v.count or v.Border or v.border or v.Cooldown or v.cooldown or (vName ~= "" and (vName:find("Buff") or vName:find("Debuff"))) or v.DebuffBorder or v.DispelBorder or v.StealableBorder or objType == "AuraButton" then
                                    isAura = true
                                end
                            end
                        end
                        
                        if isAura then
                            self:StyleAuraButton(v)
                        else
                            HandleAuras(v, depth + 1)
                        end
                    end
                end
            end
        end
    end

    local function StyleAuraContainer(container)
        if not container or IsSecret(container) then return end
        local okF, isForbid = pcall(container.IsForbidden, container)
        if okF and not IsSecret(isForbid) and isForbid then return end
        local cName = (container.GetName and container:GetName()) or ""
        if IsSecret(cName) or cName:find("UberUI_Target") then return end

        if container.buffAuraGroup and container.buffAuraGroup.GetFramesByIndex then
            for _, btn in ipairs(container.buffAuraGroup:GetFramesByIndex()) do
                btn.isDebuff = false
                self:StyleAuraButton(btn)
            end
        end
        if container.debuffAuraGroup and container.debuffAuraGroup.GetFramesByIndex then
            for _, btn in ipairs(container.debuffAuraGroup:GetFramesByIndex()) do
                btn.isDebuff = true
                self:StyleAuraButton(btn)
            end
        end
        if container.auraPools and container.auraPools.EnumerateActive then
            for frame in container.auraPools:EnumerateActive() do
                self:StyleAuraButton(frame)
            end
        end
        if container.GetChildren then
            for _, child in pairs({ container:GetChildren() }) do
                local okChildForbid, childForbid = pcall(function() return child.IsForbidden and child:IsForbidden() end)
                if okChildForbid and not childForbid and child and child.GetObjectType then
                    local okType, objType = pcall(child.GetObjectType, child)
                    if okType and (objType == "AuraButton" or objType == "Button") then
                        self:StyleAuraButton(child)
                    end
                end
            end
        end
    end

    -- TargetFrame aura handling (disabled on 12.1 / Forever 1.6 as native buttons are engine-forbidden)
    if false and not hasCustomAuras and not targetForbidden and TargetFrame then
        HandleAuras(TargetFrame, 1);
        local targetAuras = TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual and TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras
        StyleAuraContainer(targetAuras)

        if TargetFrame.auraPools then
            if TargetFrame.auraPools.EnumerateActive then
                for frame in TargetFrame.auraPools:EnumerateActive() do
                    self:StyleAuraButton(frame)
                end
            elseif TargetFrame.auraPools.GetPool then
                for _, tmpl in ipairs({"TargetBuffFrameTemplate", "TargetDebuffFrameTemplate"}) do
                    local pool = TargetFrame.auraPools:GetPool(tmpl)
                    if pool and pool.EnumerateActive then
                        for frame in pool:EnumerateActive() do
                            self:StyleAuraButton(frame)
                        end
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
    end
    
    if FocusFrame and (not FocusFrame.smallSize) then
        local focusForbidden = FocusFrame.IsForbidden and FocusFrame:IsForbidden()
        if not focusForbidden then
            local focusAuras = FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual and FocusFrame.TargetFrameContent.TargetFrameContentContextual.Auras
            local focusAurasForbidden = focusAuras and focusAuras.IsForbidden and focusAuras:IsForbidden()
            if not focusAurasForbidden then
                HandleAuras(FocusFrame, 1);
                StyleAuraContainer(focusAuras)
            end

            if FocusFrame.auraPools then
                if FocusFrame.auraPools.EnumerateActive then
                    for frame in FocusFrame.auraPools:EnumerateActive() do
                        self:StyleAuraButton(frame)
                    end
                elseif FocusFrame.auraPools.GetPool then
                    for _, tmpl in ipairs({"TargetBuffFrameTemplate", "TargetDebuffFrameTemplate", "FocusBuffFrameTemplate", "FocusDebuffFrameTemplate"}) do
                        local pool = FocusFrame.auraPools:GetPool(tmpl)
                        if pool and pool.EnumerateActive then
                            for frame in pool:EnumerateActive() do
                                self:StyleAuraButton(frame)
                            end
                        end
                    end
                end
            end
        end
    end
end

if AuraFrameMixin then
    hooksecurefunc(AuraFrameMixin, "UpdateAuraButtons", function(self)
        local isDebuff = (self == DebuffFrame)
        if not isDebuff then
            local cur = self
            while cur do
                if cur == DebuffFrame then
                    isDebuff = true
                    break
                end
                local n = cur.GetName and cur:GetName() or ""
                if n:find("Debuff") then
                    isDebuff = true
                    break
                end
                cur = cur.GetParent and cur:GetParent()
            end
        end

        for _, button in ipairs(self.auraFrames) do
            if isDebuff then
                button.isDebuff = true
            else
                button.isDebuff = false
            end
            UberUI.buffsandauras:StyleAuraButton(button)
        end

        if not isDebuff then
            for i = 1, 3 do
                local te = _G["TempEnchant"..i]
                if te then
                    te.isDebuff = false
                    te.isTempEnchant = true
                    UberUI.buffsandauras:StyleAuraButton(te)
                end
            end
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

if TemporaryEnchantFrame_Update then
    hooksecurefunc("TemporaryEnchantFrame_Update", function(...)
        for i = 1, 3 do
            local te = _G["TempEnchant"..i]
            if te then
                te.isDebuff = false
                te.isTempEnchant = true
                if UberUI.buffsandauras then
                    UberUI.buffsandauras:StyleAuraButton(te)
                end
            end
        end
    end)
end

if BuffFrame_UpdateAllBuffAnchors then
    hooksecurefunc("BuffFrame_UpdateAllBuffAnchors", function(...)
        for i = 1, 3 do
            local te = _G["TempEnchant"..i]
            if te then
                te.isDebuff = false
                te.isTempEnchant = true
                if UberUI.buffsandauras then
                    UberUI.buffsandauras:StyleAuraButton(te)
                end
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
        owner.isDebuff = false
        UberUI.buffsandauras:StyleAuraButton(owner)
    end
end)
hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, unit)
    local owner = self:GetOwner()
    if owner and UberUI.buffsandauras then
        owner.isDebuff = true
        UberUI.buffsandauras:StyleAuraButton(owner)
    end
end)
if GameTooltip.SetUnitBuffByAuraInstanceID then
    hooksecurefunc(GameTooltip, "SetUnitBuffByAuraInstanceID", function(self, unit)
        local owner = self:GetOwner()
        if owner and UberUI.buffsandauras then
            owner.isDebuff = false
            UberUI.buffsandauras:StyleAuraButton(owner)
        end
    end)
    hooksecurefunc(GameTooltip, "SetUnitDebuffByAuraInstanceID", function(self, unit)
        local owner = self:GetOwner()
        if owner and UberUI.buffsandauras then
            owner.isDebuff = true
            UberUI.buffsandauras:StyleAuraButton(owner)
        end
    end)
end

UberUI.buffsandauras = buffsandauras
