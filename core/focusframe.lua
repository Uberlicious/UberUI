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
local focusframes = CreateFrame("frame")
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

    -- Determine which texture to use: focus-specific override or general texture
    local useFocusTexture = uuidb.general.focusbartextures and uuidb.general.focusbartexture ~= "Blizzard"
    local useGeneralTexture = uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard"

    if (useFocusTexture or useGeneralTexture) then
        local texture = useFocusTexture and uuidb.statusbars[uuidb.general.focusbartexture] or
            uuidb.statusbars[uuidb.general.texture];
        focusFrame.HealthBarsContainer.HealthBar:SetStatusBarTexture(texture);
        FocusFrameToT.HealthBar:SetStatusBarTexture(texture);

        -- Color bar accordingly
        -- https://wowpedia.fandom.com/wiki/API_UnitPowerDisplayMod
        local focusPowerType = UnitPowerType("focus");
        if (focusPowerType and focusPowerType < 4) then
            focusFrame.ManaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[focusPowerType];
            focusFrame.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end

        local focusTotPowerType = UnitPowerType("focustarget");
        if (focusTotPowerType and focusTotPowerType < 4) then
            FocusFrameToT.ManaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[focusTotPowerType];
            FocusFrameToT.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end
    end
    if (uuidb.general.secondarybartextures and uuidb.general.secondarybartexture == "Blizzard") then return end
    if (uuidb.general.secondarybartextures or useFocusTexture or useGeneralTexture) then
        local texture = uuidb.general.secondarybartextures and uuidb.statusbars[uuidb.general.secondarybartexture] or
            (useFocusTexture and uuidb.statusbars[uuidb.general.focusbartexture] or uuidb.statusbars[uuidb.general.texture]);
        focusFrame.HealthBarsContainer.HealthBar.HealAbsorbBar.Fill:SetTexture(texture);
        focusFrame.HealthBarsContainer.HealthBar.MyHealPredictionBar.Fill:SetTexture(texture);
        focusFrame.HealthBarsContainer.HealthBar.OtherHealPredictionBar.Fill:SetTexture(texture);
        focusFrame.HealthBarsContainer.HealthBar.TotalAbsorbBar.Fill:SetTexture(texture);
        focusFrame.HealthBarsContainer.HealthBar.TotalAbsorbBar.Fill:SetVertexColor(.6, .9, .9, 1);
    end
end

function focusframes:PvPIcon()
    UberUI.general:PvPIcon(FocusFrame.TargetFrameContent.TargetFrameContentContextual);
end

UberUI.focusframes = focusframes
