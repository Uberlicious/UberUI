local addon, ns = ...
local cdManager = UberUI:CreateFrame("frame")
local IsSecret, SafeShown = UberUI.util.IsSecret, UberUI.util.SafeShown
local IsSquareBarBG, SquareBarsOn -- defined with the Tracked Bars code
local darkenedBarArt = setmetatable({}, { __mode = "k" }) -- texture -> true

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

local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local function ForEachItemFrame(fn, includeInactive)
    local visited = {}
    for _, name in ipairs(VIEWERS) do
        local viewer = _G[name]
        if viewer then
            if viewer.itemFramePool then
                if viewer.itemFramePool.EnumerateActive then
                    for f in viewer.itemFramePool:EnumerateActive() do
                        if f and (f.Icon or f.Bar) and not visited[f] then
                            visited[f] = true
                            f._uberViewer = viewer
                            fn(f, viewer)
                        end
                    end
                end
                if includeInactive and viewer.itemFramePool.EnumerateInactive then
                    for f in viewer.itemFramePool:EnumerateInactive() do
                        if f and (f.Icon or f.Bar) and not visited[f] then
                            visited[f] = true
                            f._uberViewer = viewer
                            fn(f, viewer)
                        end
                    end
                end
            end
            for _, f in ipairs({ viewer:GetChildren() }) do
                if f and (f.Icon or f.Bar) and not visited[f] then
                    visited[f] = true
                    f._uberViewer = viewer
                    fn(f, viewer)
                end
            end
        end
    end
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
    local name = viewer and viewer.GetName and viewer:GetName()
    return name == "BuffBarCooldownViewer" and -2 or BLIZZARD_PADDING_OFFSET
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


-- The aura's spell if showing one, else the (override) spell. Not
-- f.cooldownID: that's the Cooldown Manager's own ID.
local function ItemSpellID(f)
    local id = f.auraSpellID
    if type(id) == "number" and not IsSecret(id) and id > 0 then return id end
    local info = f.cooldownInfo
    if type(info) == "table" and not IsSecret(info) then
        for _, key in ipairs({ "overrideSpellID", "spellID" }) do
            id = info[key]
            if type(id) == "number" and not IsSecret(id) and id > 0 then return id end
        end
    end
    return nil
end

-- The aura the item is displaying, its unit and instance ID. Fields may be secret.
local function ItemAura(f)
    local aura, unit, id = f.auraDataCached, f.auraDataUnit, f.auraInstanceID
    if IsSecret(aura) or type(aura) ~= "table" then aura = nil end
    if IsSecret(unit) or type(unit) ~= "string" then unit = nil end
    if IsSecret(id) or type(id) ~= "number" then id = nil end
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

local AURA_BORDER_ATLAS = "ui-debuff-border-default-noicon"

-- Proportional to the icon's width (Edit Mode resizes icons). 3/30 rather
-- than the aura borders' 5/30 so neighbors at 0 padding don't overlap.
local function GetBorderPad(anchor)
    local ok, width = pcall(anchor.GetWidth, anchor)
    if not ok or IsSecret(width) or type(width) ~= "number" or width <= 0 then return 3 end
    return math.max(1, math.floor(width * (3 / 30) + 0.5))
end

local function PositionBorder(border, anchor)
    local pad = GetBorderPad(anchor)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", anchor, "TOPLEFT", -pad, pad)
    border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", pad, -pad)
end

local function CreateBorder(parent, anchor, dc)
    local holder
    if anchor:IsObjectType("Frame") then
        holder = anchor
    else
        holder = anchor:GetParent()
    end

    local borderTexture = holder:CreateTexture(nil, "OVERLAY", nil, -8)
    borderTexture:SetAtlas(AURA_BORDER_ATLAS)
    borderTexture:SetDesaturated(true)
    if dc then
        borderTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end
    PositionBorder(borderTexture, anchor)

    if not holder._uberBorderSized then
        holder._uberBorderSized = true
        holder:HookScript("OnSizeChanged", function()
            PositionBorder(borderTexture, anchor)
        end)
    end

    return borderTexture
end

local function EnsureRoundedBorder(f, dc)
    dc = dc or (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    if f.uberBorder then
        f.uberBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        f.uberBorder:Show()
        return f.uberBorder
    end
    local anchor = f.Icon
    if not anchor then
        local tex, holder = GetIconParts(f)
        anchor = holder or tex
    end
    if not anchor then return end
    f.uberBorder = CreateBorder(f, anchor, dc)
    f.styled = true
    f.uberBorder:Show()
    return f.uberBorder
end

-- Blizzard shows/hides DebuffBorder itself, so it's faded by alpha.
local PandemicKeepsBorder -- defined with the pandemic code
local pandemicHosts = setmetatable({}, { __mode = "k" })  -- item frame -> host

-- An item's layers, bottom to top: icon, cooldown swipe, square border,
-- pandemic highlight, countdown numbers, stack/charge text. The countdown
-- numbers belong to the Cooldown frame, so they're moved onto a text frame
-- that's a child of it (they still show and hide with the cooldown) at a
-- level above the border. A bar item's icon count is a font string on its
-- Icon frame, so it's moved onto a text layer too. Re-set whenever the
-- border is placed.
local countdownLayers = setmetatable({}, { __mode = "k" }) -- Cooldown -> frame
local function LayerItem(f, holder)
    local base = holder:GetFrameLevel()
    local cd = f.Cooldown
    if cd then cd:SetFrameLevel(base + 1) end
    local sb = SB.Find(f, 1)
    if sb then sb:SetFrameLevel(base + 2) end
    local host = pandemicHosts[f]
    if host and not f.Bar then host:SetFrameLevel(base + 3) end
    if cd and cd.GetCountdownFontString then
        local text = cd:GetCountdownFontString()
        if text then
            local layer = countdownLayers[cd]
            if not layer then
                layer = CreateFrame("Frame", nil, cd)
                layer:SetAllPoints(cd)
                layer:EnableMouse(false)
                countdownLayers[cd] = layer
            end
            if text:GetParent() ~= layer then text:SetParent(layer) end
            layer:SetFrameLevel(base + 4)
        end
    end
    for _, key in ipairs({ "ChargeCount", "Applications" }) do
        local t = f[key]
        if t and t.SetFrameLevel then t:SetFrameLevel(base + 5) end
    end
    if f.Bar and holder.Applications then
        UberUI.general:LiftAuraText(holder, 5, { "Applications" })
    end
end

-- The icon's border: dark, or black behind a pandemic glow (Proc Glow,
-- Marching Ants, Pixel Glow); hidden under a pandemic Border, which replaces it.
local function UpdateSquareDebuffColor(f)
    local tex = GetIconParts(f)
    if not tex then return end

    if f.DebuffBorder then f.DebuffBorder:SetAlpha(0) end

    local behindGlow = f._uberInPandemic and PandemicKeepsBorder(f)
    if f._uberInPandemic and not behindGlow then
        local sb = SB.Find(f, 1)
        if sb then sb:Hide() end
        if f.uberBorder then f.uberBorder:Hide() end
        return
    end

    if uuidb and uuidb.cooldown and uuidb.cooldown.borders == false then
        local sb = SB.Find(f, 1)
        if sb then sb:Hide() end
        if f.uberBorder then f.uberBorder:Hide() end
        return
    end

    local BLACK = { r = 0, g = 0, b = 0, a = 1 }
    if SquareOn() then
        local sb = SB.Get(f, 1)
        SB.LayoutFor(sb, tex, SQUARE_LOC)
        if behindGlow then SB.SetColor(sb, 0, 0, 0, 1) else SB.SetDarkColor(sb) end
        sb:Show()
        local _, holder = GetIconParts(f)
        if holder then LayerItem(f, holder) end
        RaiseProcGlow(f)
        if f.uberBorder then f.uberBorder:Hide() end
    else
        local sb = SB.Find(f, 1)
        if sb then sb:Hide() end
        local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        EnsureRoundedBorder(f, behindGlow and BLACK or dc)
    end
end

function cdManager:Color()
    if not uuidb or not uuidb.general then return end

    local bordersEnabled = not (uuidb.cooldown and uuidb.cooldown.borders == false)
    local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    local square = SquareOn and SquareOn()

    ForEachItemFrame(function(f, viewer)
        -- "Darken Tracked Bars": Blizzard's bar background/border art. Square
        -- bars hide that art, so it's left alone there.
        if f and f.Bar then
            local darken = uuidb.cooldown.darkenbars ~= false and not SquareBarsOn()
            for _, r in ipairs({ f.Bar:GetRegions() }) do
                if r:IsObjectType("Texture") and r:GetDrawLayer() == "BACKGROUND" and not IsSquareBarBG(r) then
                    if darken then
                        r:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                        darkenedBarArt[r] = true
                    elseif darkenedBarArt[r] then
                        r:SetVertexColor(1, 1, 1, 1)
                        darkenedBarArt[r] = nil
                    end
                end
            end
        end

        if f._uberInPandemic then
            pcall(UpdateSquareDebuffColor, f)
            return
        end
        if not bordersEnabled then
            if f.uberBorder then f.uberBorder:Hide() end
            if SB then SB.Hide(f, 1) end
            return
        end

        if square then
            if f.uberBorder then f.uberBorder:Hide() end
            local sb = SB and SB.Find(f, 1)
            if sb then
                SB.SetDarkColor(sb)
                sb:Show()
            else
                pcall(UpdateSquareDebuffColor, f)
            end
        else
            if SB then SB.Hide(f, 1) end
            EnsureRoundedBorder(f, dc)
        end
    end, true)
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
local barIconSizes = setmetatable({}, { __mode = "k" }) -- bar icon frame -> size we set

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
    if barIconSizes[holder] then return barIconSizes[holder], barIconSizes[holder] end
    local item = (holder.layoutIndex ~= nil) and holder or holder:GetParent()
    local viewer = item and (item._uberViewer or item:GetParent())
    local name = viewer and viewer.GetName and viewer:GetName()
    local size = name and TEMPLATE_SIZES[name]
    if size then return size, size end
    return nil
end

local function IconInset(holder)
    if barIconSizes[holder] then return 0 end
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
        SB.SetDarkColor(sb)
        sb:Show()
        LayerItem(f, holder)
        EnsureProcGlowHook()
        RaiseProcGlow(f)
    end
    EnsureDebuffHook(f)
    LayoutSquareIcon(f, tex, holder)
end

-------------------------------------------------------------------------------
-- Tracked Bars: texture, square border and icon size.
-------------------------------------------------------------------------------
local BAR_ATLAS = "UI-HUD-CoolDownManager-Bar"
local BAR_HEIGHT = 19     -- CooldownViewerBuffBarItemTemplate's bar
local BAR_ICON_SIZE = 30  -- ... and icon
local SQUARE_BAR_BG_ALPHA = 0.6
local barState = setmetatable({}, { __mode = "k" })   -- bar -> { textured, bg }
local maskedFills = setmetatable({}, { __mode = "k" }) -- fill texture -> true

function SquareBarsOn()
    return uuidb and uuidb.cooldown and uuidb.cooldown.squarebars == true
end

function IsSquareBarBG(region)
    for _, st in pairs(barState) do
        if st.bg == region then return true end
    end
    return false
end

-- The bar texture in effect, or nil for Blizzard's. Square bars need a flat
-- texture, so they default to "Blizzard_Flat".
local function GetBarTexture()
    local c, g, bars = uuidb.cooldown, uuidb.general, uuidb.statusbars
    local tex
    if c.bartextures and c.bartexture ~= "Blizzard" then
        tex = bars[c.bartexture]
    elseif g.allbartextures and g.texture ~= "Blizzard" then
        tex = bars[g.texture]
    elseif SquareBarsOn() then
        tex = bars["Blizzard_Flat"] or bars["blizzard_flat"] or "Interface\\AddOns\\Uber UI\\textures\\statusbars\\nameplate"
    end
    return type(tex) == "string" and tex or nil
end

local function StyleBarFill(bar, texture, square)
    local st = barState[bar]
    if texture then
        bar:SetStatusBarTexture(texture)
        st.textured = true
    elseif st.textured then
        local fill = bar:GetStatusBarTexture()
        if fill then fill:SetAtlas(BAR_ATLAS) end
        st.textured = nil
    end
    local fill = bar:GetStatusBarTexture()
    if not fill then return end
    -- Our rounded-end mask only on custom textures in rounded mode.
    local wantMask = texture ~= nil and not square
    if wantMask then
        ApplyMask(bar, MASK_OPTS)
        if not bar._uberStyler then
            bar._uberStyler = true
            bar:HookScript("OnSizeChanged", function(self)
                if self._uberMask then ApplyMask(self, MASK_OPTS) end
            end)
        end
    end
    if bar._uberMask then
        if wantMask and not maskedFills[fill] then
            fill:AddMaskTexture(bar._uberMask)
            maskedFills[fill] = true
        elseif not wantMask and maskedFills[fill] then
            fill:RemoveMaskTexture(bar._uberMask)
            maskedFills[fill] = nil
        end
    end
    -- Unsnapped like the border strips, so their shared edge can't round apart.
    if square and fill.SetSnapToPixelGrid then
        fill:SetSnapToPixelGrid(false)
        fill:SetTexelSnappingBias(0)
    end
end

-- Square: Blizzard's rounded bar background faded out for a flat dark one,
-- and square strips just outside the bar.
local function StyleBarBorder(bar, square)
    local st = barState[bar]
    if not square then
        if st.bg then st.bg:Hide() end
        if bar.BarBG then
            bar.BarBG:SetAlpha(1)
            bar.BarBG:Show()
        end
        SB.Hide(bar, 1)
        return
    end
    if not st.bg then
        st.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        st.bg:SetColorTexture(0, 0, 0, 1)
        st.bg:SetAllPoints(bar)
        st.bg:SetSnapToPixelGrid(false)
        st.bg:SetTexelSnappingBias(0)
    end
    st.bg:SetVertexColor(0, 0, 0, SQUARE_BAR_BG_ALPHA)
    st.bg:Show()
    -- Blizzard's rounded background/border art; Blizzard never re-shows it.
    if bar.BarBG then
        bar.BarBG:SetAlpha(0)
        bar.BarBG:Hide()
    end
    local sb = SB.Get(bar, 1)
    SB.LayoutFor(sb, bar, SQUARE_LOC)
    SB.SetDarkColor(sb)
    SB.RaiseAbove(sb, bar, 2)
    sb:Show()
end

-- "Scale Tracked Bar Icon to Bar Height": the icon frame shrinks to the bar's
-- height (the bar is anchored to it, so it follows).
local BAR_ROW_OVERLAP = 2 -- BuffBarCooldownViewerMixin:GetAdditionalPaddingOffset() (-2)
local barRowResized = setmetatable({}, { __mode = "k" }) -- item frame -> true

-- The icon's visible art matches the bar height: square icons fill their
-- frame (no inset), rounded ones are enlarged past their mask's transparent
-- edge. The row shrinks to bar height + the overlap Blizzard's grid applies,
-- so rows touch at Edit Mode padding 0.
local function SizeBarIcon(f)
    local icon, bar = f.Icon, f.Bar
    if not (icon and icon.IsObjectType and icon:IsObjectType("Frame")) then return end
    if uuidb.cooldown.baricontobar then
        local ok, h = pcall(bar.GetHeight, bar)
        if not ok or IsSecret(h) or type(h) ~= "number" or h <= 0 then h = BAR_HEIGHT end
        local size = SquareOn() and h or (h / (1 - 2 * MASK_INSET))
        if barIconSizes[icon] ~= size then
            barIconSizes[icon] = size
            icon:SetSize(size, size)
        end
        f:SetHeight(h + BAR_ROW_OVERLAP)
        barRowResized[f] = true
    else
        if barIconSizes[icon] then
            barIconSizes[icon] = nil
            icon:SetSize(BAR_ICON_SIZE, BAR_ICON_SIZE)
        end
        if barRowResized[f] then
            barRowResized[f] = nil
            f:SetHeight(BAR_ICON_SIZE)
        end
    end
end

function cdManager:Texture()
    if not BuffBarCooldownViewer or not BuffBarCooldownViewer:IsShown() then return end
    if not uuidb or not uuidb.statusbars or not uuidb.general then return end
    local texture = GetBarTexture()
    local square = SquareBarsOn()
    for _, f in ipairs({ BuffBarCooldownViewer:GetChildren() }) do
        local bar = f and f.Bar
        if bar and bar.GetStatusBarTexture then
            barState[bar] = barState[bar] or {}
            pcall(SizeBarIcon, f)
            pcall(StyleBarFill, bar, texture, square)
            pcall(StyleBarBorder, bar, square)
        end
    end
end

-------------------------------------------------------------------------------
-- Pandemic highlight: Border, Proc Glow or Marching Ants in place of
-- Blizzard's own pandemic effect.
-------------------------------------------------------------------------------
local aurakit = UberUI.aurakit
local PANDEMIC_DEFAULT_COLOR = "ffff3030"
-- Tracked Bars have their own pandemic settings (barpandemic*).
local function PandemicStyle(f)
    local c = uuidb and uuidb.cooldown
    if f and f.Bar then return (c and c.barpandemicstyle) or "blizzard" end
    return (c and c.pandemicstyle) or "blizzard"
end

local function PandemicColor(f)
    local c = uuidb and uuidb.cooldown or {}
    local bar = f and f.Bar ~= nil
    if (bar and c.barpandemicclasscolor) or (not bar and c.pandemicclasscolor) then
        local _, class = UnitClass("player")
        local cc = UberUI.util.ClassColor(class)
        if cc then return cc.r, cc.g, cc.b end
    end
    local col = UberUI.util.HexColor(bar and c.barpandemiccolor or c.pandemiccolor)
        or UberUI.util.HexColor(PANDEMIC_DEFAULT_COLOR)
    return col.r, col.g, col.b
end

-- "Bar Fill Color": the bar's fill takes the pandemic color; its own color is
-- saved first and put back afterward (Blizzard never recolors it itself).
local barFillSaved = setmetatable({}, { __mode = "k" }) -- bar -> { r, g, b, a }
local function SetBarPandemicFill(f, on)
    local bar = f and f.Bar
    if not bar then return end
    if on then
        if not barFillSaved[bar] then
            local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
            if ok and type(r) == "number" and not IsSecret(r) and not IsSecret(g) and not IsSecret(b) then
                barFillSaved[bar] = { r, g, b, (type(a) == "number" and not IsSecret(a)) and a or 1 }
            else
                barFillSaved[bar] = { 1, 0.5, 0.25, 1 } -- the template's color
            end
        end
        local r, g, b = PandemicColor(f)
        bar:SetStatusBarColor(r, g, b, 1)
    elseif barFillSaved[bar] then
        local c = barFillSaved[bar]
        barFillSaved[bar] = nil
        bar:SetStatusBarColor(c[1], c[2], c[3], c[4])
    end
end

local CDM_GLOW_SCALE = 1.1

-- Tracked Bars: highlight the bar (Blizzard's placement, default) or its icon.
local function PandemicOnBar(f)
    return f.Bar ~= nil and (uuidb.cooldown.barpandemic or "bar") == "bar"
end

-- A glow-type pandemic highlight on the icon keeps the icon's border, in
-- black, behind it (a Border highlight replaces it).
function PandemicKeepsBorder(f)
    if PandemicOnBar(f) then return false end
    local style = PandemicStyle(f)
    return style == "glow" or style == "ants" or style == "pixel"
end

-- Bar size in the item's own units; from Blizzard's fields when secret.
local function BarSize(f)
    local ok, w, h = pcall(f.Bar.GetSize, f.Bar)
    if ok and not IsSecret(w) and not IsSecret(h) and type(w) == "number" and w > 0
        and type(h) == "number" and h > 0 then
        return w, h
    end
    local viewer = f._uberViewer or f:GetParent()
    local itemW = (tonumber(viewer and viewer.baseBarWidth) or 220) * (tonumber(viewer and viewer.barWidthScale) or 1)
    return itemW - (barIconSizes[f.Icon] or BAR_ICON_SIZE) - 2, BAR_HEIGHT
end

-- Proc Glow on a bar: Blizzard's own bar pandemic effect
-- (CooldownPandemicBarFXTemplate) rebuilt in our host and tinted: a bar-shaped
-- border plus a rotating swirl masked to it, padded like
-- BuffBarCooldownViewerMixin:AnchorPandemicStateFrame.
local function StyleBarPandemicFX(host, bar, show, r, g, b)
    local fx = host.uuBarFX
    if not show then
        if fx then
            fx:Hide()
            fx.spin:Stop()
        end
        return
    end
    if not fx then
        fx = CreateFrame("Frame", nil, host)
        fx:EnableMouse(false)
        fx.border = fx:CreateTexture(nil, "ARTWORK")
        fx.border:SetAtlas("UI-CooldownManager-PandemicBorderBar")
        fx.border:SetAllPoints(fx)
        fx.swirl = fx:CreateTexture(nil, "ARTWORK", nil, 1)
        fx.swirl:SetAtlas("UI-CooldownManager-PandemicFX-Bar")
        fx.swirl:SetPoint("TOPLEFT", fx, "TOPLEFT", -256, 95)
        fx.swirl:SetPoint("BOTTOMRIGHT", fx, "BOTTOMRIGHT", 251, -199)
        local mask = fx:CreateMaskTexture()
        mask:SetAtlas("UI-CooldownManager-PandemicBorderBar-Mask", false)
        mask:SetAllPoints(fx)
        fx.swirl:AddMaskTexture(mask)
        fx.spin = fx.swirl:CreateAnimationGroup()
        fx.spin:SetLooping("REPEAT")
        local rot = fx.spin:CreateAnimation("Rotation")
        rot:SetDegrees(360)
        rot:SetDuration(5)
        rot:SetOrigin("CENTER", 0, 0)
        host.uuBarFX = fx
    end
    fx:ClearAllPoints()
    -- Symmetric like Blizzard's (the art is sliced by its atlas, so it fits
    -- any bar width); one unit wider on square bars, which have no rounded ends.
    local padX = SquareBarsOn() and 10 or 9
    fx:SetPoint("TOPLEFT", bar, "TOPLEFT", -padX, 10)
    fx:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", padX, -10)
    for _, t in ipairs({ fx.border, fx.swirl }) do
        t:SetDesaturated(true)
        t:SetVertexColor(r, g, b, 1)
    end
    fx:Show()
    if not fx.spin:IsPlaying() then fx.spin:Play() end
end

local function StylePandemicHost(f)
    local tex, holder = GetIconParts(f)
    if not tex then return nil end
    local host = pandemicHosts[f]
    if not host then
        host = CreateFrame("Frame", nil, f)
        host:EnableMouse(false)
        host:Hide()
        pandemicHosts[f] = host
    end
    local r, g, b = PandemicColor(f)

    if PandemicOnBar(f) then
        local bar = f.Bar
        host:ClearAllPoints()
        host:SetAllPoints(bar)
        local level = bar:GetFrameLevel()
        local bsb = SB.Find(bar, 1)
        if bsb then level = math.max(level, bsb:GetFrameLevel()) end
        host:SetFrameLevel(level + 2)
        local bw, bh = BarSize(f)
        local style = PandemicStyle(f)
        StyleBarPandemicFX(host, bar, style == "glow", r, g, b)
        aurakit.StyleHighlight(host, {
            kind = (style == "glow" or style == "fill") and "none" or style,
            r = r, g = g, b = b,
            square = true, loc = SQUARE_LOC, icon = bar,
            center = bar, size = bw, sizeH = bh, glowScale = CDM_GLOW_SCALE,
            pixelGap = 2, pixelInside = uuidb.cooldown.barpixelposition ~= "outside",
        })
        if host.uuSquare then SB.LayoutDispelFor(host.uuSquare, bar, SQUARE_LOC) end
        return host
    end

    StyleBarPandemicFX(host, nil, false)
    host:ClearAllPoints()
    host:SetAllPoints(holder)
    -- Over the border, under the cooldown numbers and stack text.
    LayerItem(f, holder)
    local w = IconWidth(holder)
    local iconStyle = PandemicStyle(f)
    aurakit.StyleHighlight(host, {
        kind = iconStyle == "fill" and "none" or iconStyle,
        r = r, g = g, b = b,
        square = squareState[f] ~= nil,
        loc = SQUARE_LOC, icon = tex,
        ringFrom = holder, ringX = -2,
        center = tex, size = w or 36, glowScale = CDM_GLOW_SCALE,
        pixelInside = uuidb.cooldown.pixelposition ~= "outside",
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
        if PandemicStyle(self) == "blizzard" or self._uberPandemicPending then return end
        local p = self.PandemicIcon
        local ok, a = pcall(p and p.GetAlpha, p)
        if not ok or IsSecret(a) or a == 0 then return end
        self._uberPandemicPending = true
        C_Timer.After(0, function()
            self._uberPandemicPending = nil
            if PandemicStyle(self) ~= "blizzard" then SetBlizzardPandemicAlpha(self, 0) end
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
    local style = PandemicStyle(f)
    if style ~= "fill" then SetBarPandemicFill(f, false) end
    if style == "blizzard" then
        -- Pooled: a frame we faded may come back on another item.
        SetBlizzardPandemicAlpha(f, 1)
        if f._uberInPandemic then
            f._uberInPandemic = nil
            if pandemicHosts[f] then pandemicHosts[f]:Hide() end
            pcall(UpdateSquareDebuffColor, f)
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

    if style == "none" then inPandemic = false end

    if inPandemic ~= f._uberInPandemic then
        f._uberInPandemic = inPandemic
        local host = pandemicHosts[f]
        SetBarPandemicFill(f, inPandemic and style == "fill" and f:IsShown())
        if inPandemic and style == "fill" then
            if host then host:Hide() end
        elseif inPandemic and f:IsShown() then
            local ok, res = pcall(StylePandemicHost, f)
            if ok and res then
                res:Show()
                -- The icon's own border: black behind a glow, hidden under a
                -- Border highlight.
                if not PandemicOnBar(f) then pcall(UpdateSquareDebuffColor, f) end
            elseif not ok then
                UberUI:ReportError("Cooldown Manager pandemic highlight", res)
            end
        elseif host then
            host:Hide()
            pcall(UpdateSquareDebuffColor, f)
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
    local col = UberUI.util.HexColor(hex)
    if col then return col.r, col.g, col.b end
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

    if f.Duration then
        f._uberCdText = f.Duration
        return f.Duration
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

-- "Color Countdown Text" off (the default): Blizzard's own countdown, untouched.
local function CountdownColorsOn()
    return uuidb and uuidb.cooldown and uuidb.cooldown.durationcolors == true
end

-- True once the item's countdown is the engine's job.
local function ApplyCountdownFormatter(f)
    local cd = f.Cooldown
    if not (cd and cd.SetCountdownFormatter) then return false end
    if not CountdownColorsOn() then
        if formatterAttached[cd] then
            formatterAttached[cd] = nil
            pcall(cd.SetCountdownFormatter, cd, nil)
        end
        return true
    end
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
    if not CountdownColorsOn() then
        -- Bars: put back Blizzard's color if we changed it.
        if f._uberDurationState then
            f._uberDurationState = nil
            local text = GetCountdownFontString(f)
            if text then pcall(text.SetTextColor, text, 1, 1, 1, 1) end
        end
        return
    end

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
    BuffIconCooldownViewer  = { "bufficon_align", "blizzard" },
    BuffBarCooldownViewer   = { "buffbar_align", "blizzard" },
}

local function GetViewerAlign(viewer)
    local name = viewer and viewer.GetName and viewer:GetName()
    local entry = name and ALIGN_FIELDS[name]
    if not entry then return "blizzard" end
    local v = uuidb and uuidb.cooldown and uuidb.cooldown[entry[1]]
    if v == "pack" or v == "center" or v == "blizzard" then return v end
    return entry[2]
end

-- Re-pack as items show/hide, or as an item's own active/aura state changes
-- (procs, aura gain/loss). Blizzard's item container has its own independent,
-- always-on relayout path (alwaysUpdateLayout) that resets our positions on
-- those same triggers without ever calling RefreshLayout, so RefreshLayout
-- alone is not a signal we can rely on.
-- Hooking the container's own :Layout() to react to that (tried first)
-- backfired: our own repositioning inside that hook perturbs the container's
-- dirty-tracking, retriggering :Layout() again -> visible jitter. Hooking
-- these per-item, semantic events instead (same ones CooldownManagerCentered
-- reacts to) can't be retriggered by our own SetPoint calls, since we never
-- touch the container or the item's active/aura state.
-- Only installed once a viewer uses our layout.
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
    if f.OnActiveStateChanged then
        pcall(hooksecurefunc, f, "OnActiveStateChanged", requeue)
    end
    if f.OnUnitAuraAddedEvent then
        pcall(hooksecurefunc, f, "OnUnitAuraAddedEvent", requeue)
    end
    if f.OnUnitAuraRemovedEvent then
        pcall(hooksecurefunc, f, "OnUnitAuraRemovedEvent", requeue)
    end
end

-- EnsureRepackHook only reaches item frames that are active during one of our
-- layout passes, so a frame first used later never got hooked and its procs
-- never re-centered -- the intermittent case that only cleared after an Edit
-- Mode save forced a full pool rebuild. Blizzard calls OnAcquireItemFrame for
-- every frame as it's acquired, so hooking that closes the gap at the source.
--
-- Installed per viewer, only once a viewer actually uses our layout, and never
-- for one left on Blizzard alignment. ApplyCustomViewerLayout calls this after
-- its own align check, so switching a viewer to Centered/Packed installs it
-- live (QueueStyle re-runs that pass) with no reload.
local acquireHooked = setmetatable({}, { __mode = "k" }) -- viewer -> true
local function EnsureAcquireHook(viewer)
    if acquireHooked[viewer] or type(viewer.OnAcquireItemFrame) ~= "function" then return end
    acquireHooked[viewer] = true
    hooksecurefunc(viewer, "OnAcquireItemFrame", function(self, itemFrame)
        if not itemFrame then return end
        -- Items are parented to the item container, not the viewer, so the
        -- parent walk in requeue can't find the align setting without this.
        itemFrame._uberViewer = self
        if GetViewerAlign(self) == "blizzard" then return end
        EnsureRepackHook(itemFrame)
    end)
end

-- Edit Mode padding/direction as CooldownViewerMixin:RefreshLayout reads
-- them, with getter fallbacks for other clients.
local function GetViewerPadding(viewer)
    local pad = viewer.iconPadding
    if type(pad) ~= "number" or IsSecret(pad) or pad < 0 then pad = 0 end
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
    if viewer.addIconsToRight ~= nil then toRight = viewer.addIconsToRight end
    if viewer.addIconsToTop ~= nil then toTop = viewer.addIconsToTop end
    return toRight, toTop
end

local function ApplyCustomViewerLayout(viewer)
    if not viewer or IsEditModeActive() then return end
    local align = GetViewerAlign(viewer)
    if align == "blizzard" then return end

    -- Past the align check: this viewer uses our layout, so it's worth
    -- hooking acquisitions (see EnsureAcquireHook). Idempotent.
    EnsureAcquireHook(viewer)

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

    -- Fields only: GetStride() on the buff viewers runs Blizzard's cooldown
    -- data provider from our code, which taints Blizzard's own later reads.
    local orient = Enum and Enum.CooldownViewerOrientation
    local isHoriz = not (orient and viewer.orientationSetting == orient.Vertical)
    local stride
    if IsAuraViewer(sample) then
        stride = #items -- the buff viewers are always a single row/column
    else
        stride = tonumber(viewer.iconLimit) or 8
    end
    if stride <= 0 then stride = 8 end
    -- Whole pixels, so every gap is the same width.
    local padPx = PixelUnit(sample)
    local pad = math.floor(GetViewerPadding(viewer) / padPx + 0.5) * padPx

    -- Not rounded: PixelAlignedInsets aligns each icon afterward, which only
    -- lines neighbors up when their unrounded edges coincide.
    local stepX, stepY = w + pad, h + pad
    if sample.Bar then
        stepX, stepY = stepX - BAR_ROW_OVERLAP, stepY - BAR_ROW_OVERLAP
        if pad == 0 and SquareBarsOn() then
            local t = SB.PixelsToUIUnits(sample, SB.Thickness(SQUARE_LOC))
            local shared = SB.IsInset(SQUARE_LOC) and -t or t
            stepX, stepY = stepX + shared, stepY + shared
        end
    else
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
        local point, wantX, wantY
        if align == "center" then
            local x = -(nx - 1) * stepX / 2 + col * stepX
            local y = -(ny - 1) * stepY / 2 + row * stepY
            point, wantX, wantY = "CENTER", xDir * x, yDir * y
        else
            point, wantX, wantY = anchorPoint, xDir * col * stepX, yDir * row * stepY
        end

        -- Only re-anchor when it actually moved. Touching an item that's
        -- already in place re-dirties Blizzard's container layout, which
        -- re-flows it back to its own grid and leaves us re-correcting it
        -- every frame (visible jitter).
        local settled = false
        pcall(function()
            local p, rel, relPoint, x, y = item:GetPoint(1)
            if IsSecret(p) or IsSecret(x) or IsSecret(y) then return end
            if p == point and rel == viewer and relPoint == point
                and type(x) == "number" and type(y) == "number"
                and math.abs(x - wantX) < 1 and math.abs(y - wantY) < 1 then
                settled = true
            end
        end)
        if not settled then
            item:ClearAllPoints()
            item:SetPoint(point, viewer, point, wantX, wantY)
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
        -- Do NOT hook the item container's own :Layout() here: its
        -- alwaysUpdateLayout flag makes it re-apply Blizzard's grid
        -- positions on essentially any child change, including the ones
        -- our own repositioning causes, so reacting to it becomes a
        -- self-sustaining loop (tried, caused visible jitter). Item-level
        -- state hooks in EnsureRepackHook cover the same triggers instead.
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
            SetBarPandemicFill(f, false)
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
-- Target-tracked items (e.g. a DoT/bleed icon) hide then re-show as
-- Blizzard's own CooldownViewerMixin re-evaluates them for the new target
-- (OnNewTarget forces inactive, then RefreshData re-checks truth); that
-- re-check can lag a frame or two behind the switch itself (aura data for a
-- newly-targeted/just-loaded unit isn't always available yet), so our
-- RefreshLayout/OnShow/OnHide-driven QueueStyle can settle on a stale item
-- count. Re-run it a couple more times shortly after, same fix as
-- targetframe.lua's PLAYER_TARGET_CHANGED handling.
cdManager:RegisterEvent("PLAYER_TARGET_CHANGED")

cdManager:SetScript("OnEvent", function(self, event, addon)
    if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        QueueStyle()
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        QueueStyle()
        C_Timer.After(0.1, QueueStyle)
        C_Timer.After(0.3, QueueStyle)
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

-------------------------------------------------------------------------------
-- Options preview (options/cdmpreview.lua): the same styling as the real
-- items, run on mock items built like Blizzard's item templates (the same
-- keys: Icon, Cooldown, DebuffBorder, Bar, ...). inPandemic forces the
-- pandemic look. Returns "blizzard" when Blizzard's own pandemic effect
-- should show (the caller draws that one).
-------------------------------------------------------------------------------
cdManager.preview = {}

function cdManager.preview.StyleItem(f, inPandemic)
    if not (uuidb and uuidb.cooldown and SB) then return nil end
    local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    if f.Bar then
        barState[f.Bar] = barState[f.Bar] or {}
        pcall(SizeBarIcon, f)
        pcall(StyleBarFill, f.Bar, GetBarTexture(), SquareBarsOn())
        pcall(StyleBarBorder, f.Bar, SquareBarsOn())
        -- cdManager:Color's "Darken Tracked Bars".
        local darken = uuidb.cooldown.darkenbars ~= false and not SquareBarsOn()
        for _, r in ipairs({ f.Bar:GetRegions() }) do
            if r:IsObjectType("Texture") and r:GetDrawLayer() == "BACKGROUND" and not IsSquareBarBG(r) then
                if darken then r:SetVertexColor(dc.r, dc.g, dc.b, dc.a) else r:SetVertexColor(1, 1, 1, 1) end
            end
        end
    end
    pcall(ApplySquareIcon, f, SquareOn())

    -- Out of pandemic first (the item's normal borders), then into it.
    f._uberInPandemic = nil
    if pandemicHosts[f] then pandemicHosts[f]:Hide() end
    SetBarPandemicFill(f, false)
    pcall(UpdateSquareDebuffColor, f)
    if not inPandemic then return nil end

    local style = PandemicStyle(f)
    if style == "none" then return nil end
    if style == "blizzard" then return "blizzard" end
    f._uberInPandemic = true
    if style == "fill" then
        SetBarPandemicFill(f, true)
        return nil
    end
    local ok, host = pcall(StylePandemicHost, f)
    if ok and host then
        host:Show()
        if not PandemicOnBar(f) then pcall(UpdateSquareDebuffColor, f) end
    end
    return nil
end

-- Countdown text color for `seconds` left, as the real countdowns show it
-- ("Color Countdown Text" off: Blizzard's white).
function cdManager.preview.CountdownColor(seconds)
    if not CountdownColorsOn() then return 1, 1, 1 end
    local normalHex, expiringHex, threshold = GetDurationColors()
    if seconds <= math.min(threshold, 59) then return HexToRGB(expiringHex, 1, 0.2, 0.2) end
    return HexToRGB(normalHex, 1, 1, 1)
end

-- Whether Tracked Bars highlight the bar (else their icon).
function cdManager.preview.PandemicOnBar()
    return (uuidb.cooldown.barpandemic or "bar") == "bar"
end

UberUI.cdManager = cdManager
