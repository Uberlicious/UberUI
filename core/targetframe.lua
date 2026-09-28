local addon, ns = ...

local UnitPowerType = UnitPowerType
local PowerBarColor = PowerBarColor

local function ApplyDarkenColor(region)
    local dc = uuidb.general.darkencolor
    region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
end

local aurakit = UberUI.aurakit

local targetframes = UberUI:CreateFrame("frame")
targetframes:RegisterEvent("ADDON_LOADED")
targetframes:RegisterEvent("PLAYER_LOGIN")
targetframes:RegisterEvent("PLAYER_ENTERING_WORLD")
targetframes:RegisterEvent("PLAYER_TARGET_CHANGED")
targetframes:RegisterEvent("PLAYER_FOCUS_CHANGED")
targetframes:RegisterEvent("PLAYER_REGEN_ENABLED")
targetframes:RegisterEvent("UNIT_TARGET")
targetframes:RegisterUnitEvent("UNIT_HEALTH", "target")
targetframes:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
targetframes:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target")
targetframes:RegisterUnitEvent("UNIT_POWER_UPDATE", "target")
targetframes:RegisterUnitEvent("UNIT_MAXPOWER", "target")
targetframes:RegisterUnitEvent("UNIT_AURA", "target")
targetframes:RegisterEvent("GROUP_ROSTER_UPDATE")
targetframes:RegisterEvent("PARTY_LEADER_CHANGED")
-- Cross-zone transitions can cause brief classification delay; re-check after delay.
targetframes:RegisterEvent("ZONE_CHANGED_NEW_AREA")
targetframes:RegisterEvent("ZONE_CHANGED")
targetframes:RegisterEvent("ZONE_CHANGED_INDOORS")
targetframes:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        targetframes:SetupCustomAuraContainer()
    end
    targetframes:Color()
    targetframes:HealthBarColor()
    targetframes:HealthManaBarTexture()
    targetframes:PvPIcon()
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        targetframes:UpdateAuras()
        C_Timer.After(0.05, function()
            targetframes:UpdateAuras()
            targetframes:HealthBarColor()
        end)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
        targetframes:UpdateAuraPositions()
    elseif event == "UNIT_AURA" then
        targetframes:UpdateAuras()
        C_Timer.After(0.05, function() targetframes:UpdateAuras() end)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        targetframes:UpdateAuras()
        C_Timer.After(1, function() targetframes:UpdateAuras() end)
        C_Timer.After(3, function() targetframes:UpdateAuras() end)
        C_Timer.After(5, function() targetframes:UpdateAuras() end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        targetframes:UpdateAuras()
    end
end)

local function GetTargetFrameMain()
    return TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
end

local function GetTargetFrameContextual()
    return TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual
end

function targetframes:Color()
    if TargetFrame.TargetFrameContainer then
        ApplyDarkenColor(TargetFrame.TargetFrameContainer.FrameTexture)
    elseif TargetFrameTextureFrameTexture then
        ApplyDarkenColor(TargetFrameTextureFrameTexture)
    end

    local main = GetTargetFrameMain()
    if main then
        if main.LevelTextFrame and main.LevelTextFrame.LevelBackgroundCircle then
            ApplyDarkenColor(main.LevelTextFrame.LevelBackgroundCircle)
        end
        if main.LevelBackground then
            ApplyDarkenColor(main.LevelBackground)
        end
        if main.LevelBackgroundCircle then
            ApplyDarkenColor(main.LevelBackgroundCircle)
        end
        if main.PvPBackgroundCircle then
            ApplyDarkenColor(main.PvPBackgroundCircle)
        end
        if main.ReputationColor then
            if uuidb.general.hiderepcolor then
                main.ReputationColor:Hide()
            else
                main.ReputationColor:Show()
            end
        end
    end

    if TargetFrame.LevelBackgroundCircle then
        ApplyDarkenColor(TargetFrame.LevelBackgroundCircle)
    end
    if TargetFrame.LevelBackground then
        ApplyDarkenColor(TargetFrame.LevelBackground)
    end
    if _G["TargetFrameLevelBackground"] then
        ApplyDarkenColor(_G["TargetFrameLevelBackground"])
    end

    if TargetFrameSpellBar and TargetFrameSpellBar.Border then
        ApplyDarkenColor(TargetFrameSpellBar.Border)
    end
    self:StyleCastBarIcon()

    if TargetFrameToT and TargetFrameToT.FrameTexture then
        ApplyDarkenColor(TargetFrameToT.FrameTexture)
    elseif TargetFrameToTTextureFrameTexture then
        ApplyDarkenColor(TargetFrameToTTextureFrameTexture)
    end

    self:ColorComboPoints()
end

-- WoW Forever combo points on ComboFrame (base diamond region).
function targetframes:ColorComboPoints()
    if not (ComboFrame and ComboFrame.ComboPoints) then return end
    for _, cp in ipairs(ComboFrame.ComboPoints) do
        for _, region in ipairs({ cp:GetRegions() }) do
            if region ~= cp.Highlight and region ~= cp.Shine and region.SetVertexColor then
                ApplyDarkenColor(region)
            end
        end
    end
end

function targetframes:HealthBarColor()
    local main = GetTargetFrameMain()
    local healthBar = (main and main.HealthBarsContainer.HealthBar) or TargetFrameHealthBar
    if healthBar then
        UberUI.general:SetHealthColor(healthBar, "target", uuidb.targetframes)
    end

    local totHealthBar = (TargetFrameToT and TargetFrameToT.HealthBar) or TargetFrameToTHealthBar
    if totHealthBar then
        UberUI.general:SetHealthColor(totHealthBar, "targettarget", uuidb.targetframes)
    end
end

function targetframes:HealthManaBarTexture()
    local main = GetTargetFrameMain()
    local healthBar = (main and main.HealthBarsContainer.HealthBar) or TargetFrameHealthBar
    local manaBar = (main and main.ManaBar) or TargetFrameManaBar

    local totHealthBar = (TargetFrameToT and TargetFrameToT.HealthBar) or TargetFrameToTHealthBar
    local totManaBar = (TargetFrameToT and TargetFrameToT.ManaBar) or TargetFrameToTManaBar

    local textureToApply
    if uuidb.general.targetbartextures then
        if uuidb.general.targetbartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.targetbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply then
        if healthBar then healthBar:SetStatusBarTexture(textureToApply) end
        if totHealthBar then totHealthBar:SetStatusBarTexture(textureToApply) end

        local targetPowerType = UnitPowerType("target")
        if (targetPowerType and targetPowerType < 4) and manaBar then
            manaBar:SetStatusBarTexture(textureToApply)
            local pc = PowerBarColor[targetPowerType]
            manaBar:SetStatusBarDesaturated(true)
            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b)
        end

        local totPowerType = UnitPowerType("targettarget")
        if (totPowerType and totPowerType < 4) and totManaBar then
            totManaBar:SetStatusBarTexture(textureToApply)
            local pc = PowerBarColor[totPowerType]
            totManaBar:SetStatusBarDesaturated(true)
            totManaBar:SetStatusBarColor(pc.r, pc.g, pc.b)
        end
    end
    local secondaryTextureToApply
    if uuidb.general.secondarybartextures then
        if uuidb.general.secondarybartexture ~= "Blizzard" then
            secondaryTextureToApply = uuidb.statusbars[uuidb.general.secondarybartexture]
        end
    else
        secondaryTextureToApply = textureToApply
    end

    if secondaryTextureToApply and healthBar then
        if healthBar.HealAbsorbBar and healthBar.HealAbsorbBar.Fill then
            healthBar.HealAbsorbBar.Fill:SetTexture(secondaryTextureToApply)
            if healthBar.HealAbsorbBar.fillColor then
                healthBar.HealAbsorbBar.Fill:SetVertexColor(healthBar.HealAbsorbBar.fillColor:GetRGBA())
            end
        end
        if healthBar.MyHealPredictionBar and healthBar.MyHealPredictionBar.Fill then
            healthBar.MyHealPredictionBar.Fill:SetTexture(secondaryTextureToApply)
            if healthBar.MyHealPredictionBar.fillColor then
                healthBar.MyHealPredictionBar.Fill:SetVertexColor(healthBar.MyHealPredictionBar.fillColor:GetRGBA())
            elseif CUF_MY_HEAL_PREDICTION_COLOR then
                healthBar.MyHealPredictionBar.Fill:SetVertexColor(CUF_MY_HEAL_PREDICTION_COLOR:GetRGBA())
            else
                healthBar.MyHealPredictionBar.Fill:SetVertexColor(11/255, 136/255, 105/255, 1)
            end
        end
        if healthBar.OtherHealPredictionBar and healthBar.OtherHealPredictionBar.Fill then
            healthBar.OtherHealPredictionBar.Fill:SetTexture(secondaryTextureToApply)
            if healthBar.OtherHealPredictionBar.fillColor then
                healthBar.OtherHealPredictionBar.Fill:SetVertexColor(healthBar.OtherHealPredictionBar.fillColor:GetRGBA())
            elseif CUF_OTHER_HEAL_PREDICTION_COLOR then
                healthBar.OtherHealPredictionBar.Fill:SetVertexColor(CUF_OTHER_HEAL_PREDICTION_COLOR:GetRGBA())
            else
                healthBar.OtherHealPredictionBar.Fill:SetVertexColor(21/255, 89/255, 72/255, 1)
            end
        end
        if healthBar.TotalAbsorbBar and healthBar.TotalAbsorbBar.Fill then
            healthBar.TotalAbsorbBar.Fill:SetTexture(secondaryTextureToApply)
            healthBar.TotalAbsorbBar.Fill:SetVertexColor(.7, .9, .9, 1)
        end
    end
end

local function IsEnemyTarget()
    if not UnitExists("target") then return false end
    if UnitIsUnit("player", "target") then return false end
    if UnitCanAttack("player", "target") then return true end
    return not UnitIsFriend("player", "target")
end

-- Target aura button styling.
function targetframes:UpdateAuraButtonStyle(button)
    if not button then return end
    local isBuff = button.isBuff
    local style = "both"
    if uuidb and uuidb.general then
        style = isBuff and (uuidb.general.aurastyle_targetbuffs or "both") or
        (uuidb.general.aurastyle_targetdebuffs or "zoom")
    end
    local showDispel = uuidb and uuidb.general and uuidb.general.targetbuffs_showdispel
    aurakit.ApplyAuraButtonStyle(button, { style = style, showDispel = showDispel, squareLoc = "target", stealableRing = true })
end

local TOP_X = 25
local TOP_Y = 26
local TOP_ON_TOP_X = 5
local LARGE_AURA_SIZE = 21
local SMALL_AURA_SIZE = 17
local AURA_SPACING = 3
local CONTAINER_GAP = 3

local isUpdatingAuras = false

-- Primary/secondary container anchor placement based on hostility.
function targetframes:UpdateAuraPositions()
    aurakit.UpdatePairedPositions({
        frameObj = self,
        refFrame = TargetFrame,
        isEnemyFn = IsEnemyTarget,
        buffsOnTop = TargetFrame and TargetFrame.buffsOnTop,
        topX = TOP_X,
        topY = TOP_Y,
        topOnTopX = TOP_ON_TOP_X,
        containerGap = CONTAINER_GAP,
    })
end

-- Cast bar icon border in this frame's aura border look.
function targetframes:StyleCastBarIcon()
    local bar = TargetFrame.spellbar or TargetFrameSpellBar
    if not bar then return end
    local enabled = not (uuidb and uuidb.general and uuidb.general.targetcastbariconborder == false)
    aurakit.StyleCastBarIcon(bar, "target", enabled)
end

function targetframes:UpdateAuras()
    if isUpdatingAuras then return end
    self:StyleCastBarIcon()
    isUpdatingAuras = true

    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local contextual = GetTargetFrameContextual()
    local blizzAuras = contextual and contextual.Auras

    if bothNone then
        aurakit.ShowAuraContainers(self, false)
        if blizzAuras then
            blizzAuras:SetAlpha(1)
            blizzAuras:EnableMouse(true)
        end
        isUpdatingAuras = false
        return
    end

    if not self.customDebuffs or not self.customBuffs then
        self:SetupCustomAuraContainer()
    end

    if blizzAuras then
        blizzAuras:SetAlpha(0)
        blizzAuras:EnableMouse(false)
    end

    if not self.customDebuffs or not self.customBuffs then
        isUpdatingAuras = false
        return
    end

    if not TargetFrame:IsShown() or not UnitExists("target") then
        aurakit.ShowAuraContainers(self, false)
        isUpdatingAuras = false
        return
    end

    aurakit.ShowAuraContainers(self, true)
    self:UpdateAuraPositions()

    local debuffCount = (styleDebuffs ~= "none") and 16 or 0
    local buffCount = (styleBuffs ~= "none") and 32 or 0
    local debuffMineCount = aurakit.GetSafeMineMaxFrameCount("target", true, debuffCount)
    local buffMineCount = aurakit.GetSafeMineMaxFrameCount("target", false, buffCount)
    pcall(self.customDebuffs.SetAuraGroupMaxFrameCount, self.customDebuffs, "debuffs_mine", debuffMineCount)
    pcall(self.customDebuffs.SetAuraGroupMaxFrameCount, self.customDebuffs, "debuffs_other", debuffCount)
    pcall(self.customBuffs.SetAuraGroupMaxFrameCount, self.customBuffs, "buffs_mine", buffMineCount)
    pcall(self.customBuffs.SetAuraGroupMaxFrameCount, self.customBuffs, "buffs_other", buffCount)

    pcall(self.customDebuffs.UpdateAllAuras, self.customDebuffs)
    pcall(self.customBuffs.UpdateAllAuras, self.customBuffs)

    aurakit.RefreshContainerButtons(self.customDebuffs, "debuffs_mine", "debuffs_other", function(btn) targetframes:UpdateAuraButtonStyle(btn) end)
    aurakit.RefreshContainerButtons(self.customBuffs, "buffs_mine", "buffs_other", function(btn) targetframes:UpdateAuraButtonStyle(btn) end)

    aurakit.UpdateSpellbar(TargetFrame, aurakit.GetAuraContainers(self))

    isUpdatingAuras = false
end

function targetframes:ForceZoom()
    self:UpdateAuras()
end

function targetframes:SetupCustomAuraContainer()
    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local contextual = GetTargetFrameContextual()
    local blizzAuras = contextual and contextual.Auras

    if bothNone then
        aurakit.ShowAuraContainers(self, false)
        if blizzAuras then
            blizzAuras:SetAlpha(1)
            blizzAuras:EnableMouse(true)
        end
        return
    end

    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        if C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        else
            return
        end
    end

    if not TargetFrame or not blizzAuras then return end

    blizzAuras:SetAlpha(0)
    blizzAuras:EnableMouse(false)

    local updateStyleFn = function(btn) targetframes:UpdateAuraButtonStyle(btn) end

    if not self.customDebuffs then
        self.customDebuffs = aurakit.BuildAuraContainer({
            namePrefix = "UberUI_TargetDebuffs",
            parentFrame = TargetFrame,
            unitToken = "target",
            mineKey = "debuffs_mine",
            otherKey = "debuffs_other",
            mineFilter = "HARMFUL|PLAYER",
            otherFilter = "HARMFUL|!PLAYER",
            frameLevelBonus = 20,
            exactLineSpacing = true, -- Blizzard's 3px rows
            largeSize = LARGE_AURA_SIZE,
            smallSize = SMALL_AURA_SIZE,
            spacing = AURA_SPACING,
            updateStyleFn = updateStyleFn,
            isUpdating = function() return isUpdatingAuras end,
            clearUpdating = function() isUpdatingAuras = false end,
            onApplyLayout = function()
                targetframes:UpdateAuraPositions()
                aurakit.UpdateSpellbar(TargetFrame, aurakit.GetAuraContainers(targetframes))
            end,
        })
    end
    if not self.customBuffs then
        self.customBuffs = aurakit.BuildAuraContainer({
            namePrefix = "UberUI_TargetBuffs",
            parentFrame = TargetFrame,
            unitToken = "target",
            mineKey = "buffs_mine",
            otherKey = "buffs_other",
            mineFilter = "HELPFUL|PLAYER",
            otherFilter = "HELPFUL|!PLAYER",
            frameLevelBonus = 20,
            exactLineSpacing = true, -- Blizzard's 3px rows
            largeSize = LARGE_AURA_SIZE,
            smallSize = SMALL_AURA_SIZE,
            spacing = AURA_SPACING,
            updateStyleFn = updateStyleFn,
            isUpdating = function() return isUpdatingAuras end,
            clearUpdating = function() isUpdatingAuras = false end,
            onApplyLayout = function()
                targetframes:UpdateAuraPositions()
                aurakit.UpdateSpellbar(TargetFrame, aurakit.GetAuraContainers(targetframes))
            end,
        })
    end

    if self.customDebuffs and self.customBuffs then
        targetframes:UpdateAuraPositions()
    end

    aurakit.HookSpellbarAdjustPosition(TargetFrame.spellbar or TargetFrameSpellBar, TargetFrame,
        function() return aurakit.GetAuraContainers(targetframes) end)

    aurakit.ShowAuraContainers(self, TargetFrame:IsShown())

    if not self.targetFrameHooked then
        self.targetFrameHooked = true
        TargetFrame:HookScript("OnShow", function()
            aurakit.ShowAuraContainers(targetframes, true)
            if targetframes.customDebuffs then targetframes.customDebuffs:UpdateAllAuras() end
            if targetframes.customBuffs then targetframes.customBuffs:UpdateAllAuras() end
            targetframes:UpdateAuras()
        end)
        TargetFrame:HookScript("OnHide", function()
            aurakit.ShowAuraContainers(targetframes, false)
        end)
    end
    -- ToT show/hide updates aura row width.
    if not self.totFrameHooked and TargetFrame.totFrame then
        self.totFrameHooked = true
        local function RefreshToTWidth() targetframes:UpdateAuraPositions() end
        TargetFrame.totFrame:HookScript("OnShow", RefreshToTWidth)
        TargetFrame.totFrame:HookScript("OnHide", RefreshToTWidth)
    end

    self:ApplyToTPlacement()
end

-- Target of Target placement option.
function targetframes:ApplyToTPlacement()
    local aside = uuidb and uuidb.targetframes and uuidb.targetframes.totplacement == "aside"
    aurakit.SetToTPlacement(TargetFrame, aside)
    if self.customDebuffs and self.customBuffs then self:UpdateAuraPositions() end
end

targetframes:SetupCustomAuraContainer()

if TargetFrame and TargetFrame.UpdateAuras then
    hooksecurefunc(TargetFrame, "UpdateAuras", function(self)
        if targetframes and targetframes.UpdateAuras then
            targetframes:UpdateAuras()
        end
    end)
end

if TargetFrame and TargetFrame.CheckPartyLeader then
    hooksecurefunc(TargetFrame, "CheckPartyLeader", function(self)
        if targetframes and targetframes.UpdateAuraPositions then
            targetframes:UpdateAuraPositions()
        end
    end)
end

if TargetFrame_UpdateAuras then
    hooksecurefunc("TargetFrame_UpdateAuras", function(self)
        if targetframes and targetframes.UpdateAuras then
            targetframes:UpdateAuras()
        end
    end)
end

if TargetFrame then
    if TargetFrame.CheckFaction then
        hooksecurefunc(TargetFrame, "CheckFaction", function(self)
            if targetframes and targetframes.HealthBarColor then
                targetframes:HealthBarColor()
            end
        end)
    end
    if TargetFrame.Update then
        hooksecurefunc(TargetFrame, "Update", function(self)
            if targetframes then
                targetframes:HealthBarColor()
                targetframes:HealthManaBarTexture()
            end
        end)
    end
    if TargetFrame.CreateSpellbar then
        hooksecurefunc(TargetFrame, "CreateSpellbar", function(self)
            aurakit.HookSpellbarAdjustPosition(self.spellbar or TargetFrameSpellBar, TargetFrame,
                function() return aurakit.GetAuraContainers(targetframes) end)
        end)
    end
    if TargetFrame.totFrame then
        TargetFrame.totFrame:HookScript("OnShow", function()
            if targetframes and targetframes.UpdateAuras then
                targetframes:UpdateAuras()
            end
        end)
        TargetFrame.totFrame:HookScript("OnHide", function()
            if targetframes and targetframes.UpdateAuras then
                targetframes:UpdateAuras()
            end
        end)
    end
end

hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
    if statusbar and (unit == "target" or unit == "targettarget") and targetframes and targetframes.HealthBarColor then
        targetframes:HealthBarColor()
    end
end)

function targetframes:PvPIcon()
    local contextual = GetTargetFrameContextual()
    if contextual then
        UberUI.general:PvPIcon(contextual)
    elseif TargetFrameTextureFramePVPIcon then
        UberUI.general:PvPIcon(TargetFrameTextureFramePVPIcon)
    end
end

UberUI.targetframes = targetframes
