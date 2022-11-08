local addon, ns = ...
local focusframes = {}

--[[
	Local Variables
]] --
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
    local dc = uuidb.general.darkencolor;
    FocusFrame.TargetFrameContainer.FrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    FocusFrameSpellBar.Border:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    FocusFrameToT.FrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);

    if (uuidb.general.hiderepcolor) then
        FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Hide();
    else
        FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Show();
    end
end

function focusframes:HealthBarColor()
    local healthBar = FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBar;
    UberUI.general:SetHealthColor(healthBar, "focus", uuidb.focusframes);

    local healthBar = FocusFrameToT.HealthBar;
    UberUI.general:SetHealthColor(healthBar, "focustarget", uuidb.focusframes);
end

function focusframes:HealthManaBarTexture()
    local focusFrame = FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBar;
    if (uuidb.general.texture ~= "Blizzard") then
        local texture = uuidb.statusbars[uuidb.general.texture];
        focusFrame.HealthBar:SetStatusBarTexture(texture);
        FocusFrameToT.HealthBar:SetStatusBarTexture(texture);

        -- Color bar accordingly
        -- https://wowpedia.fandom.com/wiki/API_UnitPowerDisplayMod
        local focusPowerType = UnitPowerType("focus");
        if (focusPowerType < 4) then
            focusFrame.ManaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[focusPowerType];
            focusFrame.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end

        local focusTotPowerType = UnitPowerType("focustarget");
        if (focusTotPowerType < 4) then
            FocusFrameToT.ManaBar:SetStatusBarTexture(texture);
            local pc = PowerBarColor[focusTotPowerType];
            FocusFrameToT.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end
    end
    if (uuidb.general.secondarybartextures and uuidb.general.secondarybartexture == "Blizzard") then return end
    if (uuidb.general.secondarybartextures or uuidb.general.texture ~= "Blizzard") then
        local texture = uuidb.general.secondarybartextures and uuidb.statusbars[uuidb.general.secondarybartexture] or
            uuidb.statusbars[uuidb.general.texture];
        focusFrame.HealAbsorbBar:SetTexture(texture);
        focusFrame.MyHealPredictionBar:SetTexture(texture);
        focusFrame.OtherHealPredictionBar:SetTexture(texture);
        focusFrame.TotalAbsorbBar:SetTexture(texture);
        focusFrame.TotalAbsorbBar:SetVertexColor(.6, .9, .9, 1);
    end
end

function focusframes:PvPIcon()
    UberUI.general:PvPIcon(FocusFrame.TargetFrameContent.TargetFrameContentContextual);
end

UberUI.focusframes = focusframes
