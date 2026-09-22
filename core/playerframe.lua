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

function playerframes:HealthManaBarTexture(force)
    local healthBar = PlayerFrame_GetHealthBar();
    local manaBar = PlayerFrame_GetManaBar();

    local textureToApply
    if uuidb.general.playerbartextures then
        if uuidb.general.playerbartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.playerbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply then
        healthBar:SetStatusBarTexture(textureToApply);
        if healthBar.AnimatedLossBar then
            healthBar.AnimatedLossBar:SetStatusBarTexture(textureToApply);
        end

        local playerPowerType = UnitPowerType("player");
        if (playerPowerType and playerPowerType < 4) then
            manaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[playerPowerType];
            manaBar:SetStatusBarDesaturated(true);
            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end
        healthBar.styled = true;

        if PetFrameHealthBar then
            PetFrameHealthBar:SetStatusBarTexture(textureToApply);
        end
        local petPowerType = UnitPowerType("pet");
        if (petPowerType and petPowerType < 4) and PetFrameManaBar then
            PetFrameManaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[petPowerType];
            PetFrameManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end
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
