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

-- Square pixel-depth borders (docs/square-borders.md). The border itself,
-- per-location settings and dispel coloring live in core/squareborders.lua
-- (shared with every aura location); what stays here is Player-only: the
-- duration-text push for outset borders and the temp enchant color.
local SB = UberUI.squareborders
local SQUARE_LOC = "player"

local function SquareBordersEnabled() return SB.IsEnabled(SQUARE_LOC) end
local function SquareBorderThickness() return SB.Thickness(SQUARE_LOC) end
local function SquareBorderInset() return SB.IsInset(SQUARE_LOC) end
local PixelsToUIUnits = SB.PixelsToUIUnits

local function GetSquareBorder(button) return SB.Get(button) end
local function FindSquareBorder(button) return SB.Find(button) end
local function SetSquareBorderColor(sb, r, g, b, a) SB.SetColor(sb, r, g, b, a) end

-- Blizzard anchors the Duration text to the icon's edge with no gap
-- (AuraContainerMixin:UpdateGridLayout -- TOP/BOTTOM or LEFT/RIGHT depending
-- on Edit Mode orientation), so an outset border would run into it. Push it
-- out by the border thickness along Blizzard's own anchor direction. The
-- offset is set absolutely (never added to), so repeated passes don't drift
-- and 0 puts it back exactly where Blizzard had it. Only touches Blizzard's
-- single icon-relative anchor; anything else is left alone.
local DURATION_PUSH = { TOP = { 0, 1 }, BOTTOM = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
local movedDurations = setmetatable({}, {__mode = "k"})

local function OffsetDurationText(button, iconTexture, amount)
    if amount == 0 and not movedDurations[button] then return end
    local duration = button.Duration
    if not duration or IsSecret(duration) or not duration.GetPoint or not duration.GetNumPoints then return end
    local okN, numPoints = pcall(duration.GetNumPoints, duration)
    if not okN or IsSecret(numPoints) or numPoints ~= 1 then return end
    local ok, point, relTo, relPoint = pcall(duration.GetPoint, duration, 1)
    if not ok or IsSecret(relTo) or relTo ~= iconTexture or IsSecret(point) or IsSecret(relPoint) then return end
    local dir = DURATION_PUSH[relPoint]
    if not dir then return end
    duration:SetPoint(point, relTo, relPoint, dir[1] * amount, dir[2] * amount)
    movedDurations[button] = (amount ~= 0) or nil
end

-- Blizzard's layout pass re-anchors every Duration back to the icon edge
-- (AuraContainerMixin:UpdateGridLayout), and it runs right AFTER
-- UpdateAuraButtons -- i.e. after our styling -- so the outset push above
-- only lasted until the next aura update. The mixin hook further down can't
-- catch it: BuffFrame/DebuffFrame exist before this addon loads and call
-- their own copied AuraContainer:UpdateGridLayout, so hook those two
-- instances directly. Installed once, only when outset square borders are
-- actually in use (hooks can't be removed); deferred a frame to stay out of
-- Blizzard's update chain.
local squareLayoutHooksInstalled = false

local function ReapplyDurationOffsets(auraFrame)
    if not SquareBordersEnabled() or SquareBorderInset() then return end
    local buttons = auraFrame and auraFrame.auraFrames
    if type(buttons) ~= "table" then return end
    local px = SquareBorderThickness()
    for _, button in ipairs(buttons) do
        local sb = button and FindSquareBorder(button)
        if sb and sb:IsShown() and button.Icon then
            OffsetDurationText(button, button.Icon, PixelsToUIUnits(button, px))
        end
    end
end

local function EnsureSquareBorderLayoutHooks()
    if squareLayoutHooksInstalled then return end
    squareLayoutHooksInstalled = true
    for _, auraFrame in ipairs({ BuffFrame, DebuffFrame }) do
        local container = auraFrame and auraFrame.AuraContainer
        if container and container.UpdateGridLayout then
            hooksecurefunc(container, "UpdateGridLayout", function()
                C_Timer.After(0, function() ReapplyDurationOffsets(auraFrame) end)
            end)
        end
    end
end

-- Blizzard's temp enchant border is a purple texture file
-- (Interface\Buttons\UI-TempEnchant-Border), not a vertex color. Sampled
-- from the exported BLP (BlizzardInterfaceArt): its bright rim -- the part
-- that reads as "the border" -- averages ~(128, 57, 183)/255.
local TEMP_ENCHANT_BORDER_COLOR = { 0.50, 0.22, 0.72 }

-- Player debuff buttons carry buttonInfo.index (and sometimes
-- auraInstanceID), not the aura itself -- resolve the instance ID from that.
local function GetPlayerDebuffInstanceID(button)
    local info = button.buttonInfo
    if not info or IsSecret(info) then return nil end
    local unit = (PlayerFrame and PlayerFrame.unit) or "player"
    local id = info.auraInstanceID
    if id and not IsSecret(id) then return id, unit end
    local index = info.index
    if not index or IsSecret(index) or not C_UnitAuras then return nil end
    -- In combat, GetAuraDataByIndex below is refused for addon code (aura
    -- data is secret while restricted), which left player debuffs on the
    -- "None" color. GetUnitAuraInstanceIDs isn't secret-when-restricted, and
    -- lists HARMFUL auras in the same slot order DebuffFrame's
    -- AuraUtil.ForEachAura walk numbered buttonInfo.index by.
    if C_UnitAuras.GetUnitAuraInstanceIDs then
        local okIDs, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, "HARMFUL")
        if okIDs and type(ids) == "table" and not IsSecret(ids) then
            local id = ids[index]
            if id and not IsSecret(id) then return id, unit end
        end
    end
    if not C_UnitAuras.GetAuraDataByIndex then return nil end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HARMFUL")
    if ok and aura and not IsSecret(aura) then
        id = aura.auraInstanceID
        if id and not IsSecret(id) then return id, unit end
    end
    return nil
end

local function ApplyDebuffDispelColor(sb, button, dtype)
    local id, unit = GetPlayerDebuffInstanceID(button)
    SB.ApplyDispelColor(sb, dtype, unit, id)
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

    -- Determine debuff type. In combat these fields (e.g. buttonInfo.
    -- debuffType = auraData.dispelName) are secret, and boolean-testing or
    -- comparing a secret value throws in addon code -- which aborted this
    -- whole function mid-combat and left player debuffs uncolored. IsSecret
    -- comes first everywhere; a secret dtype is kept as-is and only ever
    -- handed to squareborders.GetDispelColor, which is secret-safe.
    local function Known(v) return IsSecret(v) or v ~= nil end
    local dtype = button.debuffType
    if not Known(dtype) and not IsSecret(button.auraData) and button.auraData then
        dtype = button.auraData.dispelName
    end
    if not Known(dtype) and not IsSecret(button.buttonInfo) and button.buttonInfo then
        dtype = button.buttonInfo.debuffType
    end
    if not Known(dtype) and not IsSecret(button.auraInstanceID) and button.auraInstanceID
        and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        local okP, p = pcall(button.GetParent, button)
        local unit = button.unit or (okP and p and p.GetUnit and p:GetUnit()) or (isPlayer and "player") or "target"
        pcall(function()
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, button.auraInstanceID)
            if aura and not IsSecret(aura) then
                dtype = aura.dispelName
            end
        end)
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

    -- Square borders also override Zoom Only on Player debuffs and weapon
    -- enchants: Blizzard's rounded border becomes a square one in Blizzard's
    -- own (undarkened) color -- dispel color for debuffs, enchant purple for
    -- temp enchants. Buffs have no Blizzard border in Zoom Only, so they stay
    -- borderless there.
    local squareZoomOverride = style == "zoom" and isPlayer and (isDebuff or isTempEnchant) and SquareBordersEnabled()
    -- Rounded + Debuff Border "Dispel Color" (zoom style): our own rounded
    -- ring tinted with the dispel color, instead of switching to Blizzard's
    -- separate per-type border art -- so Dark and Dispel Color are the same
    -- ring, only the color changes.
    local roundedDispelOverride = style == "zoom" and isPlayer and isDebuff and not SquareBordersEnabled()
    local borderEnabled = (style == "both" or style == "border") or squareZoomOverride or roundedDispelOverride
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

        local squareBorder = FindSquareBorder(button)
        if showCustomBorder and isPlayer and SquareBordersEnabled() then
            borderFrame:Hide()
            squareBorder = GetSquareBorder(button)
            squareBorder:SetFrameLevel(borderFrame:GetFrameLevel())
            local px = SquareBorderThickness()
            SB.Layout(squareBorder, iconTexture, px, SquareBorderInset())
            if SquareBorderInset() then
                OffsetDurationText(button, iconTexture, 0)
            else
                EnsureSquareBorderLayoutHooks()
                OffsetDurationText(button, iconTexture, PixelsToUIUnits(button, px))
            end
            -- Debuff Border "Dark" (both/border style) stays dark; "Dispel
            -- Color" (zoom style) gets Blizzard's dispel color.
            if isDebuff and not (style == "both" or style == "border") then
                ApplyDebuffDispelColor(squareBorder, button, dtype)
            elseif isTempEnchant and squareZoomOverride then
                SetSquareBorderColor(squareBorder, TEMP_ENCHANT_BORDER_COLOR[1], TEMP_ENCHANT_BORDER_COLOR[2],
                    TEMP_ENCHANT_BORDER_COLOR[3], 1)
            else
                SetSquareBorderColor(squareBorder, r, g, b, a)
            end
            squareBorder:Show()
        elseif showCustomBorder then
            if squareBorder then squareBorder:Hide() end
            OffsetDurationText(button, iconTexture, 0)
            if roundedDispelOverride then
                local id, unit = GetPlayerDebuffInstanceID(button)
                borderFrame.texture:SetVertexColor(SB.GetDispelColor(dtype, unit, id))
            else
                borderFrame.texture:SetVertexColor(r, g, b, a)
            end
            borderFrame:Show()
        else
            if squareBorder then squareBorder:Hide() end
            OffsetDurationText(button, iconTexture, 0)
            if borderFrame then
                borderFrame:Hide()
            end
        end
    else
        if borderFrame then
            borderFrame:Hide()
        end
        local squareBorder = FindSquareBorder(button)
        if squareBorder then
            squareBorder:Hide()
        end
        OffsetDurationText(button, iconTexture, 0)

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
            local sb = FindSquareBorder(self)
            if sb then sb:Hide() end
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

-- Square border thickness is baked in from the effective scale at style
-- time, so re-measure when UI scale or resolution changes (neither restyles
-- the aura buttons on its own). Deferred a frame so the new scale has
-- settled; Refresh() itself skips combat.
local squareBorderScaleWatcher = CreateFrame("Frame")
squareBorderScaleWatcher:RegisterEvent("UI_SCALE_CHANGED")
squareBorderScaleWatcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
squareBorderScaleWatcher:SetScript("OnEvent", function()
    if not SquareBordersEnabled() then return end
    C_Timer.After(0, function()
        if UberUI.buffsandauras then
            UberUI.buffsandauras:Refresh()
        end
    end)
end)

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
