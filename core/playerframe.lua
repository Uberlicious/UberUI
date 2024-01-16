local addon, ns = ...
local playerframes = {}

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
playerframes:RegisterEvent("ARENA_OPPONENT_UPDATE")
playerframes:RegisterEvent("ZONE_CHANGED_NEW_AREA")
playerframes:SetScript("OnEvent", function(self)
    playerframes:Color();
    playerframes:HealthBarColor();
    playerframes:HealthManaBarTexture();
end)

function playerframes:Color()
    local dc = uuidb.general.darkencolor;
    PlayerFrame.PlayerFrameContainer.FrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PlayerFrame.PlayerFrameContainer.AlternatePowerFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PlayerFrame.PlayerFrameContainer.VehicleFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PlayerCastingBarFrame.Border:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PetFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);

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
    if (uuidb.general.texture ~= "Blizzard" or force) then
        local texture = uuidb.statusbars[uuidb.general.texture];
        healthBar:SetStatusBarTexture(texture);
        healthBar.AnimatedLossBar:SetStatusBarTexture(texture);

        local playerPowerType = UnitPowerType("player");
        if (playerPowerType < 4) then
            manaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[playerPowerType];
            manaBar:SetStatusBarDesaturated(true);
            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end
        healthBar.styled = true;

        PetFrameHealthBar:SetStatusBarTexture(texture);
        local petPowerType = UnitPowerType("pet");
        if (petPowerType and petPowerType < 4) then
            PetFrameManaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[petPowerType];
            PetFrameManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end
    end
    if (uuidb.general.secondarybartextures and uuidb.general.secondarybartexture == "Blizzard") then return end
    if (uuidb.general.secondarybartextures or uuidb.general.texture ~= "Blizzard") then
        local texture = uuidb.general.secondarybartextures and uuidb.statusbars[uuidb.general.secondarybartexture] or
            uuidb.statusbars[uuidb.general.texture];
        healthBar.HealAbsorbBar.Fill:SetTexture(texture);
        healthBar.MyHealPredictionBar.Fill:SetTexture(texture);
        healthBar.OtherHealPredictionBar.Fill:SetTexture(texture);
        healthBar.TotalAbsorbBar.Fill:SetTexture(texture);
        healthBar.TotalAbsorbBar.Fill:SetVertexColor(.7, .9, .9, 1);
        manaBar.ManaCostPredictionBar.Fill:SetTexture(texture);
        manaBar.FeedbackFrame.BarTexture:SetTexture(texture);
    end
end

function playerframes:PvPIcon()
    UberUI.general:PvPIcon(PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual);
end

function playerframes:ColorTotems()
    local dc = uuidb.general.darkencolor;
    for _, totems in pairs({ TotemFrame:GetChildren() }) do
        totems.Border:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    end
end

function playerframes:ColorAlternatePower()
    local dc = uuidb.general.darkencolor;
    local texture = uuidb.statusbars[uuidb.general.texture];
    local pc = PowerBarColor[0];
    AlternatePowerBar:SetStatusBarTexture(texture);
    AlternatePowerBar:SetStatusBarDesaturated(true);
    AlternatePowerBar:SetStatusBarColor(pc.r, pc.g, pc.b);
end

function playerframes:ColorHolyPower()
    local dc = uuidb.general.darkencolor;
    PaladinPowerBarFrame.Background:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PaladinPowerBarFrame.ActiveTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
end

function playerframes:ColorComboPoints()
    local dc = uuidb.general.darkencolor;
    for _, cp in pairs({ RogueComboPointBarFrame:GetChildren() }) do
        cp.BGInactive:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        cp.BGActive:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    end
end

function playerframes:ColorSoulShards()
    local dc = uuidb.general.darkencolor;
    for _, ss in pairs({ WarlockPowerFrame:GetChildren() }) do
        ss.Background:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    end
end

function playerframes:ColorMonkChi()
    local dc = uuidb.general.darkencolor;
    for _, chi in pairs({ MonkHarmonyBarFrame:GetChildren() }) do
        chi.Chi_BG:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        chi.Chi_BG_Active:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    end
end

UberUI.playerframes = playerframes
