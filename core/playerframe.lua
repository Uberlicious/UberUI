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

local class = UnitClass("player")
local classcolor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
local pvphook = false;

playerframes = CreateFrame("frame")
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
playerframes:SetScript("OnEvent", function(self)
    playerframes:Color();
    playerframes:HealthBarColor();
    playerframes:HealthManaBarTexture();
end)

function playerframes:Color()
    ApplyDarkenColor(PlayerFrame.PlayerFrameContainer.FrameTexture)
    ApplyDarkenColor(PlayerFrame.PlayerFrameContainer.AlternatePowerFrameTexture)
    ApplyDarkenColor(PlayerFrame.PlayerFrameContainer.VehicleFrameTexture)
    ApplyDarkenColor(PlayerCastingBarFrame.Border)
    ApplyDarkenColor(PetFrameTexture)

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
        healthBar.AnimatedLossBar:SetStatusBarTexture(textureToApply);

        local playerPowerType = UnitPowerType("player");
        if (playerPowerType and playerPowerType < 4) then
            manaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[playerPowerType];
            manaBar:SetStatusBarDesaturated(true);
            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end
        healthBar.styled = true;

        PetFrameHealthBar:SetStatusBarTexture(textureToApply);
        local petPowerType = UnitPowerType("pet");
        if (petPowerType and petPowerType < 4) then
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
        healthBar.HealAbsorbBar.Fill:SetTexture(secondaryTextureToApply);
        healthBar.MyHealPredictionBar.Fill:SetTexture(secondaryTextureToApply);
        healthBar.OtherHealPredictionBar.Fill:SetTexture(secondaryTextureToApply);
        healthBar.TotalAbsorbBar.Fill:SetTexture(secondaryTextureToApply);
        healthBar.TotalAbsorbBar.Fill:SetVertexColor(.7, .9, .9, 1);
        manaBar.ManaCostPredictionBar.Fill:SetTexture(secondaryTextureToApply);
        manaBar.FeedbackFrame.BarTexture:SetTexture(secondaryTextureToApply);
    end
end

function playerframes:PvPIcon()
    UberUI.general:PvPIcon(PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual);
end

function playerframes:ColorTotems()
    for _, totems in pairs({ TotemFrame:GetChildren() }) do
        ApplyDarkenColor(totems.Border)
    end
end

function playerframes:ColorAlternatePower()
    local applyCustomLook = (uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard")
    if applyCustomLook then
        local dc = uuidb.general.darkencolor;
        local texture = uuidb.statusbars[uuidb.general.texture];
        local pc = PowerBarColor[0];
        AlternatePowerBar:SetStatusBarTexture(texture);
        AlternatePowerBar:SetStatusBarDesaturated(true);
        AlternatePowerBar:SetStatusBarColor(pc.r, pc.g, pc.b);
    end
end

function playerframes:ColorHolyPower()
    ApplyDarkenColor(PaladinPowerBarFrame.Background)
    ApplyDarkenColor(PaladinPowerBarFrame.ActiveTexture)
end

function playerframes:ColorComboPoints()
    for _, cp in pairs({ RogueComboPointBarFrame:GetChildren() }) do
        ApplyDarkenColor(cp.BGInactive)
        ApplyDarkenColor(cp.BGActive)
    end
end

function playerframes:ColorSoulShards()
    for _, ss in pairs({ WarlockPowerFrame:GetChildren() }) do
        ApplyDarkenColor(ss.Background)
    end
end

function playerframes:ColorMonkChi()
    for _, chi in pairs({ MonkHarmonyBarFrame:GetChildren() }) do
        ApplyDarkenColor(chi.Chi_BG)
        ApplyDarkenColor(chi.Chi_BG_Active)
    end
end

UberUI.playerframes = playerframes
