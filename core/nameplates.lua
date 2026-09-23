local addon, ns = ...
local nameplates = {}

local _uberOriginalPoints = setmetatable({}, {__mode = "k"})

-- No masking here at all, by design: Blizzard's own nameplate
-- healthBar.barTexture (Blizzard_NamePlates.xml) is anchored with a plain
-- setAllPoints and uses no mask whatsoever -- confirmed against the live
-- client source. Two things were tried and ruled out with actual pixel
-- data before landing here: (1) masking with the atlas
-- ("UI-HUD-CoolDownManager-Bar") Blizzard uses for that same barTexture --
-- dumping the exported UICooldownManager.BLP showed that atlas region is
-- almost entirely alpha=0, not a usable shape to mask with; (2) the
-- addon's original hand-made cdm_bar_mask.tga -- dumping that TGA's alpha
-- channel showed it's just a near-fully-opaque rectangle with a few-pixel
-- edge feather, not a rounded pill either, and stretching its 38px-tall
-- source down to a ~10px nameplate bar was producing visible seam
-- artifacts (the reported gaps, then a stray dark line) with no shape
-- benefit to justify it. Matching Blizzard's real (unmasked) approach
-- avoids all of that.

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
    local textureToApply
    if uuidb.general.nameplatebartextures and uuidb.general.nameplatebartexture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.nameplatebartexture]
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply and type(textureToApply) == "string" then
        healthBar:SetStatusBarTexture(textureToApply)
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

    if (uuidb.general.hidenameplateglow) then
        if healthBar.selectedBorder then
            healthBar.selectedBorder:SetAlpha(0);
        end
    end

    self:UpdateRaidTargetScale(unitFrame)
end

function nameplates:UpdateRaidTargetScale(unitFrame)
    if unitFrame and unitFrame.RaidTargetFrame and not unitFrame:IsForbidden() then
        local raidTargetFrame = unitFrame.RaidTargetFrame

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
        -- intervention needed (see setValue in options.lua for the one-time
        -- restore-to-native call when the option gets turned off).
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
