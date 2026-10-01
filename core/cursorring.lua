-- Cursor ring: a ring that follows the mouse cursor (class color or a chosen
-- color, Normal or Thin), optionally only in combat, with an optional GCD
-- ring in its center that fills as the global cooldown runs.
--
-- Nothing is created, hooked or ticked until the ring is turned on. The GCD
-- ring is a Cooldown frame whose swipe texture is the ring itself.

local addon, ns = ...
local cursorring = {}

local TEXTURES = {
    normal = "Interface\\AddOns\\Uber UI\\textures\\cursorring-normal",
    thin = "Interface\\AddOns\\Uber UI\\textures\\cursorring-thin",
}
local GCD_SPELL = 61304       -- the global cooldown's reference spell
-- Ring art geometry (textures/cursorring-*.tga, 128 px): outer radius 62,
-- inner radius per style. The GCD ring sits GCD_GAP screen pixels inside the
-- cursor ring's inner edge.
local TEX_SIZE, TEX_OUTER = 128, 62
local TEX_INNER = { normal = 52, thin = 57 }
local GCD_GAP = 2

local root, ring, gcd
local events
local inCombat = false -- from the regen events (InCombatLockdown can lag them)

local function G() return uuidb and uuidb.general or {} end

local function Enabled() return G().cursorring == true end

local function Color()
    local g = G()
    if g.cursorringclasscolor ~= false then
        local _, class = UnitClass("player")
        local cc = UberUI.util.ClassColor(class)
        if cc then return cc.r, cc.g, cc.b end
    end
    local c = UberUI.util.HexColor(g.cursorringcolor or "ffffffff")
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function Style(key)
    return TEXTURES[key] and key or "normal"
end

-- Sizes and colors a ring texture + its GCD Cooldown from the settings,
-- `size` in the ring's own units. Shared by the real ring and the preview.
local function StyleRing(ringTex, gcdCd, size)
    local g = G()
    local style, gcdStyle = Style(g.cursorringstyle), Style(g.cursorringgcdstyle)
    local r, gg, b = Color()
    ringTex:SetTexture(TEXTURES[style])
    ringTex:SetVertexColor(r, gg, b, 1)

    -- GCD ring: its outer edge GCD_GAP pixels inside the cursor ring's inner
    -- edge, in its own style and color.
    local innerRadius = size * TEX_INNER[style] / TEX_SIZE
    local gap = UberUI.squareborders and UberUI.squareborders.PixelsToUIUnits(gcdCd, GCD_GAP) or GCD_GAP
    local gsize = math.max(4, (innerRadius - gap) * TEX_SIZE / TEX_OUTER)
    gcdCd:SetSize(gsize, gsize)
    gcdCd:SetSwipeTexture(TEXTURES[gcdStyle])
    local gc = UberUI.util.HexColor(g.cursorringgcdcolor or "ffffffff")
    gcdCd:SetSwipeColor(gc and gc.r or 1, gc and gc.g or 1, gc and gc.b or 1, 1)
end

-- A GCD Cooldown frame: its swipe is the ring texture (a ring that sweeps
-- away). The template anchors it to all of its parent's edges, which would
-- override its own size: centered instead.
local function NewGCD(parent)
    local cd = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
    cd:ClearAllPoints()
    cd:SetPoint("CENTER", parent, "CENTER", 0, 0)
    cd:SetHideCountdownNumbers(true)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd:SetReverse(true)
    cd:EnableMouse(false)
    return cd
end

-- Shown while enabled, and only in combat when "In Combat Only" is on.
-- While the mouse turns the camera the cursor is hidden: the ring stays where
-- the cursor was ("Show While Cursor Is Hidden", default) or hides with it.
local function ShouldShow()
    if not Enabled() then return false end
    if G().cursorringcombatonly and not inCombat then return false end
    return true
end

local function FollowCursor(self)
    if IsMouselooking and IsMouselooking() then
        if G().cursorringwhilehidden == false then
            ring:Hide()
            if gcd then gcd:Hide() end
        end
        -- The cursor position is frozen meanwhile; the ring stays put.
        return
    end
    ring:Show()
    if gcd and G().cursorringgcd then gcd:Show() end
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end

-- The GCD. Two ways, tried in order:
--  1. As a duration object (no secret value is read; isActive / isOnGCD are
--     never secret): the reference spell's cooldown where the client has it,
--     else the spell just cast while it's on the global cooldown (Forever may
--     have no reference spell).
--  2. As plain start/duration numbers from the reference spell, when they
--     aren't secret (EllesmereUI's way): a 0-1.6 s cooldown is the GCD.
-- Run on the cast events and SPELL_UPDATE_COOLDOWN; cleared when a cast
-- fails or is interrupted and no GCD is running.
local lastSpell
local IsSecret = UberUI.util.IsSecret

local function DurationFor(spellID)
    local info = C_Spell.GetSpellCooldown(spellID)
    if not info then return nil end
    return info, C_Spell.GetSpellCooldownDuration(spellID)
end

local function StartFromDurationObject()
    if not (C_Spell.GetSpellCooldownDuration and gcd.SetCooldownFromDurationObject) then
        return false, "no duration-object API"
    end
    local ok, info, duration = pcall(DurationFor, GCD_SPELL)
    local source = "reference spell"
    if not (ok and info and info.isActive and duration) then
        if not lastSpell then return false, "reference spell inactive, no spell cast yet" end
        ok, info, duration = pcall(DurationFor, lastSpell)
        source = "spell " .. tostring(lastSpell)
        if not (ok and info and info.isOnGCD and duration) then
            return false, source .. " not on GCD (info=" .. tostring(info ~= nil) .. ")"
        end
    end
    local okSet, err = pcall(gcd.SetCooldownFromDurationObject, gcd, duration)
    if not okSet then return false, "SetCooldownFromDurationObject failed: " .. tostring(err) end
    return true, "duration object from " .. source
end

local function StartFromNumbers()
    local info = C_Spell.GetSpellCooldown(GCD_SPELL)
    if not info then return false, "no reference spell info" end
    local start, duration = info.startTime, info.duration
    if IsSecret(start) or IsSecret(duration) then return false, "reference spell numbers secret" end
    if not (start and duration and start > 0 and duration > 0 and duration <= 1.6) then
        return false, "reference spell not on GCD (start=" .. tostring(start) .. " dur=" .. tostring(duration) .. ")"
    end
    gcd:SetCooldown(start, duration)
    return true, "numbers " .. tostring(duration) .. "s"
end

local function StartGCD()
    if not (gcd and G().cursorringgcd and C_Spell and C_Spell.GetSpellCooldown) then return end
    local ok, started = pcall(StartFromDurationObject)
    if ok and started then return end
    pcall(StartFromNumbers)
end

local function StopIfNoGCD()
    local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(GCD_SPELL)
    if info and info.isActive then return end
    gcd:Clear()
end

local function Create()
    if root then return end
    root = CreateFrame("Frame", nil, UIParent)
    root:SetFrameStrata("TOOLTIP")
    root:SetFrameLevel(9000)
    root:EnableMouse(false)
    root:Hide()
    root:SetScript("OnUpdate", FollowCursor)

    ring = root:CreateTexture(nil, "ARTWORK")
    ring:SetAllPoints(root)

    gcd = NewGCD(root)

    events = CreateFrame("Frame")
    events:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
            if spellID and not IsSecret(spellID) then lastSpell = spellID end
            -- The cooldown update can come before this event on instant casts.
            StartGCD()
        elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            pcall(StopIfNoGCD)
        elseif event == "SPELL_UPDATE_COOLDOWN" then
            StartGCD()
        else
            inCombat = (event == "PLAYER_REGEN_DISABLED")
            root:SetShown(ShouldShow())
        end
    end)
end

-- Applies the settings; called from the options and at login.
function cursorring:Refresh()
    if not Enabled() then
        if root then
            root:Hide()
            events:UnregisterAllEvents()
        end
        return
    end
    Create()
    local g = G()
    local size = tonumber(g.cursorringsize) or 30
    root:SetSize(size, size)
    StyleRing(ring, gcd, size)
    if not g.cursorringgcd then gcd:Clear() gcd:Hide() end

    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    if g.cursorringgcd then
        events:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
        events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
        events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
        events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    else
        for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
                             "UNIT_SPELLCAST_INTERRUPTED", "SPELL_UPDATE_COOLDOWN" }) do
            events:UnregisterEvent(e)
        end
    end
    inCombat = InCombatLockdown() or UnitAffectingCombat("player") or false
    root:SetShown(ShouldShow())
end

-- Options preview: the ring at its on-screen size around the game's own
-- arrow cursor art, the GCD sweep replaying every couple of seconds.
local CURSOR_ART = "Interface\\Cursor\\Point"
local PREVIEW_GCD, PREVIEW_PERIOD = 1.5, 2.2

function cursorring.CreatePreview(parent)
    local preview = CreateFrame("Frame", nil, parent)
    preview:SetSize(120, 70)
    local holder = CreateFrame("Frame", nil, preview)
    holder:SetPoint("CENTER", preview, "LEFT", 40, 0)
    holder.ring = holder:CreateTexture(nil, "ARTWORK")
    holder.ring:SetAllPoints()
    holder.gcd = NewGCD(holder)
    local cursor = CreateFrame("Frame", nil, holder)
    cursor:SetAllPoints()
    cursor:SetFrameLevel(holder.gcd:GetFrameLevel() + 5)
    holder.cursor = cursor:CreateTexture(nil, "OVERLAY")
    holder.cursor:SetTexture(CURSOR_ART)
    -- The arrow's tip at the ring's center, like the real cursor.
    holder.cursor:SetPoint("TOPLEFT", holder, "CENTER", 0, 0)

    local elapsed = PREVIEW_PERIOD
    preview:SetScript("OnUpdate", function(_, dt)
        if not G().cursorringgcd then return end
        elapsed = elapsed + dt
        if elapsed >= PREVIEW_PERIOD then
            elapsed = 0
            holder.gcd:SetCooldown(GetTime(), PREVIEW_GCD)
        end
    end)

    function preview:Update()
        local g = G()
        local size = tonumber(g.cursorringsize) or 30
        -- The real ring is on UIParent; the panel may be scaled differently.
        local ratio = UIParent:GetEffectiveScale() / math.max(self:GetEffectiveScale(), 0.01)
        holder:SetScale(ratio)
        holder:SetSize(size, size)
        StyleRing(holder.ring, holder.gcd, size)
        holder.cursor:SetSize(32, 32)
        holder.gcd:SetShown(g.cursorringgcd == true)
        if not g.cursorringgcd then holder.gcd:Clear() end
    end
    preview:SetScript("OnShow", preview.Update)
    return preview
end

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function() cursorring:Refresh() end)

UberUI.cursorring = cursorring
