local addon, ns = ...

-- Cache frequently accessed globals for performance
local UnitPowerType = UnitPowerType
local PowerBarColor = PowerBarColor

-- Helper function for applying darken color
local function ApplyDarkenColor(region)
    local dc = uuidb.general.darkencolor
    region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
end

--[[
	Local Variables
]]
--
local targetframes = CreateFrame("frame")
targetframes:RegisterEvent("ADDON_LOADED")
targetframes:RegisterEvent("PLAYER_LOGIN")
targetframes:RegisterEvent("PLAYER_ENTERING_WORLD")
targetframes:RegisterEvent("PLAYER_TARGET_CHANGED")
targetframes:RegisterEvent("PLAYER_FOCUS_CHANGED")
targetframes:RegisterEvent("UNIT_TARGET")
targetframes:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target")
targetframes:RegisterUnitEvent("UNIT_POWER_UPDATE", "target")
targetframes:RegisterUnitEvent("UNIT_MAXPOWER", "target")
targetframes:SetScript("OnEvent", function(self, event)
    targetframes:Color();
    targetframes:HealthBarColor();
    targetframes:HealthManaBarTexture();
    targetframes:PvPIcon();
end)

function targetframes:Color()
    ApplyDarkenColor(TargetFrame.TargetFrameContainer.FrameTexture)
    ApplyDarkenColor(TargetFrameSpellBar.Border)
    ApplyDarkenColor(TargetFrameToT.FrameTexture)

    if uuidb.general.hiderepcolor then
        TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Hide()
    else
        TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Show()
    end
end

function targetframes:HealthBarColor()
    local healthBar = TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar;
    UberUI.general:SetHealthColor(healthBar, "target", uuidb.targetframes);

    local healthBar = TargetFrameToT.HealthBar;
    UberUI.general:SetHealthColor(healthBar, "targettarget", uuidb.targetframes);
end

function targetframes:HealthManaBarTexture()
    local targetFrame = TargetFrame.TargetFrameContent.TargetFrameContentMain;

    -- Determine which texture to use: target-specific override or general texture
    local useTargetTexture = uuidb.general.targetbartextures and uuidb.general.targetbartexture ~= "Blizzard"
    local useGeneralTexture = uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard"

    if (useTargetTexture or useGeneralTexture) then
        local texture = useTargetTexture and uuidb.statusbars[uuidb.general.targetbartexture] or
            uuidb.statusbars[uuidb.general.texture];
        targetFrame.HealthBarsContainer.HealthBar:SetStatusBarTexture(texture);
        TargetFrameToT.HealthBar:SetStatusBarTexture(texture);

        -- Color bar accordingly
        -- https://wowpedia.fandom.com/wiki/API_UnitPowerDisplayMod
        local targetPowerType = UnitPowerType("target");
        if (targetPowerType and targetPowerType < 4) then
            targetFrame.ManaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[targetPowerType];
            targetFrame.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end

        local totPowerType = UnitPowerType("targettarget");
        if (totPowerType and totPowerType < 4) then
            TargetFrameToT.ManaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[totPowerType];
            TargetFrameToT.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end
    end
    if (uuidb.general.secondarybartextures and uuidb.general.secondarybartexture == "Blizzard") then return end
    if (uuidb.general.secondarybartextures or useTargetTexture or useGeneralTexture) then
        local texture = uuidb.general.secondarybartextures and uuidb.statusbars[uuidb.general.secondarybartexture] or
            (useTargetTexture and uuidb.statusbars[uuidb.general.targetbartexture] or uuidb.statusbars[uuidb.general.texture]);
        targetFrame.HealthBarsContainer.HealthBar.HealAbsorbBar.Fill:SetTexture(texture);
        targetFrame.HealthBarsContainer.HealthBar.MyHealPredictionBar.Fill:SetTexture(texture);
        targetFrame.HealthBarsContainer.HealthBar.OtherHealPredictionBar.Fill:SetTexture(texture);
        targetFrame.HealthBarsContainer.HealthBar.TotalAbsorbBar.Fill:SetTexture(texture);
        targetFrame.HealthBarsContainer.HealthBar.TotalAbsorbBar.Fill:SetVertexColor(.7, .9, .9, 1);
    end
end

function targetframes:PvPIcon()
    UberUI.general:PvPIcon(TargetFrame.TargetFrameContent.TargetFrameContentContextual);
end

UberUI.targetframes = targetframes
