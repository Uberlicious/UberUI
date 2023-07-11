local addon, ns = ...
local misc = {}


local misc = CreateFrame("frame")
misc:RegisterEvent("PLAYER_ENTERING_WORLD")
misc:RegisterEvent("GROUP_ROSTER_UPDATE")
misc:RegisterEvent("RAID_ROSTER_UPDATE")
misc:RegisterEvent("PLAYER_LEAVE_COMBAT")
misc:RegisterEvent("PLAYER_FOCUS_CHANGED")
misc:SetScript("OnEvent", function(self, event)
    misc:NameplateTexture();
    misc:EndCaps();
    misc:StatusTrackingBars();
end)

local nthook = false
function misc:NameplateTexture()
    local texture = uuidb.statusbars[uuidb.general.texture];
    if nthook then return end
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
        if not frame:IsForbidden() and frame.healthBar ~= nil and
            not
            (frame:GetName() ~= nil and (frame:GetName():find("CompactRaid") or frame:GetName():find("CompactParty"))) then
            local player = UnitIsUnit(frame.unit, "player");
            if (player and uuidb.general.ccpersonalresource) then
                local classColor = RAID_CLASS_COLORS[select(2, UnitClass("player"))];
                frame.healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b);
            end
            if (uuidb.general.hidenameplateglow) then
                frame.selectionHighlight:SetAlpha(0);
            else
                frame.selectionHighlight:SetAlpha(.24);
            end

            local texture = uuidb.statusbars[uuidb.general.texture]
            frame.healthBar:SetStatusBarTexture(texture);
            frame.healthBar:SetStatusBarDesaturated(true);

            if (uuidb.general.secondarybartextures and uuidb.general.secondarybartexture == "Blizzard") then return end
            if (uuidb.general.secondarybartextures or uuidb.general.texture ~= "Blizzard") then
                local texture = uuidb.general.secondarybartextures and
                    uuidb.statusbars[uuidb.general.secondarybartexture] or
                    uuidb.statusbars[uuidb.general.texture];
                frame.myHealPrediction:SetTexture(texture);
                frame.otherHealPrediction:SetTexture(texture);
                frame.totalAbsorb:SetTexture(texture);
                frame.totalAbsorb:SetVertexColor(.6, .9, .9, 1);
            end
            ClassNameplateManaBarFrame:SetStatusBarTexture(texture);
            ClassNameplateManaBarFrame:SetStatusBarDesaturated(true);
        end
    end)
    nthook = true
end

function misc:EndCaps()
    local dc = uuidb.general.darkencolor;
    MainMenuBar.EndCaps.RightEndCap:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    MainMenuBar.EndCaps.LeftEndCap:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
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
end

function misc:AllFramesHealthColor()
    UberUI.playerframes:HealthBarColor();
    UberUI.targetframes:HealthBarColor();
    UberUI.focusframes:HealthBarColor();
    UberUI.partyframes:HealthBarColor();
    UberUI.arenaframes:LoopFrames();
end

function misc:AllFramesHealthManaTexture()
    UberUI.playerframes:HealthManaBarTexture();
    UberUI.targetframes:HealthManaBarTexture();
    UberUI.focusframes:HealthManaBarTexture();
    UberUI.partyframes:HealthManaBarTexture();
    UberUI.raidframes:HealthManaBarTexture();
    UberUI.playerframes:ColorAlternatePower();
    UberUI.arenaframes:LoopFrames();
end

UberUI.misc = misc
