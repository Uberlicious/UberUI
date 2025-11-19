local addon, ns = ...
local misc = {}
local isLoaded = false

local misc = UberUI:CreateFrame("frame")
misc:RegisterEvent("ADDON_LOADED")
misc:RegisterEvent("PLAYER_ENTERING_WORLD")
misc:RegisterEvent("GROUP_ROSTER_UPDATE")
misc:RegisterEvent("RAID_ROSTER_UPDATE")
misc:RegisterEvent("PLAYER_LEAVE_COMBAT")
misc:RegisterEvent("PLAYER_FOCUS_CHANGED")
misc:RegisterEvent("PLAYER_TARGET_CHANGED")
misc:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        isLoaded = true
        misc:EndCaps()
        misc:StatusTrackingBars()
    elseif event == "ADDON_LOADED" then
        misc:EndCaps()
        misc:StatusTrackingBars()
    end
end)

function misc:EndCaps()
    local dc = uuidb.general.darkencolor;
    MainActionBar.EndCaps.RightEndCap:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    MainActionBar.EndCaps.LeftEndCap:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
end

function misc:StatusTrackingBars()
    local dc = uuidb.general.darkencolor;
    MainStatusTrackingBarContainer.BarFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    SecondaryStatusTrackingBarContainer.BarFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
end

function misc:AllFramesColor()
    self:EndCaps();
    UberUI.playerframes:Color();
    UberUI.targetframes:Color();
    UberUI.focusframes:Color();
    UberUI.minimap:Color();
    UberUI.actionbars:Color();
    UberUI.cdManager:Color();
end

function misc:AllFramesHealthColor()
    UberUI.playerframes:HealthBarColor();
    UberUI.targetframes:HealthBarColor();
    UberUI.focusframes:HealthBarColor();
    UberUI.partyframes:HealthBarColor();
    UberUI.arenaframes:LoopFrames();
end

function misc:AllFramesHealthManaTexture()
    if UberUI.playerframes then UberUI.playerframes:HealthManaBarTexture() end
    if UberUI.targetframes then UberUI.targetframes:HealthManaBarTexture() end
    if UberUI.focusframes then UberUI.focusframes:HealthManaBarTexture() end
    if UberUI.partyframes then UberUI.partyframes:HealthManaBarTexture() end
    if UberUI.playerframes then UberUI.playerframes:ColorAlternatePower() end
    if UberUI.arenaframes then UberUI.arenaframes:LoopFrames() end
end

UberUI.misc = misc
