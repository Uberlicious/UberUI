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
    if TargetFrame.TargetFrameContainer then
        ApplyDarkenColor(TargetFrame.TargetFrameContainer.FrameTexture)
    elseif TargetFrameTextureFrameTexture then
        ApplyDarkenColor(TargetFrameTextureFrameTexture)
    end
    
    if TargetFrame then
        if TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain then
            if TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelTextFrame and TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelTextFrame.LevelBackgroundCircle then
                ApplyDarkenColor(TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelTextFrame.LevelBackgroundCircle)
            end
            if TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelBackground then
                ApplyDarkenColor(TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelBackground)
            end
            if TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelBackgroundCircle then
                ApplyDarkenColor(TargetFrame.TargetFrameContent.TargetFrameContentMain.LevelBackgroundCircle)
            end
            if TargetFrame.TargetFrameContent.TargetFrameContentMain.PvPBackgroundCircle then
                ApplyDarkenColor(TargetFrame.TargetFrameContent.TargetFrameContentMain.PvPBackgroundCircle)
            end
        end
        if TargetFrame.LevelBackgroundCircle then
            ApplyDarkenColor(TargetFrame.LevelBackgroundCircle)
        end
        if TargetFrame.LevelBackground then
            ApplyDarkenColor(TargetFrame.LevelBackground)
        end
        if _G["TargetFrameLevelBackground"] then
            ApplyDarkenColor(_G["TargetFrameLevelBackground"])
        end
    end
    
    if TargetFrameSpellBar and TargetFrameSpellBar.Border then
        ApplyDarkenColor(TargetFrameSpellBar.Border)
    end
    
    if TargetFrameToT and TargetFrameToT.FrameTexture then
        ApplyDarkenColor(TargetFrameToT.FrameTexture)
    elseif TargetFrameToTTextureFrameTexture then
        ApplyDarkenColor(TargetFrameToTTextureFrameTexture)
    end

    if TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain and TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor then
        if uuidb.general.hiderepcolor then
            TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Hide()
        else
            TargetFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Show()
        end
    end
end

function targetframes:HealthBarColor()
    local healthBar = (TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar) or TargetFrameHealthBar;
    if healthBar then
        UberUI.general:SetHealthColor(healthBar, "target", uuidb.targetframes);
    end

    local totHealthBar = (TargetFrameToT and TargetFrameToT.HealthBar) or TargetFrameToTHealthBar;
    if totHealthBar then
        UberUI.general:SetHealthColor(totHealthBar, "targettarget", uuidb.targetframes);
    end
end

function targetframes:HealthManaBarTexture()
    local targetFrameMain = TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain;
    local healthBar = (targetFrameMain and targetFrameMain.HealthBarsContainer.HealthBar) or TargetFrameHealthBar;
    local manaBar = (targetFrameMain and targetFrameMain.ManaBar) or TargetFrameManaBar;
    
    local totHealthBar = (TargetFrameToT and TargetFrameToT.HealthBar) or TargetFrameToTHealthBar;
    local totManaBar = (TargetFrameToT and TargetFrameToT.ManaBar) or TargetFrameToTManaBar;

    local textureToApply
    if uuidb.general.targetbartextures then
        if uuidb.general.targetbartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.targetbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply then
        if healthBar then healthBar:SetStatusBarTexture(textureToApply); end
        if totHealthBar then totHealthBar:SetStatusBarTexture(textureToApply); end

        -- Color bar accordingly
        -- https://wowpedia.fandom.com/wiki/API_UnitPowerDisplayMod
        local targetPowerType = UnitPowerType("target");
        if (targetPowerType and targetPowerType < 4) and manaBar then
            manaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[targetPowerType];
            manaBar:SetStatusBarDesaturated(true)
            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end

        local totPowerType = UnitPowerType("targettarget");
        if (totPowerType and totPowerType < 4) and totManaBar then
            totManaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[totPowerType];
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
            healthBar.TotalAbsorbBar.Fill:SetVertexColor(.7, .9, .9, 1);
        end
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

if TargetFrame and TargetFrame.UpdateAuras then
    hooksecurefunc(TargetFrame, "UpdateAuras", function(aura)
        targetframes:ZoomAuras()
        if UberUI.buffsandauras then
            UberUI.buffsandauras:ColorAuras(false)
        end
    end)
end

local aurasContainer = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual and TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras
if aurasContainer then
    local function HandleAuraUpdate(self)
        targetframes:ZoomAuras()
        if UberUI.buffsandauras then
            UberUI.buffsandauras:ColorAuras(false)
            if self and self.auraFrames then
                for _, btn in ipairs(self.auraFrames) do
                    UberUI.buffsandauras:StyleAuraButton(btn)
                end
            end
        end
    end
    
    if aurasContainer.Update then
        hooksecurefunc(aurasContainer, "Update", HandleAuraUpdate)
    end
    if aurasContainer.UpdateAllAuras then
        hooksecurefunc(aurasContainer, "UpdateAllAuras", HandleAuraUpdate)
    end
    if aurasContainer.UpdateAuras then
        hooksecurefunc(aurasContainer, "UpdateAuras", HandleAuraUpdate)
    end
end

function targetframes:PvPIcon()
    if TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual then
        UberUI.general:PvPIcon(TargetFrame.TargetFrameContent.TargetFrameContentContextual);
    elseif TargetFrameTextureFramePVPIcon then
        UberUI.general:PvPIcon(TargetFrameTextureFramePVPIcon);
    end
end

UberUI.targetframes = targetframes
