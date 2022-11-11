local addon, ns = ...
local targetframes = {}

--[[
	Local Variables
]] --
local targetframes = CreateFrame("frame")
targetframes:RegisterEvent("ADDON_LOADED")
targetframes:RegisterEvent("PLAYER_LOGIN")
targetframes:RegisterEvent("PLAYER_ENTERING_WORLD")
targetframes:RegisterEvent("PLAYER_TARGET_CHANGED")
targetframes:RegisterEvent("PLAYER_FOCUS_CHANGED")
targetframes:RegisterEvent("UNIT_TARGET")
targetframes:SetScript("OnEvent", function(self, event)
    targetframes:Color();
    targetframes:HealthBarColor();
    targetframes:HealthManaBarTexture();
    targetframes:PvPIcon();
end)

function targetframes:Color()
    local dc = uuidb.general.darkencolor;
    TargetFrame.TargetFrameContainer.FrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    TargetFrameSpellBar.Border:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    TargetFrameToT.FrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);

    if (uuidb.general.hiderepcolor) then
        TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Hide();
    else
        TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Show();
    end
end

function targetframes:HealthBarColor()
    local healthBar = TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBar;
    UberUI.general:SetHealthColor(healthBar, "target", uuidb.targetframes);

    local healthBar = TargetFrameToT.HealthBar;
    UberUI.general:SetHealthColor(healthBar, "targettarget", uuidb.targetframes);
end

function targetframes:HealthManaBarTexture()
    local targetFrame = TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBar;
    if (uuidb.general.texture ~= "Blizzard") then
        local texture = uuidb.statusbars[uuidb.general.texture];
        targetFrame.HealthBar:SetStatusBarTexture(texture);
        TargetFrameToT.HealthBar:SetStatusBarTexture(texture);

        -- Color bar accordingly
        -- https://wowpedia.fandom.com/wiki/API_UnitPowerDisplayMod
        local targetPowerType = UnitPowerType("target");
        if (targetPowerType < 4) then
            targetFrame.ManaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[targetPowerType];
            targetFrame.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end

        local totPowerType = UnitPowerType("targettarget");
        if (totPowerType < 4) then
            TargetFrameToT.ManaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[totPowerType];
            TargetFrameToT.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end
    end
    if (uuidb.general.secondarybartextures and uuidb.general.secondarybartexture == "Blizzard") then return end
    if (uuidb.general.secondarybartextures or uuidb.general.texture ~= "Blizzard") then
        local texture = uuidb.general.secondarybartextures and uuidb.statusbars[uuidb.general.secondarybartexture] or
            uuidb.statusbars[uuidb.general.texture];
        targetFrame.HealAbsorbBar:SetTexture(texture);
        targetFrame.MyHealPredictionBar:SetTexture(texture);
        targetFrame.OtherHealPredictionBar:SetTexture(texture);
        targetFrame.TotalAbsorbBar:SetTexture(texture);
        targetFrame.TotalAbsorbBar:SetVertexColor(.7, .9, .9, 1);
    end
end

function targetframes:PvPIcon()
    UberUI.general:PvPIcon(TargetFrame.TargetFrameContent.TargetFrameContentContextual);
end

UberUI.targetframes = targetframes
