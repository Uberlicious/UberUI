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
        -- We delay the call by a second to give the default UI time to create the bars
        -- before we try to skin them. This helps solve the timing issue.
        C_Timer.After(1, function()
            misc:StatusTrackingBars()
            misc:BagSlots()
        end)
        misc:ObjectiveTrackerFrames()
    elseif event == "ADDON_LOADED" then
        misc:EndCaps()
        -- We don't call StatusTrackingBars here anymore as it's almost always too early.
    end
end)

function misc:EndCaps()
    local dc = uuidb.general.darkencolor;
    MainActionBar.EndCaps.RightEndCap:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    MainActionBar.EndCaps.LeftEndCap:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
end

function misc:StatusTrackingBars()
    local dc = uuidb.general.darkencolor

    local containers = { MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }
    for _, container in ipairs(containers) do
        if container then
            container.BarFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)

            -- Also find the XP bar to darken its exhaustion tick
            for _, bar in ipairs({ container:GetChildren() }) do
                if bar.barIndex and bar.barIndex == StatusTrackingBarInfo.BarsEnum.Experience and bar.ExhaustionTick and bar.ExhaustionTick.Normal then
                    bar.ExhaustionTick.Normal:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                end
            end
        end
    end
end

function misc:ObjectiveTrackerFrames()
    local dc = uuidb.general.darkencolor
    ObjectiveTrackerFrame.Header.Background:SetVertexColor(dc.r, dc.g, dc.b, dc.a)

    for _, frame in ipairs({ ObjectiveTrackerFrame:GetChildren() }) do
        if frame.Header then
            frame.Header.Background:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        end
    end
end

function misc:BagSlots()
    local dc = uuidb.general.darkencolor

    if not misc.hookedBags then
        if BaseBagSlotButtonMixin then
            hooksecurefunc(BaseBagSlotButtonMixin, "UpdateTextures", function(self)
                local dc = uuidb.general.darkencolor
                local r, g, b = dc.r, dc.g, dc.b
                if self:GetName() == "MainMenuBarBackpackButton" then
                    r, g, b = (r + 1) / 2, (g + 1) / 2, (b + 1) / 2
                end

                if self:GetName() and _G[self:GetName() .. "NormalTexture"] then
                    _G[self:GetName() .. "NormalTexture"]:SetVertexColor(r, g, b, dc.a)
                elseif self.NormalTexture then
                    self.NormalTexture:SetVertexColor(r, g, b, dc.a)
                end
            end)
        end

        if MainMenuBarBagManager then
            hooksecurefunc(MainMenuBarBagManager, "OnExpandBarChanged", function()
                misc:BagSlots()
            end)
        end
        misc.hookedBags = true
    end

    for _, bag in ipairs({ BagsBar:GetChildren() }) do
        local r, g, b = dc.r, dc.g, dc.b
        if bag:GetName() == "MainMenuBarBackpackButton" then
            r, g, b = (r + 1) / 2, (g + 1) / 2, (b + 1) / 2
        end

        if bag:GetName() and _G[bag:GetName() .. "NormalTexture"] then
            _G[bag:GetName() .. "NormalTexture"]:SetVertexColor(r, g, b, dc.a)
        elseif bag.NormalTexture then
            bag.NormalTexture:SetVertexColor(r, g, b, dc.a)
        end
    end
end

function misc:AllFramesColor()
    self:EndCaps();
    UberUI.playerframes:Color();
    UberUI.targetframes:Color();
    UberUI.focusframes:Color();
    UberUI.minimap:Color();
    UberUI.actionbars:Color();
    UberUI.cdManager:Color();
    UberUI.damageMeter:ForceTexture()
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
