local addon, ns = ...
local buffsandauras = {}

if not buffsandauras.borderFrames then
    buffsandauras.borderFrames = setmetatable({}, {__mode = "k"})
end

local IsSecret, SafeBool = UberUI.util.IsSecret, UberUI.util.SafeBool

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

-- Player square borders and temp enchant styling.
local SB = UberUI.squareborders
local SQUARE_LOC = "player"

local function SquareBordersEnabled() return SB.IsEnabled(SQUARE_LOC) end
local function SquareBorderThickness() return SB.Thickness(SQUARE_LOC) end
local function SquareBorderInset() return SB.IsInset(SQUARE_LOC) end
local PixelsToUIUnits = SB.PixelsToUIUnits

local function GetSquareBorder(button) return SB.Get(button) end
local function FindSquareBorder(button) return SB.Find(button) end
local function SetSquareBorderColor(sb, r, g, b, a) SB.SetColor(sb, r, g, b, a) end

-- Duration text sits where Blizzard puts it (its top on the icon's bottom,
-- or above / beside the icon per the buff frame's grow direction), pushed
-- outward past any border we draw outside the icon: the rounded ring, or a
-- square border drawn outside. The anchor is worked out the way Blizzard's
-- UpdateGridLayout sets it -- reading it back returns secret values in
-- combat.
local DURATION_PUSH = { TOP = { 0, 1 }, BOTTOM = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }
-- The rounded ring's pad includes transparent margin in Blizzard's art, and
-- Blizzard's text already sits a little below its anchor, so the push is this
-- much less than the full pad: the text lands just under the ring (measured
-- in game: zoomed ring 6 -> push 1; unzoomed 5 -> 0, Blizzard's own spot).
local RING_TEXT_TUCK = 5
local movedDurations = setmetatable({}, {__mode = "k"}) -- button -> push amount

local function StockDurationAnchor(button)
    local parent = button:GetParent()
    local info = parent and parent.currentGridLayoutInfo
    local point, relPoint = "TOP", "BOTTOM"
    if type(info) == "table" and not IsSecret(info) then
        if info.isHorizontal == false then
            point = info.addIconsToRight and "LEFT" or "RIGHT"
            relPoint = info.addIconsToRight and "RIGHT" or "LEFT"
        elseif info.addIconsToTop then
            point, relPoint = "BOTTOM", "TOP"
        end
    end
    return point, relPoint, DURATION_PUSH[relPoint]
end

local EnsureSquareBorderLayoutHooks

local function OffsetDurationText(button, iconTexture, amount)
    if amount == 0 and not movedDurations[button] then return end
    local duration = button.Duration
    if not duration or IsSecret(duration) or not iconTexture then return end
    local point, relPoint, dir = StockDurationAnchor(button)
    duration:ClearAllPoints()
    duration:SetPoint(point, iconTexture, relPoint, dir[1] * amount, dir[2] * amount)
    movedDurations[button] = (amount ~= 0) and amount or nil
    if amount ~= 0 then EnsureSquareBorderLayoutHooks() end
end

-- Re-applies the pushes after Blizzard's UpdateGridLayout re-anchors the text.
local squareLayoutHooksInstalled = false

local function ReapplyDurationOffsets(auraFrame)
    local buttons = auraFrame and auraFrame.auraFrames
    if type(buttons) ~= "table" then return end
    for _, button in ipairs(buttons) do
        local amount = button and movedDurations[button]
        if amount and button.Icon then
            OffsetDurationText(button, button.Icon, amount)
        end
    end
end

function EnsureSquareBorderLayoutHooks()
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

-------------------------------------------------------------------------------
-- Player aura text (auratext_player_*): Blizzard's own buttons, restyled in
-- place -- no container needed.
--  * Stack count: Blizzard's Count (NumberFontNormal, BOTTOMRIGHT of the icon
--    at -2, 2), resized and moved.
--  * Duration: while its size is changed or Centered is on, Blizzard's
--    Duration text is faded out and mirrored into our own font string (same
--    text, e.g. "1 m", and color) at the chosen size -- under the icon like
--    Blizzard's, or centered on it. Blizzard re-sets its font and anchor on
--    its own schedule, so it's never resized directly. The mirror follows
--    Blizzard's UpdateDuration / Show / Hide, hooked per button only once the
--    feature is on.
--  * Centered: the row space Blizzard reserves for the text under (or beside)
--    each icon is dropped -- the buttons shrink to the icon and Blizzard's own
--    grid layout is re-applied to them after each of its passes.
-------------------------------------------------------------------------------
local function PlayerText() return UberUI.aurakit.TextSettings("player") end

local function PlayerDurationActive(t)
    return t.center or t.duration ~= 1
end

local mirrors = setmetatable({}, { __mode = "k" })       -- button -> font string
local mirrorHooked = setmetatable({}, { __mode = "k" })  -- button -> true

-- White Outlined Text: a duration text binding per button (whole seconds,
-- then "2m"/"1h", like the other locations' text), fed the aura's own
-- duration object. Re-fed only when the aura or its expiration changes;
-- Blizzard calls UpdateDuration every frame. Weapon enchants have no aura
-- instance and keep Blizzard's text.
local bindings = setmetatable({}, { __mode = "k" })      -- button -> { binding, key }

local function UnbindLongDuration(button)
    local b = bindings[button]
    if b and b.enabled then
        pcall(b.binding.SetEnabled, b.binding, false)
        b.enabled, b.key = false, nil
    end
end

local function BindLongDuration(button, own)
    local info = button.buttonInfo
    local id = info and info.auraInstanceID
    if not id or IsSecret(id) or not (C_DurationUtil and C_DurationUtil.CreateDurationTextBinding)
        or not (C_UnitAuras and C_UnitAuras.GetAuraDuration) then
        return false
    end
    local formatter = UberUI.aurakit.GetLongDurationFormatter()
    if not formatter then return false end

    local b = bindings[button]
    if not b then
        local ok, binding = pcall(C_DurationUtil.CreateDurationTextBinding)
        if not ok or not binding then return false end
        b = { binding = binding }
        bindings[button] = b
    end
    -- A secret expiration can't tell a refresh from a repeat: no key, so
    -- it's re-fed on every update.
    local exp = info.expirationTime
    local key = (exp ~= nil and not IsSecret(exp)) and (id .. ":" .. tostring(exp)) or nil
    if key and b.enabled and b.key == key then return true end
    local ok = pcall(function()
        local binding = b.binding
        binding:SetToDefaults()
        binding:SetFormatter(formatter)
        binding:SetFontString(own)
        binding:SetDuration(C_UnitAuras.GetAuraDuration(PlayerFrame and PlayerFrame.unit or "player", id))
        binding:SetEnabled(true)
    end)
    b.enabled = true
    if not ok then
        UnbindLongDuration(button)
        return false
    end
    b.key = key
    return true
end

local function UpdateDurationMirror(button)
    local blizz = button and button.Duration
    if not blizz or IsSecret(blizz) then return end
    local t = PlayerText()
    local own = mirrors[button]
    if not PlayerDurationActive(t) then
        if own then
            UnbindLongDuration(button)
            own:Hide()
            blizz:SetAlpha(1)
        end
        return
    end
    if not own then
        local holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints(button)
        holder:SetFrameLevel(button:GetFrameLevel() + 6)
        holder:EnableMouse(false)
        own = holder:CreateFontString(nil, "OVERLAY")
        mirrors[button] = own
    end
    blizz:SetAlpha(0)
    -- Above the border ring (button + 5), re-set each time: the button's
    -- own level can change after the holder was made.
    own:GetParent():SetFrameLevel(button:GetFrameLevel() + 10)
    if not blizz:IsShown() then
        own:Hide()
        return
    end
    -- Blizzard's font object first (its shadow and color), then its size
    -- scaled; outlined when centered, since it sits on the icon art.
    own:SetFontObject(blizz:GetFontObject() or GameFontNormalSmall)
    local font, size, flags = blizz:GetFont()
    if font and size then
        own:SetFont(font, math.max(4, size * t.duration), t.center and "OUTLINE" or flags)
    end
    if t.center then own:SetShadowOffset(0, 0) end
    -- White Outlined Text (centered only): white, and our own duration
    -- binding drives the text below instead of Blizzard's.
    local long = t.center and t.white
    if long then
        own:SetTextColor(1, 1, 1, 1)
    else
        -- Blizzard's color, but never its alpha: hiding Blizzard's text with
        -- SetAlpha(0) shows up in its GetTextColor alpha too.
        local cr, cg, cb = blizz:GetTextColor()
        own:SetTextColor(cr, cg, cb, 1)
    end
    own:ClearAllPoints()
    local icon = button.Icon
    if t.center and icon then
        own:SetPoint("CENTER", icon, "CENTER", 0, 0)
    else
        -- Blizzard's anchor, worked out the way its UpdateGridLayout sets it
        -- (reading it back returns secret values in combat): under the icon,
        -- or above / beside it per the container's grow direction, plus our
        -- square-border push (OffsetDurationText).
        local point, relPoint, dir = StockDurationAnchor(button)
        local push = movedDurations[button] or 0
        if icon then
            own:SetPoint(point, icon, relPoint, dir[1] * push, dir[2] * push)
        end
    end
    if not (long and BindLongDuration(button, own)) then
        UnbindLongDuration(button)
        -- Blizzard's own text (possibly secret in combat; SetText accepts it).
        own:SetText(blizz:GetText())
    end
    own:Show()
end

local function EnsureDurationMirror(button)
    if mirrorHooked[button] or not button.Duration or not button.UpdateDuration then return end
    mirrorHooked[button] = true
    hooksecurefunc(button, "UpdateDuration", UpdateDurationMirror)
    local blizz = button.Duration
    hooksecurefunc(blizz, "Hide", function() local own = mirrors[button] if own then own:Hide() end end)
    hooksecurefunc(blizz, "Show", function() UpdateDurationMirror(button) end)
    hooksecurefunc(blizz, "SetShown", function() UpdateDurationMirror(button) end)
end

-- Stack count and duration text for one player aura button. At the default
-- settings Blizzard's Count is left exactly as its template made it
-- (NumberFontNormal, BOTTOMRIGHT of the icon at -2, 2); if we changed it,
-- that's restored.
local countTouched = setmetatable({}, { __mode = "k" }) -- button -> true

local function StylePlayerText(button, iconTexture)
    local t = PlayerText()
    local count = button.Count
    if count and not IsSecret(count) and NumberFontNormal then
        local stock = t.stack == 1 and t.anchor == "BOTTOMRIGHT" and t.x == 0 and t.y == 0
        if stock then
            if countTouched[button] then
                count:SetFontObject(NumberFontNormal)
                count:ClearAllPoints()
                count:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", -2, 2)
                count:SetJustifyH("CENTER")
                countTouched[button] = nil
            end
        else
            local font, fsize, flags = NumberFontNormal:GetFont()
            if font then count:SetFont(font, math.max(4, fsize * t.stack), flags) end
            UberUI.aurakit.PlaceCount(count, iconTexture, t, -2, 2)
            countTouched[button] = true
        end
    end
    if PlayerDurationActive(t) then EnsureDurationMirror(button) end
    if mirrorHooked[button] then UpdateDurationMirror(button) end
end

-- Cooldown Swipe (uuidb.general.playerauraswipe): Blizzard's player aura
-- buttons have no Cooldown frame, so each gets our own, styled like the
-- aurakit buttons' (reversed, no edge, corner-masked swipe, no numbers) and
-- fed the aura's own duration object. Runs from StyleAuraButton, which
-- Blizzard's UpdateAuraButtons already drives on every aura change, so it
-- needs no hook of its own. Re-fed only when the aura or its expiration
-- changes (always, when the expiration is secret). Weapon enchants have no
-- aura instance and get no swipe.
local swipes = setmetatable({}, { __mode = "k" }) -- button -> { cd, key }

local function SwipeEnabled()
    return uuidb and uuidb.general and uuidb.general.playerauraswipe == true
end

local function ClearPlayerSwipe(button)
    local s = swipes[button]
    if s then
        pcall(s.cd.Clear, s.cd)
        s.cd:Hide()
        s.key = nil
    end
end

local function UpdatePlayerSwipe(button, iconTexture)
    local info = button.buttonInfo
    local id = info and info.auraInstanceID
    if not SwipeEnabled() or not id or IsSecret(id) or button.isTempEnchant
        or not (C_UnitAuras and C_UnitAuras.GetAuraDuration) then
        ClearPlayerSwipe(button)
        return
    end

    local s = swipes[button]
    if not s then
        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetReverse(true)
        cd:SetDrawEdge(false)
        cd:SetDrawSwipe(true)
        cd:SetHideCountdownNumbers(true)
        cd:EnableMouse(false)
        pcall(cd.SetSwipeTexture, cd, "Interface\\AddOns\\Uber UI\\textures\\auracornermask", 0, 0, 0, 0.8)
        pcall(cd.SetUseCircularEdge, cd, false)
        s = { cd = cd }
        swipes[button] = s
    end
    local cd = s.cd
    -- Over the icon, under our borders (button + 5) and text (button + 10).
    cd:ClearAllPoints()
    cd:SetAllPoints(iconTexture)
    cd:SetFrameLevel(button:GetFrameLevel() + 1)

    local duration = info.duration
    if duration ~= nil and not IsSecret(duration) and duration <= 0 then
        ClearPlayerSwipe(button) -- permanent aura
        return
    end
    local exp = info.expirationTime
    local key = (exp ~= nil and not IsSecret(exp)) and (id .. ":" .. tostring(exp)) or nil
    if key and s.key == key and cd:IsShown() then return end
    local ok = pcall(function()
        cd:SetCooldownFromDurationObject(C_UnitAuras.GetAuraDuration(PlayerFrame and PlayerFrame.unit or "player", id))
    end)
    if not ok then
        ClearPlayerSwipe(button)
        return
    end
    cd:Show()
    s.key = key
end

-- Centered: shrink the buttons to the icon and re-apply Blizzard's grid.
local STOCK_SIZE = { horizontal = { 30, 40 }, vertical = { 60, 30 } }
local compacted = setmetatable({}, { __mode = "k" }) -- container -> true

local function ApplyPlayerRows(container, auras, doNotAnchorDisabledFrames)
    local info = container and container.currentGridLayoutInfo
    if not (info and info.layout and info.anchor and type(auras) == "table") then return end
    local center = PlayerText().center
    if not center and not compacted[container] then return end
    local list = auras
    if doNotAnchorDisabledFrames then
        list = {}
        for _, f in ipairs(auras) do
            if f.hasValidInfo or f.isExample or f.isAuraAnchor then list[#list + 1] = f end
        end
    end
    if #list == 0 then return end
    -- Never resize protected buttons in combat (they aren't today; guarded
    -- in case Blizzard makes them secure).
    if InCombatLockdown() and list[1].IsProtected and list[1]:IsProtected() then return end
    local stock = info.isHorizontal and STOCK_SIZE.horizontal or STOCK_SIZE.vertical
    local w, h = stock[1], stock[2]
    if center then w, h = 30, 30 end
    for _, aura in ipairs(list) do
        if not IsSecret(aura) then aura:SetSize(w, h) end
    end
    GridLayoutUtil.ApplyGridLayout(list, info.anchor, info.layout)
    compacted[container] = center or nil
end

local rowHooks = setmetatable({}, { __mode = "k" }) -- container -> true
local function EnsurePlayerRowHooks()
    if not PlayerText().center then return end
    for _, auraFrame in ipairs({ BuffFrame, DebuffFrame }) do
        local container = auraFrame and auraFrame.AuraContainer
        if container and container.UpdateGridLayout and not rowHooks[container] then
            rowHooks[container] = true
            hooksecurefunc(container, "UpdateGridLayout", ApplyPlayerRows)
        end
    end
end

-- From the options (via Refresh): re-apply rows to the current buttons.
local function RefreshPlayerRows()
    EnsurePlayerRowHooks()
    if not (GridLayoutUtil and GridLayoutUtil.ApplyGridLayout) then return end
    for _, auraFrame in ipairs({ BuffFrame, DebuffFrame }) do
        local container = auraFrame and auraFrame.AuraContainer
        if container and auraFrame.auraFrames then
            pcall(ApplyPlayerRows, container, auraFrame.auraFrames, auraFrame.doNotAnchorDisabledFrames)
        end
    end
end

-- Blizzard temp enchant purple border color.
local TEMP_ENCHANT_BORDER_COLOR = { 0.50, 0.22, 0.72 }

-- Player debuff buttons carry buttonInfo.index, not the aura itself.
local function GetPlayerDebuffInstanceID(button)
    local info = button.buttonInfo
    if not info or IsSecret(info) then return nil end
    local unit = (PlayerFrame and PlayerFrame.unit) or "player"
    local id = info.auraInstanceID
    if id and not IsSecret(id) then return id, unit end
    local index = info.index
    if not index or IsSecret(index) or not C_UnitAuras then return nil end
    -- GetAuraDataByIndex is refused in combat; GetUnitAuraInstanceIDs isn't,
    -- and lists HARMFUL auras in the same order as buttonInfo.index.
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
    if isPlayer then
        -- Stack count and duration above our border frames (button + 5).
        UberUI.general:LiftAuraText(button, 10, { "Count", "Duration" })
        pcall(StylePlayerText, button, iconTexture)
        pcall(UpdatePlayerSwipe, button, iconTexture)
    end

    -- In combat these fields (e.g. debuffType) are secret: IsSecret comes
    -- first everywhere, and a secret dtype only goes to the secret-safe
    -- squareborders.GetDispelColor.
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

    -- Square borders replace Blizzard's rounded border in Zoom Only too, in
    -- Blizzard's own color (dispel color, enchant purple); buffs stay
    -- borderless there. Weapon enchants keep purple when that option is on.
    local enchantColor = isTempEnchant and not (uuidb and uuidb.general and uuidb.general.playertempenchantcolor == false)
    local squareZoomOverride = style == "zoom" and isPlayer and (isDebuff or enchantColor) and SquareBordersEnabled()
    -- Rounded + "Dispel Color" re-shows Blizzard's own DebuffBorder (full
    -- brightness, correct in combat); tinting our red-art ring came out dark.
    local borderEnabled = (style == "both" or style == "border") or squareZoomOverride
    local zoomEnabled = (style == "both" or style == "zoom")

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

        -- Same rule as the dispel-colored DebuffBorder below: Blizzard's
        -- 5px at 30px, grown slightly while zoomed.
        local pad = (isPlayer and 5 or 4) + UberUI.general:ZoomBorderGrow(zoomEnabled)
        pcall(function()
            local iconWidth = iconTexture.GetWidth and iconTexture:GetWidth()
            if IsSecret(iconWidth) then return end
            if type(iconWidth) == "number" and iconWidth > 0 then
                pad = math.max(2, math.floor(iconWidth * (5 / 30) + 0.5))
                    + UberUI.general:ZoomBorderGrow(zoomEnabled, iconWidth)
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
                -- Blizzard's TempEnchantBorder art is 32x32 over a 30x30
                -- icon (1px inset), much tighter than DebuffBorder's 40x40
                -- (5px inset) -- reusing the debuff `pad` here oversized it.
                -- Zoom crops the icon's edge, so (matching the zoom-only
                -- path below) nudge the inset out slightly to compensate.
                local teRatio = zoomEnabled and (2 / 30) or (1 / 30)
                local tePad = zoomEnabled and 2 or 1
                pcall(function()
                    local iconWidth = iconTexture.GetWidth and iconTexture:GetWidth()
                    if IsSecret(iconWidth) then return end
                    if type(iconWidth) == "number" and iconWidth > 0 then
                        tePad = math.max(1, math.floor(iconWidth * teRatio + 0.5))
                    end
                end)
                teBorder:ClearAllPoints()
                teBorder:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -tePad, tePad)
                teBorder:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", tePad, -tePad)
                teBorder:SetAlpha(0)
            end
            showCustomBorder = true
        else
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
            -- Dispel colors and enchant purple use the thicker colored border.
            local px = SquareBorderThickness()
            if (isDebuff and not (style == "both" or style == "border")) or enchantColor then
                px = SB.DispelThickness(SQUARE_LOC)
            end
            SB.Layout(squareBorder, iconTexture, px, SquareBorderInset())
            if SquareBorderInset() then
                OffsetDurationText(button, iconTexture, 0)
            else
                EnsureSquareBorderLayoutHooks()
                OffsetDurationText(button, iconTexture, PixelsToUIUnits(button, px))
            end
            if isDebuff and not (style == "both" or style == "border") then
                ApplyDebuffDispelColor(squareBorder, button, dtype)
            elseif enchantColor then
                SetSquareBorderColor(squareBorder, TEMP_ENCHANT_BORDER_COLOR[1], TEMP_ENCHANT_BORDER_COLOR[2],
                    TEMP_ENCHANT_BORDER_COLOR[3], 1)
            else
                if isStealable then
                    SetSquareBorderColor(squareBorder, 1, 1, 1, 1)
                else
                    SB.SetDarkColor(squareBorder)
                end
            end
            squareBorder:Show()
        elseif showCustomBorder and enchantColor and teBorder and not IsSecret(teBorder) then
            -- Rounded: Blizzard's own purple enchant border (tinting our
            -- red-art ring purple comes out dark).
            if squareBorder then squareBorder:Hide() end
            OffsetDurationText(button, iconTexture, 0)
            borderFrame:Hide()
            teBorder:SetAlpha(1)
            teBorder:SetVertexColor(1, 1, 1, 1)
            teBorder:Show()
        elseif showCustomBorder then
            if squareBorder then squareBorder:Hide() end
            OffsetDurationText(button, iconTexture, math.max(0, pad - RING_TEXT_TUCK))
            borderFrame.texture:SetVertexColor(r, g, b, a)
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
            -- Same size as the dark ring above (same art family): Blizzard's
            -- 5px at 30px, grown slightly while zoomed.
            local pad = (isPlayer and 5 or 4) + UberUI.general:ZoomBorderGrow(zoomEnabled)
            pcall(function()
                local iconWidth = iconTexture.GetWidth and iconTexture:GetWidth()
                if IsSecret(iconWidth) then return end
                if type(iconWidth) == "number" and iconWidth > 0 then
                    pad = math.max(2, math.floor(iconWidth * (5 / 30) + 0.5))
                        + UberUI.general:ZoomBorderGrow(zoomEnabled, iconWidth)
                end
            end)
            borderObj:SetAlpha(1)
            borderObj:ClearAllPoints()
            borderObj:SetPoint("TOPLEFT", iconTexture, "TOPLEFT", -pad, pad)
            borderObj:SetPoint("BOTTOMRIGHT", iconTexture, "BOTTOMRIGHT", pad, -pad)
            borderObj:Show()
            if isDebuff then OffsetDurationText(button, iconTexture, math.max(0, pad - RING_TEXT_TUCK)) end
        end

        if isTempEnchant and not enchantColor and teBorder and not IsSecret(teBorder) then
            -- Enchant border color off: no border, like a plain buff.
            teBorder:SetAlpha(0)
        elseif isTempEnchant and teBorder and not IsSecret(teBorder) then
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
    -- Player debuffs move into our own container in square mode
    -- (playerdebuffs.lua).
    if UberUI.playerdebuffs then UberUI.playerdebuffs:Update() end
    if InCombatLockdown() then return end
    RefreshPlayerRows()

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

-- Re-measure square borders when UI scale or resolution changes.
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

-- Catch buffs missed by the hooks when hovered.
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
