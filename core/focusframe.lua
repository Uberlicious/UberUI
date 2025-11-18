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
local focusframes = UberUI:CreateFrame("frame")
focusframes:RegisterEvent("ADDON_LOADED")
focusframes:RegisterEvent("PLAYER_LOGIN")
focusframes:RegisterEvent("PLAYER_ENTERING_WORLD")
focusframes:RegisterEvent("PLAYER_TARGET_CHANGED")
focusframes:RegisterEvent("PLAYER_FOCUS_CHANGED")
focusframes:RegisterEvent("UNIT_TARGET")
focusframes:SetScript("OnEvent", function(self, event)
    focusframes:Color();
    focusframes:HealthBarColor();
    focusframes:HealthManaBarTexture();
    focusframes:PvPIcon();
end)

function focusframes:Color()
    ApplyDarkenColor(FocusFrame.TargetFrameContainer.FrameTexture)
    ApplyDarkenColor(FocusFrameSpellBar.Border)
    ApplyDarkenColor(FocusFrameToT.FrameTexture)

    if uuidb.general.hiderepcolor then
        FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Hide()
    else
        FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Show()
    end
end

function focusframes:HealthBarColor()
    local healthBar = FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar;
    UberUI.general:SetHealthColor(healthBar, "focus", uuidb.focusframes);

    local healthBar = FocusFrameToT.HealthBar;
    UberUI.general:SetHealthColor(healthBar, "focustarget", uuidb.focusframes);
end

function focusframes:HealthManaBarTexture()
    local focusFrame = FocusFrame.TargetFrameContent.TargetFrameContentMain;

    local textureToApply
    if uuidb.general.focusbartextures then
        if uuidb.general.focusbartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.focusbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply then
        focusFrame.HealthBarsContainer.HealthBar:SetStatusBarTexture(textureToApply);
        FocusFrameToT.HealthBar:SetStatusBarTexture(textureToApply);

        -- Color bar accordingly
        -- https://wowpedia.fandom.com/wiki/API_UnitPowerDisplayMod
        local focusPowerType = UnitPowerType("focus");
        if (focusPowerType and focusPowerType < 4) then
            focusFrame.ManaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[focusPowerType];
            focusFrame.ManaBar:SetStatusBarDesaturated(true)
            focusFrame.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end

        local focusTotPowerType = UnitPowerType("focustarget");
        if (focusTotPowerType and focusTotPowerType < 4) then
            FocusFrameToT.ManaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[focusTotPowerType];
            FocusFrameToT.ManaBar:SetStatusBarDesaturated(true)
            FocusFrameToT.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
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
        focusFrame.HealthBarsContainer.HealthBar.HealAbsorbBar.Fill:SetTexture(secondaryTextureToApply);
        focusFrame.HealthBarsContainer.HealthBar.MyHealPredictionBar.Fill:SetTexture(secondaryTextureToApply);
        focusFrame.HealthBarsContainer.HealthBar.OtherHealPredictionBar.Fill:SetTexture(secondaryTextureToApply);
        focusFrame.HealthBarsContainer.HealthBar.TotalAbsorbBar.Fill:SetTexture(secondaryTextureToApply);
        focusFrame.HealthBarsContainer.HealthBar.TotalAbsorbBar.Fill:SetVertexColor(.6, .9, .9, 1);
    end
end

function focusframes:PvPIcon()
    UberUI.general:PvPIcon(FocusFrame.TargetFrameContent.TargetFrameContentContextual);
end

UberUI.focusframes = focusframes
