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
    if not FocusFrame then return end
    if FocusFrame.TargetFrameContainer then
        ApplyDarkenColor(FocusFrame.TargetFrameContainer.FrameTexture)
    elseif FocusFrameTextureFrameTexture then
        ApplyDarkenColor(FocusFrameTextureFrameTexture)
    end
    
    if FocusFrame then
        if FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain and FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelTextFrame then
            if FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelTextFrame.LevelBackgroundCircle then
                ApplyDarkenColor(FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelTextFrame.LevelBackgroundCircle)
            end
        end
        if FocusFrame.LevelBackgroundCircle then
            ApplyDarkenColor(FocusFrame.LevelBackgroundCircle)
        end
    end
    
    if FocusFrameSpellBar and FocusFrameSpellBar.Border then
        ApplyDarkenColor(FocusFrameSpellBar.Border)
    end
    
    if FocusFrameToTTextureFrameTexture then
        ApplyDarkenColor(FocusFrameToTTextureFrameTexture)
    end
    
    if FocusFrameToT and FocusFrameToT.FrameTexture then
        ApplyDarkenColor(FocusFrameToT.FrameTexture)
    elseif FocusFrameToTTextureFrameTexture then
        ApplyDarkenColor(FocusFrameToTTextureFrameTexture)
    end

    if FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain and FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor then
        if uuidb.general.hiderepcolor then
            FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Hide()
        else
            FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Show()
        end
    end
end

function focusframes:HealthBarColor()
    if not FocusFrame then return end
    local healthBar = (FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain and FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar) or FocusFrameHealthBar;
    if healthBar then
        UberUI.general:SetHealthColor(healthBar, "focus", uuidb.focusframes);
    end

    local totHealthBar = (FocusFrameToT and FocusFrameToT.HealthBar) or FocusFrameToTHealthBar;
    if totHealthBar then
        UberUI.general:SetHealthColor(totHealthBar, "focustarget", uuidb.focusframes);
    end
end

function focusframes:HealthManaBarTexture()
    if not FocusFrame then return end
    local focusFrameMain = FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain;
    local healthBar = (focusFrameMain and focusFrameMain.HealthBarsContainer.HealthBar) or FocusFrameHealthBar;
    local manaBar = (focusFrameMain and focusFrameMain.ManaBar) or FocusFrameManaBar;
    
    local totHealthBar = (FocusFrameToT and FocusFrameToT.HealthBar) or FocusFrameToTHealthBar;
    local totManaBar = (FocusFrameToT and FocusFrameToT.ManaBar) or FocusFrameToTManaBar;

    local textureToApply
    if uuidb.general.focusbartextures then
        if uuidb.general.focusbartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.focusbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply then
        if healthBar then healthBar:SetStatusBarTexture(textureToApply); end
        if totHealthBar then totHealthBar:SetStatusBarTexture(textureToApply); end

        local focusPowerType = UnitPowerType("focus");
        if (focusPowerType and focusPowerType < 4) and manaBar then
            manaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[focusPowerType];
            manaBar:SetStatusBarDesaturated(true)
            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end

        local focusTotPowerType = UnitPowerType("focustarget");
        if (focusTotPowerType and focusTotPowerType < 4) and totManaBar then
            totManaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[focusTotPowerType];
            totManaBar:SetStatusBarDesaturated(true)
            totManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
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

    if secondaryTextureToApply and healthBar then
        if healthBar.HealAbsorbBar then healthBar.HealAbsorbBar.Fill:SetTexture(secondaryTextureToApply); end
        if healthBar.MyHealPredictionBar then healthBar.MyHealPredictionBar.Fill:SetTexture(secondaryTextureToApply); end
        if healthBar.OtherHealPredictionBar then healthBar.OtherHealPredictionBar.Fill:SetTexture(secondaryTextureToApply); end
        if healthBar.TotalAbsorbBar then
            healthBar.TotalAbsorbBar.Fill:SetTexture(secondaryTextureToApply);
            healthBar.TotalAbsorbBar.Fill:SetVertexColor(.6, .9, .9, 1);
        end
    end
end

function focusframes:PvPIcon()
    if not FocusFrame then return end
    if FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual then
        UberUI.general:PvPIcon(FocusFrame.TargetFrameContent.TargetFrameContentContextual);
    elseif FocusFrameTextureFramePVPIcon then
        UberUI.general:PvPIcon(FocusFrameTextureFramePVPIcon);
    end
end

UberUI.focusframes = focusframes
