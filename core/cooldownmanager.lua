local addon, ns = ...
local cdManager = UberUI:CreateFrame("frame")

local function GetMaskTexture()
    if uuidb and uuidb.masks and uuidb.masks.cdm_mask then
        return uuidb.masks.cdm_mask
    end
    return [[Interface\AddOns\Uber UI\textures\statusbars\cdm_bar_mask.tga]]
end

-- Bar fill mask: per-side crop (px) and whole-mask shift (+X right, +Y up).
local MASK_OPTS = {
    insetL = 0,
    insetT = -2,
    insetR = 0,
    insetB = -2,
    shiftX = 0,
    shiftY = 0,
}

local function ApplyMask(bar, opts)
    opts = opts or MASK_OPTS
    local L, T, R, B = opts.insetL or 0, opts.insetT or 0, opts.insetR or 0, opts.insetB or 0
    local SX, SY = opts.shiftX or 0, opts.shiftY or 0

    if not bar._uberMask then
        local m = bar:CreateMaskTexture(nil, "OVERLAY")
        m:SetTexture(GetMaskTexture(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if m.SetSnapToPixelGrid then m:SetSnapToPixelGrid(true) end
        if m.SetTexelSnappingBias then m:SetTexelSnappingBias(0) end
        if m.SetHorizTile then m:SetHorizTile(false) end
        if m.SetVertTile then m:SetVertTile(false) end
        bar._uberMask = m
    end
    local m = bar._uberMask

    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", bar, "TOPLEFT", L + SX, -(T - SY))
    m:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -R + SX, B + SY)
end

function cdManager:Texture()
    if not BuffBarCooldownViewer then return end
    if not BuffBarCooldownViewer:IsShown() then return end
    if not uuidb or not uuidb.statusbars or not uuidb.general then return end

    local applyCustomLook = false
    local texture = nil

    if uuidb.cooldown.bartextures and uuidb.cooldown.bartexture ~= "Blizzard" then
        applyCustomLook = true
        texture = uuidb.statusbars[uuidb.cooldown.bartexture]
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        applyCustomLook = true
        texture = uuidb.statusbars[uuidb.general.texture]
    end

    if not texture then return end

    if not BuffBarCooldownViewer then return end
    local children = { BuffBarCooldownViewer:GetChildren() }
    if #children == 0 then return end

    for _, f in ipairs(children) do
        if f and f.Bar then
            local bar = f.Bar

            -- Only the fill is masked.
            local fill
            if bar:GetObjectType() == "StatusBar" then
                bar:SetStatusBarTexture(texture)
                fill = bar:GetStatusBarTexture()
            else
                for _, r in ipairs({ bar:GetRegions() }) do
                    if r:IsObjectType("Texture") and r:GetDrawLayer() == "ARTWORK" then
                        fill = r; break
                    end
                end
                if not fill then
                    fill = bar:CreateTexture(nil, "ARTWORK")
                end
                fill:SetAllPoints(bar)
                fill:SetTexture(texture)
            end

            ApplyMask(bar, MASK_OPTS)

            if fill and bar._uberMask and not fill._masked then
                fill:AddMaskTexture(bar._uberMask)
                fill._masked = true
            end

            if not bar._uberStyler then
                bar._uberStyler = true
                bar:HookScript("OnSizeChanged", function(self)
                    if self._uberMask then ApplyMask(self, MASK_OPTS) end
                end)
            end
        end
    end
end

function cdManager:Color()
    if not uuidb or not uuidb.general then return end

    if uuidb.cooldown.borders == false then
        local function DestroyBorders(viewer)
            if not viewer then return end
            for _, f in ipairs({ viewer:GetChildren() }) do
                if f.uberBorder then
                    f.uberBorder:Hide()
                    f.uberBorder = nil
                    f.styled = nil
                end
            end
        end
        if BuffBarCooldownViewer then DestroyBorders(BuffBarCooldownViewer) end
        if BuffIconCooldownViewer then DestroyBorders(BuffIconCooldownViewer) end
        if UtilityCooldownViewer then DestroyBorders(UtilityCooldownViewer) end
        if EssentialCooldownViewer then DestroyBorders(EssentialCooldownViewer) end
        return
    end

    local dc = uuidb.general.darkencolor

    local AURA_BORDER_ATLAS = "ui-debuff-border-default-noicon"

    -- Proportional to the icon's width (Edit Mode resizes icons). 3/30 rather
    -- than the aura borders' 5/30 so neighbors at 0 padding don't overlap.
    local function GetBorderPad(anchor)
        local ok, width = pcall(anchor.GetWidth, anchor)
        if not ok or (issecretvalue and issecretvalue(width)) or type(width) ~= "number" or width <= 0 then return 3 end
        return math.max(1, math.floor(width * (3 / 30) + 0.5))
    end

    local function PositionBorder(border, anchor)
        local pad = GetBorderPad(anchor)
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", anchor, "TOPLEFT", -pad, pad)
        border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", pad, -pad)
    end

    local function CreateBorder(parent, anchor)
        local holder
        if anchor:IsObjectType("Frame") then
            holder = anchor
        else
            holder = anchor:GetParent()
        end

        local borderTexture = holder:CreateTexture(nil, "OVERLAY", nil, -8)
        borderTexture:SetAtlas(AURA_BORDER_ATLAS)
        borderTexture:SetDesaturated(true)
        borderTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        PositionBorder(borderTexture, anchor)

        if not holder._uberBorderSized then
            holder._uberBorderSized = true
            holder:HookScript("OnSizeChanged", function()
                PositionBorder(borderTexture, anchor)
            end)
        end

        return borderTexture
    end

    if BuffBarCooldownViewer and BuffBarCooldownViewer:IsShown() then
        local children = { BuffBarCooldownViewer:GetChildren() }
        for _, f in ipairs(children) do
            if f and f.Bar then
                for _, r in ipairs({ f.Bar:GetRegions() }) do
                    if r:IsObjectType("Texture") and r:GetDrawLayer() == "BACKGROUND" then
                        r:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                    end
                end
            end

            if f and not f.styled and f.Icon then
                local iconFrame = f.Icon
                local iconTexture
                for _, region in ipairs({ iconFrame:GetRegions() }) do
                    if region:IsObjectType("Texture") then
                        iconTexture = region
                        break
                    end
                end

                if iconTexture then
                    f.uberBorder = CreateBorder(f, iconFrame)
                    f.styled = true
                end
            end
        end
    end

    local function ApplyBordersToIconViewer(viewer)
        if viewer then
            local children = { viewer:GetChildren() }
            for _, f in ipairs(children) do
                if f and not f.styled and f.Icon then
                    local icon = f.Icon
                    if icon:IsObjectType("Frame") then
                        local iconFrame = icon
                        local iconTexture
                        for _, region in ipairs({ iconFrame:GetRegions() }) do
                            if region:IsObjectType("Texture") then
                                iconTexture = region
                                break
                            end
                        end

                        if iconTexture then
                            f.uberBorder = CreateBorder(f, iconFrame)
                            f.styled = true
                        end
                    elseif icon:IsObjectType("Texture") then
                        local iconTexture = icon
                        f.uberBorder = CreateBorder(f, iconTexture)
                        f.styled = true
                    end
                end
            end
        end
    end

    ApplyBordersToIconViewer(BuffIconCooldownViewer)
    ApplyBordersToIconViewer(UtilityCooldownViewer)
    ApplyBordersToIconViewer(EssentialCooldownViewer)
end

-------------------------------------------------------------------------------
-- Square icons: Blizzard's rounded mask, ring overlay and rounded swipe are
-- taken off/hidden, the icon zoomed, and a square border (squareborders.lua,
-- location "cdm") drawn instead. Undone when switching back.
-------------------------------------------------------------------------------
local SB = UberUI.squareborders
local SQUARE_LOC = "cdm"
local RING_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local SWIPE_ROUNDED = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local SWIPE_SQUARE = "Interface\\Buttons\\WHITE8X8"
local squareState = setmetatable({}, { __mode = "k" }) -- item frame -> { masks, ring }
local function SquareOn()
    return SB and SB.IsEnabled(SQUARE_LOC)
end

-- Icon texture and the frame holding it (bars nest the icon in an .Icon frame).
local function GetIconParts(f)
    local icon = f and f.Icon
    if not icon then return nil end
    if icon:IsObjectType("Frame") then
        return icon.Icon, icon
    end
    return icon, f
end

local function FindRing(holder)
    for _, region in ipairs({ holder:GetRegions() }) do
        if region:IsObjectType("Texture") and region.GetAtlas and region:GetAtlas() == RING_ATLAS then
            return region
        end
    end
end

local sizeHooked = setmetatable({}, { __mode = "k" })  -- icon holder -> true

-- Blizzard's grid overlaps item frames by GetAdditionalPaddingOffset() (-4,
-- in item units) so the rounded art touches at padding 0. Square icons are
-- inset by half that per side to touch the same way. Bar icons aren't in that
-- grid and use MASK_INSET.
local BLIZZARD_PADDING_OFFSET = -4
local MASK_INSET = 3 / 64

local function GetPaddingOffset(viewer)
    if viewer and viewer.GetAdditionalPaddingOffset then
        local ok, v = pcall(viewer.GetAdditionalPaddingOffset, viewer)
        if ok and type(v) == "number" and not (issecretvalue and issecretvalue(v)) then return v end
    end
    return BLIZZARD_PADDING_OFFSET
end

local function IsAuraViewer(f)
    local p = f and (f._uberViewer or f:GetParent())
    if p then
        if p == _G["BuffIconCooldownViewer"] or p == _G["BuffBarCooldownViewer"] then
            return true
        end
        local pName = p.GetName and p:GetName()
        if pName == "BuffIconCooldownViewer" or pName == "BuffBarCooldownViewer" then
            return true
        end
    end
    return false
end


-- Borders are always dark; Blizzard's dispel-colored DebuffBorder stays hidden
-- (the dispel type is secret to addons in combat).

local QueueStyle -- defined further down

local function SafeShown(region)
    local ok, shown = pcall(region.IsShown, region)
    if not ok or (issecretvalue and issecretvalue(shown)) then return false end
    return shown and true or false
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

-- The aura's spell if showing one, else the (override) spell. Not
-- f.cooldownID: that's the Cooldown Manager's own ID.
local function ItemSpellID(f)
    local ok, id
    if f.GetAuraSpellID then
        ok, id = pcall(f.GetAuraSpellID, f)
        if ok and type(id) == "number" and not IsSecret(id) and id > 0 then return id end
    end
    if f.GetSpellID then
        ok, id = pcall(f.GetSpellID, f)
        if ok and type(id) == "number" and not IsSecret(id) and id > 0 then return id end
    end
    if f.GetBaseSpellID then
        ok, id = pcall(f.GetBaseSpellID, f)
        if ok and type(id) == "number" and not IsSecret(id) and id > 0 then return id end
    end
    return nil
end

-- The aura the item is displaying, its unit and instance ID. Fields may be secret.
local function ItemAura(f)
    local aura, unit, id
    if f.GetAuraDataCached then
        local ok, a = pcall(f.GetAuraDataCached, f)
        if ok and a and not IsSecret(a) then aura = a end
    end
    if f.GetAuraDataUnit then
        local ok, u = pcall(f.GetAuraDataUnit, f)
        if ok and type(u) == "string" and not IsSecret(u) then unit = u end
    end
    if f.GetAuraSpellInstanceID then
        local ok, i = pcall(f.GetAuraSpellInstanceID, f)
        if ok and type(i) == "number" and not IsSecret(i) then id = i end
    end
    if not id and aura and not IsSecret(aura.auraInstanceID) then id = aura.auraInstanceID end
    return aura, unit, id
end

local function FindItemAuraData(f)
    local spellID = ItemSpellID(f)
    local aura, unit = ItemAura(f)
    return aura, unit, spellID
end

-- Essential/Utility Cooldown frames also show the GCD swipe; anything this
-- short is never the spell's own cooldown.
local GCD_MAX = 1.5

-- Seconds, whichever unit the source used (some report milliseconds).
local function NormalizeTimes(start, duration, now)
    if start > (now * 2) or duration > 1000 then
        return start / 1000, duration / 1000
    end
    return start, duration
end

-- expTime, duration of what the item counts down. 0, 0 when nothing runs;
-- nil when the values are secret, so callers keep their last known state.
local function GetItemCooldownAndDuration(f, now)
    now = now or GetTime()
    local sawSecret = false

    if f.Cooldown and f.Cooldown.GetCooldownTimes then
        local ok, startTime, duration = pcall(f.Cooldown.GetCooldownTimes, f.Cooldown)
        if ok and (IsSecret(startTime) or IsSecret(duration)) then
            sawSecret = true
        elseif ok and type(startTime) == "number" and type(duration) == "number" and duration > 0 then
            startTime, duration = NormalizeTimes(startTime, duration, now)
            local expTime = startTime + duration
            if duration > GCD_MAX and expTime > now then
                return expTime, duration
            end
        end
    end

    local aura = FindItemAuraData(f)
    if aura then
        local expTime, duration = aura.expirationTime, aura.duration
        if IsSecret(expTime) or IsSecret(duration) then
            sawSecret = true
        elseif type(expTime) == "number" and type(duration) == "number" and duration > 0 then
            expTime, duration = NormalizeTimes(expTime, duration, now)
            if expTime > now then
                return expTime, duration
            end
        end
    end

    -- Spell cooldown: Essential/Utility only (a tracked aura's spell cooldown
    -- says nothing about the aura's time left).
    if not IsAuraViewer(f) then
        local spellID = ItemSpellID(f)
        local ok, sc = pcall(C_Spell.GetSpellCooldown, spellID or 0)
        if spellID and ok and sc then
            if IsSecret(sc.startTime) or IsSecret(sc.duration) or IsSecret(sc.isOnGCD) then
                sawSecret = true
            elseif not sc.isOnGCD and type(sc.startTime) == "number" and type(sc.duration) == "number"
                and sc.duration > GCD_MAX then
                local startTime, duration = NormalizeTimes(sc.startTime, sc.duration, now)
                local expTime = startTime + duration
                if expTime > now then
                    return expTime, duration
                end
            end
        end
    end

    if sawSecret then return nil end
    return 0, 0
end

-- Keep Blizzard's proc glow (SpellActivationAlert) above our square border.
local function RaiseProcGlow(f)
    local alert = f.SpellActivationAlert
    local sb = SB.Find(f, 1)
    if alert and sb then
        local ok, level = pcall(sb.GetFrameLevel, sb)
        if ok and type(level) == "number" then alert:SetFrameLevel(level + 2) end
    end
end

local procHookInstalled = false
local function EnsureProcGlowHook()
    if procHookInstalled or not (ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.ShowAlert) then return end
    procHookInstalled = true
    hooksecurefunc(ActionButtonSpellAlertManager, "ShowAlert", function(_, button)
        if button and SB.Find(button, 1) then
            C_Timer.After(0, function() pcall(RaiseProcGlow, button) end)
        end
    end)
end

-- Blizzard shows/hides DebuffBorder itself, so it's faded by alpha.
local function UpdateSquareDebuffColor(f)
    local tex = GetIconParts(f)
    if not tex then return end

    if f.DebuffBorder then f.DebuffBorder:SetAlpha(0) end

    if uuidb.cooldown.borders == false then
        local sb = SB.Find(f, 1)
        if sb then sb:Hide() end
        if f.uberBorder then f.uberBorder:Hide() end
        return
    end

    if SquareOn() then
        local sb = SB.Get(f, 1)
        SB.LayoutFor(sb, tex, SQUARE_LOC)
        SB.SetDarkColor(sb)
        SB.RaiseAbove(sb, f.DebuffBorder or f.Cooldown or f, 2)
        sb:Show()
        RaiseProcGlow(f)
    elseif f.uberBorder then
        local dc = uuidb.general.darkencolor
        f.uberBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        f.uberBorder:Show()
    end
end

local function QueueDebuffColor(f)
    if f._uberDebuffQueued then return end
    f._uberDebuffQueued = true
    C_Timer.After(0, function()
        f._uberDebuffQueued = nil
        pcall(UpdateSquareDebuffColor, f)
    end)
end

local function EnsureDebuffHook(f)
    if not f._uberDebuffHooked then
        f._uberDebuffHooked = true
        f:HookScript("OnShow", QueueDebuffColor)
    end
end

-- One physical pixel in `region`'s coordinate space.
local function PixelUnit(region)
    local factor = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()) or 1
    local ok, scale = pcall(region.GetEffectiveScale, region)
    if not ok or IsSecret(scale) or type(scale) ~= "number" or scale <= 0 then scale = 1 end
    return factor / scale
end

-- Item sizes in the items' own units (CooldownViewer.xml; bars: the Icon
-- frame). Edit Mode's icon size is a SetScale on top, so these are constant.
-- Fallback for when GetSize comes back secret.
local TEMPLATE_SIZES = {
    EssentialCooldownViewer = 50,
    UtilityCooldownViewer   = 30,
    BuffIconCooldownViewer  = 40,
    BuffBarCooldownViewer   = 30,
}

-- holder: an icon viewer's item frame, or a bar item's Icon frame.
local function HolderSize(holder)
    local ok, w, h = pcall(holder.GetSize, holder)
    if ok and not IsSecret(w) and not IsSecret(h) and type(w) == "number" and w > 0
        and type(h) == "number" and h > 0 then
        return w, h
    end
    local item = (holder.layoutIndex ~= nil) and holder or holder:GetParent()
    local viewer = item and (item._uberViewer or item:GetParent())
    local name = viewer and viewer.GetName and viewer:GetName()
    local size = name and TEMPLATE_SIZES[name]
    if size then return size, size end
    return nil
end

local function IconInset(holder)
    local w = HolderSize(holder)
    if not w then return 0 end
    local inset
    if holder.layoutIndex ~= nil and holder.Bar == nil then
        inset = -GetPaddingOffset(holder._uberViewer or holder:GetParent()) / 2
    else
        inset = w * MASK_INSET
    end
    return math.max(0, inset)
end

-- Round half up, with slack so float dust can't round equal edges apart.
local function RoundPixel(v)
    return math.floor(v + 0.5 + 0.001)
end

-- Insets (left, right, top, bottom) that put the icon's edges on whole
-- physical pixels. Rounding absolute edges (not the inset) makes touching
-- icons agree: one's right edge and the next one's left edge are the same
-- number before rounding. Falls back to the plain inset if the rect is secret.
local function PixelAlignedInsets(holder, inset)
    local ok, left, bottom, width, height = pcall(holder.GetRect, holder)
    if not ok or IsSecret(left) or IsSecret(bottom) or IsSecret(width) or IsSecret(height)
        or type(left) ~= "number" or type(bottom) ~= "number"
        or type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
        return inset, inset, inset, inset
    end
    local px = PixelUnit(holder)
    local L, R = left / px, (left + width) / px
    local B, T = bottom / px, (bottom + height) / px
    local i = inset / px
    return (RoundPixel(L + i) - L) * px, (R - RoundPixel(R - i)) * px,
           (T - RoundPixel(T - i)) * px, (RoundPixel(B + i) - B) * px
end

-- Visible icon width in item units, for sizing the pandemic glows (the item's
-- scale applies on top).
local function IconWidth(holder)
    local w = HolderSize(holder)
    return w and (w - 2 * IconInset(holder)) or nil
end

local function LayoutSquareIcon(f, tex, holder)
    local l, r, t, b = PixelAlignedInsets(holder, IconInset(holder))
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", holder, "TOPLEFT", l, -t)
    tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -r, b)
    if f.Cooldown then
        f.Cooldown:ClearAllPoints()
        f.Cooldown:SetAllPoints(tex)
    end
    local sb = SB.Find(f, 1)
    if sb and sb:IsShown() then SB.LayoutFor(sb, tex, SQUARE_LOC) end
    pcall(UpdateSquareDebuffColor, f)
end

local function ApplySquareIcon(f, square)
    local tex, holder = GetIconParts(f)
    if not tex then return end
    local state = squareState[f]

    if not square then
        if not state then return end
        for _, m in ipairs(state.masks) do pcall(tex.AddMaskTexture, tex, m) end
        if state.ring then state.ring:SetAlpha(1) end
        if f.OutOfRange then f.OutOfRange:SetAlpha(1) end
        tex:SetTexCoord(0, 1, 0, 1)
        tex:ClearAllPoints()
        tex:SetAllPoints(holder)
        if f.Cooldown then
            pcall(f.Cooldown.SetSwipeTexture, f.Cooldown, SWIPE_ROUNDED)
            f.Cooldown:ClearAllPoints()
            f.Cooldown:SetAllPoints(f)
        end
        SB.Hide(f, 1)
        squareState[f] = nil
        if f.DebuffBorder then f.DebuffBorder:SetAlpha(0) end
        return
    end

    if not state then
        state = { masks = {} }
        local n = tex.GetNumMaskTextures and tex:GetNumMaskTextures() or 0
        for i = n, 1, -1 do
            local m = tex:GetMaskTexture(i)
            if m then
                state.masks[#state.masks + 1] = m
                tex:RemoveMaskTexture(m)
            end
        end
        state.ring = FindRing(holder)
        squareState[f] = state
    end
    if state.ring then state.ring:SetAlpha(0) end
    -- The out-of-range shadow is shaped for the rounded icon; the icon's red
    -- tint still marks out of range.
    if f.OutOfRange then f.OutOfRange:SetAlpha(0) end
    if f.DebuffBorder then f.DebuffBorder:SetAlpha(0) end
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if not sizeHooked[holder] then
        sizeHooked[holder] = true
        holder:HookScript("OnSizeChanged", function()
            if squareState[f] then pcall(LayoutSquareIcon, f, tex, holder) end
        end)
    end
    if f.Cooldown then pcall(f.Cooldown.SetSwipeTexture, f.Cooldown, SWIPE_SQUARE) end

    if uuidb.cooldown.borders == false then
        SB.Hide(f, 1)
    else
        local sb = SB.Get(f, 1)
        SB.LayoutFor(sb, tex, SQUARE_LOC)
        SB.RaiseAbove(sb, f.Cooldown or holder, 2)
        SB.SetDarkColor(sb)
        sb:Show()
        EnsureProcGlowHook()
        RaiseProcGlow(f)
    end
    EnsureDebuffHook(f)
    LayoutSquareIcon(f, tex, holder)
end

-------------------------------------------------------------------------------
-- Pandemic highlight: Border, Proc Glow or Marching Ants in place of
-- Blizzard's own pandemic effect.
-------------------------------------------------------------------------------
local aurakit = UberUI.aurakit
local PANDEMIC_DEFAULT_COLOR = "ffff2626"
local pandemicHosts = setmetatable({}, { __mode = "k" })  -- item frame -> host

local function PandemicStyle()
    return (uuidb and uuidb.cooldown and uuidb.cooldown.pandemicstyle) or "blizzard"
end

local function PandemicColor()
    if uuidb and uuidb.cooldown and uuidb.cooldown.pandemicclasscolor then
        local _, class = UnitClass("player")
        local c = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or RAID_CLASS_COLORS[class])
        if c then return c.r, c.g, c.b end
    end
    local hex = uuidb and uuidb.cooldown and uuidb.cooldown.pandemiccolor
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x%x%x$") then hex = PANDEMIC_DEFAULT_COLOR end
    local ok, c = pcall(CreateColorFromHexString, hex)
    if ok and c then return c.r, c.g, c.b end
    return 1, 0.15, 0.15
end

local CDM_GLOW_SCALE = 1.1

local function StylePandemicHost(f)
    local tex, holder = GetIconParts(f)
    if not tex then return nil end
    local host = pandemicHosts[f]
    if not host then
        host = CreateFrame("Frame", nil, f)
        host:SetAllPoints(holder)
        host:SetFrameLevel((f.Cooldown or holder):GetFrameLevel() + 4)
        host:EnableMouse(false)
        host:Hide()
        pandemicHosts[f] = host
    end
    local level = (f.Cooldown or holder):GetFrameLevel()
    local sb = SB.Find(f, 1)
    if sb then level = math.max(level, sb:GetFrameLevel()) end
    host:SetFrameLevel(level + 2)
    local w = IconWidth(holder)
    local r, g, b = PandemicColor()
    aurakit.StyleHighlight(host, {
        kind = PandemicStyle(),
        r = r, g = g, b = b,
        square = squareState[f] ~= nil,
        loc = SQUARE_LOC, icon = tex,
        ringFrom = holder, ringX = -2,
        center = tex, size = w or 36, glowScale = CDM_GLOW_SCALE,
    })
    return host
end

-- Our highlight follows Blizzard's pandemic state (item.PandemicIcon, shown
-- by ShowPandemicStateFrame): Blizzard knows which auras can pandemic and the
-- real window, and it works while aura data is secret.
local function HasBlizzardPandemic(f)
    return type(f.ShowPandemicStateFrame) == "function"
end

-- Alpha, not Hide: Blizzard re-shows it every frame while in pandemic.
local function SetBlizzardPandemicAlpha(f, alpha)
    local p = f.PandemicIcon
    if not p then return end
    local ok, cur = pcall(p.GetAlpha, p)
    if ok and not IsSecret(cur) and cur ~= alpha then pcall(p.SetAlpha, p, alpha) end
end

-- Only installed while a custom pandemic style is chosen.
local pandemicShowHooked = setmetatable({}, { __mode = "k" })
local function EnsurePandemicShowHook(f)
    if pandemicShowHooked[f] or not HasBlizzardPandemic(f) then return end
    pandemicShowHooked[f] = true
    hooksecurefunc(f, "ShowPandemicStateFrame", function(self)
        if PandemicStyle() == "blizzard" or self._uberPandemicPending then return end
        local p = self.PandemicIcon
        local ok, a = pcall(p and p.GetAlpha, p)
        if not ok or IsSecret(a) or a == 0 then return end
        self._uberPandemicPending = true
        C_Timer.After(0, function()
            self._uberPandemicPending = nil
            if PandemicStyle() ~= "blizzard" then SetBlizzardPandemicAlpha(self, 0) end
        end)
    end)

    -- Once an aura ends Blizzard stops updating the pandemic window but keeps
    -- checking it, so a re-apply inside the old window would read as pandemic.
    -- Distrust the flag from the aura leaving (auraInstanceID cleared before
    -- the item hides) until Blizzard computes a new window.
    f:HookScript("OnHide", function(self)
        local id = self.auraInstanceID
        if not IsSecret(id) and id == nil then self._uberPandemicStale = true end
    end)
    if type(f.SetPandemicAlertTriggerTime) == "function" then
        hooksecurefunc(f, "SetPandemicAlertTriggerTime", function(self)
            self._uberPandemicStale = nil
        end)
    end
end

local function UpdateItemPandemic(f, now)
    local custom = PandemicStyle() ~= "blizzard"
    if not custom then
        -- Pooled: a frame we faded may come back on another item.
        SetBlizzardPandemicAlpha(f, 1)
        if f._uberInPandemic then
            f._uberInPandemic = nil
            if pandemicHosts[f] then pandemicHosts[f]:Hide() end
        end
        return
    end

    local inPandemic = false
    if HasBlizzardPandemic(f) then
        EnsurePandemicShowHook(f)
        SetBlizzardPandemicAlpha(f, 0)
        inPandemic = not f._uberPandemicStale and f.PandemicIcon ~= nil and SafeShown(f.PandemicIcon) or false
    elseif IsAuraViewer(f) then
        -- No Blizzard pandemic state on this client: time the aura itself.
        local aura = FindItemAuraData(f)
        local expTime = aura and aura.expirationTime
        local duration = aura and aura.duration
        if not IsSecret(expTime) and not IsSecret(duration) and type(expTime) == "number"
            and type(duration) == "number" and duration > 0 then
            local remaining = expTime - now
            inPandemic = remaining > 0 and remaining <= duration * 0.3
        end
    end

    if inPandemic ~= f._uberInPandemic then
        f._uberInPandemic = inPandemic
        local host = pandemicHosts[f]
        if inPandemic and f:IsShown() then
            local ok, res = pcall(StylePandemicHost, f)
            if ok and res then
                res:Show()
            elseif not ok then
                UberUI:ReportError("Cooldown Manager pandemic highlight", res)
            end
        elseif host then
            host:Hide()
        end
    end
end

local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local function ForEachItemFrame(fn)
    local visited = {}
    for _, name in ipairs(VIEWERS) do
        local viewer = _G[name]
        if viewer then
            if viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
                for f in viewer.itemFramePool:EnumerateActive() do
                    if f and f.Icon and not visited[f] then
                        visited[f] = true
                        f._uberViewer = viewer
                        fn(f, viewer)
                    end
                end
            end
            for _, f in ipairs({ viewer:GetChildren() }) do
                if f and f.Icon and not visited[f] then
                    visited[f] = true
                    f._uberViewer = viewer
                    fn(f, viewer)
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Countdown text colors
-------------------------------------------------------------------------------
local function GetDurationColors()
    local c = uuidb and uuidb.cooldown or {}
    local threshold = tonumber(c.durationthreshold) or 5
    if threshold < 0 then threshold = 0 end
    return c.durationcolor or "ffffffff", c.durationexpiringcolor or "ffff3333", threshold
end

local function HexToRGB(hex, defR, defG, defB)
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x%x%x$") then return defR or 1, defG or 1, defB or 1 end
    local ok, col = pcall(CreateColorFromHexString, hex)
    if ok and col then return col.r, col.g, col.b end
    return defR or 1, defG or 1, defB or 1
end

local function GetCountdownFontString(f)
    if f._uberCdText then return f._uberCdText end

    if f.Bar and f.Bar.Duration then
        f._uberCdText = f.Bar.Duration
        return f.Bar.Duration
    end

    local cd = f.Cooldown
    if cd then
        if cd.GetCountdownFontString then
            local fs = cd:GetCountdownFontString()
            if fs then f._uberCdText = fs; return fs end
        end
        if cd.timer and cd.timer.text then
            f._uberCdText = cd.timer.text
            return cd.timer.text
        end
        if cd.text then
            f._uberCdText = cd.text
            return cd.text
        end
        for _, region in ipairs({ cd:GetRegions() }) do
            if region:IsObjectType("FontString") then
                f._uberCdText = region
                return region
            end
        end
    end

    for _, region in ipairs({ f:GetRegions() }) do
        if region:IsObjectType("FontString") and region ~= f.Count and region ~= f.count then
            f._uberCdText = region
            return region
        end
    end

    local durText = (f.Bar and f.Bar.Duration) or f.Duration
    if durText then
        f._uberCdText = durText
        return durText
    end

    return nil
end

-- Icon countdowns use an engine countdown formatter (Cooldown:
-- SetCountdownFormatter): the engine picks the color from the time left (it's
-- in the format string), so it works on secret durations and never sees the
-- GCD. One shared formatter per (threshold, colors).
local countdownFormatters = {}
local formatterUnsupported = false
local formatterAttached = setmetatable({}, { __mode = "k" }) -- Cooldown -> formatter

local function BuildCountdownFormatter(threshold, nr, ng, nb, er, eg, eb)
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter
        and Enum and Enum.NumericRuleFormatRounding) then
        return nil
    end
    local Up = Enum.NumericRuleFormatRounding.Up
    local normal = CreateColor(nr, ng, nb, 1)
    local function N(fmt) return normal:WrapTextInColorCode(fmt) end
    local points = {
        { threshold = 0, format = CreateColor(er, eg, eb, 1):WrapTextInColorCode("%d"), rounding = Up, step = 1 },
        { threshold = threshold, format = N("%d"), rounding = Up, step = 1 },
        -- Just above each unit boundary so an up-rounded 59.x reads "1:00", not "60".
        { threshold = 59.0001, format = N("%d:%02d"), rounding = Up, step = 1,
          components = { { div = 60 }, { mod = 60 } } },
        { threshold = 3599.0001, format = N("%dh"), rounding = Up, step = 1,
          components = { { div = 3600 } } },
        { threshold = 86399.0001, format = N("%dd"), rounding = Up, step = 1,
          components = { { div = 86400 } } },
    }
    local f = C_StringUtil.CreateNumericRuleFormatter()
    if not pcall(f.SetBreakpoints, f, points) then return nil end
    return f
end

local function GetCountdownFormatter()
    if formatterUnsupported then return nil end
    local normalHex, expiringHex, threshold = GetDurationColors()
    threshold = math.min(threshold, 59)
    local key = normalHex .. expiringHex .. threshold
    local f = countdownFormatters[key]
    if not f then
        local nr, ng, nb = HexToRGB(normalHex, 1, 1, 1)
        local er, eg, eb = HexToRGB(expiringHex, 1, 0.2, 0.2)
        f = BuildCountdownFormatter(threshold, nr, ng, nb, er, eg, eb)
        if not f then
            formatterUnsupported = true
            return nil
        end
        countdownFormatters[key] = f
    end
    return f
end

-- True once the item's countdown is the engine's job.
local function ApplyCountdownFormatter(f)
    local cd = f.Cooldown
    if not (cd and cd.SetCountdownFormatter) then return false end
    local formatter = GetCountdownFormatter()
    if not formatter then return false end
    if formatterAttached[cd] ~= formatter then
        formatterAttached[cd] = formatter
        pcall(cd.SetCountdownFormatter, cd, formatter)
    end
    return true
end

local function UpdateItemDurationColor(f, now)
    if ApplyCountdownFormatter(f) then return end

    -- Bars: Blizzard sets Bar.Duration's text from Lua, so color it by time
    -- left; while that's secret, keep the last known state until it would end.
    local threshold = select(3, GetDurationColors())
    local expTime = GetItemCooldownAndDuration(f, now)
    local state
    if expTime == nil then
        local known = f._uberDurationExp
        state = (known and known > now and known - now <= threshold) and "expiring" or "normal"
    elseif expTime > now then
        f._uberDurationExp = expTime
        state = (expTime - now <= threshold) and "expiring" or "normal"
    else
        f._uberDurationExp = nil
        state = "normal"
    end

    if f._uberDurationState ~= state then
        f._uberDurationState = state
        local text = GetCountdownFontString(f)
        if text then
            local normalHex, expiringHex = GetDurationColors()
            local r, g, b
            if state == "expiring" then
                r, g, b = HexToRGB(expiringHex, 1, 0.2, 0.2)
            else
                r, g, b = HexToRGB(normalHex, 1, 1, 1)
            end
            pcall(text.SetTextColor, text, r, g, b, 1)
        end
    end
end

function cdManager:StyleIcons()
    if not (uuidb and uuidb.cooldown and SB) then return end
    local square = SquareOn()
    ForEachItemFrame(function(f, viewer)
        pcall(ApplySquareIcon, f, square)
        EnsureDebuffHook(f)
        pcall(UpdateSquareDebuffColor, f)
        if pandemicHosts[f] then pcall(StylePandemicHost, f) end
        if f.uberBorder then f.uberBorder:SetShown(not square) end
    end)
end

local function IsEditModeActive()
    return EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
end

-------------------------------------------------------------------------------
-- Alignment: "blizzard" (Blizzard's layout), "pack" (shown items packed from
-- the Edit Mode edge) or "center".
-------------------------------------------------------------------------------
local ALIGN_FIELDS = {
    EssentialCooldownViewer = { "essential_align", "blizzard" },
    UtilityCooldownViewer   = { "utility_align", "blizzard" },
    BuffIconCooldownViewer  = { "bufficon_align", "pack" },
    BuffBarCooldownViewer   = { "buffbar_align", "pack" },
}

local function GetViewerAlign(viewer)
    local name = viewer and viewer.GetName and viewer:GetName()
    local entry = name and ALIGN_FIELDS[name]
    if not entry then return "blizzard" end
    local v = uuidb and uuidb.cooldown and uuidb.cooldown[entry[1]]
    if v == "pack" or v == "center" or v == "blizzard" then return v end
    return entry[2]
end

-- Re-pack as items show/hide. Only installed once a viewer uses our layout.
local repackHooked = setmetatable({}, { __mode = "k" })
local function EnsureRepackHook(f)
    if repackHooked[f] then return end
    repackHooked[f] = true
    local function requeue(self)
        local p = self._uberViewer or (self.GetParent and self:GetParent())
        if p and GetViewerAlign(p) ~= "blizzard" then QueueStyle() end
    end
    f:HookScript("OnShow", requeue)
    f:HookScript("OnHide", requeue)
end

-- Edit Mode padding/direction as CooldownViewerMixin:RefreshLayout reads
-- them, with getter fallbacks for other clients.
local function GetViewerPadding(viewer)
    local pad = viewer.iconPadding
    if type(pad) ~= "number" and viewer.GetPadding then
        local ok, v = pcall(viewer.GetPadding, viewer)
        if ok then pad = v end
    end
    if type(pad) ~= "number" or pad < 0 then pad = 0 end
    return pad
end

local function GetViewerDirection(viewer, isHoriz)
    local enum = Enum and Enum.CooldownViewerIconDirection
    if viewer.iconDirection ~= nil and enum and enum.Right ~= nil then
        local right = viewer.iconDirection == enum.Right
        -- Vertical: always left to right; horizontal: always top to bottom.
        return (not isHoriz) or right, (not isHoriz) and right
    end
    local toRight, toTop = true, false
    if viewer.addIconsToRight ~= nil then
        toRight = viewer.addIconsToRight
    elseif viewer.GetAddIconsToRight then
        local ok, v = pcall(viewer.GetAddIconsToRight, viewer)
        if ok and v ~= nil then toRight = v end
    end
    if viewer.addIconsToTop ~= nil then
        toTop = viewer.addIconsToTop
    elseif viewer.GetAddIconsToTop then
        local ok, v = pcall(viewer.GetAddIconsToTop, viewer)
        if ok and v ~= nil then toTop = v end
    end
    return toRight, toTop
end

local function ApplyCustomViewerLayout(viewer)
    if not viewer or IsEditModeActive() then return end
    local align = GetViewerAlign(viewer)
    if align == "blizzard" then return end

    -- Only shown items get a slot, so hidden (inactive) ones leave no gap.
    local items = {}
    local function consider(f)
        if f and (f.Icon or f.Bar) then
            EnsureRepackHook(f)
            if f:IsShown() then items[#items + 1] = f end
        end
    end
    if viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
        for f in viewer.itemFramePool:EnumerateActive() do consider(f) end
    end
    if #items == 0 then
        for _, f in ipairs({ viewer:GetChildren() }) do consider(f) end
    end
    if #items == 0 then return end

    table.sort(items, function(a, b)
        local ia = a.layoutIndex or 0
        local ib = b.layoutIndex or 0
        if ia ~= ib then return ia < ib end
        return tostring(a) < tostring(b)
    end)

    local sample = items[1]
    local w, h
    if sample.Bar then
        -- Bar width is set at runtime (no template size): skip while secret.
        w, h = sample:GetWidth(), sample:GetHeight()
        if IsSecret(w) or IsSecret(h) then return end
    else
        w, h = HolderSize(sample)
    end
    if type(w) ~= "number" or w <= 0 then w = 36 end
    if type(h) ~= "number" or h <= 0 then h = 36 end

    local isHoriz = (viewer.IsHorizontal and viewer:IsHorizontal()) ~= false
    local stride = (viewer.GetStride and viewer:GetStride()) or 8
    if not stride or stride <= 0 then stride = 8 end
    -- Whole pixels, so every gap is the same width.
    local padPx = PixelUnit(sample)
    local pad = math.floor(GetViewerPadding(viewer) / padPx + 0.5) * padPx

    -- Not rounded: PixelAlignedInsets aligns each icon afterward, which only
    -- lines neighbors up when their unrounded edges coincide.
    local stepX, stepY = w + pad, h + pad
    if not sample.Bar then
        -- Padding is between the visible icons, not the (overlapping) frames.
        local inset = IconInset(sample)
        stepX, stepY = w - 2 * inset + pad, h - 2 * inset + pad
        -- Touching square icons share one border line.
        if pad == 0 and SquareOn() and uuidb.cooldown.borders ~= false then
            local t = SB.PixelsToUIUnits(sample, SB.Thickness(SQUARE_LOC))
            local shared = SB.IsInset(SQUARE_LOC) and -t or t
            stepX, stepY = stepX + shared, stepY + shared
        end
    end

    local goingRight, goingUp = GetViewerDirection(viewer, isHoriz)
    local xDir = goingRight and 1 or -1
    local yDir = goingUp and 1 or -1
    local anchorPoint = (goingUp and "BOTTOM" or "TOP") .. (goingRight and "LEFT" or "RIGHT")

    local numItems = #items
    local numLines = math.ceil(numItems / stride)
    for k = 1, numItems do
        local line = math.floor((k - 1) / stride)
        local i = (k - 1) % stride
        local lineCount = math.min(stride, numItems - line * stride)
        local col, row, nx, ny
        if isHoriz then
            col, row, nx, ny = i, line, lineCount, numLines
        else
            col, row, nx, ny = line, i, numLines, lineCount
        end

        local item = items[k]
        item:ClearAllPoints()
        if align == "center" then
            local x = -(nx - 1) * stepX / 2 + col * stepX
            local y = -(ny - 1) * stepY / 2 + row * stepY
            item:SetPoint("CENTER", viewer, "CENTER", xDir * x, yDir * y)
        else
            item:SetPoint(anchorPoint, viewer, anchorPoint, xDir * col * stepX, yDir * row * stepY)
        end
    end

    -- Moved: re-align the art to whole pixels.
    for k = 1, numItems do
        local item = items[k]
        if squareState[item] then
            local tex, holder = GetIconParts(item)
            if tex then pcall(LayoutSquareIcon, item, tex, holder) end
        end
    end
end

-- Viewers re-create item frames when they lay out: restyle once it's done.
local layoutHooked = false
local stylePending = false
function QueueStyle()
    if stylePending then return end
    stylePending = true
    C_Timer.After(0, function()
        stylePending = false
        cdManager:Texture()
        cdManager:Color()
        cdManager:StyleIcons()
        for _, name in ipairs(VIEWERS) do
            local v = _G[name]
            if v then pcall(ApplyCustomViewerLayout, v) end
        end
    end)
end

local function EnsureLayoutHooks()
    if layoutHooked then return end
    layoutHooked = true
    for _, name in ipairs(VIEWERS) do
        local viewer = _G[name]
        if viewer and viewer.RefreshLayout then
            hooksecurefunc(viewer, "RefreshLayout", function(self)
                QueueStyle()
            end)
        end
    end
end

-- Countdown colors (bars) and pandemic highlights.
local tickerElapsed = 0
cdManager:SetScript("OnUpdate", function(self, elapsed)
    tickerElapsed = tickerElapsed + elapsed
    if tickerElapsed < 0.05 then return end
    tickerElapsed = 0

    local now = GetTime()
    ForEachItemFrame(function(f)
        local okShown, shown = pcall(f.IsShown, f)
        if okShown and shown then
            UpdateItemDurationColor(f, now)
            UpdateItemPandemic(f, now)
        else
            if pandemicHosts[f] then pandemicHosts[f]:Hide() end
            f._uberDurationState = nil
            f._uberDurationExp = nil
            f._uberInPandemic = nil
        end
    end)
end)

local function RegisterCooldownCallbacks()
    if cdManager._callbackRegistered then return end

    EventRegistry:RegisterCallback("CooldownViewerSettings.OnEnterItem", function(cooldownItem)
        QueueStyle()
    end, cdManager)

    EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
        QueueStyle()
    end, cdManager)

    if EventRegistry.RegisterCallback then
        pcall(function()
            EventRegistry:RegisterCallback("EditMode.Exit", function()
                QueueStyle()
            end, cdManager)
        end)
    end

    if EditModeManagerFrame and EditModeManagerFrame.HookScript then
        pcall(function()
            EditModeManagerFrame:HookScript("OnHide", function()
                QueueStyle()
            end)
        end)
    end

    cdManager._callbackRegistered = true
end

cdManager:RegisterEvent("ADDON_LOADED")
cdManager:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Pixel alignment depends on UI scale and resolution.
cdManager:RegisterEvent("UI_SCALE_CHANGED")
cdManager:RegisterEvent("DISPLAY_SIZE_CHANGED")

cdManager:SetScript("OnEvent", function(self, event, addon)
    if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        QueueStyle()
        return
    end
    if event == "ADDON_LOADED" and addon == "Blizzard_CooldownViewer" then
        local function applyStyling()
            cdManager:Texture()
            cdManager:Color()
            cdManager:StyleIcons()
        end
        EnsureLayoutHooks()

        if BuffBarCooldownViewer then BuffBarCooldownViewer:HookScript("OnShow", applyStyling) end
        if BuffIconCooldownViewer then BuffIconCooldownViewer:HookScript("OnShow", applyStyling) end
        if UtilityCooldownViewer then UtilityCooldownViewer:HookScript("OnShow", applyStyling) end
        if EssentialCooldownViewer then EssentialCooldownViewer:HookScript("OnShow", applyStyling) end

        C_Timer.After(0.5, function()
            RegisterCooldownCallbacks()
            applyStyling()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            if EventRegistry then
                RegisterCooldownCallbacks()
            end
            self:Texture()
            self:Color()
            self:StyleIcons()
        end)
    end
end)

function cdManager:Refresh()
    self:Texture()
    self:Color()
    self:StyleIcons()
    for _, name in ipairs(VIEWERS) do
        local v = _G[name]
        if v then pcall(ApplyCustomViewerLayout, v) end
    end
    ForEachItemFrame(function(f)
        f._uberDurationState = nil
        f._uberInPandemic = nil
        if pandemicHosts[f] then pcall(StylePandemicHost, f) end
        pcall(UpdateSquareDebuffColor, f)
    end)
end

UberUI.cdManager = cdManager
