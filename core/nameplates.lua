local addon, ns = ...
local nameplates = {}

local _uberOriginalPoints = setmetatable({}, {__mode = "k"})

-- The custom health bar texture in effect, or nil for Blizzard's own.
local function GetNameplateBarTexture()
    if not (uuidb and uuidb.general and uuidb.statusbars) then return nil end
    local tex
    if uuidb.general.nameplatebartextures and uuidb.general.nameplatebartexture ~= "Blizzard" then
        tex = uuidb.statusbars[uuidb.general.nameplatebartexture]
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        tex = uuidb.statusbars[uuidb.general.texture]
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
        bar:SetTexture(textureToApply)
        if layer then bar:SetDrawLayer(layer, sublevel or 0) end
    else
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

local function EnsureUpdateAnchorsHook(unitFrame)
    if anchorHooked[unitFrame] or not unitFrame.UpdateAnchors then return end
    anchorHooked[unitFrame] = true
    hooksecurefunc(unitFrame, "UpdateAnchors", function(self)
        if anchorPending[self] then return end
        anchorPending[self] = true
        C_Timer.After(0, function()
            anchorPending[self] = nil
            if self:IsForbidden() or not self.healthBar or self.healthBar:IsForbidden() then return end
            local tex = GetNameplateBarTexture()
            if tex then ApplyHealthBarTexture(self.healthBar, tex) end
            UpdateBarMask(self.healthBar, tex ~= nil)
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
    if textureToApply then
        ApplyHealthBarTexture(healthBar, textureToApply)
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
        end
        if unitFrame.otherHealPrediction then
            unitFrame.otherHealPrediction:SetTexture(secondaryTextureToApply)
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
    UpdateBarMask(healthBar, textureToApply ~= nil)

    if unitFrame.PlayerLevelDiffFrame then
        unitFrame.PlayerLevelDiffFrame.playerLevelDiffIcon:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end

    if healthBar.selectedBorder then
        healthBar.selectedBorder:SetAlpha(uuidb.general.hidenameplateglow and 0 or 1);
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
