local addon, ns = ...
local nameplates = {}

local function GetMaskTexture()
    if uuidb and uuidb.masks and uuidb.masks.cdm_mask then
        return uuidb.masks.cdm_mask
    end
    return [[Interface\AddOns\Uber UI\textures\statusbars\cdm_bar_mask.tga]]
end

local MASK_OPTS = {
    insetL = 0,  -- left crop
    insetT = 0,  -- top crop (raise top edge)
    insetR = 0,  -- right crop (pull right edge inward more)
    insetB = -1, -- bottom crop
    shiftX = 0,  -- whole mask shift on X
    shiftY = 0,  -- whole mask shift on Y (raise mask slightly)
}

function nameplates:OnNamePlateLoad(unitFrame)
    if not unitFrame or not unitFrame.healthBar then
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

    -- MASKING LOGIC
    if healthBar.CreateMaskTexture and healthBar.GetStatusBarTexture then
        local opts = MASK_OPTS
        local L, T, R, B = opts.insetL or 0, opts.insetT or 0, opts.insetR or 0, opts.insetB or 0
        local SX, SY = opts.shiftX or 0, opts.shiftY or 0

        if not healthBar._uberMask then
            local m = healthBar:CreateMaskTexture(nil, "OVERLAY")
            if m and m.SetTexture then
                m:SetTexture(GetMaskTexture(), "CLAMPTOBLACK", "CLAMPTOBLACK")
                if m.SetSnapToPixelGrid then m:SetSnapToPixelGrid(true) end
                if m.SetTexelSnappingBias then m:SetTexelSnappingBias(0) end
                if m.SetHorizTile then m:SetHorizTile(false) end
                if m.SetVertTile then m:SetVertTile(false) end
                healthBar._uberMask = m
            end
        end
        local m = healthBar._uberMask

        if m and m.ClearAllPoints and m.SetPoint then
            m:ClearAllPoints()
            m:SetPoint("TOPLEFT", healthBar, "TOPLEFT", L + SX, -(T - SY))
            m:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -R + SX, B + SY)
        end

        -- Apply the mask to the fill texture
        local fill = healthBar:GetStatusBarTexture()
        if fill and m and fill.AddMaskTexture and not fill._masked then
            fill:AddMaskTexture(m)
            fill._masked = true
        end
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

        if not raidTargetFrame.uberOriginalPoints and raidTargetFrame:GetNumPoints() > 0 then
            raidTargetFrame.uberOriginalPoints = {}
            for i = 1, raidTargetFrame:GetNumPoints() do
                local success, p1, p2, p3, p4, p5 = pcall(raidTargetFrame.GetPoint, raidTargetFrame, i)
                if success and p1 then
                    raidTargetFrame.uberOriginalPoints[#raidTargetFrame.uberOriginalPoints + 1] = { p1, p2, p3, p4, p5 }
                end
            end
            if #raidTargetFrame.uberOriginalPoints == 0 then
                local fallbackAnchor = unitFrame.name or unitFrame
                raidTargetFrame.uberOriginalPoints[1] = { "RIGHT", fallbackAnchor, "LEFT", -5, 0 }
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

        if raidTargetFrame.uberOriginalPoints then
            if isFriendly and isSimplified and not isTarget and uuidb.general.nameplateraidtargettopanchor then
                raidTargetFrame:ClearAllPoints()
                if unitFrame.healthBar then
                    raidTargetFrame:SetPoint("BOTTOM", unitFrame.healthBar, "TOP", 0, 12)
                else
                    raidTargetFrame:SetPoint("BOTTOM", unitFrame, "TOP", 0, 12)
                end
            else
                raidTargetFrame:ClearAllPoints()
                for _, point in ipairs(raidTargetFrame.uberOriginalPoints) do
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

local originalNameplateWidth = nil
function nameplates:UpdateNameplateSize()
    for _, nameplateFrame in ipairs(C_NamePlate.GetNamePlates()) do
        if originalNameplateWidth == nil then
            originalNameplateWidth = nameplateFrame:GetWidth()
        end
        if nameplateFrame.UnitFrame and nameplateFrame.UnitFrame.isFriend and not nameplateFrame:IsForbidden() and not InCombatLockdown() then
            if uuidb.general.smallfriendlynameplate then
                nameplateFrame:SetWidth(100)
            else
                nameplateFrame:SetWidth(230)
            end
        end
    end
end

hooksecurefunc(NamePlateUnitFrameMixin, "OnLoad", function(self)
    UberUI.nameplates:OnNamePlateLoad(self)
end)

local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("RAID_TARGET_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate and nameplate.UnitFrame then
            if nameplate.UnitFrame.RaidTargetFrame then
                if nameplate.UnitFrame.RaidTargetFrame.uberOriginalPoints then
                    nameplate.UnitFrame.RaidTargetFrame:ClearAllPoints()
                    for _, point in ipairs(nameplate.UnitFrame.RaidTargetFrame.uberOriginalPoints) do
                        nameplate.UnitFrame.RaidTargetFrame:SetPoint(unpack(point))
                    end
                    nameplate.UnitFrame.RaidTargetFrame.uberOriginalPoints = nil
                end
            end
            UberUI.nameplates:UpdateRaidTargetScale(nameplate.UnitFrame)
        end
    else
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

if CompactUnitFrame_UpdateAll then
    hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
        if frame and frame.unit and string.find(frame.unit, "nameplate") then
            UberUI.nameplates:UpdateRaidTargetScale(frame)
        end
    end)
end

if CompactUnitFrame_UpdateCenterStatusIcon then
    hooksecurefunc("CompactUnitFrame_UpdateCenterStatusIcon", function(frame)
        if frame and frame.unit and string.find(frame.unit, "nameplate") then
            UberUI.nameplates:UpdateRaidTargetScale(frame)
        end
    end)
end

UberUI.nameplates = nameplates
