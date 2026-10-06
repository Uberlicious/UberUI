local addon, ns = ...
local nameplates = {}

local _uberOriginalPoints = setmetatable({}, {__mode = "k"})

local function SquareBorderOn()
    return uuidb and uuidb.general and uuidb.general.nameplatesquareborder == true
end

-- The custom health bar texture in effect, or nil for Blizzard's own. Square
-- mode needs a flat texture, so it defaults to "Blizzard_Flat".
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

-- Applied the way Blizzard does (barTexture:SetTexture/SetAtlas), never
-- SetStatusBarTexture, which drew the bar over the nameplate border. The
-- original draw layer is restored.
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

-- Blizzard's UpdateAnchors puts its own atlas back on the health bar (plate
-- added, option changes, and on retail every plate resize), so ours is
-- re-applied after it: an instance hook per unit frame (pooled frames already
-- exist), only while something of ours is in use, deferred and coalesced.
local anchorHooked = setmetatable({}, { __mode = "k" })
local anchorPending = setmetatable({}, { __mode = "k" })

-- Blizzard's bar art has chamfered corners and a dark edge, so the border
-- ring behind reads as in front of the fill. A custom texture gets that shape
-- from a mask stretched over the health bar. Notes: MaskTexture ignores
-- SetTexCoord in-game, and texture files stay cached across /reload.
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

-- Square health bar border: four strips just outside the bar, in the
-- darkness color, over a dark background of our own for missing health.
-- Blizzard's rounded bgTexture (ring + background) is faded to 0 (Blizzard
-- never touches its alpha, and selectedBorder still anchors to it).
--
-- Pixel-perfect: plates sit at fractional pixels and rescale, so the strips
-- live on a layer that ignores the plate's scale (whole-pixel thickness at
-- any scale), and every texture meeting a strip has pixel snapping off like
-- the strips -- mixed snapped/unsnapped edges round apart into hairline gaps.

-- Square border base color (Forever copper, retail silver), multiplied by
-- the darkness color.
local function GetSquareBorderBase()
    return UberUI.squareborders.GetBorderBase()
end

local SQUARE_BG_ALPHA = 0.6
local squareParts = setmetatable({}, { __mode = "k" }) -- healthBar -> { bg, edges, layer }

local function Unsnap(region)
    if region and region.SetSnapToPixelGrid then
        pcall(region.SetSnapToPixelGrid, region, false)
        pcall(region.SetTexelSnappingBias, region, 0)
    end
end

-- A frame over `owner` fixed at scale 1, independent of the plate's. Frames
-- anchored into a nameplate need DisableUntrustedLayoutScriptsTemplate in
-- 12.x. nil if it can't be made (callers draw on `owner` instead).
local scaleFreeLayers = setmetatable({}, { __mode = "k" }) -- owner -> frame or false
local function ScaleFreeLayer(owner)
    local layer = scaleFreeLayers[owner]
    if layer == nil then
        local ok, f = pcall(CreateFrame, "Frame", nil, owner, "DisableUntrustedLayoutScriptsTemplate")
        if ok and f and f.SetIgnoreParentScale then
            f:SetIgnoreParentScale(true)
            f:SetScale(1)
            f:SetAllPoints(owner)
            layer = f
        else
            layer = false
        end
        scaleFreeLayers[owner] = layer
    end
    return layer or nil
end

local function UpdateSquareBorder(healthBar, on)
    local parts = squareParts[healthBar]
    local bgTexture = healthBar.bgTexture
    if not on then
        if parts then
            parts.bg:Hide()
            for _, e in ipairs(parts.edges) do e:Hide() end
            if bgTexture then bgTexture:SetAlpha(1) end
            local fill = healthBar.GetStatusBarTexture and healthBar:GetStatusBarTexture()
            if fill and fill.SetSnapToPixelGrid then pcall(fill.SetSnapToPixelGrid, fill, true) end
        end
        return
    end
    if not parts then
        parts = { edges = {} }
        parts.bg = healthBar:CreateTexture(nil, "BACKGROUND", nil, -1)
        parts.bg:SetColorTexture(0, 0, 0, 1)
        parts.bg:SetAllPoints(healthBar)
        Unsnap(parts.bg)
        parts.layer = ScaleFreeLayer(healthBar) or healthBar
        for i = 1, 4 do
            local e = parts.layer:CreateTexture(nil, "ARTWORK", nil, 7)
            e:SetColorTexture(1, 1, 1, 1)
            Unsnap(e)
            parts.edges[i] = e
        end
        squareParts[healthBar] = parts
    end
    -- SetStatusBarTexture makes a new fill texture with snapping back on.
    Unsnap(healthBar.GetStatusBarTexture and healthBar:GetStatusBarTexture())

    local px = tonumber(uuidb.general.nameplatesquareborder_thickness) or 1
    local SB = UberUI.squareborders
    local t = SB and SB.PixelsToUIUnits(parts.layer, px) or px
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

    local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    local base = GetSquareBorderBase()
    local cr = base.r * dc.r
    local cg = base.g * dc.g
    local cb = base.b * dc.b
    for _, e in ipairs(parts.edges) do
        e:SetVertexColor(cr, cg, cb, 1)
        e:Show()
    end
    parts.bg:SetVertexColor(0, 0, 0, SQUARE_BG_ALPHA)
    parts.bg:Show()
    if bgTexture then bgTexture:SetAlpha(0) end
end

-- Level box (Forever): the rounded level badge joined to the bar becomes a
-- square box the bar's height, sharing the bar's right border; the badge art
-- is faded out. Its textures live on the badge, so they show/hide with it.
--
-- Selection: Blizzard's rounded target/focus glows are faded out and replaced
-- by a square outline around the bar (plus the level box while shown), in
-- Blizzard's colors. Refreshed after UpdateSelectionBorder /
-- CompactUnitFrame_UpdatePlayerLevelDiff (hooked only in square mode).
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

local SafeShown = UberUI.util.SafeShown

-- Once per part.
local reportedError = {}
local function ReportError(where, err)
    if reportedError[where] then return end
    reportedError[where] = true
    UberUI:ReportError("square nameplate border (" .. where .. ")", err)
end

-- Blizzard re-centers the level text on its badge art on every level update;
-- ours is re-applied after it.
local function CenterLevelText(badge, anchor)
    local text, skull = badge.playerLevelDiffText, badge.highLevelTexture
    local icon = badge.playerLevelDiffIcon
    local target = anchor or icon
    if not target then return end
    if text then text:SetPoint("CENTER", target, "CENTER", 0, 0) end
    if skull then skull:SetPoint("CENTER", target, "CENTER", 0, 0) end
end

-- How far short of the badge's width the box stops (UI units). Kept small so
-- bar + box stay centered under the name.
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
                -- Faded out in square mode; nothing else puts it back.
                badge.playerLevelDiffIcon:SetAlpha(1)
            end
            if badge.selectedBorder then badge.selectedBorder:SetAlpha(1) end
            CenterLevelText(badge, nil)
        end
        return
    end
    -- Badge art first, so it's hidden even if anything below fails.
    if badge.playerLevelDiffIcon then badge.playerLevelDiffIcon:SetAlpha(0) end
    if badge.selectedBorder then badge.selectedBorder:SetAlpha(0) end
    if not parts then
        -- Background on the badge (under its level text); strips on its
        -- scale-free layer.
        local layer = ScaleFreeLayer(badge) or badge
        parts = {
            bg = NewStrip(badge, "BACKGROUND", -8),
            top = NewStrip(layer, "BACKGROUND", -7),
            bottom = NewStrip(layer, "BACKGROUND", -7),
            right = NewStrip(layer, "BACKGROUND", -7),
        }
        for _, tex in pairs(parts) do tex:Hide() end
        levelParts[badge] = parts
    end
    if not parts.left then
        parts.left = NewStrip(ScaleFreeLayer(badge) or badge, "BACKGROUND", -7)
        parts.left:Hide()
    end
    local t = Px(parts.top, BorderPx())
    -- The box starts at the bar's right edge with its own left strip over the
    -- bar's right border (the badge is far above the bar's border layer).
    -- Anchored to the health bar, not the strip: anchoring to a
    -- ScaleFreeLayer region is refused (it carries a forbidden aspect).
    local ok, err = pcall(function()
        parts.bg:ClearAllPoints()
        parts.bg:SetPoint("TOPLEFT", healthBar, "TOPRIGHT", 0, 0)
        parts.bg:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMRIGHT", 0, 0)
        -- Blizzard shortens the bar by the badge's width and centers the name
        -- over bar + badge, so the box runs out to the badge's edge.
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
        parts.left:ClearAllPoints()
        parts.left:SetPoint("TOPLEFT", parts.bg, "TOPLEFT", 0, 0)
        parts.left:SetPoint("BOTTOMLEFT", parts.bg, "BOTTOMLEFT", 0, 0)
        parts.left:SetWidth(t)
        CenterLevelText(badge, parts.bg)
    end)
    if not ok then
        ReportError("level box", err)
        return
    end
    local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    local base = GetSquareBorderBase()
    local cr = base.r * dc.r
    local cg = base.g * dc.g
    local cb = base.b * dc.b
    parts.bg:SetVertexColor(0, 0, 0, SQUARE_BG_ALPHA)
    for _, key in ipairs({ "top", "bottom", "right", "left" }) do
        parts[key]:SetVertexColor(cr, cg, cb, 1)
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

-- Blizzard's deselectedOverlay (dims non-target plates) is a rounded atlas
-- that leaves a bright rim inside the square border; square mode uses a flat
-- overlay of the same darkness under Blizzard's own conditions.
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
        Unsnap(dim)
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
        local layer = ScaleFreeLayer(healthBar) or healthBar
        parts = { NewStrip(layer, "OVERLAY", 7), NewStrip(layer, "OVERLAY", 7),
                  NewStrip(layer, "OVERLAY", 7), NewStrip(layer, "OVERLAY", 7) }
        outlineParts[healthBar] = parts
    end
    local t = Px(parts[1], BorderPx())
    local o = Px(parts[1], OUTLINE_PX)
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

local function ApplySquareExtras(unitFrame, on)
    local ok, err = pcall(UpdateLevelBox, unitFrame, on)
    if not ok then ReportError("level box", err) end
    ok, err = pcall(UpdateSelectionOutline, unitFrame, on)
    if not ok then ReportError("selection outline", err) end
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
    -- Re-apply whenever Blizzard shows the level badge.
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
    local square = SquareBorderOn()
    local tex = GetNameplateBarTexture()
    ApplyHealthBarTexture(healthBar, tex)
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
            ApplyBarLook(self.healthBar, self)
        end)
    end)
end

function nameplates:OnNamePlateLoad(unitFrame)
    if not unitFrame or not unitFrame.healthBar then
        return
    end
    -- Some plates are fully forbidden (mask calls would throw).
    if unitFrame:IsForbidden() or unitFrame.healthBar:IsForbidden() then
        return
    end

    local healthBar = unitFrame.healthBar

    local textureToApply = GetNameplateBarTexture()
    ApplyHealthBarTexture(healthBar, textureToApply)
    if textureToApply or SquareBorderOn() then
        EnsureUpdateAnchorsHook(unitFrame)
    end

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

    -- Darken Forever's level badge art only in Rounded mode (square fades it,
    -- and SetVertexColor's alpha would undo that).
    if unitFrame.PlayerLevelDiffFrame and not square then
        unitFrame.PlayerLevelDiffFrame.playerLevelDiffIcon:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end

    if healthBar.selectedBorder then
        healthBar.selectedBorder:SetAlpha((uuidb.general.hidenameplateglow or SquareBorderOn()) and 0 or 1);
    end

    self:UpdateRaidTargetScale(unitFrame)
end

function nameplates:UpdateRaidTargetScale(unitFrame)
    if unitFrame and unitFrame.RaidTargetFrame and not unitFrame:IsForbidden() then
        local raidTargetFrame = unitFrame.RaidTargetFrame

        -- At the no-op default, never touch Blizzard's layout (restore once if
        -- we changed it earlier).
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
            -- Each plate's own native width, restored when the option is off.
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
        -- Deferred: OnLoad runs in the same synchronous burst as Blizzard's
        -- SetUnit -> UpdateAll chain, and writing to the health bar inside it
        -- taints that chain (secret health compares then error).
        local capturedFrame = self
        C_Timer.After(0, function()
            UberUI.nameplates:OnNamePlateLoad(capturedFrame)
        end)
    end)
end

local MaybeRegisterRaidTargetScaleHooks

local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("RAID_TARGET_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, unit)
    MaybeRegisterRaidTargetScaleHooks()
    if event == "NAME_PLATE_UNIT_ADDED" then
        -- Deferred: this fires inside Blizzard's nameplate-add chain, and a
        -- synchronous SetWidth tainted it.
        if uuidb and uuidb.general and uuidb.general.smallfriendlynameplate then
            C_Timer.After(0, function()
                UberUI.nameplates:UpdateNameplateSize()
            end)
        end
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate and nameplate.UnitFrame then
            -- Pooled plates only get OnLoad once; every reuse resets the bar,
            -- so re-apply here too (deferred for the same taint reason).
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

-- These fire inside Blizzard's SetUnit chain: deferred, and only registered
-- when the raid target scale/anchor feature is actually customized.
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

-- Options preview (options/cdmpreview.lua): the same health bar styling as
-- the real plates, on a mock health bar built like Blizzard's (barTexture,
-- bgTexture, selectedBorder, deselectedOverlay).
-- unitFrame (optional): a mock with .healthBar and Forever's
-- .PlayerLevelDiffFrame, for the level box.
function nameplates.PreviewHealthBar(healthBar, unitFrame)
    if not (uuidb and uuidb.general) then return end
    local dc = uuidb.general.darkencolor
    if healthBar.bgTexture and dc then
        healthBar.bgTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end
    -- OnNamePlateLoad's rounded-mode badge darkening.
    local badge = unitFrame and unitFrame.PlayerLevelDiffFrame
    if badge and badge.playerLevelDiffIcon and dc and not SquareBorderOn() then
        badge.playerLevelDiffIcon:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        badge.playerLevelDiffIcon:SetAlpha(1)
    end
    ApplyBarLook(healthBar, unitFrame)
end

UberUI.nameplates = nameplates
