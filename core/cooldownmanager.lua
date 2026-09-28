local addon, ns = ...
local cdManager = UberUI:CreateFrame("frame")

-- Get mask from config (fallback to hardcoded if not available)
local function GetMaskTexture()
    if uuidb and uuidb.masks and uuidb.masks.cdm_mask then
        return uuidb.masks.cdm_mask
    end
    return [[Interface\AddOns\Uber UI\textures\statusbars\cdm_bar_mask.tga]]
end

-- Tuning knobs:
--   insetL/T/R/B: how much to crop in from each side (px)
--   shiftX/shiftY: move the whole mask without changing its size (px)
--     +X = move right,  -X = move left
--     +Y = move up,     -Y = move down
local MASK_OPTS = {
    insetL = 0,  -- left crop
    insetT = -2, -- top crop (raise top edge)
    insetR = 0,  -- right crop (pull right edge inward more)
    insetB = -2, -- bottom crop
    shiftX = 0,  -- whole mask shift on X
    shiftY = 0,  -- whole mask shift on Y (raise mask slightly)
}

local function ApplyMask(bar, opts)
    opts = opts or MASK_OPTS
    local L, T, R, B = opts.insetL or 0, opts.insetT or 0, opts.insetR or 0, opts.insetB or 0
    local SX, SY = opts.shiftX or 0, opts.shiftY or 0

    -- Create/reuse the mask
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

    -- Position the mask relative to the BAR (not the BG)
    m:ClearAllPoints()
    -- Note: Y offsets: negative goes down for TOP anchors; positive goes up for BOTTOM anchors.
    m:SetPoint("TOPLEFT", bar, "TOPLEFT", L + SX, -(T - SY))
    m:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -R + SX, B + SY)
end

function cdManager:Texture()
    -- Safety checks
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

            -- Find/create the fill we want to clip (only the fill is masked)
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

            -- Place the mask with custom insets + shift
            ApplyMask(bar, MASK_OPTS)

            -- Apply the mask ONLY to the fill
            if fill and bar._uberMask and not fill._masked then
                fill:AddMaskTexture(bar._uberMask)
                fill._masked = true
            end

            -- Keep mask aligned on resize and fix tiling on update
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

    -- Same border atlas AND the same proportional padding formula the rest
    -- of the addon's aura borders use (buffsandauras.lua's StyleAuraButton:
    -- 5px of padding at a 30px reference icon width), instead of a fixed
    -- pixel offset tuned for one specific icon size. Cooldown Viewer icons
    -- have their own user-adjustable size/padding per category in Edit Mode,
    -- so the border has to be computed from -- and kept in sync with -- each
    -- icon's actual current width, not a hardcoded constant.
    local AURA_BORDER_ATLAS = "ui-debuff-border-default-noicon"

    -- Tighter than the 5/30 ratio buffsandauras.lua uses elsewhere -- the
    -- border extends outward past the icon's own bounds on every side, and
    -- Cooldown Viewer icons can sit right next to each other (icon padding
    -- set to 0), so a bigger pad here means neighboring borders overlap.
    local function GetBorderPad(anchor)
        local width = anchor.GetWidth and anchor:GetWidth()
        if type(width) ~= "number" or width <= 0 then return 3 end
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
        else -- is a region
            holder = anchor:GetParent()
        end

        local borderTexture = holder:CreateTexture(nil, "OVERLAY", nil, -8)
        borderTexture:SetAtlas(AURA_BORDER_ATLAS)
        borderTexture:SetDesaturated(true)
        borderTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        PositionBorder(borderTexture, anchor)

        -- Edit Mode's icon size/padding sliders resize the icon frame
        -- directly and don't otherwise notify us -- keep the border in sync
        -- with that instead of only ever sizing it once at creation.
        if not holder._uberBorderSized then
            holder._uberBorderSized = true
            holder:HookScript("OnSizeChanged", function()
                PositionBorder(borderTexture, anchor)
            end)
        end

        return borderTexture
    end

    -- Safety checks for BuffBarCooldownViewer
    if BuffBarCooldownViewer and BuffBarCooldownViewer:IsShown() then
        local children = { BuffBarCooldownViewer:GetChildren() }
        for _, f in ipairs(children) do
            if f and f.Bar then
                -- Tint bar background
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
                        -- Handle case where f.Icon is a frame
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
                        -- Handle case where f.Icon is a texture
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
-- Square icons ("Cooldown Manager Icon Shape: Square")
--
-- Blizzard draws every Cooldown Manager icon (Essential, Utility, tracked
-- buff icons, and the icon on tracked buff bars -- CooldownViewer.xml) through
-- a rounded mask (UI-HUD-CoolDownManager-Mask), with a ring overlay
-- (UI-HUD-CoolDownManager-IconOverlay) and a rounded-corner cooldown swipe.
-- Square mode takes the mask off the icon, hides the ring, zooms the icon
-- like our aura icons (the mask used to crop Blizzard's built-in icon edge),
-- gives the swipe a plain square texture, and draws a square border
-- (core/squareborders.lua, location "cdm": thickness / inside-outside) in
-- the darkness color in place of our rounded one. All of it is undone when
-- switching back. Blizzard only sets the mask, ring and swipe texture in XML
-- and re-sets the icon with SetTexture (which keeps texcoords), so nothing
-- needs re-applying on its updates; new item frames are styled as the
-- viewers lay them out (RefreshLayout hook below).
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

-- The icon texture and the frame holding it: the icon itself on the icon
-- viewers, a nested .Icon frame on buff bars.
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

-- Blizzard's rounded masks leave empty transparent space around each icon's
-- edge; Blizzard offsets adjacent item frames closer than their size
-- (CooldownViewerMixin:GetAdditionalPaddingOffset) so the visible icons just touch.
-- Square icons are inset by the same 3/64 per side, or unmasked icons overlap their neighbors.
local MASK_INSET = 3 / 64

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


-- Tracked auras that are harmful (e.g. your DoTs on the target) get
-- dispel-type border coloring when Cooldown Manager Debuff Border is set to
-- "dispel". In Square mode our square border takes the aura's dispel color
-- (or Blizzard's "None" red for auras with no type) at the colored-border
-- thickness. In Rounded mode our rounded border takes the dispel color.
local KNOWN_SPELL_DISPEL = {
    -- Shaman
    [188389] = "Magic", -- Flame Shock debuff
    [188838] = "Magic", -- Flame Shock
    -- Priest
    [589]    = "Magic", -- Shadow Word: Pain
    [34914]  = "Magic", -- Vampiric Touch
    [34433]  = "Magic", -- Shadowfiend
    -- Druid
    [8921]   = "Magic", -- Moonfire
    [93402]  = "Magic", -- Sunfire
    [155722] = "Bleed", -- Rake
    [1079]   = "Bleed", -- Rip
    -- Warlock
    [980]    = "Curse", -- Agony
    [172]    = "Magic", -- Corruption
    [316099] = "Magic", -- Unstable Affliction
    -- Rogue
    [703]    = "Bleed", -- Garrote
    [1943]   = "Bleed", -- Rupture
    -- Death Knight
    [191587] = "Disease", -- Virulent Plague
    [55095]  = "Disease", -- Frost Fever
    [55078]  = "Disease", -- Blood Plague
    -- Mage
    [12654]  = "Magic", -- Ignite
}

local knownDispelCache = {}
local knownHarmfulCache = {}

local function UpdateTargetAuraCache()
    if not UnitExists("target") then return end
    for i = 1, 40 do
        local d = C_UnitAuras.GetDebuffDataByIndex("target", i)
        if not d then break end
        if not (issecretvalue and issecretvalue(d)) then
            local spellID = d.spellId
            if spellID and not (issecretvalue and issecretvalue(spellID)) then
                if d.dispelName and not (issecretvalue and issecretvalue(d.dispelName)) then
                    knownDispelCache[spellID] = d.dispelName
                end
                if d.isHarmful ~= nil and not (issecretvalue and issecretvalue(d.isHarmful)) then
                    knownHarmfulCache[spellID] = d.isHarmful
                end
                if d.name and not (issecretvalue and issecretvalue(d.name)) then
                    knownDispelCache[d.name] = d.dispelName
                end
            end
        end
    end
end

local function SafeShown(region)
    local ok, shown = pcall(region.IsShown, region)
    if not ok or (issecretvalue and issecretvalue(shown)) then return false end
    return shown and true or false
end

-- "Cooldown Manager Debuff Border: Dark": harmful tracked auras (DoTs in the
-- Tracked Buffs section) get the same dark border as everything else instead
-- of Blizzard's dispel color (red for no type), so only the pandemic
-- highlight stands out.
local function DebuffBorderDark()
    return uuidb and uuidb.cooldown and uuidb.cooldown.debuffborder == "dark"
end

local function FindItemAuraData(f)
    local spellID = f.spellID or f.cooldownID or (f.GetSpellID and f:GetSpellID()) or (f.GetBaseSpellID and f:GetBaseSpellID())
    local spellName = spellID and type(spellID) == "number" and C_Spell.GetSpellName(spellID)
    local aura, unit

    -- 1. Check player auras
    if spellID and type(spellID) == "number" then
        local pAura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if pAura and not (issecretvalue and issecretvalue(pAura)) then
            aura = pAura
            unit = "player"
        end
    end

    -- 2. Check target debuffs (for harmful DoTs like Flame Shock)
    if not aura and UnitExists("target") then
        for i = 1, 40 do
            local dAura = C_UnitAuras.GetDebuffDataByIndex("target", i)
            if not dAura then break end
            if not (issecretvalue and issecretvalue(dAura)) then
                if (spellID and dAura.spellId == spellID) or (spellName and dAura.name == spellName) then
                    aura = dAura
                    unit = "target"
                    break
                end
            end
        end
    end

    -- 3. Check target buffs (in case tracked buff is on target)
    if not aura and UnitExists("target") then
        for i = 1, 40 do
            local bAura = C_UnitAuras.GetBuffDataByIndex("target", i)
            if not bAura then break end
            if not (issecretvalue and issecretvalue(bAura)) then
                if (spellID and bAura.spellId == spellID) or (spellName and bAura.name == spellName) then
                    aura = bAura
                    unit = "target"
                    break
                end
            end
        end
    end

    -- 4. Cache dispelName if discovered
    if aura and aura.dispelName and not (issecretvalue and issecretvalue(aura.dispelName)) then
        if spellID and type(spellID) == "number" then
            knownDispelCache[spellID] = aura.dispelName
        end
        if spellName then
            knownDispelCache[spellName] = aura.dispelName
        end
    end

    return aura, unit, spellID
end

local function GetItemCooldownAndDuration(f, now)
    now = now or GetTime()

    -- 1. Widget Cooldown frame (direct C++ call, zero Blizzard Lua execution)
    if f.Cooldown and f.Cooldown.GetCooldownTimes then
        local okTimes, startTime, duration = pcall(f.Cooldown.GetCooldownTimes, f.Cooldown)
        if okTimes and startTime and duration then
            if not (issecretvalue and (issecretvalue(startTime) or issecretvalue(duration))) then
                if type(startTime) == "number" and type(duration) == "number" and duration > 0 then
                    if startTime > (now * 2) or duration > 1000 then
                        startTime = startTime / 1000
                        duration = duration / 1000
                    end
                    local expTime = startTime + duration
                    if expTime > now then
                        return expTime, duration
                    end
                end
            end
        end
    end

    -- 2. Check aura data on target or player
    local aura = FindItemAuraData(f)
    if aura and aura.expirationTime and aura.duration then
        if not (issecretvalue and (issecretvalue(aura.expirationTime) or issecretvalue(aura.duration))) then
            local expTime = aura.expirationTime
            local duration = aura.duration
            if type(expTime) == "number" and type(duration) == "number" and duration > 0 then
                if expTime > (now * 2) or duration > 1000 then
                    expTime = expTime / 1000
                    duration = duration / 1000
                end
                if expTime > now then
                    return expTime, duration
                end
            end
        end
    end

    -- 3. Spell cooldown (for Essential / Utility cooldowns)
    local spellID = f.spellID or f.cooldownID or (f.GetSpellID and f:GetSpellID()) or (f.GetBaseSpellID and f:GetBaseSpellID())
    if spellID and type(spellID) == "number" and spellID > 0 then
        local sc = C_Spell.GetSpellCooldown(spellID)
        if sc and sc.startTime and sc.duration then
            if not (issecretvalue and (issecretvalue(sc.startTime) or issecretvalue(sc.duration))) then
                local startTime = sc.startTime
                local duration = sc.duration
                if type(startTime) == "number" and type(duration) == "number" and duration > 0 then
                    if startTime > (now * 2) or duration > 1000 then
                        startTime = startTime / 1000
                        duration = duration / 1000
                    end
                    local expTime = startTime + duration
                    if expTime > now then
                        return expTime, duration
                    end
                end
            end
        end
    end

    return 0, 0
end

local function UpdateSquareDebuffColor(f)
    local tex = GetIconParts(f)
    if not tex then return end

    local square = SquareOn()
    if f.DebuffBorder then
        f.DebuffBorder:SetAlpha(square and 0 or (DebuffBorderDark() and 0 or 1))
    end

    if uuidb.cooldown.borders == false then
        local sb = SB.Find(f, 1)
        if sb then sb:Hide() end
        if f.uberBorder then f.uberBorder:Hide() end
        return
    end

    local isHarmful = false
    local dispelName = "None"
    local aura, unit

    -- Only tracked buff/debuff auras can have dispel colors.
    -- Essential Cooldowns and Utility Cooldowns are always plain dark borders.
    if IsAuraViewer(f) then
        local spellID = f.spellID or f.cooldownID or (f.GetSpellID and f:GetSpellID()) or (f.GetBaseSpellID and f:GetBaseSpellID())
        if spellID and type(spellID) == "number" then
            aura, unit = FindItemAuraData(f)
        end

        if aura and aura.isHarmful then
            isHarmful = true
        elseif unit == "target" then
            isHarmful = true
        elseif spellID and type(spellID) == "number" then
            if KNOWN_SPELL_DISPEL[spellID] then
                isHarmful = true
            elseif knownHarmfulCache[spellID] then
                isHarmful = true
            end
        end

        if aura and aura.dispelName and not (issecretvalue and issecretvalue(aura.dispelName)) then
            dispelName = aura.dispelName
        elseif spellID and type(spellID) == "number" then
            dispelName = knownDispelCache[spellID] or KNOWN_SPELL_DISPEL[spellID]
        end
        dispelName = dispelName or "None"
    end

    local useDispel = isHarmful and (not DebuffBorderDark())

    if square then
        local sb = SB.Get(f, 1)
        if useDispel then
            SB.LayoutDispelFor(sb, tex, SQUARE_LOC)
            SB.ApplyDispelColor(sb, dispelName, unit or "target", aura and aura.auraInstanceID)
        else
            SB.LayoutFor(sb, tex, SQUARE_LOC)
            SB.SetDarkColor(sb)
        end
        SB.RaiseAbove(sb, f.DebuffBorder or f.Cooldown or f, 2)
        sb:Show()
    else
        -- Rounded icon: tint f.uberBorder
        if f.uberBorder then
            if useDispel then
                local r, g, b, a = SB.GetDispelColor(dispelName, unit or "target", aura and aura.auraInstanceID)
                f.uberBorder:SetVertexColor(r, g, b, a)
            else
                local dc = uuidb.general.darkencolor
                f.uberBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
            f.uberBorder:Show()
        end
    end
end

local function EnsureDebuffHook(f)
    if not f._uberDebuffHooked then
        f._uberDebuffHooked = true
        f:HookScript("OnShow", function(self)
            C_Timer.After(0, function() pcall(UpdateSquareDebuffColor, self) end)
        end)
    end
end

local function LayoutSquareIcon(f, tex, holder)
    local ok, w = pcall(holder.GetWidth, holder)
    local inset = (ok and type(w) == "number" and w > 0) and (w * MASK_INSET) or 0
    tex:ClearAllPoints()
    if inset > 0 then
        tex:SetPoint("TOPLEFT", holder, "TOPLEFT", inset, -inset)
        tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -inset, inset)
    else
        tex:SetAllPoints(holder)
    end
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
        if f.DebuffBorder then f.DebuffBorder:SetAlpha(DebuffBorderDark() and 0 or 1) end
        return
    end

    if not state then
        state = { masks = {} }
        -- Take Blizzard's rounded mask(s) off the icon, remembered for undo.
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
    if f.DebuffBorder then f.DebuffBorder:SetAlpha(0) end
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Edit Mode's icon size changes resize the frame directly.
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
    end
    EnsureDebuffHook(f)
    LayoutSquareIcon(f, tex, holder)
end

-------------------------------------------------------------------------------
-- Pandemic highlight ("Cooldown Manager Pandemic Highlight")
--
-- Tracked auras in their pandemic window (<= 30% of base duration remaining)
-- get styled with the chosen highlight (Border, Proc Glow, or Marching Ants)
-- in the user's selected color.
-------------------------------------------------------------------------------
local aurakit = UberUI.aurakit
local PANDEMIC_DEFAULT_COLOR = "ffff2626"
local pandemicHosts = setmetatable({}, { __mode = "k" })  -- item frame -> host

local function PandemicStyle()
    return (uuidb and uuidb.cooldown and uuidb.cooldown.pandemicstyle) or "blizzard"
end

local function PandemicColor()
    local hex = uuidb and uuidb.cooldown and uuidb.cooldown.pandemiccolor
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x%x%x$") then hex = PANDEMIC_DEFAULT_COLOR end
    local ok, c = pcall(CreateColorFromHexString, hex)
    if ok and c then return c.r, c.g, c.b end
    return 1, 0.15, 0.15
end

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
    local ok, w = pcall(tex.GetWidth, tex)
    local r, g, b = PandemicColor()
    aurakit.StyleHighlight(host, {
        kind = PandemicStyle(),
        r = r, g = g, b = b,
        square = squareState[f] ~= nil,
        loc = SQUARE_LOC, icon = tex,
        ringFrom = holder, ringX = -2,
        center = tex, size = (ok and type(w) == "number" and w > 0) and w or 36,
    })
    return host
end

local function UpdateItemPandemic(f, now)
    local custom = PandemicStyle() ~= "blizzard"
    if not custom then
        if f._uberInPandemic then
            f._uberInPandemic = nil
            if pandemicHosts[f] then pandemicHosts[f]:Hide() end
        end
        return
    end

    local expTime, duration = GetItemCooldownAndDuration(f, now)
    local inPandemic = false
    if expTime and duration and duration > 0 then
        local remaining = expTime - now
        if remaining > 0 and remaining <= (duration * 0.3) then
            inPandemic = true
        end
    end

    if inPandemic ~= f._uberInPandemic then
        f._uberInPandemic = inPandemic
        local host = pandemicHosts[f]
        if inPandemic and f:IsShown() then
            host = StylePandemicHost(f)
            if host then host:Show() end
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
-- Expiration text coloring ("Cooldown Duration Colors")
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

local function UpdateItemDurationColor(f, now)
    local expTime, duration = GetItemCooldownAndDuration(f, now)
    local cdText = GetCountdownFontString(f)

    if not expTime or type(expTime) ~= "number" or expTime <= 0 then
        if f._uberDurationState then
            f._uberDurationState = nil
            if cdText then
                local normalHex = GetDurationColors()
                local r, g, b = HexToRGB(normalHex, 1, 1, 1)
                pcall(cdText.SetTextColor, cdText, r, g, b, 1)
            end
        end
        return
    end

    local remaining = expTime - now
    if remaining <= 0 then
        if f._uberDurationState then
            f._uberDurationState = nil
            if cdText then
                local normalHex = GetDurationColors()
                local r, g, b = HexToRGB(normalHex, 1, 1, 1)
                pcall(cdText.SetTextColor, cdText, r, g, b, 1)
            end
        end
        return
    end

    local normalHex, expiringHex, threshold = GetDurationColors()
    local isExpiring = (remaining <= threshold)
    local state = isExpiring and "expiring" or "normal"

    if f._uberDurationState ~= state or isExpiring then
        f._uberDurationState = state
        local r, g, b
        if isExpiring then
            r, g, b = HexToRGB(expiringHex, 1, 0.2, 0.2)
        else
            r, g, b = HexToRGB(normalHex, 1, 1, 1)
        end
        if cdText then
            pcall(cdText.SetTextColor, cdText, r, g, b, 1)
        end
    end
end



-- Debug (/uuidebugcdm): what each tracked buff icon is actually drawing.
function cdManager:DebugReport()
    local lines = { "==== cooldown manager report ====",
        "square: " .. tostring(SquareOn()) .. "  pandemic style: " .. PandemicStyle() }
    local function fmt(v)
        if issecretvalue and issecretvalue(v) then return "<secret>" end
        if type(v) == "number" then return string.format("%.2f", v) end
        return tostring(v)
    end
    local now = GetTime()
    for _, name in ipairs(VIEWERS) do
        local viewer = _G[name]
        if viewer then
            lines[#lines + 1] = string.format("-- %s (isHoriz=%s, stride=%s)",
                name, tostring(viewer.IsHorizontal and viewer:IsHorizontal()), fmt(viewer.GetStride and viewer:GetStride()))
            local n = 0
            if viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
                for f in viewer.itemFramePool:EnumerateActive() do
                    if f.Icon and n < 8 then
                        local okS, shown = pcall(f.IsShown, f)
                        if okS and shown == true then
                            n = n + 1
                            local sb = SB.Find(f, 1)
                            local r, g, b
                            if sb and sb.edges then r, g, b = sb.edges[1]:GetVertexColor() end
                            local host = pandemicHosts[f]
                            local spell = f.spellID or f.cooldownID or (f.GetSpellID and f:GetSpellID())
                            local aura, unit = FindItemAuraData(f)
                            local expTime, dur = GetItemCooldownAndDuration(f, now)
                            local rem = (expTime and type(expTime) == "number" and expTime > now) and (expTime - now) or 0
                            lines[#lines + 1] = string.format(
                                "  spell=%s unit=%s dispel=%s | our border shown=%s color=(%.2f,%.2f,%.2f) | rem=%.1f/%.1f inPan=%s hostShown=%s durState=%s",
                                fmt(spell), fmt(unit), fmt(aura and aura.dispelName or (spell and KNOWN_SPELL_DISPEL[spell])),
                                fmt(sb and sb:IsShown()), r or 0, g or 0, b or 0,
                                rem, dur or 0, fmt(f._uberInPandemic), fmt(host and host:IsShown()), fmt(f._uberDurationState))
                        end
                    end
                end
            end
        end
    end
    return table.concat(lines, "\n")
end

function cdManager:StyleIcons()
    if not (uuidb and uuidb.cooldown and SB) then return end
    local square = SquareOn()
    ForEachItemFrame(function(f, viewer)
        pcall(ApplySquareIcon, f, square)
        EnsureDebuffHook(f)
        pcall(UpdateSquareDebuffColor, f)
        if pandemicHosts[f] then pcall(StylePandemicHost, f) end
        -- Our rounded border (Color) only in Rounded mode.
        if f.uberBorder then f.uberBorder:SetShown(not square) end
    end)
end

-- New item frames appear when a viewer lays out (spec change, Edit Mode
-- count/size change, settings changes): style them once it's done.
local layoutHooked = false
local stylePending = false
local function QueueStyle()
    if stylePending then return end
    stylePending = true
    C_Timer.After(0, function()
        stylePending = false
        cdManager:Texture()
        cdManager:Color()
        cdManager:StyleIcons()
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

-- Centralized update loop for cooldown countdown text coloring and pandemic glows
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
            f._uberInPandemic = nil
        end
    end)
end)

-- Register the specific callback we need
local function RegisterCooldownCallbacks()
    if cdManager._callbackRegistered then return end

    -- This is the specific callback that fires when hovering items in settings
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnEnterItem", function(cooldownItem)
        QueueStyle()
    end, cdManager)

    -- Also register for data changes (when items added/removed)
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
        QueueStyle()
    end, cdManager)

    cdManager._callbackRegistered = true
end

-- Wait for CooldownViewer to load
cdManager:RegisterEvent("ADDON_LOADED")
cdManager:RegisterEvent("PLAYER_ENTERING_WORLD")
cdManager:RegisterEvent("PLAYER_TARGET_CHANGED")
cdManager:RegisterUnitEvent("UNIT_AURA", "player", "target")

cdManager:SetScript("OnEvent", function(self, event, addon)
    if event == "PLAYER_TARGET_CHANGED" or event == "UNIT_AURA" then
        UpdateTargetAuraCache()
        ForEachItemFrame(function(f)
            pcall(UpdateSquareDebuffColor, f)
        end)
        return
    end

    if event == "ADDON_LOADED" and addon == "Blizzard_CooldownViewer" then
        local function applyStyling()
            cdManager:Texture()
            cdManager:Color()
            cdManager:StyleIcons()
        end
        EnsureLayoutHooks()

        -- Hook OnShow for all relevant viewers to apply styling when they are enabled
        if BuffBarCooldownViewer then BuffBarCooldownViewer:HookScript("OnShow", applyStyling) end
        if BuffIconCooldownViewer then BuffIconCooldownViewer:HookScript("OnShow", applyStyling) end
        if UtilityCooldownViewer then UtilityCooldownViewer:HookScript("OnShow", applyStyling) end
        if EssentialCooldownViewer then EssentialCooldownViewer:HookScript("OnShow", applyStyling) end

        -- Give it a moment to fully initialize
        C_Timer.After(0.5, function()
            RegisterCooldownCallbacks()
            -- Apply initial styling
            applyStyling()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Apply styling on world enter (after everything is loaded)
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

-- Public function for manual refresh
function cdManager:Refresh()
    self:Texture()
    self:Color()
    self:StyleIcons()
    ForEachItemFrame(function(f)
        f._uberDurationState = nil
        f._uberInPandemic = nil
        if pandemicHosts[f] then pcall(StylePandemicHost, f) end
        pcall(UpdateSquareDebuffColor, f)
    end)
end

UberUI.cdManager = cdManager
