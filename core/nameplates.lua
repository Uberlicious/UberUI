local addon, ns = ...
local nameplates = {}

local _uberOriginalPoints = setmetatable({}, {__mode = "k"})

local function SquareBorderOn()
    return uuidb and uuidb.general and uuidb.general.nameplatesquareborder == true
end

-- The custom health bar texture in effect, or nil for Blizzard's own.
-- Square nameplates require a flat texture (the stock Blizzard nameplate
-- texture is rounded/pill-shaped and cannot work with square borders),
-- so Square mode defaults to "Blizzard_Flat" if no other custom texture is set.
local function GetNameplateBarTexture()
    if not (uuidb and uuidb.general and uuidb.statusbars) then return nil end
    local tex
    if uuidb.general.nameplatebartextures and uuidb.general.nameplatebartexture ~= "Blizzard" then
        tex = uuidb.statusbars[uuidb.general.nameplatebartexture]
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        tex = uuidb.statusbars[uuidb.general.texture]
    elseif SquareBorderOn() then
        tex = uuidb.statusbars["Blizzard_Flat"] or uuidb.statusbars["blizzard_flat"] or "Interface\\AddOns\\Uber UI\\textures\\statusbars\\nameplate"
    end
    return type(tex) == "string" and tex or nil
end

-- Apply it the way Blizzard does (Blizzard_NamePlateUnitFrame.lua
-- UpdateAnchors: healthBar.barTexture:SetTexture / SetAtlas on the same
-- texture object) -- never SetStatusBarTexture, which Blizzard doesn't use
-- here and which left the bar drawing over the nameplate border after a
-- reload, in every style, on retail and Forever. The bar's original draw
-- layer is also put back, so the layering is always Blizzard's own.
local function ApplyHealthBarTexture(healthBar, textureToApply)
    local bar = healthBar.barTexture or healthBar:GetStatusBarTexture()
    if bar then
        local layer, sublevel = bar:GetDrawLayer()
        if textureToApply then
            bar:SetTexture(textureToApply)
        else
            if IsUsingLargeNamePlateStyle and IsUsingLargeNamePlateStyle() then
                bar:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
            else
                bar:SetAtlas("UI-HUD-CoolDownManager-Bar", true)
            end
        end
        if layer then bar:SetDrawLayer(layer, sublevel or 0) end
    elseif textureToApply then
        healthBar:SetStatusBarTexture(textureToApply)
    end
end

-- Blizzard's NamePlateUnitFrameMixin:UpdateAnchors puts its own atlas back
-- on the health bar every time it runs: nameplate added, option changes
-- (style, size, class colors, DISPLAY_SIZE_CHANGED -- all via
-- NamePlateDriverMixin:UpdateNamePlateOptions), and on retail every
-- nameplate resize (NamePlateBaseMixin:OnSizeChanged; Forever has no such
-- call). So our texture was being reverted constantly and only came back
-- when a plate was re-added. Re-apply after each UpdateAnchors: an instance
-- hook per unit frame (pooled frames already exist, so the mixin can't be
-- hooked), installed only once a custom texture is actually in use, and
-- deferred a frame + coalesced per frame (this file's nameplate taint rule).
local anchorHooked = setmetatable({}, { __mode = "k" })
local anchorPending = setmetatable({}, { __mode = "k" })

-- Blizzard's nameplate bar art (UI-HUD-CoolDownManager-Bar) has chamfered
-- corners and a dark edge painted into it, which is what makes the border
-- ring (healthBar.bgTexture, behind the fill) read as sitting in front of the
-- fill. A custom texture is square and bright right up to its edge, so it
-- looked drawn over the border. Give our fill that shape with a mask:
-- textures/nameplate_bar_mask.tga (hand-made from the 2x atlas region of
-- UICooldownManager2x.BLP) -- clear outside the edge, partial along it so the
-- dark border behind shows through, open inside. Stretched over the whole
-- health bar, the same rectangle Blizzard's bar art covers, so it stays put
-- as health changes. Only while a custom texture is in use; kept in weak
-- tables, never as fields on Blizzard's frame. Notes from getting here:
-- MaskTexture ignores SetTexCoord in-game (no padded canvases), and WoW
-- keeps an already-loaded texture file cached across /reload -- restart the
-- client after editing the file.
local BAR_MASK_TEXTURE = "Interface\\AddOns\\Uber UI\\textures\\nameplate_bar_mask"
local barMasks = setmetatable({}, { __mode = "k" }) -- healthBar -> mask
local barMasked = setmetatable({}, { __mode = "k" }) -- healthBar -> fill texture it's on

local function UpdateBarMask(healthBar, show)
    local fill = healthBar.barTexture or healthBar:GetStatusBarTexture()
    local mask = barMasks[healthBar]
    local current = barMasked[healthBar]
    if current and (not show or current ~= fill) then
        current:RemoveMaskTexture(mask)
        barMasked[healthBar] = nil
    end
    if not (show and fill) then return end
    if not mask then
        local ok, m = pcall(healthBar.CreateMaskTexture, healthBar)
        if not ok or not m then return end
        m:SetTexture(BAR_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(healthBar)
        mask = m
        barMasks[healthBar] = mask
    end
    if barMasked[healthBar] ~= fill then
        fill:AddMaskTexture(mask)
        barMasked[healthBar] = fill
    end
end

-- Square health bar border ("Nameplate Health Bar Border: Square"): four
-- solid strips a whole number of physical pixels thick just outside the
-- health bar, in the darkness color, over a dark background of our own for
-- the missing-health part. Blizzard's rounded border (bgTexture, which is
-- both the ring and that background) is faded to 0 meanwhile -- Blizzard
-- never touches its alpha, and selectedBorder still anchors to it -- and the
-- rounded fill mask is skipped so a custom texture stays square. Plain
-- textures on the health bar (a frame anchored into a nameplate would need
-- DisableUntrustedLayoutScriptsTemplate), kept in a weak table.
local SQUARE_BG_ALPHA = 0.6
local squareParts = setmetatable({}, { __mode = "k" }) -- healthBar -> { bg, edges }

local function UpdateSquareBorder(healthBar, on)
    local parts = squareParts[healthBar]
    local bgTexture = healthBar.bgTexture
    if not on then
        if parts then
            parts.bg:Hide()
            for _, e in ipairs(parts.edges) do e:Hide() end
            if bgTexture then bgTexture:SetAlpha(1) end
        end
        return
    end
    if not parts then
        parts = { edges = {} }
        parts.bg = healthBar:CreateTexture(nil, "BACKGROUND", nil, -1)
        parts.bg:SetColorTexture(0, 0, 0, 1)
        parts.bg:SetAllPoints(healthBar)
        for i = 1, 4 do
            local e = healthBar:CreateTexture(nil, "ARTWORK", nil, 7)
            e:SetColorTexture(1, 1, 1, 1)
            if e.SetSnapToPixelGrid then e:SetSnapToPixelGrid(false) end
            if e.SetTexelSnappingBias then e:SetTexelSnappingBias(0) end
            parts.edges[i] = e
        end
        squareParts[healthBar] = parts
    end

    local px = tonumber(uuidb.general.nameplatesquareborder_thickness) or 1
    local SB = UberUI.squareborders
    local t = SB and SB.PixelsToUIUnits(healthBar, px) or px
    local top, bottom, left, right = parts.edges[1], parts.edges[2], parts.edges[3], parts.edges[4]
    top:ClearAllPoints()
    top:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", -t, 0)
    top:SetPoint("BOTTOMRIGHT", healthBar, "TOPRIGHT", t, 0)
    top:SetHeight(t)
    bottom:ClearAllPoints()
    bottom:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", -t, 0)
    bottom:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", t, 0)
    bottom:SetHeight(t)
    left:ClearAllPoints()
    left:SetPoint("TOPRIGHT", healthBar, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMLEFT", 0, 0)
    left:SetWidth(t)
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(t)

    local dc = uuidb.general.darkencolor
    for _, e in ipairs(parts.edges) do
        e:SetVertexColor(dc.r, dc.g, dc.b, 1)
        e:Show()
    end
    parts.bg:SetVertexColor(0, 0, 0, SQUARE_BG_ALPHA)
    parts.bg:Show()
    if bgTexture then bgTexture:SetAlpha(0) end
end

-- Square border, part 2: the level box (WoW Forever) and the selection
-- outline (both clients).
--
-- Level box: Forever shows the unit's level in PlayerLevelDiffFrame, a
-- rounded badge (Camelot art) joined to the right of the health bar. With the
-- square border it becomes a square box the height of the health bar, from
-- the bar's right border out to the badge's right edge, sharing the bar's
-- right border; the level text and skull stay on top. Its textures live on
-- the badge frame itself, so they show and hide with it; the badge art is
-- faded to 0 meanwhile.
--
-- Selection: Blizzard's rounded target/focus glows (healthBar.selectedBorder,
-- and Forever's badge's own) are faded to 0 and replaced by a square outline
-- around the whole area -- the bar, plus the level box while the badge is
-- shown -- in Blizzard's target/focus colors. Refreshed after Blizzard's own
-- UpdateSelectionBorder / CompactUnitFrame_UpdatePlayerLevelDiff (hooks
-- installed only once the square border is in use, deferred a frame).
local levelParts = setmetatable({}, { __mode = "k" })   -- level badge -> { bg, top, bottom, right }
local outlineParts = setmetatable({}, { __mode = "k" }) -- healthBar -> { top, bottom, left, right }
local OUTLINE_PX = 2

local function NewStrip(owner, layer, sublevel)
    local t = owner:CreateTexture(nil, layer, nil, sublevel)
    t:SetColorTexture(1, 1, 1, 1)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    return t
end

local function Px(region, px)
    local SB = UberUI.squareborders
    return SB and SB.PixelsToUIUnits(region, px) or px
end

local function BorderPx()
    return tonumber(uuidb.general.nameplatesquareborder_thickness) or 1
end

local function SafeShown(region)
    local ok, shown = pcall(region.IsShown, region)
    if not ok or (issecretvalue and issecretvalue(shown)) then return false end
    return shown and true or false
end

-- One chat line the first time a square-border part fails, so a problem on
-- some plates is visible instead of silently leaving Blizzard's art up.
local reportedError = false
local function ReportError(where, err)
    if reportedError then return end
    reportedError = true
    print("|cff33ff99Uber UI|r: square nameplate border (" .. where .. ") failed: " .. tostring(err))
end

-- Blizzard centers the level text (and skull) on its badge art and re-sets
-- that on every CompactUnitFrame_UpdatePlayerLevelDiff; ours is re-applied
-- after it (hook below), so both sit centered in our box.
local function CenterLevelText(badge, anchor)
    local text, skull = badge.playerLevelDiffText, badge.highLevelTexture
    local icon = badge.playerLevelDiffIcon
    local target = anchor or icon
    if not target then return end
    if text then text:SetPoint("CENTER", target, "CENTER", 0, 0) end
    if skull then skull:SetPoint("CENTER", target, "CENTER", 0, 0) end
end

-- How far short of Blizzard's badge width the level box stops, in UI units.
-- Small on purpose: more than a few units and the bar + box stop lining up
-- with the name centered over them.
local LEVEL_BOX_TRIM = 3

local function UpdateLevelBox(unitFrame, on)
    local badge = unitFrame.PlayerLevelDiffFrame
    local healthBar = unitFrame.healthBar
    if not (badge and healthBar) then return end
    local parts = levelParts[badge]
    if not on then
        if parts then
            for _, tex in pairs(parts) do tex:Hide() end
            if badge.playerLevelDiffIcon then
                local dc = uuidb.general.darkencolor
                badge.playerLevelDiffIcon:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
            if badge.selectedBorder then badge.selectedBorder:SetAlpha(1) end
            CenterLevelText(badge, nil)
        end
        return
    end
    -- Blizzard's badge art goes first, so it's hidden even if anything
    -- below fails.
    if badge.playerLevelDiffIcon then badge.playerLevelDiffIcon:SetAlpha(0) end
    if badge.selectedBorder then badge.selectedBorder:SetAlpha(0) end
    if not parts then
        parts = {
            bg = NewStrip(badge, "BACKGROUND", -8),
            top = NewStrip(badge, "BACKGROUND", -7),
            bottom = NewStrip(badge, "BACKGROUND", -7),
            right = NewStrip(badge, "BACKGROUND", -7),
        }
        for _, tex in pairs(parts) do tex:Hide() end
        levelParts[badge] = parts
    end
    local t = Px(healthBar, BorderPx())
    local ok, err = pcall(function()
        parts.bg:ClearAllPoints()
        parts.bg:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", t, 0)
        parts.bg:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", t, 0)
        -- Out to (just short of) the badge's own right edge: Blizzard shortens
        -- the health bar by exactly the badge's width and centers the name
        -- over bar + badge (Thin/Modern's name-above layout), so a much
        -- narrower box left the bar looking shifted left of the name.
        parts.bg:SetPoint("RIGHT", badge, "RIGHT", -LEVEL_BOX_TRIM, 0)
        parts.top:ClearAllPoints()
        parts.top:SetPoint("BOTTOMLEFT", parts.bg, "TOPLEFT", 0, 0)
        parts.top:SetPoint("BOTTOMRIGHT", parts.bg, "TOPRIGHT", t, 0)
        parts.top:SetHeight(t)
        parts.bottom:ClearAllPoints()
        parts.bottom:SetPoint("TOPLEFT", parts.bg, "BOTTOMLEFT", 0, 0)
        parts.bottom:SetPoint("TOPRIGHT", parts.bg, "BOTTOMRIGHT", t, 0)
        parts.bottom:SetHeight(t)
        parts.right:ClearAllPoints()
        parts.right:SetPoint("TOPLEFT", parts.bg, "TOPRIGHT", 0, 0)
        parts.right:SetPoint("BOTTOMLEFT", parts.bg, "BOTTOMRIGHT", 0, 0)
        parts.right:SetWidth(t)
        CenterLevelText(badge, parts.bg)
    end)
    if not ok then
        ReportError("level box", err)
        return
    end
    local dc = uuidb.general.darkencolor
    parts.bg:SetVertexColor(0, 0, 0, SQUARE_BG_ALPHA)
    for _, key in ipairs({ "top", "bottom", "right" }) do
        parts[key]:SetVertexColor(dc.r, dc.g, dc.b, 1)
    end
    for _, tex in pairs(parts) do tex:Show() end
end

-- Blizzard's colors (Forever's NamePlateConstants values as fallback).
local function SelectionColor(healthBar)
    local isTarget = healthBar.IsTarget and healthBar:IsTarget()
    local isFocus = healthBar.IsFocus and healthBar:IsFocus()
    local c
    if isTarget then
        c = NAMEPLATE_BORDER_TARGET_COLOR
        if c and c.GetRGB then return c:GetRGB() end
        return 1, 1, 1
    elseif isFocus then
        c = NAMEPLATE_BORDER_FOCUS_TARGET_COLOR
        if c and c.GetRGB then return c:GetRGB() end
        return 1, 0.49, 0.039
    end
    return nil
end

-- Blizzard also darkens every nameplate that isn't the target or focus with
-- deselectedOverlay, a ROUNDED atlas (ui-hud-nameplates-deselected-overlay),
-- which left a bright rounded rim inside the square border. Square mode swaps
-- it for a flat overlay of the same darkness (~34%, sampled in-game), shown
-- under Blizzard's own condition (NamePlateHealthBarMixin:
-- UpdateSelectionBorder: selection borders in use, not target, not focus).
local DESELECTED_ALPHA = 0.34
local dimOverlays = setmetatable({}, { __mode = "k" }) -- healthBar -> texture

local function UpdateDeselectedOverlay(healthBar, on)
    local blizz = healthBar.deselectedOverlay
    local dim = dimOverlays[healthBar]
    if not on then
        if dim then
            dim:Hide()
            if blizz then blizz:SetAlpha(1) end
        end
        return
    end
    if not dim then
        -- ARTWORK 6: over the fill, under the health text (OVERLAY).
        dim = healthBar:CreateTexture(nil, "ARTWORK", nil, 6)
        dim:SetColorTexture(0, 0, 0, 1)
        dim:SetAllPoints(healthBar)
        dimOverlays[healthBar] = dim
    end
    if blizz then blizz:SetAlpha(0) end
    local useSelected = not healthBar.ShouldUseSelectedBorder or healthBar:ShouldUseSelectedBorder()
    local selected = (healthBar.IsTarget and healthBar:IsTarget()) or (healthBar.IsFocus and healthBar:IsFocus())
    dim:SetVertexColor(0, 0, 0, DESELECTED_ALPHA)
    dim:SetShown((useSelected and not selected) and true or false)
end

local function UpdateSelectionOutline(unitFrame, on)
    local healthBar = unitFrame.healthBar
    if not healthBar then return end
    pcall(UpdateDeselectedOverlay, healthBar, on)
    local parts = outlineParts[healthBar]
    local hideGlow = uuidb.general.hidenameplateglow
    if healthBar.selectedBorder and (on or parts) then
        healthBar.selectedBorder:SetAlpha((on or hideGlow) and 0 or 1)
    end
    local r, g, b
    if on and not hideGlow then r, g, b = SelectionColor(healthBar) end
    if not r then
        if parts then for _, tex in ipairs(parts) do tex:Hide() end end
        return
    end
    if not parts then
        parts = { NewStrip(healthBar, "OVERLAY", 7), NewStrip(healthBar, "OVERLAY", 7),
                  NewStrip(healthBar, "OVERLAY", 7), NewStrip(healthBar, "OVERLAY", 7) }
        outlineParts[healthBar] = parts
    end
    local t = Px(healthBar, BorderPx())
    local o = Px(healthBar, OUTLINE_PX)
    -- Right edge: the level box's while Forever's badge is shown.
    local badge = unitFrame.PlayerLevelDiffFrame
    local rightRel = healthBar
    if badge and levelParts[badge] and SafeShown(badge) then rightRel = levelParts[badge].bg end
    local top, bottom, left, right = parts[1], parts[2], parts[3], parts[4]
    local ok, err = pcall(function()
        top:ClearAllPoints()
        top:SetPoint("BOTTOMLEFT", healthBar, "TOPLEFT", -t - o, t)
        top:SetPoint("RIGHT", rightRel, "RIGHT", t + o, 0)
        top:SetHeight(o)
        bottom:ClearAllPoints()
        bottom:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", -t - o, -t)
        bottom:SetPoint("RIGHT", rightRel, "RIGHT", t + o, 0)
        bottom:SetHeight(o)
        left:ClearAllPoints()
        left:SetPoint("TOPRIGHT", healthBar, "TOPLEFT", -t, t)
        left:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMLEFT", -t, -t)
        left:SetWidth(o)
        right:ClearAllPoints()
        right:SetPoint("TOP", healthBar, "TOP", 0, t)
        right:SetPoint("BOTTOM", healthBar, "BOTTOM", 0, -t)
        right:SetPoint("LEFT", rightRel, "RIGHT", t, 0)
        right:SetWidth(o)
    end)
    if not ok then
        ReportError("selection outline", err)
        return
    end
    for _, tex in ipairs(parts) do
        tex:SetVertexColor(r, g, b, 1)
        tex:Show()
    end
end

-- Cast bar: on WoW Forever (Camelot), Blizzard anchors HealthBarsContainer
-- only 2px above CastBarsContainer (castBarToHealthBarSpacing = 2), but the
-- health bar's background/border extends below that spacing:
--   - In Rounded mode, Blizzard's bgTexture extends 6px below the health bar,
--     hanging 4px down into the cast bar.
--   - In Square mode, the square bottom border adds BorderPx() px below the
--     health bar, touching or overlapping the cast bar.
--   - Uninterruptible shield and target indicators reach an extra 3-4px up.
-- Moving the castBar StatusBar (and its Classic border/icon if present) down
-- inside CastBarsContainer clears the overlap cleanly in both modes without
-- shifting HealthBarsContainer (which is anchored to CastBarsContainer itself).
-- Captures Blizzard's own anchor point(s) and restores them when needed.
local function IsForeverClient()
    return WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
end

local function GetNameplateCastBar(unitFrame)
    if not unitFrame then return nil end
    if unitFrame.CastBarsContainer and unitFrame.CastBarsContainer.castBar then
        return unitFrame.CastBarsContainer.castBar
    end
    return unitFrame.castBar
end

local function CaptureOriginalPoints(region)
    if not region or region:GetNumPoints() == 0 then return nil end
    local points = {}
    for i = 1, region:GetNumPoints() do
        local ok, p1, p2, p3, p4, p5 = pcall(region.GetPoint, region, i)
        if ok and p1 then
            points[#points + 1] = { p1, p2, p3, p4, p5 or 0 }
        end
    end
    return #points > 0 and points or nil
end

local castBarOriginalPoints = setmetatable({}, { __mode = "k" })
local castBarNudged = setmetatable({}, { __mode = "k" })
local borderOriginalPoints = setmetatable({}, { __mode = "k" })
local iconOriginalPoints = setmetatable({}, { __mode = "k" })

local function UpdateNameplateCastBarNudge(unitFrame, on)
    local castBar = GetNameplateCastBar(unitFrame)
    if not castBar or castBar:IsForbidden() then return end

    if not on then
        if castBarNudged[castBar] then
            local orig = castBarOriginalPoints[castBar]
            if orig then
                castBar:ClearAllPoints()
                for _, pt in ipairs(orig) do
                    castBar:SetPoint(unpack(pt))
                end
            end
            local borderOrig = borderOriginalPoints[castBar]
            if borderOrig and castBar.Border then
                castBar.Border:ClearAllPoints()
                for _, pt in ipairs(borderOrig) do
                    castBar.Border:SetPoint(unpack(pt))
                end
            end
            local iconOrig = iconOriginalPoints[castBar]
            if iconOrig and castBar.Icon then
                castBar.Icon:ClearAllPoints()
                for _, pt in ipairs(iconOrig) do
                    castBar.Icon:SetPoint(unpack(pt))
                end
            end
            castBarOriginalPoints[castBar] = nil
            borderOriginalPoints[castBar] = nil
            iconOriginalPoints[castBar] = nil
            castBarNudged[castBar] = nil
        end
        return
    end

    if not castBarNudged[castBar] then
        local pts = CaptureOriginalPoints(castBar)
        if pts then
            castBarOriginalPoints[castBar] = pts
        end
        if castBar.Border and castBar.Border:IsShown() then
            local bpts = CaptureOriginalPoints(castBar.Border)
            if bpts then borderOriginalPoints[castBar] = bpts end
        end
        if castBar.Icon and castBar.Icon:GetNumPoints() > 0 then
            local ok, _, relTo = pcall(castBar.Icon.GetPoint, castBar.Icon, 1)
            if ok and relTo and relTo == castBar:GetParent() then
                local ipts = CaptureOriginalPoints(castBar.Icon)
                if ipts then iconOriginalPoints[castBar] = ipts end
            end
        end
    end

    local orig = castBarOriginalPoints[castBar]
    if not orig then return end

    -- The cast bar's "Important Cast" indicator (ImportantCastIndicator) reaches 3px
    -- above the cast bar, and the "targeting you" indicator (CastTargetIndicator)
    -- reaches 4px above the cast bar.
    -- Rounded mode: Blizzard bgTexture extends 6px down, spacing is 2px, so
    -- an 8px nudge leaves the indicators sitting cleanly below the rounded frame.
    -- Square mode: square border hangs BorderPx() down; a nudge of BorderPx() + 5
    -- gives an exact clean 3px gap between the square border and the indicators.
    local base = SquareBorderOn() and (BorderPx() + 5) or 8
    local nudge = Px(castBar, base)

    local ok, err = pcall(function()
        castBar:ClearAllPoints()
        for _, pt in ipairs(orig) do
            castBar:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5] - nudge)
        end
        local borderOrig = borderOriginalPoints[castBar]
        if borderOrig and castBar.Border and castBar.Border:IsShown() then
            castBar.Border:ClearAllPoints()
            for _, pt in ipairs(borderOrig) do
                castBar.Border:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5] - nudge)
            end
        end
        local iconOrig = iconOriginalPoints[castBar]
        if iconOrig and castBar.Icon then
            castBar.Icon:ClearAllPoints()
            for _, pt in ipairs(iconOrig) do
                castBar.Icon:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5] - nudge)
            end
        end
        castBarNudged[castBar] = true
    end)
    if not ok then ReportError("cast bar nudge", err) end
end

local function ApplySquareExtras(unitFrame, on)
    local ok, err = pcall(UpdateLevelBox, unitFrame, on)
    if not ok then ReportError("level box", err) end
    ok, err = pcall(UpdateSelectionOutline, unitFrame, on)
    if not ok then ReportError("selection outline", err) end
    UpdateNameplateCastBarNudge(unitFrame, IsForeverClient())
end

local extrasPending = setmetatable({}, { __mode = "k" })
local function QueueSquareExtras(unitFrame)
    if not unitFrame or extrasPending[unitFrame] then return end
    extrasPending[unitFrame] = true
    C_Timer.After(0, function()
        extrasPending[unitFrame] = nil
        if unitFrame:IsForbidden() or not unitFrame.healthBar or unitFrame.healthBar:IsForbidden() then return end
        ApplySquareExtras(unitFrame, SquareBorderOn())
    end)
end

local selectionHooked = setmetatable({}, { __mode = "k" }) -- healthBar -> unitFrame
local levelHookInstalled = false
local badgeShowHooked = setmetatable({}, { __mode = "k" }) -- level badge -> true
local function EnsureSquareExtrasHooks(unitFrame)
    local healthBar = unitFrame.healthBar
    if healthBar and healthBar.UpdateSelectionBorder and not selectionHooked[healthBar] then
        selectionHooked[healthBar] = unitFrame
        hooksecurefunc(healthBar, "UpdateSelectionBorder", function(self)
            QueueSquareExtras(selectionHooked[self])
        end)
    end
    -- Forever's level badge: re-apply whenever Blizzard shows it (the level
    -- update and plate reuse both do), in case the load-time pass didn't
    -- stick on this plate.
    local badge = unitFrame.PlayerLevelDiffFrame
    if badge and not badgeShowHooked[badge] then
        badgeShowHooked[badge] = true
        badge:HookScript("OnShow", function() QueueSquareExtras(unitFrame) end)
    end
    if not levelHookInstalled and CompactUnitFrame_UpdatePlayerLevelDiff then
        levelHookInstalled = true
        hooksecurefunc("CompactUnitFrame_UpdatePlayerLevelDiff", function(frame)
            -- Also runs for raid frames; only nameplates we've touched.
            if frame and frame.healthBar and selectionHooked[frame.healthBar] then
                QueueSquareExtras(frame)
            end
        end)
    end
end

-- Everything this file re-applies to a nameplate's health bar.
local function ApplyBarLook(healthBar, unitFrame)
    local tex = GetNameplateBarTexture()
    ApplyHealthBarTexture(healthBar, tex)
    local square = SquareBorderOn()
    UpdateBarMask(healthBar, tex ~= nil and not square)
    UpdateSquareBorder(healthBar, square)
    if unitFrame then
        if square then EnsureSquareExtrasHooks(unitFrame) end
        ApplySquareExtras(unitFrame, square)
    end
end

local function EnsureUpdateAnchorsHook(unitFrame)
    if anchorHooked[unitFrame] or not unitFrame.UpdateAnchors then return end
    anchorHooked[unitFrame] = true
    hooksecurefunc(unitFrame, "UpdateAnchors", function(self)
        if anchorPending[self] then return end
        anchorPending[self] = true
        C_Timer.After(0, function()
            anchorPending[self] = nil
            if self:IsForbidden() or not self.healthBar or self.healthBar:IsForbidden() then return end
            local cb = GetNameplateCastBar(self)
            if cb then
                castBarOriginalPoints[cb] = nil
                borderOriginalPoints[cb] = nil
                iconOriginalPoints[cb] = nil
                castBarNudged[cb] = nil
            end
            ApplyBarLook(self.healthBar, self)
        end)
    end)
end

function nameplates:OnNamePlateLoad(unitFrame)
    if not unitFrame or not unitFrame.healthBar then
        return
    end
    -- Some nameplates (e.g. other players' in certain content) come up
    -- fully Forbidden -- CreateMaskTexture/AddMaskTexture below throw
    -- "Attempt to access forbidden object" on those, deferred timer or not.
    if unitFrame:IsForbidden() or unitFrame.healthBar:IsForbidden() then
        return
    end

    local healthBar = unitFrame.healthBar

    -- Main texture logic
    local textureToApply = GetNameplateBarTexture()
    ApplyHealthBarTexture(healthBar, textureToApply)
    -- Blizzard re-sets the bar art on every UpdateAnchors; only hook when
    -- there's something of ours to put back.
    if textureToApply or SquareBorderOn() or IsForeverClient() then
        EnsureUpdateAnchorsHook(unitFrame)
    end

    -- Secondary texture logic for absorbs and heals
    local secondaryTextureToApply
    if uuidb.general.secondarybartextures and uuidb.general.secondarybartexture ~= "Blizzard" then
        secondaryTextureToApply = uuidb.statusbars[uuidb.general.secondarybartexture]
    else
        secondaryTextureToApply = textureToApply -- Fallback to main texture
    end

    if secondaryTextureToApply then
        if unitFrame.myHealPrediction then
            unitFrame.myHealPrediction:SetTexture(secondaryTextureToApply)
            if CUF_MY_HEAL_PREDICTION_COLOR then
                unitFrame.myHealPrediction:SetVertexColor(CUF_MY_HEAL_PREDICTION_COLOR:GetRGBA())
            else
                unitFrame.myHealPrediction:SetVertexColor(11/255, 136/255, 105/255, 1)
            end
        end
        if unitFrame.otherHealPrediction then
            unitFrame.otherHealPrediction:SetTexture(secondaryTextureToApply)
            if CUF_OTHER_HEAL_PREDICTION_COLOR then
                unitFrame.otherHealPrediction:SetVertexColor(CUF_OTHER_HEAL_PREDICTION_COLOR:GetRGBA())
            else
                unitFrame.otherHealPrediction:SetVertexColor(21/255, 89/255, 72/255, 1)
            end
        end
        if unitFrame.totalAbsorb then
            unitFrame.totalAbsorb:SetTexture(secondaryTextureToApply)
            unitFrame.totalAbsorb:SetVertexColor(.6, .9, .9, 1)
        end
    end

    local dc = uuidb.general.darkencolor
    if healthBar.bgTexture then
        healthBar.bgTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end
    local square = SquareBorderOn()
    UpdateBarMask(healthBar, textureToApply ~= nil and not square)
    UpdateSquareBorder(healthBar, square)
    if square then EnsureSquareExtrasHooks(unitFrame) end
    ApplySquareExtras(unitFrame, square)

    -- Darken Forever's level badge art -- only in Rounded mode. On a texture,
    -- SetVertexColor's alpha IS its alpha, so this used to undo the Square
    -- mode's fade of that art (UpdateLevelBox) on every plate but the target.
    if unitFrame.PlayerLevelDiffFrame and not square then
        unitFrame.PlayerLevelDiffFrame.playerLevelDiffIcon:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end

    if healthBar.selectedBorder then
        -- Square border: our own square outline replaces this glow.
        healthBar.selectedBorder:SetAlpha((uuidb.general.hidenameplateglow or SquareBorderOn()) and 0 or 1);
    end

    self:UpdateRaidTargetScale(unitFrame)
end

function nameplates:UpdateRaidTargetScale(unitFrame)
    if unitFrame and unitFrame.RaidTargetFrame and not unitFrame:IsForbidden() then
        local raidTargetFrame = unitFrame.RaidTargetFrame

        -- Feature at its no-op default (scale 1, top anchor off): don't
        -- touch Blizzard's nameplate layout at all. Re-anchoring/rescaling
        -- the native RaidTargetFrame from addon code on every plate add was
        -- the only nameplate layout write left at default settings, and is
        -- the prime suspect for the "execution tainted by 'Uber UI'" secret
        -- health compare errors in Blizzard's SetUnit chain. If we changed
        -- this frame earlier (feature was on), restore it once and forget it.
        local wantsScale = uuidb.general.nameplateraidtargetscale and uuidb.general.nameplateraidtargetscale ~= 1
        local wantsTopAnchor = uuidb.general.nameplateraidtargettopanchor
        if not (wantsScale or wantsTopAnchor) then
            local original = _uberOriginalPoints[raidTargetFrame]
            if original then
                raidTargetFrame:ClearAllPoints()
                for _, point in ipairs(original) do
                    raidTargetFrame:SetPoint(unpack(point))
                end
                raidTargetFrame:SetScale(1)
                _uberOriginalPoints[raidTargetFrame] = nil
            end
            return
        end

        if not _uberOriginalPoints[raidTargetFrame] and raidTargetFrame:GetNumPoints() > 0 then
            _uberOriginalPoints[raidTargetFrame] = {}
            for i = 1, raidTargetFrame:GetNumPoints() do
                local success, p1, p2, p3, p4, p5 = pcall(raidTargetFrame.GetPoint, raidTargetFrame, i)
                if success and p1 then
                    _uberOriginalPoints[raidTargetFrame][#_uberOriginalPoints[raidTargetFrame] + 1] = { p1, p2, p3, p4, p5 }
                end
            end
            if #_uberOriginalPoints[raidTargetFrame] == 0 then
                local fallbackAnchor = unitFrame.name or unitFrame
                _uberOriginalPoints[raidTargetFrame][1] = { "RIGHT", fallbackAnchor, "LEFT", -5, 0 }
            end
        end

        local scale = 1
        local isFriendly = unitFrame.unit and UnitIsFriend("player", unitFrame.unit)
        local isTarget = unitFrame.unit and UnitIsUnit("target", unitFrame.unit)
        local isSimplified = unitFrame.isSimplified

        if isFriendly and isSimplified and not isTarget then
            if uuidb.general.nameplateraidtargetscale then
                scale = uuidb.general.nameplateraidtargetscale
            end
        end

        if _uberOriginalPoints[raidTargetFrame] then
            if isFriendly and isSimplified and not isTarget and uuidb.general.nameplateraidtargettopanchor then
                raidTargetFrame:ClearAllPoints()
                if unitFrame.healthBar then
                    raidTargetFrame:SetPoint("BOTTOM", unitFrame.healthBar, "TOP", 0, 12)
                else
                    raidTargetFrame:SetPoint("BOTTOM", unitFrame, "TOP", 0, 12)
                end
            else
                raidTargetFrame:ClearAllPoints()
                for _, point in ipairs(_uberOriginalPoints[raidTargetFrame]) do
                    raidTargetFrame:SetPoint(unpack(point))
                end
            end
        end
        raidTargetFrame:SetScale(scale)
    end
end

function nameplates:UpdateAllNameplateRaidTargetScale()
    for _, nameplateFrame in ipairs(C_NamePlate.GetNamePlates()) do
        if nameplateFrame.UnitFrame then
            self:UpdateRaidTargetScale(nameplateFrame.UnitFrame)
        end
    end
end

function nameplates:ForceNameplateTexture()
    for _, nameplateFrame in ipairs(C_NamePlate.GetNamePlates()) do
        if nameplateFrame.UnitFrame then
            self:OnNamePlateLoad(nameplateFrame.UnitFrame)
        end
    end
end

local _originalPlateWidths = setmetatable({}, { __mode = "k" })
function nameplates:UpdateNameplateSize()
    for _, nameplateFrame in ipairs(C_NamePlate.GetNamePlates()) do
        if nameplateFrame.UnitFrame and nameplateFrame.UnitFrame.isFriend and not nameplateFrame:IsForbidden() and not InCombatLockdown() then
            -- Capture this nameplate's own native width before we ever touch
            -- it (not a single shared value -- friendly/hostile/simplified
            -- nameplates aren't guaranteed to share one native width), so
            -- disabling the option restores it instead of forcing a
            -- hardcoded size on every nameplate regardless of its own
            -- native default.
            if _originalPlateWidths[nameplateFrame] == nil then
                _originalPlateWidths[nameplateFrame] = nameplateFrame:GetWidth()
            end
            if uuidb.general.smallfriendlynameplate then
                nameplateFrame:SetWidth(100)
            else
                nameplateFrame:SetWidth(_originalPlateWidths[nameplateFrame])
            end
        end
    end
end

if NamePlateUnitFrameMixin then
    hooksecurefunc(NamePlateUnitFrameMixin, "OnLoad", function(self)
        -- Deferred: for a brand-new nameplate frame, OnLoad and the
        -- immediately-following SetUnit -> CompactUnitFrame_UpdateAll ->
        -- health-text-update chain can happen in the same synchronous
        -- burst. OnNamePlateLoad's texture/mask writes on the native
        -- healthBar (CreateMaskTexture/AddMaskTexture/SetStatusBarTexture)
        -- running inside that burst tainted the rest of it, breaking
        -- Blizzard's own later secret-health-value comparison with
        -- "execution tainted by 'Uber UI'". Run this on the next frame
        -- instead, fully detached from Blizzard's in-progress chain.
        local capturedFrame = self
        C_Timer.After(0, function()
            UberUI.nameplates:OnNamePlateLoad(capturedFrame)
        end)
    end)
end

-- Forward-declared: defined further down, called from f's OnEvent below.
local MaybeRegisterRaidTargetScaleHooks

local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("RAID_TARGET_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, unit)
    MaybeRegisterRaidTargetScaleHooks()
    if event == "NAME_PLATE_UNIT_ADDED" then
        -- Only do this at all while the feature is actually on -- when off,
        -- friendly nameplates just keep Blizzard's native size, no addon
        -- intervention needed (see the Small Friendly Nameplates onChange in
        -- options/nameplates.lua for the one-time restore-to-native call when
        -- the option gets turned off).
        --
        -- Deferred: this event fires nested inside Blizzard's own native
        -- nameplate-add call stack (OnNamePlateAdded -> SetUnit -> ...).
        -- Calling SetWidth synchronously from here tainted that same chain
        -- for the rest of its run, breaking a later secret-health-value
        -- comparison in Blizzard's own TextStatusBar code with "execution
        -- tainted by 'Uber UI'". C_Timer.After(0, ...) runs this on the next
        -- frame instead, in a clean call stack fully detached from
        -- Blizzard's in-progress one.
        if uuidb and uuidb.general and uuidb.general.smallfriendlynameplate then
            C_Timer.After(0, function()
                UberUI.nameplates:UpdateNameplateSize()
            end)
        end
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate and nameplate.UnitFrame then
            -- Nameplate frames are pooled and reused across many different
            -- units -- OnLoad (which OnNamePlateLoad's texture/mask setup
            -- normally rides on) only fires once, the first time a given
            -- pooled frame is ever created. Every later reuse for a new
            -- unit only fires NAME_PLATE_UNIT_ADDED, and Blizzard's own
            -- SetUnit-driven refresh resets the health bar back to its
            -- default texture in the process -- so without reapplying here
            -- too, the custom texture quietly reverts as plates get
            -- recycled while running around. Same deferral as the OnLoad
            -- hook, for the same taint reason.
            local capturedFrame = nameplate.UnitFrame
            C_Timer.After(0, function()
                UberUI.nameplates:OnNamePlateLoad(capturedFrame)
            end)
            if nameplate.UnitFrame.RaidTargetFrame then
                if _uberOriginalPoints[nameplate.UnitFrame.RaidTargetFrame] then
                    nameplate.UnitFrame.RaidTargetFrame:ClearAllPoints()
                    for _, point in ipairs(_uberOriginalPoints[nameplate.UnitFrame.RaidTargetFrame]) do
                        nameplate.UnitFrame.RaidTargetFrame:SetPoint(unpack(point))
                    end
                    _uberOriginalPoints[nameplate.UnitFrame.RaidTargetFrame] = nil
                end
            end
            UberUI.nameplates:UpdateRaidTargetScale(nameplate.UnitFrame)
        end
    else
        if uuidb and uuidb.general and uuidb.general.smallfriendlynameplate then
            C_Timer.After(0, function()
                UberUI.nameplates:UpdateNameplateSize()
            end)
        end
        UberUI.nameplates:UpdateAllNameplateRaidTargetScale()
    end
end)

function nameplates:SafeModify(nameplateFrame, callback)
    if not nameplateFrame or not nameplateFrame.UnitFrame then
        return
    end

    local isForbidden = nameplateFrame:IsForbidden()
    callback(nameplateFrame.UnitFrame, isForbidden)
end

function nameplates:GetSafeBgTexture(nameplateFrame)
    if not nameplateFrame or not nameplateFrame.UnitFrame or nameplateFrame:IsForbidden() then
        return nil
    end

    if nameplateFrame.UnitFrame.healthBar and nameplateFrame.UnitFrame.healthBar.bgTexture then
        return nameplateFrame.UnitFrame.healthBar.bgTexture
    end

    return nil
end

-- Both hooks below fire synchronously as part of the same nameplate-render
-- burst as the OnLoad hook above (CompactUnitFrame_UpdateAll/
-- UpdateCenterStatusIcon are directly in Blizzard's OnNamePlateAdded ->
-- SetUnit chain) -- same taint risk, deferred the same way. Only registered
-- at all if the raid-target-scale feature is actually customized away from
-- its no-op default (scale=1, top-anchor off) -- our own events already
-- call UpdateRaidTargetScale/UpdateAllNameplateRaidTargetScale directly, so
-- these two hooks only exist to catch a narrower edge case (Blizzard's own
-- update cycle changing something ours might miss), which isn't worth the
-- extra hook surface when the feature isn't even in use.
local raidTargetHooksRegistered = false
function MaybeRegisterRaidTargetScaleHooks()
    if raidTargetHooksRegistered then return end
    if not (uuidb and uuidb.general) then return end
    local wantsScale = uuidb.general.nameplateraidtargetscale and uuidb.general.nameplateraidtargetscale ~= 1
    local wantsTopAnchor = uuidb.general.nameplateraidtargettopanchor
    if not (wantsScale or wantsTopAnchor) then return end
    raidTargetHooksRegistered = true

    if CompactUnitFrame_UpdateAll then
        hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
            if frame and frame.unit and string.find(frame.unit, "nameplate") then
                C_Timer.After(0, function()
                    UberUI.nameplates:UpdateRaidTargetScale(frame)
                end)
            end
        end)
    end

    if CompactUnitFrame_UpdateCenterStatusIcon then
        hooksecurefunc("CompactUnitFrame_UpdateCenterStatusIcon", function(frame)
            if frame and frame.unit and string.find(frame.unit, "nameplate") then
                C_Timer.After(0, function()
                    UberUI.nameplates:UpdateRaidTargetScale(frame)
                end)
            end
        end)
    end
end

UberUI.nameplates = nameplates
