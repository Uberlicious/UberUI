local addon, ns = ...
local misc = {}
local isLoaded = false

local misc = UberUI:CreateFrame("frame")
misc:RegisterEvent("ADDON_LOADED")
misc:RegisterEvent("PLAYER_ENTERING_WORLD")
misc:RegisterEvent("GROUP_ROSTER_UPDATE")
misc:RegisterEvent("RAID_ROSTER_UPDATE")
misc:RegisterEvent("PLAYER_LEAVE_COMBAT")
misc:RegisterEvent("PLAYER_FOCUS_CHANGED")
misc:RegisterEvent("NAME_PLATE_UNIT_ADDED")
misc:RegisterEvent("PLAYER_TARGET_CHANGED")
misc:SetScript("OnEvent", function(self, event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unitId = ...
        misc:NameplateTextureSpecific(unitId)
        misc:UpdateNameplateSize()
    elseif event == "PLAYER_ENTERING_WORLD" then
        isLoaded = true
        misc:EndCaps()
        misc:StatusTrackingBars()
    elseif event == "ADDON_LOADED" then
        misc:EndCaps()
        misc:StatusTrackingBars()
    end
end)

local function GetMaskTexture()
    if uuidb and uuidb.masks and uuidb.masks.cdm_mask then
        return uuidb.masks.cdm_mask
    end
    return [[Interface\AddOns\Uber UI\textures\statusbars\cdm_bar_mask.tga]]
end

local MASK_OPTS = {
    insetL = 0, -- left crop
    insetT = 0, -- top crop (raise top edge)
    insetR = 0, -- right crop (pull right edge inward more)
    insetB = 0, -- bottom crop
    shiftX = 0, -- whole mask shift on X
    shiftY = 0, -- whole mask shift on Y (raise mask slightly)
}

function misc:NameplateTextureSpecific(unitId)
    C_Timer.After(0, function()
        if not isLoaded then return end
        if not unitId then return end

        -- Note: C_NamePlate.GetNamePlateForUnit can be unreliable. If issues persist,
        -- iterating through C_NamePlate.GetNamePlates() is a more robust alternative.
        local nameplateFrame = C_NamePlate.GetNamePlateForUnit(unitId)
        if not (nameplateFrame and nameplateFrame.UnitFrame and nameplateFrame.UnitFrame.healthBar) then
            return
        end

        local healthBar = nameplateFrame.UnitFrame.healthBar
        local unitFrame = nameplateFrame.UnitFrame

        -- Main texture logic
        local textureToApply
        if uuidb.general.nameplatebartextures and uuidb.general.nameplatebartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.nameplatebartexture]
        elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.texture]
        end

        if textureToApply then
            healthBar:SetStatusBarTexture(textureToApply)

            -- MASKING LOGIC
            local opts = MASK_OPTS
            local L, T, R, B = opts.insetL or 0, opts.insetT or 0, opts.insetR or 0, opts.insetB or 0
            local SX, SY = opts.shiftX or 0, opts.shiftY or 0

            if not healthBar._uberMask then
                local m = healthBar:CreateMaskTexture(nil, "OVERLAY")
                m:SetTexture(GetMaskTexture(), "CLAMPTOBLACK", "CLAMPTOBLACK")
                if m.SetSnapToPixelGrid then m:SetSnapToPixelGrid(true) end
                if m.SetTexelSnappingBias then m:SetTexelSnappingBias(0) end
                if m.SetHorizTile then m:SetHorizTile(false) end
                if m.SetVertTile then m:SetVertTile(false) end
                healthBar._uberMask = m
            end
            local m = healthBar._uberMask

            m:ClearAllPoints()
            m:SetPoint("TOPLEFT", healthBar, "TOPLEFT", L + SX, -(T - SY))
            m:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -R + SX, B + SY)

            -- Apply the mask to the fill texture
            local fill = healthBar:GetStatusBarTexture()
            if fill and m and not fill._masked then
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
        healthBar.bgTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)

        if (uuidb.general.hidenameplateglow) then
            healthBar.selectedBorder:SetAlpha(0);
        else
            -- healthBar.selectedBorder:SetAlpha(.24);
        end
    end)
end

function misc:ForceNameplateTexture()
    local nameplates = C_NamePlate.GetNamePlates()
    for _, nameplateFrame in ipairs(nameplates) do
        misc:NameplateTextureSpecific(nameplateFrame.UnitFrame.unit)
    end
end

local originalNameplateWidth = nil
function misc:UpdateNameplateSize()
    local nameplates = C_NamePlate.GetNamePlates()

    for _, nameplateFrame in ipairs(nameplates) do
        if originalNameplateWidth == nil then
            originalNameplateWidth = nameplateFrame:GetWidth()
        end
        if nameplateFrame.UnitFrame.isFriend and not nameplateFrame:IsForbidden() and not InCombatLockdown() then
            if uuidb.general.smallfriendlynameplate then
                nameplateFrame:SetWidth(100)
            else
                nameplateFrame:SetWidth(230)
            end
        end
    end
end

local nthook = false
function misc:NameplateTexture()
    if nthook then return end
    -- hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
    --     print(frame:GetName())
    --     if not frame:IsForbidden() and frame.healthBar ~= nil and
    --         not
    --         (frame:GetName() ~= nil and (frame:GetName():find("CompactRaid") or frame:GetName():find("CompactParty"))) then
    --         -- Main texture logic
    --         local textureToApply
    --         if uuidb.general.nameplatebartextures then
    --             if uuidb.general.nameplatebartexture ~= "Blizzard" then
    --                 textureToApply = uuidb.statusbars[uuidb.general.nameplatebartexture]
    --             end
    --         elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
    --             textureToApply = uuidb.statusbars[uuidb.general.texture]
    --         end
    --         if textureToApply then
    --             frame.healthBar:SetStatusBarTexture(textureToApply);
    --             frame.healthBar:SetStatusBarDesaturated(true);
    --             ClassNameplateManaBarFrame:SetStatusBarTexture(textureToApply);
    --             ClassNameplateManaBarFrame:SetStatusBarDesaturated(true);
    --         end

    --         -- Secondary texture logic
    --         local secondaryTextureToApply
    --         if uuidb.general.secondarybartextures then
    --             if uuidb.general.secondarybartexture ~= "Blizzard" then
    --                 secondaryTextureToApply = uuidb.statusbars[uuidb.general.secondarybartexture]
    --             end
    --         else
    --             secondaryTextureToApply = textureToApply -- Fallback
    --         end

    --         if secondaryTextureToApply then
    --             frame.myHealPrediction:SetTexture(secondaryTextureToApply);
    --             frame.otherHealPrediction:SetTexture(secondaryTextureToApply);
    --             frame.totalAbsorb:SetTexture(secondaryTextureToApply);
    --             frame.totalAbsorb:SetVertexColor(.6, .9, .9, 1);
    --         end

    --         -- Other logic from original function
    --         local player = UnitIsUnit(frame.unit, "player");
    --         if (player and uuidb.general.ccpersonalresource) then
    --             local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))];
    --             frame.healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b);
    --         end
    --         if (uuidb.general.hidenameplateglow) then
    --             frame.selectionHighlight:SetAlpha(0);
    --         else
    --             frame.selectionHighlight:SetAlpha(.24);
    --         end
    --     end
    -- end)
    nthook = true
end

function misc:EndCaps()
    local dc = uuidb.general.darkencolor;
    MainActionBar.EndCaps.RightEndCap:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    MainActionBar.EndCaps.LeftEndCap:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
end

function misc:StatusTrackingBars()
    local dc = uuidb.general.darkencolor;
    MainStatusTrackingBarContainer.BarFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    SecondaryStatusTrackingBarContainer.BarFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
end

function misc:AllFramesColor()
    self:EndCaps();
    UberUI.playerframes:Color();
    UberUI.targetframes:Color();
    UberUI.focusframes:Color();
    UberUI.minimap:Color();
    UberUI.actionbars:Color();
    UberUI.cdManager:Color();
end

function misc:AllFramesHealthColor()
    UberUI.playerframes:HealthBarColor();
    UberUI.targetframes:HealthBarColor();
    UberUI.focusframes:HealthBarColor();
    UberUI.partyframes:HealthBarColor();
    UberUI.arenaframes:LoopFrames();
end

function misc:AllFramesHealthManaTexture()
    if UberUI.playerframes then UberUI.playerframes:HealthManaBarTexture() end
    if UberUI.targetframes then UberUI.targetframes:HealthManaBarTexture() end
    if UberUI.focusframes then UberUI.focusframes:HealthManaBarTexture() end
    if UberUI.partyframes then UberUI.partyframes:HealthManaBarTexture() end
    if UberUI.playerframes then UberUI.playerframes:ColorAlternatePower() end
    if UberUI.arenaframes then UberUI.arenaframes:LoopFrames() end
end

UberUI.misc = misc
