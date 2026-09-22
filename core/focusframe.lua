local addon, ns = ...

-- Cache frequently accessed globals for performance
local UnitPowerType = UnitPowerType
local PowerBarColor = PowerBarColor

-- Helper function for applying darken color
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
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Force a correctness pass once combat lockdown lifts, in case any
        -- styling was skipped or failed while we were in combat.
        focusframes:UpdateAuras()
    end
end)

-- Shared lookups for the frequently-nested Blizzard focus frame paths.
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
        if healthBar.HealAbsorbBar then healthBar.HealAbsorbBar.Fill:SetTexture(secondaryTextureToApply) end
        if healthBar.MyHealPredictionBar then healthBar.MyHealPredictionBar.Fill:SetTexture(secondaryTextureToApply) end
        if healthBar.OtherHealPredictionBar then healthBar.OtherHealPredictionBar.Fill:SetTexture(secondaryTextureToApply) end
        if healthBar.TotalAbsorbBar then
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

-- Thin per-frame wrapper: resolves this frame's uuidb style/showDispel
-- settings, then hands off to the shared aurakit.ApplyAuraButtonStyle (see
-- core/aurakit.lua, shared with targetframe.lua).
function focusframes:UpdateAuraButtonStyle(button)
    if not button then return end
    local isBuff = button.isBuff
    local style = "both"
    if uuidb and uuidb.general then
        style = isBuff and (uuidb.general.aurastyle_focusbuffs or "both") or
        (uuidb.general.aurastyle_focusdebuffs or "zoom")
    end
    local showDispel = uuidb and uuidb.general and uuidb.general.focusbuffs_showdispel
    aurakit.ApplyAuraButtonStyle(button, { style = style, showDispel = showDispel })
end

local FOCUS_TOP_X = 25
local FOCUS_TOP_Y = 26
local FOCUS_TOP_ON_TOP_X = 5
local FOCUS_LARGE_AURA_SIZE = 17
local FOCUS_SMALL_AURA_SIZE = 13
local FOCUS_AURA_SPACING = 3
local FOCUS_CONTAINER_GAP = 2

local isUpdatingAuras = false

-- Mirrors targetframe.lua's UpdateAuraPositions (see aurakit.UpdatePairedPositions
-- for the shared anchor math) with one difference: stock Blizzard disables
-- buffsOnTop repositioning entirely while the focus frame is in its small/
-- compact form (FocusFrameMixin:SetSmallSize sets maxBuffs=0 -- there's
-- nothing to put "on top" -- see UpdateAuras below for the matching buff
-- count override).
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

function focusframes:UpdateAuras()
    if isUpdatingAuras then return end
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

    -- Group identity/container are permanent (see SetupCustomAuraContainer);
    -- hostility is handled entirely in UpdateAuraPositions above. Small/
    -- compact focus frames never show buffs at all (stock Blizzard: see
    -- FocusFrameMixin:SetSmallSize's maxBuffs=0) -- the one place focus
    -- deviates from target's aura logic.
    local debuffCount = (styleDebuffs ~= "none") and 16 or 0
    local buffCount = (styleBuffs ~= "none") and 32 or 0
    if FocusFrame and FocusFrame.smallSize then
        buffCount = 0
    end
    pcall(self.customDebuffs.SetAuraGroupMaxFrameCount, self.customDebuffs, "debuffs_mine", debuffCount)
    pcall(self.customDebuffs.SetAuraGroupMaxFrameCount, self.customDebuffs, "debuffs_other", debuffCount)
    pcall(self.customBuffs.SetAuraGroupMaxFrameCount, self.customBuffs, "buffs_mine", buffCount)
    pcall(self.customBuffs.SetAuraGroupMaxFrameCount, self.customBuffs, "buffs_other", buffCount)

    pcall(self.customDebuffs.UpdateAllAuras, self.customDebuffs)
    pcall(self.customBuffs.UpdateAllAuras, self.customBuffs)

    -- Force a final button style pass.
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

    -- Blizzard's own FocusFrame re-shows its native aura container more
    -- aggressively than TargetFrame's -- re-hide it whenever our own style
    -- is active.
    if not self.blizzHooked then
        self.blizzHooked = true
        hooksecurefunc(blizzAuras, "Show", function(self)
            local sBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusbuffs) or "both"
            local sDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusdebuffs) or "zoom"
            if sBuffs ~= "none" or sDebuffs ~= "none" then
                self:Hide()
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
            largeSize = FOCUS_LARGE_AURA_SIZE,
            smallSize = FOCUS_SMALL_AURA_SIZE,
            spacing = FOCUS_AURA_SPACING,
            updateStyleFn = updateStyleFn,
            isUpdating = function() return isUpdatingAuras end,
            clearUpdating = function() isUpdatingAuras = false end,
            onApplyLayout = function() aurakit.UpdateSpellbar(FocusFrame, aurakit.GetAuraContainers(focusframes)) end,
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
            largeSize = FOCUS_LARGE_AURA_SIZE,
            smallSize = FOCUS_SMALL_AURA_SIZE,
            spacing = FOCUS_AURA_SPACING,
            updateStyleFn = updateStyleFn,
            isUpdating = function() return isUpdatingAuras end,
            clearUpdating = function() isUpdatingAuras = false end,
            onApplyLayout = function() aurakit.UpdateSpellbar(FocusFrame, aurakit.GetAuraContainers(focusframes)) end,
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
end

-- Initialize immediately if FocusFrame is already present
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
