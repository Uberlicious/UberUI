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
playerframes:SetScript("OnEvent", function(self)
    playerframes:Color();
    playerframes:HealthBarColor();
    playerframes:HealthManaBarTexture();
end)

function playerframes:Color()
    local dc = uuidb.general.darkencolor;
    PlayerFrame.PlayerFrameContainer.FrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PlayerFrame.PlayerFrameContainer.VehicleFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PlayerCastingBarFrame.Border:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PetFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);

    self:ColorTotems();
    self:ColorHolyPower();
    self:ColorComboPoints();
    self:ColorAlternateMana();
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
        if (petPowerType < 4) then
            PetFrameManaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[petPowerType];
            PetFrameManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end
    end
    if (uuidb.general.secondarybartextures and uuidb.general.secondarybartexture == "Blizzard") then return end
    if (uuidb.general.secondarybartextures or uuidb.general.texture ~= "Blizzard") then
        local texture = uuidb.general.secondarybartextures and uuidb.statusbars[uuidb.general.secondarybartexture] or
            uuidb.statusbars[uuidb.general.texture];
        healthBar.HealAbsorbBar:SetTexture(texture);
        healthBar.MyHealPredictionBar:SetTexture(texture);
        healthBar.OtherHealPredictionBar:SetTexture(texture);
        healthBar.TotalAbsorbBar:SetTexture(texture);
        healthBar.TotalAbsorbBar:SetVertexColor(.7, .9, .9, 1);
    end
end

function playerframes:PvPIcon()
    UberUI.general:PvPIcon(PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual);
end

function playerframes:ColorTotems()
    local dc = uuidb.general.darkencolor;
    for _, totems in pairs({ TotemFrame:GetChildren() }) do
        for _, items in pairs({ totems:GetChildren() }) do
            if (items:GetChildren() == nil) then
                for _, reg in pairs({ items:GetRegions() }) do
                    reg:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                end

            end
        end
    end
end

function playerframes:ColorAlternateMana()
    local dc = uuidb.general.darkencolor;
    PlayerFrameAlternateManaBarBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PlayerFrameAlternateManaBarLeftBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PlayerFrameAlternateManaBarRightBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a);

    local texture = uuidb.statusbars[uuidb.general.texture];
    local pc = PowerBarColor[0];
    PlayerFrameAlternateManaBar:SetStatusBarTexture(texture);
    PlayerFrameAlternateManaBar:SetStatusBarDesaturated(true);
    PlayerFrameAlternateManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
end

function playerframes:ColorHolyPower()
    local dc = uuidb.general.darkencolor;
    PaladinPowerBarFrameBG:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    PaladinPowerBarFrameBankBG:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
end

function playerframes:ColorComboPoints()
    local dc = uuidb.general.darkencolor;
    for _, cp in pairs({ ComboPointPlayerFrame:GetChildren() }) do
        cp.PointOff:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    end
end

UberUI.playerframes = playerframes
