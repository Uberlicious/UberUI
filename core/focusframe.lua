local addon, ns = ...

local UnitPowerType = UnitPowerType
local PowerBarColor = PowerBarColor

local function ApplyDarkenColor(region)
    local dc = uuidb.general.darkencolor
    region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
end

local aurakit = UberUI.aurakit

local focusframes = UberUI:CreateFrame("frame")
focusframes:RegisterEvent("ADDON_LOADED")
focusframes:RegisterEvent("PLAYER_LOGIN")
focusframes:RegisterEvent("PLAYER_ENTERING_WORLD")
focusframes:RegisterEvent("PLAYER_TARGET_CHANGED")
focusframes:RegisterEvent("PLAYER_FOCUS_CHANGED")
focusframes:RegisterEvent("PLAYER_REGEN_ENABLED")
focusframes:RegisterEvent("UNIT_TARGET")
focusframes:RegisterUnitEvent("UNIT_HEALTH", "focus")
focusframes:RegisterUnitEvent("UNIT_MAXHEALTH", "focus")
focusframes:RegisterUnitEvent("UNIT_DISPLAYPOWER", "focus")
focusframes:RegisterUnitEvent("UNIT_POWER_UPDATE", "focus")
focusframes:RegisterUnitEvent("UNIT_MAXPOWER", "focus")
focusframes:RegisterUnitEvent("UNIT_AURA", "focus")
focusframes:RegisterEvent("GROUP_ROSTER_UPDATE")
focusframes:RegisterEvent("PARTY_LEADER_CHANGED")
-- Cross-zone transitions can cause brief classification delay; re-check after delay.
focusframes:RegisterEvent("ZONE_CHANGED_NEW_AREA")
focusframes:RegisterEvent("ZONE_CHANGED")
focusframes:RegisterEvent("ZONE_CHANGED_INDOORS")
focusframes:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        focusframes:SetupCustomAuraContainer()
    end
    focusframes:Color()
    focusframes:HealthBarColor()
    focusframes:HealthManaBarTexture()
    focusframes:PvPIcon()
    if event == "PLAYER_FOCUS_CHANGED" then
        focusframes:UpdateAuras()
        C_Timer.After(0.05, function()
            focusframes:UpdateAuras()
            focusframes:HealthBarColor()
        end)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
        focusframes:UpdateAuraPositions()
    elseif event == "UNIT_AURA" then
        focusframes:UpdateAuras()
        C_Timer.After(0.05, function() focusframes:UpdateAuras() end)
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        focusframes:UpdateAuras()
        C_Timer.After(1, function() focusframes:UpdateAuras() end)
        C_Timer.After(3, function() focusframes:UpdateAuras() end)
        C_Timer.After(5, function() focusframes:UpdateAuras() end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        focusframes:UpdateAuras()
    end
end)

local function GetFocusFrameMain()
    return FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain
end

local function GetFocusFrameContextual()
    return FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual
end

function focusframes:Color()
    if not FocusFrame then return end
    if FocusFrame.TargetFrameContainer then
        ApplyDarkenColor(FocusFrame.TargetFrameContainer.FrameTexture)
    elseif FocusFrameTextureFrameTexture then
        ApplyDarkenColor(FocusFrameTextureFrameTexture)
    end

    local main = GetFocusFrameMain()
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

    if FocusFrame.LevelBackgroundCircle then
        ApplyDarkenColor(FocusFrame.LevelBackgroundCircle)
    end
    if FocusFrame.LevelBackground then
        ApplyDarkenColor(FocusFrame.LevelBackground)
    end
    if _G["FocusFrameLevelBackground"] then
        ApplyDarkenColor(_G["FocusFrameLevelBackground"])
    end

    if FocusFrameSpellBar and FocusFrameSpellBar.Border then
        ApplyDarkenColor(FocusFrameSpellBar.Border)
    end
    self:StyleCastBarIcon()

    if FocusFrameToT and FocusFrameToT.FrameTexture then
        ApplyDarkenColor(FocusFrameToT.FrameTexture)
    elseif FocusFrameToTTextureFrameTexture then
        ApplyDarkenColor(FocusFrameToTTextureFrameTexture)
    end
end

function focusframes:HealthBarColor()
    if not FocusFrame then return end
    local main = GetFocusFrameMain()
    local healthBar = (main and main.HealthBarsContainer.HealthBar) or FocusFrameHealthBar
    if healthBar then
        UberUI.general:SetHealthColor(healthBar, "focus", uuidb.focusframes)
    end

    local totHealthBar = (FocusFrameToT and FocusFrameToT.HealthBar) or FocusFrameToTHealthBar
    if totHealthBar then
        UberUI.general:SetHealthColor(totHealthBar, "focustarget", uuidb.focusframes)
    end
end

function focusframes:HealthManaBarTexture()
    if not FocusFrame then return end
    local main = GetFocusFrameMain()
    local healthBar = (main and main.HealthBarsContainer.HealthBar) or FocusFrameHealthBar
    local manaBar = (main and main.ManaBar) or FocusFrameManaBar

    local totHealthBar = (FocusFrameToT and FocusFrameToT.HealthBar) or FocusFrameToTHealthBar
    local totManaBar = (FocusFrameToT and FocusFrameToT.ManaBar) or FocusFrameToTManaBar

    local textureToApply
    if uuidb.general.focusbartextures then
        if uuidb.general.focusbartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.focusbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply then
        if healthBar then healthBar:SetStatusBarTexture(textureToApply) end
        if totHealthBar then totHealthBar:SetStatusBarTexture(textureToApply) end

        local focusPowerType = UnitPowerType("focus")
        if (focusPowerType and focusPowerType < 4) and manaBar then
            manaBar:SetStatusBarTexture(textureToApply)
            local pc = PowerBarColor[focusPowerType]
            manaBar:SetStatusBarDesaturated(true)
            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b)
        end

        local focusTotPowerType = UnitPowerType("focustarget")
        if (focusTotPowerType and focusTotPowerType < 4) and totManaBar then
            totManaBar:SetStatusBarTexture(textureToApply)
            local pc = PowerBarColor[focusTotPowerType]
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

local function IsEnemyFocus()
    if not UnitExists("focus") then return false end
    if UnitIsUnit("player", "focus") then return false end
    if UnitCanAttack("player", "focus") then return true end
    return not UnitIsFriend("player", "focus")
end

-- Resolves this frame's style settings for aurakit.ApplyAuraButtonStyle.
function focusframes:UpdateAuraButtonStyle(button)
    if not button then return end
    local isBuff = button.isBuff
    local style = "both"
    if uuidb and uuidb.general then
        style = isBuff and (uuidb.general.aurastyle_focusbuffs or "both") or
        (uuidb.general.aurastyle_focusdebuffs or "zoom")
    end
    local showDispel = uuidb and uuidb.general and uuidb.general.focusbuffs_showdispel
    aurakit.ApplyAuraButtonStyle(button, { style = style, showDispel = showDispel, squareLoc = "focus" })
end

local FOCUS_TOP_X = 25
local FOCUS_TOP_Y = 26
local FOCUS_TOP_ON_TOP_X = 5
local FOCUS_LARGE_AURA_SIZE = 21
local FOCUS_SMALL_AURA_SIZE = 17
local FOCUS_AURA_SPACING = 3
local FOCUS_CONTAINER_GAP = 3

local isUpdatingAuras = false

-- Primary/secondary container anchor placement based on hostility.
function focusframes:UpdateAuraPositions()
    aurakit.UpdatePairedPositions({
        frameObj = self,
        refFrame = FocusFrame,
        isEnemyFn = IsEnemyFocus,
        buffsOnTop = FocusFrame and FocusFrame.buffsOnTop and (not FocusFrame.smallSize),
        topX = FOCUS_TOP_X,
        topY = FOCUS_TOP_Y,
        topOnTopX = FOCUS_TOP_ON_TOP_X,
        containerGap = FOCUS_CONTAINER_GAP,
    })
end

-- Cast bar icon border in this frame's aura border look.
function focusframes:StyleCastBarIcon()
    local bar = FocusFrame.spellbar or FocusFrameSpellBar
    if not bar then return end
    local enabled = not (uuidb and uuidb.general and uuidb.general.focuscastbariconborder == false)
    aurakit.StyleCastBarIcon(bar, "focus", enabled)
end

function focusframes:UpdateAuras()
    if isUpdatingAuras then return end
    self:StyleCastBarIcon()
    isUpdatingAuras = true

    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local contextual = GetFocusFrameContextual()
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

    if not FocusFrame:IsShown() or not UnitExists("focus") then
        aurakit.ShowAuraContainers(self, false)
        isUpdatingAuras = false
        return
    end

    aurakit.ShowAuraContainers(self, true)
    self:UpdateAuraPositions()

    local debuffCount = (styleDebuffs ~= "none") and 16 or 0
    local buffCount = (styleBuffs ~= "none") and 32 or 0
    if FocusFrame and FocusFrame.smallSize then
        buffCount = 0
    end
    local debuffMineCount = aurakit.GetSafeMineMaxFrameCount("focus", true, debuffCount)
    local buffMineCount = aurakit.GetSafeMineMaxFrameCount("focus", false, buffCount)
    pcall(self.customDebuffs.SetAuraGroupMaxFrameCount, self.customDebuffs, "debuffs_mine", debuffMineCount)
    pcall(self.customDebuffs.SetAuraGroupMaxFrameCount, self.customDebuffs, "debuffs_other", debuffCount)
    pcall(self.customBuffs.SetAuraGroupMaxFrameCount, self.customBuffs, "buffs_mine", buffMineCount)
    pcall(self.customBuffs.SetAuraGroupMaxFrameCount, self.customBuffs, "buffs_other", buffCount)

    pcall(self.customDebuffs.UpdateAllAuras, self.customDebuffs)
    pcall(self.customBuffs.UpdateAllAuras, self.customBuffs)

    aurakit.RefreshContainerButtons(self.customDebuffs, "debuffs_mine", "debuffs_other", function(btn) focusframes:UpdateAuraButtonStyle(btn) end)
    aurakit.RefreshContainerButtons(self.customBuffs, "buffs_mine", "buffs_other", function(btn) focusframes:UpdateAuraButtonStyle(btn) end)

    aurakit.UpdateSpellbar(FocusFrame, aurakit.GetAuraContainers(self))

    isUpdatingAuras = false
end

function focusframes:ForceZoom()
    self:UpdateAuras()
end

function focusframes:SetupCustomAuraContainer()
    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local contextual = GetFocusFrameContextual()
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

    if not FocusFrame or not blizzAuras then return end

    blizzAuras:SetAlpha(0)
    blizzAuras:EnableMouse(false)

    -- Blizzard re-shows its native aura container often: keep it invisible by
    -- alpha, never Hide(), since its cast bar positions itself from it.
    blizzAuras:EnableMouse(false)
    if not self.blizzHooked then
        self.blizzHooked = true
        hooksecurefunc(blizzAuras, "Show", function(self)
            local sBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusbuffs) or "both"
            local sDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusdebuffs) or "zoom"
            if sBuffs ~= "none" or sDebuffs ~= "none" then
                self:SetAlpha(0)
            end
        end)
    end

    local updateStyleFn = function(btn) focusframes:UpdateAuraButtonStyle(btn) end

    if not self.customDebuffs then
        self.customDebuffs = aurakit.BuildAuraContainer({
            namePrefix = "UberUI_FocusDebuffs",
            parentFrame = FocusFrame,
            unitToken = "focus",
            mineKey = "debuffs_mine",
            otherKey = "debuffs_other",
            mineFilter = "HARMFUL|PLAYER",
            otherFilter = "HARMFUL|!PLAYER",
            frameLevelBonus = 20,
            exactLineSpacing = true, -- Blizzard's 3px rows
            largeSize = FOCUS_LARGE_AURA_SIZE,
            smallSize = FOCUS_SMALL_AURA_SIZE,
            spacing = FOCUS_AURA_SPACING,
            updateStyleFn = updateStyleFn,
            isUpdating = function() return isUpdatingAuras end,
            clearUpdating = function() isUpdatingAuras = false end,
            onApplyLayout = function()
                focusframes:UpdateAuraPositions()
                aurakit.UpdateSpellbar(FocusFrame, aurakit.GetAuraContainers(focusframes))
            end,
        })
    end
    if not self.customBuffs then
        self.customBuffs = aurakit.BuildAuraContainer({
            namePrefix = "UberUI_FocusBuffs",
            parentFrame = FocusFrame,
            unitToken = "focus",
            mineKey = "buffs_mine",
            otherKey = "buffs_other",
            mineFilter = "HELPFUL|PLAYER",
            otherFilter = "HELPFUL|!PLAYER",
            frameLevelBonus = 20,
            exactLineSpacing = true, -- Blizzard's 3px rows
            largeSize = FOCUS_LARGE_AURA_SIZE,
            smallSize = FOCUS_SMALL_AURA_SIZE,
            spacing = FOCUS_AURA_SPACING,
            updateStyleFn = updateStyleFn,
            isUpdating = function() return isUpdatingAuras end,
            clearUpdating = function() isUpdatingAuras = false end,
            onApplyLayout = function()
                focusframes:UpdateAuraPositions()
                aurakit.UpdateSpellbar(FocusFrame, aurakit.GetAuraContainers(focusframes))
            end,
        })
    end

    if self.customDebuffs and self.customBuffs then
        focusframes:UpdateAuraPositions()
    end

    aurakit.HookSpellbarAdjustPosition(FocusFrame.spellbar or FocusFrameSpellBar, FocusFrame,
        function() return aurakit.GetAuraContainers(focusframes) end)

    aurakit.ShowAuraContainers(self, FocusFrame:IsShown())

    if not self.focusFrameHooked then
        self.focusFrameHooked = true
        FocusFrame:HookScript("OnShow", function()
            aurakit.ShowAuraContainers(focusframes, true)
            if focusframes.customDebuffs then focusframes.customDebuffs:UpdateAllAuras() end
            if focusframes.customBuffs then focusframes.customBuffs:UpdateAllAuras() end
            focusframes:UpdateAuras()
        end)
        FocusFrame:HookScript("OnHide", function()
            aurakit.ShowAuraContainers(focusframes, false)
        end)
    end
    -- ToT show/hide changes the aura row width.
    if not self.totFrameHooked and FocusFrame.totFrame then
        self.totFrameHooked = true
        local function RefreshToTWidth() focusframes:UpdateAuraPositions() end
        FocusFrame.totFrame:HookScript("OnShow", RefreshToTWidth)
        FocusFrame.totFrame:HookScript("OnHide", RefreshToTWidth)
    end

    self:ApplyToTPlacement()
end

-- Focus Target of Target placement option.
local focusSmallSizeHooked = false
function focusframes:ApplyToTPlacement()
    local aside = uuidb and uuidb.focusframes and uuidb.focusframes.totplacement == "aside"
    if aside and not focusSmallSizeHooked and FocusFrame and FocusFrame.SetSmallSize then
        focusSmallSizeHooked = true
        hooksecurefunc(FocusFrame, "SetSmallSize", function()
            C_Timer.After(0, function()
                aurakit.RecaptureToTAnchor(FocusFrame)
                if focusframes.customDebuffs and focusframes.customBuffs then
                    focusframes:UpdateAuraPositions()
                end
            end)
        end)
    end
    aurakit.SetToTPlacement(FocusFrame, aside)
    if self.customDebuffs and self.customBuffs then self:UpdateAuraPositions() end
end

focusframes:SetupCustomAuraContainer()

if FocusFrame and FocusFrame.UpdateAuras then
    hooksecurefunc(FocusFrame, "UpdateAuras", function(self)
        if focusframes and focusframes.UpdateAuras then
            focusframes:UpdateAuras()
        end
    end)
end

if FocusFrame and FocusFrame.CheckPartyLeader then
    hooksecurefunc(FocusFrame, "CheckPartyLeader", function(self)
        if focusframes and focusframes.UpdateAuraPositions then
            focusframes:UpdateAuraPositions()
        end
    end)
end

if FocusFrame and FocusFrame.SetSmallSize then
    hooksecurefunc(FocusFrame, "SetSmallSize", function(self)
        if focusframes and focusframes.UpdateAuras then
            focusframes:UpdateAuras()
        end
    end)
end

if FocusFrame_UpdateAuras then
    hooksecurefunc("FocusFrame_UpdateAuras", function(self)
        if focusframes and focusframes.UpdateAuras then
            focusframes:UpdateAuras()
        end
    end)
end

do
    local focusAuras = FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual and
    FocusFrame.TargetFrameContent.TargetFrameContentContextual.Auras
    if focusAuras then
        if focusAuras.ApplyLayout then
            hooksecurefunc(focusAuras, "ApplyLayout", function(self)
                if focusframes and focusframes.UpdateAuras then
                    focusframes:UpdateAuras()
                end
            end)
        end
        if focusAuras.UpdateAllAuras then
            hooksecurefunc(focusAuras, "UpdateAllAuras", function(self)
                if focusframes and focusframes.UpdateAuras then
                    focusframes:UpdateAuras()
                end
            end)
        end
    end
end

if FocusFrame then
    if FocusFrame.CheckFaction then
        hooksecurefunc(FocusFrame, "CheckFaction", function(self)
            if focusframes and focusframes.HealthBarColor then
                focusframes:HealthBarColor()
            end
        end)
    end
    if FocusFrame.CreateSpellbar then
        hooksecurefunc(FocusFrame, "CreateSpellbar", function(self)
            aurakit.HookSpellbarAdjustPosition(self.spellbar or FocusFrameSpellBar, FocusFrame,
                function() return aurakit.GetAuraContainers(focusframes) end)
        end)
    end
    if FocusFrame.totFrame then
        FocusFrame.totFrame:HookScript("OnShow", function()
            if focusframes and focusframes.UpdateAuras then
                focusframes:UpdateAuras()
            end
        end)
        FocusFrame.totFrame:HookScript("OnHide", function()
            if focusframes and focusframes.UpdateAuras then
                focusframes:UpdateAuras()
            end
        end)
    end
end

function focusframes:PvPIcon()
    local contextual = GetFocusFrameContextual()
    if contextual then
        UberUI.general:PvPIcon(contextual)
    elseif FocusFrameTextureFramePVPIcon then
        UberUI.general:PvPIcon(FocusFrameTextureFramePVPIcon)
    end
end

UberUI.focusframes = focusframes
