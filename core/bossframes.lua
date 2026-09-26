local addon, ns = ...

-- Boss frames (Boss1TargetFrame..Boss5TargetFrame) inherit the FULL
-- TargetFrameTemplate (BossTargetFrameMixin adds a thin layer on top for the
-- portraitless small layout -- see Blizzard_UnitFrame/Mainline/TargetFrame.lua,
-- BossTargetFrameMixin:OnLoad), so this file mirrors targetframe.lua/
-- focusframe.lua's approach exactly, just looped over 5 statically-declared
-- frames (Boss1TargetFrame.."Boss5TargetFrame" are named XML children of
-- BossTargetFrameContainer, id=1..5 -- always present once Blizzard_UnitFrame
-- loads, not a pool, unlike nameplates -- so no attach/detach lifecycle is
-- needed here).
--
-- Confirmed via BossTargetFrameMixin:OnLoad: unit token is "boss"..id, and
-- self.TargetFrameContent.TargetFrameContentMain / .TargetFrameContentContextual
-- / self.TargetFrameContainer all exist exactly as on Target/Focus, just
-- resized/repositioned for the small portraitless layout.

local UnitPowerType = UnitPowerType
local PowerBarColor = PowerBarColor
local aurakit = UberUI.aurakit

local function ApplyDarkenColor(region)
    local dc = uuidb.general.darkencolor
    region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
end

local MAX_BOSS_FRAMES = 5
local BOSS_TOP_X = 25
local BOSS_TOP_Y = 26
local BOSS_TOP_ON_TOP_X = 5
local BOSS_LARGE_AURA_SIZE = 15
local BOSS_SMALL_AURA_SIZE = 11
local BOSS_AURA_SPACING = 2
local BOSS_CONTAINER_GAP = 2

local bossframes = UberUI:CreateFrame("frame")

-- Per-slot state (customDebuffs/customBuffs/isUpdatingAuras/hook flags),
-- keyed 1..5 -- these live on OUR OWN table, never written onto the Blizzard
-- Boss{i}TargetFrame objects themselves (same taint-avoidance rule as every
-- other frame module in this addon).
local slots = {}
for i = 1, MAX_BOSS_FRAMES do
    slots[i] = { unit = "boss" .. i, isUpdatingAuras = false }
end

local function GetSlotFrame(i)
    return _G["Boss" .. i .. "TargetFrame"]
end

local function GetBossFrameMain(frame)
    return frame and frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentMain
end

local function GetBossFrameContextual(frame)
    return frame and frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentContextual
end

function bossframes:Color()
    for i = 1, MAX_BOSS_FRAMES do
        local frame = GetSlotFrame(i)
        if frame then
            if frame.TargetFrameContainer and frame.TargetFrameContainer.FrameTexture then
                ApplyDarkenColor(frame.TargetFrameContainer.FrameTexture)
            end

            local main = GetBossFrameMain(frame)
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

            if frame.LevelBackgroundCircle then
                ApplyDarkenColor(frame.LevelBackgroundCircle)
            end
            if frame.LevelBackground then
                ApplyDarkenColor(frame.LevelBackground)
            end
        end
    end
end

function bossframes:HealthBarColor()
    for i = 1, MAX_BOSS_FRAMES do
        local frame = GetSlotFrame(i)
        local main = GetBossFrameMain(frame)
        local healthBar = main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar
        if healthBar then
            UberUI.general:SetHealthColor(healthBar, slots[i].unit, uuidb.bossframes)
        end
    end
end

function bossframes:HealthManaBarTexture()
    local textureToApply
    if uuidb.general.bossbartextures then
        if uuidb.general.bossbartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.bossbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    local secondaryTextureToApply
    if uuidb.general.secondarybartextures then
        if uuidb.general.secondarybartexture ~= "Blizzard" then
            secondaryTextureToApply = uuidb.statusbars[uuidb.general.secondarybartexture]
        end
    else
        secondaryTextureToApply = textureToApply
    end

    for i = 1, MAX_BOSS_FRAMES do
        local frame = GetSlotFrame(i)
        local main = GetBossFrameMain(frame)
        local healthBar = main and main.HealthBarsContainer and main.HealthBarsContainer.HealthBar
        local manaBar = main and main.ManaBar

        if textureToApply then
            if healthBar then healthBar:SetStatusBarTexture(textureToApply) end

            local powerType = UnitPowerType(slots[i].unit)
            if (powerType and powerType < 4) and manaBar then
                manaBar:SetStatusBarTexture(textureToApply)
                local pc = PowerBarColor[powerType]
                manaBar:SetStatusBarDesaturated(true)
                manaBar:SetStatusBarColor(pc.r, pc.g, pc.b)
            end
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
end

function bossframes:PvPIcon()
    for i = 1, MAX_BOSS_FRAMES do
        local frame = GetSlotFrame(i)
        local contextual = GetBossFrameContextual(frame)
        if contextual then
            UberUI.general:PvPIcon(contextual)
        end
    end
end

local function IsEnemyBoss(unit)
    if not UnitExists(unit) then return false end
    if UnitIsUnit("player", unit) then return false end
    if UnitCanAttack("player", unit) then return true end
    return not UnitIsFriend("player", unit)
end

-- Thin per-frame wrapper: resolves the boss style/showDispel settings, then
-- hands off to the shared aurakit.ApplyAuraButtonStyle (see core/aurakit.lua,
-- shared with target/focus/party).
function bossframes:UpdateAuraButtonStyle(button)
    if not button then return end
    local isBuff = button.isBuff
    local style = "both"
    if uuidb and uuidb.general then
        style = isBuff and (uuidb.general.aurastyle_bossbuffs or "both") or
        (uuidb.general.aurastyle_bossdebuffs or "zoom")
    end
    local showDispel = uuidb and uuidb.general and uuidb.general.bossbuffs_showdispel
    aurakit.ApplyAuraButtonStyle(button, { style = style, showDispel = showDispel, squareLoc = "boss" })
end

function bossframes:UpdateAuraPositions(i)
    local slot = slots[i]
    local frame = GetSlotFrame(i)
    if not frame then return end
    aurakit.UpdatePairedPositions({
        frameObj = slot,
        refFrame = frame,
        isEnemyFn = function() return IsEnemyBoss(slot.unit) end,
        buffsOnTop = frame.buffsOnTop,
        topX = BOSS_TOP_X,
        topY = BOSS_TOP_Y,
        topOnTopX = BOSS_TOP_ON_TOP_X,
        containerGap = BOSS_CONTAINER_GAP,
    })
end

function bossframes:UpdateAuras(i)
    local slot = slots[i]
    if slot.isUpdatingAuras then return end
    slot.isUpdatingAuras = true

    local frame = GetSlotFrame(i)
    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_bossbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_bossdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local contextual = GetBossFrameContextual(frame)
    local blizzAuras = contextual and contextual.Auras

    if bothNone then
        aurakit.ShowAuraContainers(slot, false)
        if blizzAuras then
            blizzAuras:SetAlpha(1)
            blizzAuras:EnableMouse(true)
        end
        slot.isUpdatingAuras = false
        return
    end

    if not slot.customDebuffs or not slot.customBuffs then
        self:SetupCustomAuraContainer(i)
    end

    if blizzAuras then
        blizzAuras:SetAlpha(0)
        blizzAuras:EnableMouse(false)
    end

    if not slot.customDebuffs or not slot.customBuffs then
        slot.isUpdatingAuras = false
        return
    end

    if not frame or not frame:IsShown() or not UnitExists(slot.unit) then
        aurakit.ShowAuraContainers(slot, false)
        slot.isUpdatingAuras = false
        return
    end

    aurakit.ShowAuraContainers(slot, true)
    self:UpdateAuraPositions(i)

    local debuffCount = (styleDebuffs ~= "none") and 16 or 0
    local buffCount = (styleBuffs ~= "none") and 32 or 0
    -- "mine" gets forced to 0 specifically when the engine's PLAYER/!PLAYER
    -- caster classification is currently ambiguous for this unit (see
    -- aurakit.HasAmbiguousMineMatch). "other" is left untouched, so the aura
    -- stays visible there instead of duplicating OR vanishing.
    local debuffMineCount = aurakit.GetSafeMineMaxFrameCount(slot.unit, true, debuffCount)
    local buffMineCount = aurakit.GetSafeMineMaxFrameCount(slot.unit, false, buffCount)
    pcall(slot.customDebuffs.SetAuraGroupMaxFrameCount, slot.customDebuffs, "debuffs_mine", debuffMineCount)
    pcall(slot.customDebuffs.SetAuraGroupMaxFrameCount, slot.customDebuffs, "debuffs_other", debuffCount)
    pcall(slot.customBuffs.SetAuraGroupMaxFrameCount, slot.customBuffs, "buffs_mine", buffMineCount)
    pcall(slot.customBuffs.SetAuraGroupMaxFrameCount, slot.customBuffs, "buffs_other", buffCount)

    pcall(slot.customDebuffs.UpdateAllAuras, slot.customDebuffs)
    pcall(slot.customBuffs.UpdateAllAuras, slot.customBuffs)

    local updateStyleFn = function(btn) bossframes:UpdateAuraButtonStyle(btn) end
    aurakit.RefreshContainerButtons(slot.customDebuffs, "debuffs_mine", "debuffs_other", updateStyleFn)
    aurakit.RefreshContainerButtons(slot.customBuffs, "buffs_mine", "buffs_other", updateStyleFn)

    aurakit.UpdateSpellbar(frame, aurakit.GetAuraContainers(slot))

    slot.isUpdatingAuras = false
end

function bossframes:UpdateAllAuras()
    for i = 1, MAX_BOSS_FRAMES do
        self:UpdateAuras(i)
    end
end

function bossframes:ForceZoom()
    self:UpdateAllAuras()
end

function bossframes:SetupCustomAuraContainer(i)
    local slot = slots[i]
    local frame = GetSlotFrame(i)
    if not frame then return end

    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_bossbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_bossdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local contextual = GetBossFrameContextual(frame)
    local blizzAuras = contextual and contextual.Auras

    if bothNone then
        aurakit.ShowAuraContainers(slot, false)
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

    if not blizzAuras then return end

    blizzAuras:SetAlpha(0)
    blizzAuras:EnableMouse(false)

    local updateStyleFn = function(btn) bossframes:UpdateAuraButtonStyle(btn) end

    if not slot.customDebuffs then
        slot.customDebuffs = aurakit.BuildAuraContainer({
            namePrefix = "UberUI_Boss" .. i .. "Debuffs",
            parentFrame = frame,
            unitToken = slot.unit,
            mineKey = "debuffs_mine",
            otherKey = "debuffs_other",
            mineFilter = "HARMFUL|PLAYER",
            otherFilter = "HARMFUL|!PLAYER",
            frameLevelBonus = 20,
            largeSize = BOSS_LARGE_AURA_SIZE,
            smallSize = BOSS_SMALL_AURA_SIZE,
            spacing = BOSS_AURA_SPACING,
            updateStyleFn = updateStyleFn,
            isUpdating = function() return slot.isUpdatingAuras end,
            clearUpdating = function() slot.isUpdatingAuras = false end,
            onApplyLayout = function()
                bossframes:UpdateAuraPositions(i)
                aurakit.UpdateSpellbar(frame, aurakit.GetAuraContainers(slot))
            end,
        })
    end
    if not slot.customBuffs then
        slot.customBuffs = aurakit.BuildAuraContainer({
            namePrefix = "UberUI_Boss" .. i .. "Buffs",
            parentFrame = frame,
            unitToken = slot.unit,
            mineKey = "buffs_mine",
            otherKey = "buffs_other",
            mineFilter = "HELPFUL|PLAYER",
            otherFilter = "HELPFUL|!PLAYER",
            frameLevelBonus = 20,
            largeSize = BOSS_LARGE_AURA_SIZE,
            smallSize = BOSS_SMALL_AURA_SIZE,
            spacing = BOSS_AURA_SPACING,
            updateStyleFn = updateStyleFn,
            isUpdating = function() return slot.isUpdatingAuras end,
            clearUpdating = function() slot.isUpdatingAuras = false end,
            onApplyLayout = function()
                bossframes:UpdateAuraPositions(i)
                aurakit.UpdateSpellbar(frame, aurakit.GetAuraContainers(slot))
            end,
        })
    end

    if slot.customDebuffs and slot.customBuffs then
        bossframes:UpdateAuraPositions(i)
    end

    aurakit.HookSpellbarAdjustPosition(frame.spellbar, frame, function() return aurakit.GetAuraContainers(slot) end)

    aurakit.ShowAuraContainers(slot, frame:IsShown())

    if not slot.frameHooked then
        slot.frameHooked = true
        frame:HookScript("OnShow", function()
            aurakit.ShowAuraContainers(slot, true)
            if slot.customDebuffs then slot.customDebuffs:UpdateAllAuras() end
            if slot.customBuffs then slot.customBuffs:UpdateAllAuras() end
            bossframes:UpdateAuras(i)
        end)
        frame:HookScript("OnHide", function()
            aurakit.ShowAuraContainers(slot, false)
        end)
    end

    if not slot.mixinHooked then
        slot.mixinHooked = true
        if frame.UpdateAuras then
            hooksecurefunc(frame, "UpdateAuras", function()
                bossframes:UpdateAuras(i)
            end)
        end
        if frame.CheckPartyLeader then
            hooksecurefunc(frame, "CheckPartyLeader", function()
                bossframes:UpdateAuraPositions(i)
            end)
        end
        if frame.CheckFaction then
            hooksecurefunc(frame, "CheckFaction", function()
                bossframes:HealthBarColor()
            end)
        end
        if frame.Update then
            hooksecurefunc(frame, "Update", function()
                bossframes:HealthBarColor()
                bossframes:HealthManaBarTexture()
            end)
        end
        if frame.CreateSpellbar then
            hooksecurefunc(frame, "CreateSpellbar", function()
                aurakit.HookSpellbarAdjustPosition(frame.spellbar, frame, function() return aurakit.GetAuraContainers(slot) end)
            end)
        end
    end
end

function bossframes:SetupAllCustomAuraContainers()
    for i = 1, MAX_BOSS_FRAMES do
        self:SetupCustomAuraContainer(i)
    end
end

-- Initialize immediately if the boss frames already exist.
bossframes:SetupAllCustomAuraContainers()

if TargetFrame_UpdateAuras then
    hooksecurefunc("TargetFrame_UpdateAuras", function()
        bossframes:UpdateAllAuras()
    end)
end

hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
    if statusbar and unit and string.find(unit, "^boss%d$") then
        bossframes:HealthBarColor()
    end
end)

bossframes:RegisterEvent("ADDON_LOADED")
bossframes:RegisterEvent("PLAYER_LOGIN")
bossframes:RegisterEvent("PLAYER_ENTERING_WORLD")
bossframes:RegisterEvent("PLAYER_REGEN_ENABLED")
bossframes:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
bossframes:RegisterEvent("GROUP_ROSTER_UPDATE")
bossframes:RegisterEvent("PARTY_LEADER_CHANGED")
-- Same rationale as target/focus: the engine's PLAYER/!PLAYER caster
-- classification (aurakit.HasAmbiguousMineMatch) can go ambiguous or clear
-- up a few seconds after a zone transition, not instantly at the event.
bossframes:RegisterEvent("ZONE_CHANGED_NEW_AREA")
bossframes:RegisterEvent("ZONE_CHANGED")
bossframes:RegisterEvent("ZONE_CHANGED_INDOORS")
for i = 1, MAX_BOSS_FRAMES do
    bossframes:RegisterUnitEvent("UNIT_AURA", slots[i].unit)
end

bossframes:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        bossframes:SetupAllCustomAuraContainers()
    end
    bossframes:Color()
    bossframes:HealthBarColor()
    bossframes:HealthManaBarTexture()
    bossframes:PvPIcon()

    if event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        bossframes:UpdateAllAuras()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
        for i = 1, MAX_BOSS_FRAMES do
            bossframes:UpdateAuraPositions(i)
        end
    elseif event == "UNIT_AURA" then
        for i = 1, MAX_BOSS_FRAMES do
            if slots[i].unit == unit then
                bossframes:UpdateAuras(i)
                C_Timer.After(0.05, function() bossframes:UpdateAuras(i) end)
                break
            end
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        bossframes:UpdateAllAuras()
        C_Timer.After(1, function() bossframes:UpdateAllAuras() end)
        C_Timer.After(3, function() bossframes:UpdateAllAuras() end)
        C_Timer.After(5, function() bossframes:UpdateAllAuras() end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Force a correctness pass once combat lockdown lifts, in case any
        -- styling was skipped or failed while we were in combat.
        bossframes:UpdateAllAuras()
    end
end)

UberUI.bossframes = bossframes
