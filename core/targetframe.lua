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
local targetframes = UberUI:CreateFrame("frame")
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
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
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

    local textureToApply
    if uuidb.general.targetbartextures then
        if uuidb.general.targetbartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.targetbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply then
        targetFrame.HealthBarsContainer.HealthBar:SetStatusBarTexture(textureToApply);
        TargetFrameToT.HealthBar:SetStatusBarTexture(textureToApply);

        -- Color bar accordingly
        -- https://wowpedia.fandom.com/wiki/API_UnitPowerDisplayMod
        local targetPowerType = UnitPowerType("target");
        if (targetPowerType and targetPowerType < 4) then
            targetFrame.ManaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[targetPowerType];
            targetFrame.ManaBar:SetStatusBarDesaturated(true)
            targetFrame.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end

        local totPowerType = UnitPowerType("targettarget");
        if (totPowerType and totPowerType < 4) then
            TargetFrameToT.ManaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[totPowerType];
            TargetFrameToT.ManaBar:SetStatusBarDesaturated(true)
            TargetFrameToT.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
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
        targetFrame.HealthBarsContainer.HealthBar.HealAbsorbBar.Fill:SetTexture(secondaryTextureToApply);
        targetFrame.HealthBarsContainer.HealthBar.MyHealPredictionBar.Fill:SetTexture(secondaryTextureToApply);
        targetFrame.HealthBarsContainer.HealthBar.OtherHealPredictionBar.Fill:SetTexture(secondaryTextureToApply);
        targetFrame.HealthBarsContainer.HealthBar.TotalAbsorbBar.Fill:SetTexture(secondaryTextureToApply);
        targetFrame.HealthBarsContainer.HealthBar.TotalAbsorbBar.Fill:SetVertexColor(.7, .9, .9, 1);
    end
end

function targetframes:ZoomAuras()
    local dc = uuidb.general.darkencolor
    for _, child in pairs({ TargetFrame:GetChildren() }) do
        if child.Icon then
            for _, region in pairs({ child:GetRegions() }) do
                -- Check if the region is a Texture object
                if region:IsObjectType("Texture") then
                    -- This is the object we need!
                    local iconTexture = region
                    UberUI.general:ApplyIconZoom(iconTexture, uuidb.general.zoomicontarget)
                    break
                end
            end
        end
    end
end

function targetframes:ForceZoom()
    self:ZoomAuras()
end

hooksecurefunc(TargetFrame, "UpdateAuras", function(aura)
    targetframes:ZoomAuras()
end)

function targetframes:PvPIcon()
    UberUI.general:PvPIcon(TargetFrame.TargetFrameContent.TargetFrameContentContextual);
end

UberUI.targetframes = targetframes
