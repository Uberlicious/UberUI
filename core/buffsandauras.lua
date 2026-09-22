local addon, ns = ...
local buffsandauras = {}

if not buffsandauras.borderFrames then
    buffsandauras.borderFrames = setmetatable({}, {__mode = "k"})
end

local function IsSecret(v)
    return (issecretvalue and issecretvalue(v))
end

local function SafeBool(v)
    if v == nil or IsSecret(v) then return false end
    return (v == true)
end

local function SafeIsShown(frame)
    if not frame or IsSecret(frame) then return false end
    local ok, isShown = pcall(frame.IsShown, frame)
    return ok and SafeBool(isShown)
end

local function SafeIsForbidden(frame)
    if not frame or IsSecret(frame) then return true end
    local ok, isForbid = pcall(frame.IsForbidden, frame)
    return ok and SafeBool(isForbid)
end

local function GetAuraInfo(button)
    local isPlayer = false
    local isDebuff = false
    local isTempEnchant = false

    local btnName = ""
    local okName, name = pcall(button.GetName, button)
    if okName and not IsSecret(name) and type(name) == "string" then
        btnName = name
    end

    pcall(function()
        if SafeBool(button.isTempEnchant)
            or (not IsSecret(button.auraType) and button.auraType == "TempEnchant")
            or (button.buttonInfo and not IsSecret(button.buttonInfo.auraType) and button.buttonInfo.auraType == "TempEnchant")
            or (btnName ~= "" and btnName:find("^TempEnchant") ~= nil)
            or SafeIsShown(button.TempEnchantBorder) then
            isTempEnchant = true
        end
    end)

    if isTempEnchant then
        isPlayer = true
    end

    if button.isDebuff ~= nil and not IsSecret(button.isDebuff) then
        isDebuff = SafeBool(button.isDebuff)
    end

    local cur = button
    local depth = 0
    while cur and depth < 10 do
        depth = depth + 1
        if cur == DebuffFrame then
            isPlayer = true
            isDebuff = true
            break
        elseif cur == BuffFrame or cur == TemporaryEnchantFrame then
            isPlayer = true
            break
        end

        local curName = ""
        local okCurName, cName = pcall(cur.GetName, cur)
        if okCurName and not IsSecret(cName) and type(cName) == "string" then
            curName = cName
        end

        if curName:find("DebuffFrame") or curName:find("^DebuffButton") then
            isPlayer = true
            isDebuff = true
            break
        elseif curName:find("BuffFrame") or curName:find("^BuffButton") or curName:find("^TempEnchant") then
            isPlayer = true
            break
        end

        local okP, parent = pcall(cur.GetParent, cur)
        if okP and parent and not IsSecret(parent) then
            cur = parent
        else
            cur = nil
        end
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

        if button.auraInstanceID and not IsSecret(button.auraInstanceID) and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
            local p = button.GetParent and button:GetParent()
            local unit = button.unit or (p and p.GetUnit and p:GetUnit()) or (isPlayer and "player") or "target"
            local aura
            pcall(function()
                aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, button.auraInstanceID)
            end)
            if aura and not IsSecret(aura) then
                if SafeBool(aura.isHarmful) then
                    isDebuff = true
                elseif SafeBool(aura.isHelpful) then
                    isDebuff = false
                end
            end
        end

        if not isDebuff then
            if button.GetAuraInstance then
                local ok, unitToken, auraData = pcall(button.GetAuraInstance, button)
                if ok and auraData and not IsSecret(auraData) and SafeBool(auraData.isHarmful) then
                    isDebuff = true
                end
            elseif not IsSecret(button.auraType) and button.auraType == "Debuff" then
                isDebuff = true
            elseif button.buttonInfo and not IsSecret(button.buttonInfo.auraType) and button.buttonInfo.auraType == "Debuff" then
                isDebuff = true
            elseif not IsSecret(button.filter) and button.filter == "HARMFUL" then
                isDebuff = true
            elseif button.buttonInfo and not IsSecret(button.buttonInfo.filter) and button.buttonInfo.filter == "HARMFUL" then
                isDebuff = true
            elseif button.auraData and not IsSecret(button.auraData) and SafeBool(button.auraData.isHarmful) then
                isDebuff = true
            elseif SafeIsShown(button.DispelBorder) then
                isDebuff = true
            elseif SafeIsShown(button.DebuffBorder) then
                isDebuff = true
            end
        end
    end

    return isPlayer, isDebuff, isTempEnchant
end

function buffsandauras:StyleAuraButton(button)
    if not button or IsSecret(button) or type(button) ~= "table" then
        return
    end

    -- Skip custom container buttons (Target/Focus frames) that handle their own borders
    if button.borderHost or button.container or SafeBool(button.isAuraAnchor) then
        return
    end

    if SafeIsForbidden(button) then
        return
    end

    local okType, objType = pcall(button.GetObjectType, button)
    if not okType or IsSecret(objType) or (objType ~= "Button" and objType ~= "Frame" and objType ~= "AuraButton") then
        return
    end

    local btnName = ""
    local okName, name = pcall(button.GetName, button)
    if okName and not IsSecret(name) and type(name) == "string" then
        btnName = name
    end

    local iconTexture = button.Icon or button.icon or (btnName ~= "" and _G[btnName .. "Icon"])
    if not iconTexture or IsSecret(iconTexture) then
        local okReg, regions = pcall(function() return { button:GetRegions() } end)
        if okReg and regions and not IsSecret(regions) then
            for _, region in pairs(regions) do
                if region and not IsSecret(region) then
                    local okObj, rType = pcall(region.GetObjectType, region)
                    if okObj and rType == "Texture" then
                        if region ~= button.DebuffBorder and region ~= button.TempEnchantBorder and region ~= button.Border then
                            iconTexture = region
                            break
                        end
                    end
                end
            end
        end
    end
    if not iconTexture or IsSecret(iconTexture) then return end

    local isPlayer, isDebuff, isTempEnchant = GetAuraInfo(button)

    -- Determine debuff type
    local dtype = button.debuffType or (button.auraData and not IsSecret(button.auraData) and button.auraData.dispelName)
    if not dtype and button.buttonInfo and not IsSecret(button.buttonInfo) and button.buttonInfo.debuffType then
        dtype = button.buttonInfo.debuffType
    end
    if not dtype and button.auraInstanceID and not IsSecret(button.auraInstanceID) and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        local okP, p = pcall(button.GetParent, button)
        local unit = button.unit or (okP and p and p.GetUnit and p:GetUnit()) or (isPlayer and "player") or "target"
        pcall(function()
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, button.auraInstanceID)
            if aura and not IsSecret(aura) then
                dtype = aura.dispelName
            end
        end)
    end

    local isTypeless = true
    if dtype and not IsSecret(dtype) then
        local ok, lowerDtype = pcall(string.lower, dtype)
        if ok and lowerDtype and lowerDtype ~= "" and lowerDtype ~= "none" then
            isTypeless = false
        end
    elseif IsSecret(dtype) then
        isTypeless = false
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

    if borderEnabled and SafeIsShown(button) then
        local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }

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

        local ok, level = pcall(function() return button:GetFrameLevel() end)
        if ok and level and not IsSecret(level) and type(level) == "number" then
            borderFrame:SetFrameLevel(level + 5)
        else
            borderFrame:SetFrameLevel(100)
        end

        local pad = isPlayer and 5 or 4
        pcall(function()
            local iconWidth = iconTexture.GetWidth and iconTexture:GetWidth()
            if IsSecret(iconWidth) then return end
            if type(iconWidth) == "number" and iconWidth > 0 then
                pad = math.max(2, math.floor(iconWidth * (5 / 30) + 0.5))
            end
        end)
        borderFrame:ClearAllPoints()
        borderFrame:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -pad, pad)
        borderFrame:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", pad, -pad)

        local showCustomBorder = false
        if isDebuff then
            if borderObj and not IsSecret(borderObj) then
                borderObj:ClearAllPoints()
                borderObj:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -pad, pad)
                borderObj:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", pad, -pad)
                borderObj:SetAlpha(0)
            end
            showCustomBorder = true
        elseif isTempEnchant then
            if teBorder and not IsSecret(teBorder) then
                teBorder:ClearAllPoints()
                teBorder:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -pad, pad)
                teBorder:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", pad, -pad)
                teBorder:SetAlpha(0)
            end
            showCustomBorder = true
        else
            -- Buff
            if borderObj and not IsSecret(borderObj) then
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
                if SafeBool(button.isStealable) then isStealable = true end
                if SafeIsShown(button.Stealable) then isStealable = true end
                if SafeIsShown(button.StealableBorder) then isStealable = true end
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

        if borderObj and not IsSecret(borderObj) and not isTempEnchant then
            local pad = zoomEnabled and (isPlayer and 5 or 4) or 0
            pcall(function()
                local iconWidth = iconTexture.GetWidth and iconTexture:GetWidth()
                if IsSecret(iconWidth) then return end
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

        if isTempEnchant and teBorder and not IsSecret(teBorder) then
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

    -- Hook OnHide safely to prevent crashes on buttons with secret aspects
    if not button.uberUIHookedHide and button.HookScript then
        button.uberUIHookedHide = true
        pcall(button.HookScript, button, "OnHide", function(self)
            local bf = buffsandauras.borderFrames[self]
            if bf then bf:Hide() end
        end)
    end
end

function buffsandauras:Refresh()
    if InCombatLockdown() then return end

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
                if child and not IsSecret(child) and child.GetObjectType and (child:GetObjectType() == "Button" or child:GetObjectType() == "Frame") then
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
            if child and not IsSecret(child) and child.GetObjectType and (child:GetObjectType() == "Button" or child:GetObjectType() == "Frame") then
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
                if child and not IsSecret(child) and child.GetObjectType and (child:GetObjectType() == "Button" or child:GetObjectType() == "Frame") then
                    local cName = child.GetName and child:GetName()
                    if child.Icon or child.icon or (cName and _G[cName.."Icon"]) then
                        child.isDebuff = true
                        self:StyleAuraButton(child)
                    elseif child.GetChildren then
                        for _, grandchild in pairs({ child:GetChildren() }) do
                            if grandchild and not IsSecret(grandchild) and grandchild.GetObjectType and (grandchild:GetObjectType() == "Button" or grandchild:GetObjectType() == "Frame") then
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
    if InCombatLockdown() then return end

    local function HandleAuras(frame, depth)
        if not frame or depth > 10 or IsSecret(frame) then return end
        if SafeIsForbidden(frame) or not frame.GetChildren then return end

        local fName = ""
        local okName, name = pcall(frame.GetName, frame)
        if okName and not IsSecret(name) and type(name) == "string" then
            fName = name
        end
        -- Ignore all custom UberUI aura containers and Blizzard aura containers
        if fName:find("UberUI") or fName:find("AuraContainer") or fName:find("TargetAuras") or fName:find("FocusAuras") then return end

        local okKids, kids = pcall(function() return { frame:GetChildren() } end)
        if not okKids or not kids or IsSecret(kids) then return end

        for _, v in pairs(kids) do
            if v and not IsSecret(v) then
                if not SafeIsForbidden(v) and v.GetObjectType then
                    local okType, objType = pcall(v.GetObjectType, v)
                    if okType and objType and not IsSecret(objType) then
                        local isAura = false
                        local vName = ""
                        local okVName, vn = pcall(v.GetName, v)
                        if okVName and not IsSecret(vn) and type(vn) == "string" then
                            vName = vn
                        end

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
                            if not v.borderHost and not v.container then
                                self:StyleAuraButton(v)
                            end
                        else
                            HandleAuras(v, depth + 1)
                        end
                    end
                end
            end
        end
    end

    local function StyleAuraContainer(container)
        if not container or IsSecret(container) or SafeIsForbidden(container) then return end

        local cName = ""
        local okName, cn = pcall(container.GetName, container)
        if okName and not IsSecret(cn) and type(cn) == "string" then
            cName = cn
        end
        if cName:find("UberUI") then return end

        if container.buffAuraGroup and container.buffAuraGroup.GetFramesByIndex then
            local ok, frames = pcall(container.buffAuraGroup.GetFramesByIndex, container.buffAuraGroup)
            if ok and frames and not IsSecret(frames) then
                for _, btn in ipairs(frames) do
                    btn.isDebuff = false
                    self:StyleAuraButton(btn)
                end
            end
        end
        if container.debuffAuraGroup and container.debuffAuraGroup.GetFramesByIndex then
            local ok, frames = pcall(container.debuffAuraGroup.GetFramesByIndex, container.debuffAuraGroup)
            if ok and frames and not IsSecret(frames) then
                for _, btn in ipairs(frames) do
                    btn.isDebuff = true
                    self:StyleAuraButton(btn)
                end
            end
        end
        if container.auraPools and container.auraPools.EnumerateActive then
            pcall(function()
                for frame in container.auraPools:EnumerateActive() do
                    self:StyleAuraButton(frame)
                end
            end)
        end
        if container.GetChildren then
            local okKids, kids = pcall(function() return { container:GetChildren() } end)
            if okKids and kids and not IsSecret(kids) then
                for _, child in pairs(kids) do
                    if child and not IsSecret(child) and not SafeIsForbidden(child) and child.GetObjectType then
                        local okType, objType = pcall(child.GetObjectType, child)
                        if okType and not IsSecret(objType) and (objType == "AuraButton" or objType == "Button") then
                            self:StyleAuraButton(child)
                        end
                    end
                end
            end
        end
    end

    if FocusFrame and (not FocusFrame.smallSize) and not InCombatLockdown() then
        if not SafeIsForbidden(FocusFrame) then
            local focusAuras = FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual and FocusFrame.TargetFrameContent.TargetFrameContentContextual.Auras
            if focusAuras and not SafeIsForbidden(focusAuras) then
                HandleAuras(FocusFrame, 1)
                StyleAuraContainer(focusAuras)
            end

            if FocusFrame.auraPools then
                if FocusFrame.auraPools.EnumerateActive then
                    pcall(function()
                        for frame in FocusFrame.auraPools:EnumerateActive() do
                            self:StyleAuraButton(frame)
                        end
                    end)
                elseif FocusFrame.auraPools.GetPool then
                    for _, tmpl in ipairs({"TargetBuffFrameTemplate", "TargetDebuffFrameTemplate", "FocusBuffFrameTemplate", "FocusDebuffFrameTemplate"}) do
                        local pool = FocusFrame.auraPools:GetPool(tmpl)
                        if pool and pool.EnumerateActive then
                            pcall(function()
                                for frame in pool:EnumerateActive() do
                                    self:StyleAuraButton(frame)
                                end
                            end)
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
            if button and not IsSecret(button) then
                button.isDebuff = isDebuff
                UberUI.buffsandauras:StyleAuraButton(button)
            end
        end

        if not isDebuff then
            for i = 1, 3 do
                local te = _G["TempEnchant"..i]
                if te and not IsSecret(te) then
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
        if type(auras) == "table" and not IsSecret(auras) then
            for _, button in ipairs(auras) do
                if button and not IsSecret(button) then
                    UberUI.buffsandauras:StyleAuraButton(button)
                end
            end
        end
    end)
end

if TemporaryEnchantFrame_Update then
    hooksecurefunc("TemporaryEnchantFrame_Update", function(...)
        for i = 1, 3 do
            local te = _G["TempEnchant"..i]
            if te and not IsSecret(te) then
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
            if te and not IsSecret(te) then
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
    if InCombatLockdown() then return end
    if UberUI.buffsandauras then
        UberUI.buffsandauras:ColorAuras(false)
    end
end)

-- Catch any elusive buffs when the user hovers over them for a tooltip
hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, unit)
    local owner = self:GetOwner()
    if owner and not IsSecret(owner) and UberUI.buffsandauras then
        owner.isDebuff = false
        UberUI.buffsandauras:StyleAuraButton(owner)
    end
end)

hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, unit)
    local owner = self:GetOwner()
    if owner and not IsSecret(owner) and UberUI.buffsandauras then
        owner.isDebuff = true
        UberUI.buffsandauras:StyleAuraButton(owner)
    end
end)

if GameTooltip.SetUnitBuffByAuraInstanceID then
    hooksecurefunc(GameTooltip, "SetUnitBuffByAuraInstanceID", function(self, unit)
        local owner = self:GetOwner()
        if owner and not IsSecret(owner) and UberUI.buffsandauras then
            owner.isDebuff = false
            UberUI.buffsandauras:StyleAuraButton(owner)
        end
    end)

    hooksecurefunc(GameTooltip, "SetUnitDebuffByAuraInstanceID", function(self, unit)
        local owner = self:GetOwner()
        if owner and not IsSecret(owner) and UberUI.buffsandauras then
            owner.isDebuff = true
            UberUI.buffsandauras:StyleAuraButton(owner)
        end
    end)
end

UberUI.buffsandauras = buffsandauras
