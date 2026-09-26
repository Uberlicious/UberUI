local addon, ns = ...

-- Cache frequently accessed globals for performance
local UnitPowerType = UnitPowerType
local UnitClass = UnitClass
local PowerBarColor = PowerBarColor
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- Helper function for applying darken color
local function ApplyDarkenColor(region)
    local dc = uuidb.general.darkencolor
    region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
end

local localizedClass, englishClass = UnitClass("player")
local classcolor = englishClass and ((C_ClassColor and C_ClassColor.GetClassColor(englishClass)) or (GetClassColorObj and GetClassColorObj(englishClass)) or RAID_CLASS_COLORS[englishClass])
local class = localizedClass
local pvphook = false;

playerframes = UberUI:CreateFrame("frame")
playerframes:RegisterEvent("ADDON_LOADED")
playerframes:RegisterEvent("PLAYER_LOGIN")
playerframes:RegisterEvent("PLAYER_ENTERING_WORLD")
playerframes:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
playerframes:RegisterEvent("ACTIONBAR_UPDATE_STATE")
playerframes:RegisterEvent("PVP_WORLDSTATE_UPDATE")
playerframes:RegisterEvent("UNIT_ENTERED_VEHICLE")
playerframes:RegisterEvent("UNIT_EXITED_VEHICLE")
playerframes:RegisterEvent("UNIT_AURA")
playerframes:RegisterEvent("PLAYER_LOSES_VEHICLE_DATA")
playerframes:RegisterEvent("PLAYER_GAINS_VEHICLE_DATA")
playerframes:RegisterEvent("PVP_MATCH_ACTIVE")
playerframes:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
playerframes:RegisterEvent("ZONE_CHANGED_NEW_AREA")
-- Without this, a totem's border only gets darkened if some other
-- registered event happens to fire after it's summoned -- nothing here
-- previously reacted to totems actually being placed/cleared.
playerframes:RegisterEvent("PLAYER_TOTEM_UPDATE")
playerframes:SetScript("OnEvent", function(self, event)
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
    playerframes:Color();
    playerframes:HealthBarColor();
    playerframes:HealthManaBarTexture();
end)

function playerframes:Color()
    if PlayerFrame.PlayerFrameContainer then
        ApplyDarkenColor(PlayerFrame.PlayerFrameContainer.FrameTexture)
        ApplyDarkenColor(PlayerFrame.PlayerFrameContainer.AlternatePowerFrameTexture)
        ApplyDarkenColor(PlayerFrame.PlayerFrameContainer.VehicleFrameTexture)
    elseif PlayerFrameTexture then
        ApplyDarkenColor(PlayerFrameTexture)
        if PlayerFrameAlternateManaBar and PlayerFrameAlternateManaBar.Border then
            ApplyDarkenColor(PlayerFrameAlternateManaBar.Border)
        end
    end
    
    if PlayerFrame then
        if PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain then
            if PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelTextFrame and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelTextFrame.LevelBackgroundCircle then
                ApplyDarkenColor(PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelTextFrame.LevelBackgroundCircle)
            end
            if PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelBackground then
                ApplyDarkenColor(PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelBackground)
            end
            if PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelBackgroundCircle then
                ApplyDarkenColor(PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.LevelBackgroundCircle)
            end
            if PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.PvPBackgroundCircle then
                ApplyDarkenColor(PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.PvPBackgroundCircle)
            end
            -- WoW Forever names this field with a lowercase "Pvp" (unlike
            -- Target/Focus's "PvP"), so it never matched the check above.
            if PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.PvpBackgroundCircle then
                ApplyDarkenColor(PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.PvpBackgroundCircle)
            end
        end
        if PlayerFrame.LevelBackgroundCircle then
            ApplyDarkenColor(PlayerFrame.LevelBackgroundCircle)
        end
        if PlayerFrame.LevelBackground then
            ApplyDarkenColor(PlayerFrame.LevelBackground)
        end
        if _G["PlayerFrameLevelBackground"] then
            ApplyDarkenColor(_G["PlayerFrameLevelBackground"])
        end
    end
    
    if PlayerCastingBarFrame and PlayerCastingBarFrame.Border then
        ApplyDarkenColor(PlayerCastingBarFrame.Border)
    elseif CastingBarFrame and CastingBarFrame.Border then
        ApplyDarkenColor(CastingBarFrame.Border)
    end
    
    if PetFrameTexture then
        ApplyDarkenColor(PetFrameTexture)
    end

    if (class == "Shaman") then
        self:ColorTotems();
    elseif (class == "Paladin") then
        self:ColorTotems();
        self:ColorHolyPower();
    elseif (class == "Rogue") then
        self:ColorComboPoints();
    elseif (class == "Druid") then
        -- Retail Mainline: Feral's combo points render through the same
        -- shared RogueComboPointBarFrame Rogues use. Not relevant on
        -- Forever 1.60.1 -- that client (like every classic-family build)
        -- shows combo points via the native ComboFrame anchored to
        -- TargetFrame instead; see targetframes:ColorComboPoints().
        self:ColorComboPoints();
    elseif (class == "Warlock") then
        self:ColorSoulShards();
    elseif (class == "Monk") then
        self:ColorMonkChi();
    end
    self:ColorAlternatePower();
    self:PvPIcon();
end

function playerframes:HealthBarColor()
    local healthBar = PlayerFrame_GetHealthBar();
    if uuidb.playerframes.classcolor then
        healthBar:SetStatusBarDesaturated(true);
        healthBar:SetStatusBarColor(classcolor.r, classcolor.g, classcolor.b, classcolor.a);
    else
        healthBar:SetStatusBarDesaturated(false);
        healthBar:SetStatusBarColor(0, 1, 0, 1);
    end
    PetFrameHealthBar:SetStatusBarDesaturated(false);
    PetFrameHealthBar:SetStatusBarColor(0, 1, 0, 1);
end

local function GetPlayerBarTexture()
    if uuidb.general.playerbartextures then
        if uuidb.general.playerbartexture ~= "Blizzard" then
            return uuidb.statusbars[uuidb.general.playerbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        return uuidb.statusbars[uuidb.general.texture]
    end
end

-- How far the mana cost prediction tint is pushed from the power color
-- toward white (0 = same as the bar, 1 = white).
local MANA_COST_PREDICTION_LIGHTEN = 0.35

-- Blizzard tints the cost prediction segment once, at load, with
-- MANAPREDICTIONBLUE -- on a flat/custom texture that ends up nearly the same
-- blue as the mana bar under it. Tint it a lightened copy of the bar's own
-- power color instead so the spell cost stands out, and follows form/power
-- type changes.
local function LightenManaCostPrediction(manaBar, unit)
    local prediction = manaBar and manaBar.ManaCostPredictionBar
    local fill = prediction and prediction.Fill
    if not fill then return end
    local powerType = UnitPowerType(unit);
    local pc = powerType and PowerBarColor[powerType]
    if not pc then return end
    local f = MANA_COST_PREDICTION_LIGHTEN
    fill:SetDesaturated(true);
    fill:SetVertexColor(pc.r + (1 - pc.r) * f, pc.g + (1 - pc.g) * f, pc.b + (1 - pc.b) * f, 1);
end

-- Mana/rage/focus/energy only (power types 0-3); other power types keep
-- Blizzard's own art.
local function ApplyManaBarTexture(manaBar, unit, textureToApply)
    if not manaBar or not textureToApply then return end
    local powerType = UnitPowerType(unit);
    if (powerType and powerType < 4) then
        manaBar:SetStatusBarTexture(textureToApply);
        local pc = PowerBarColor[powerType];
        manaBar:SetStatusBarDesaturated(true);
        manaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        LightenManaCostPrediction(manaBar, unit);
    end
end

-- Blizzard's UnitFrameManaBar_Update calls UnitFrameManaBar_UpdateType on
-- every mana bar update, which puts its own atlas back on the bar. Out of
-- combat our event handler above re-applies ours often enough to hide that,
-- but it skips everything in combat, so the bar showed Blizzard's texture
-- for the whole fight. Re-applying right after UpdateType fixes that in and
-- out of combat. Texture/color calls only -- no writes to Blizzard's
-- frame fields.
--
-- Only worth installing if a custom player bar texture is actually active --
-- hooksecurefunc can't be undone, so this is gated on GetPlayerBarTexture()
-- rather than installed unconditionally. Can't check that at file-load time
-- though: uuidb is still the empty placeholder table from config.lua here
-- (this addon's own ADDON_LOADED/PLAYER_LOGIN handler, which swaps in the
-- real SavedVariables and populates uuidb.general, hasn't run yet -- that's
-- what crashed with "attempt to index field 'general' (a nil value)" when
-- this checked it directly at the top level). Deferred into
-- EnsureManaBarCombatHook() instead, called from HealthManaBarTexture()
-- below, which only ever runs from playerframes' own OnEvent handler or an
-- options page toggle -- both always after uuidb is populated. The Player/All
-- Bar Textures tooltips already warn a reload is needed to properly attach,
-- which covers turning this on after load too.
local manaBarCombatHookInstalled = false
local function EnsureManaBarCombatHook()
    if manaBarCombatHookInstalled or not UnitFrameManaBar_UpdateType or not GetPlayerBarTexture() then return end
    manaBarCombatHookInstalled = true
    hooksecurefunc("UnitFrameManaBar_UpdateType", function(manaBar)
        if not manaBar or not uuidb or not uuidb.general then return end
        local unit
        if manaBar == PlayerFrame_GetManaBar() then
            unit = manaBar.unit or "player" -- "vehicle" while in one
        elseif PetFrameManaBar and manaBar == PetFrameManaBar then
            unit = manaBar.unit or "pet"
        else
            return
        end
        ApplyManaBarTexture(manaBar, unit, GetPlayerBarTexture())
    end)
end

function playerframes:HealthManaBarTexture(force)
    EnsureManaBarCombatHook()

    local healthBar = PlayerFrame_GetHealthBar();
    local manaBar = PlayerFrame_GetManaBar();

    local textureToApply = GetPlayerBarTexture()

    if textureToApply then
        healthBar:SetStatusBarTexture(textureToApply);
        if healthBar.AnimatedLossBar then
            healthBar.AnimatedLossBar:SetStatusBarTexture(textureToApply);
        end

        ApplyManaBarTexture(manaBar, "player", textureToApply);
        healthBar.styled = true;

        if PetFrameHealthBar then
            PetFrameHealthBar:SetStatusBarTexture(textureToApply);
        end
        ApplyManaBarTexture(PetFrameManaBar, "pet", textureToApply);
    end
    local secondaryTextureToApply
    if uuidb.general.secondarybartextures then
        if uuidb.general.secondarybartexture ~= "Blizzard" then
            secondaryTextureToApply = uuidb.statusbars[uuidb.general.secondarybartexture]
        end
    else
        secondaryTextureToApply = textureToApply -- Fallback to the main texture decision
    end

    if secondaryTextureToApply then
        if healthBar.HealAbsorbBar then
            healthBar.HealAbsorbBar.Fill:SetTexture(secondaryTextureToApply);
        end
        if healthBar.MyHealPredictionBar then
            healthBar.MyHealPredictionBar.Fill:SetTexture(secondaryTextureToApply);
        end
        if healthBar.OtherHealPredictionBar then
            healthBar.OtherHealPredictionBar.Fill:SetTexture(secondaryTextureToApply);
        end
        if healthBar.TotalAbsorbBar then
            healthBar.TotalAbsorbBar.Fill:SetTexture(secondaryTextureToApply);
            healthBar.TotalAbsorbBar.Fill:SetVertexColor(.7, .9, .9, 1);
        end
        if manaBar.ManaCostPredictionBar then
            manaBar.ManaCostPredictionBar.Fill:SetTexture(secondaryTextureToApply);
            LightenManaCostPrediction(manaBar, manaBar.unit or "player");
        end
        if manaBar.FeedbackFrame and manaBar.FeedbackFrame.BarTexture then
            manaBar.FeedbackFrame.BarTexture:SetTexture(secondaryTextureToApply);
        end
    end
end

function playerframes:PvPIcon()
    if PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual then
        UberUI.general:PvPIcon(PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual);
    elseif PlayerPVPIcon then
        UberUI.general:PvPIcon(PlayerPVPIcon);
    end
end

function playerframes:ColorTotems()
    if TotemFrame then
        for _, totems in pairs({ TotemFrame:GetChildren() }) do
            if totems.Border then
                ApplyDarkenColor(totems.Border)
            end
        end
    end
end

function playerframes:ColorAlternatePower()
    local applyCustomLook = (uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard")
    if applyCustomLook and AlternatePowerBar then
        local dc = uuidb.general.darkencolor;
        local texture = uuidb.statusbars[uuidb.general.texture];
        local pc = PowerBarColor[0] or {r=1, g=1, b=1};
        AlternatePowerBar:SetStatusBarTexture(texture);
        AlternatePowerBar:SetStatusBarDesaturated(true);
        AlternatePowerBar:SetStatusBarColor(pc.r, pc.g, pc.b);
    end
end

function playerframes:ColorHolyPower()
    if PaladinPowerBarFrame then
        if PaladinPowerBarFrame.Background then ApplyDarkenColor(PaladinPowerBarFrame.Background) end
        if PaladinPowerBarFrame.ActiveTexture then ApplyDarkenColor(PaladinPowerBarFrame.ActiveTexture) end
    end
end

function playerframes:ColorComboPoints()
    if RogueComboPointBarFrame then
        for _, cp in pairs({ RogueComboPointBarFrame:GetChildren() }) do
            if cp.BGInactive then ApplyDarkenColor(cp.BGInactive) end
            if cp.BGActive then ApplyDarkenColor(cp.BGActive) end
            if cp.Border then ApplyDarkenColor(cp.Border) end
            if cp.ComboPointBorder then ApplyDarkenColor(cp.ComboPointBorder) end
        end
    end
end

function playerframes:ColorSoulShards()
    if WarlockPowerFrame then
        for _, ss in pairs({ WarlockPowerFrame:GetChildren() }) do
            if ss.Background then ApplyDarkenColor(ss.Background) end
        end
    end
end

function playerframes:ColorMonkChi()
    if MonkHarmonyBarFrame then
        for _, chi in pairs({ MonkHarmonyBarFrame:GetChildren() }) do
            if chi.Chi_BG then ApplyDarkenColor(chi.Chi_BG) end
            if chi.Chi_BG_Active then ApplyDarkenColor(chi.Chi_BG_Active) end
        end
    end
end


UberUI.playerframes = playerframes
