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
            misc:MicroButtons()
        end)
        misc:ObjectiveTrackerFrames()
    elseif event == "ADDON_LOADED" then
        misc:EndCaps()
        -- We don't call StatusTrackingBars here anymore as it's almost always too early.
    end
end)

function misc:EndCaps()
    local dc = uuidb.general.darkencolor;
    
    local function ColorEndCap(endCap)
        if not endCap then return end
        -- These are Frames (MainMenuBarEndCaps.xml), not Textures, so
        -- SetVertexColor lives on their .Texture child -- checking
        -- type(endCap.SetVertexColor) here can read as a function even though
        -- calling it directly throws "attempt to call a nil value", so we
        -- gate the direct-call branch on the widget's real object type.
        if endCap.Texture and type(endCap.Texture.SetVertexColor) == "function" then
            endCap.Texture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        elseif endCap.IsObjectType and endCap:IsObjectType("Texture") and type(endCap.SetVertexColor) == "function" then
            endCap:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        elseif endCap.GetRegions then
            for _, region in ipairs({endCap:GetRegions()}) do
                if region:IsObjectType("Texture") then
                    region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                end
            end
        end
    end

    if MainActionBar and MainActionBar.EndCaps then
        ColorEndCap(MainActionBar.EndCaps.RightEndCap)
        ColorEndCap(MainActionBar.EndCaps.LeftEndCap)
    else
        ColorEndCap(MainMenuBarLeftEndCap)
        ColorEndCap(MainMenuBarRightEndCap)
    end
end

function misc:StatusTrackingBars()
    local dc = uuidb.general.darkencolor

    local containers = { MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }
    for _, container in ipairs(containers) do
        if container then
            if container.BarFrameTexture then container.BarFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end

            for _, bar in ipairs({ container:GetChildren() }) do
                if bar.barIndex and StatusTrackingBarInfo and bar.barIndex == StatusTrackingBarInfo.BarsEnum.Experience and bar.ExhaustionTick and bar.ExhaustionTick.Normal then
                    bar.ExhaustionTick.Normal:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                end
            end
        end
    end
    
    if MainMenuExpBar and MainMenuExpBar.Texture then
        -- Handle classic exp bar if needed
    end
    if ReputationWatchBar and ReputationWatchBar.StatusBar then
        -- Handle classic rep bar if needed
    end
end

function misc:ObjectiveTrackerFrames()
    local dc = uuidb.general.darkencolor
    if ObjectiveTrackerFrame then
        if ObjectiveTrackerFrame.Header and ObjectiveTrackerFrame.Header.Background then
            ObjectiveTrackerFrame.Header.Background:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        end
        for _, frame in ipairs({ ObjectiveTrackerFrame:GetChildren() }) do
            if frame.Header and frame.Header.Background then
                frame.Header.Background:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
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

                local nt = (self.GetName and self:GetName() and _G[self:GetName() .. "NormalTexture"]) or self.NormalTexture or (self.GetNormalTexture and self:GetNormalTexture())
                if nt then nt:SetVertexColor(r, g, b, dc.a) end
            end)
        end

        if MainMenuBarBagManager then
            hooksecurefunc(MainMenuBarBagManager, "OnExpandBarChanged", function()
                misc:BagSlots()
            end)
        end
        misc.hookedBags = true
    end

    local function DarkenBag(bag, isBackpack)
        if not bag then return end
        local r, g, b = dc.r, dc.g, dc.b
        if isBackpack then
            r, g, b = (r + 1) / 2, (g + 1) / 2, (b + 1) / 2
        end
        local nt = (bag.GetName and bag:GetName() and _G[bag:GetName() .. "NormalTexture"]) or bag.NormalTexture or (bag.GetNormalTexture and bag:GetNormalTexture())
        if nt then nt:SetVertexColor(r, g, b, dc.a) end
        if bag.IconBorder then bag.IconBorder:SetVertexColor(r, g, b, dc.a) end
        if bag.SlotHighlightTexture then bag.SlotHighlightTexture:SetVertexColor(r, g, b, dc.a) end
    end

    if BagsBar and BagsBar.BorderArt then
        BagsBar.BorderArt:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end

    local bagNames = {
        "CharacterBag0Slot",
        "CharacterBag1Slot",
        "CharacterBag2Slot",
        "CharacterBag3Slot",
        "CharacterReagentBag0Slot",
        "MainMenuBarBackpackButton",
    }

    for _, bagName in ipairs(bagNames) do
        local bag = _G[bagName]
        if bag then
            local isBackpack = (bagName == "MainMenuBarBackpackButton")
            DarkenBag(bag, isBackpack)
            if not bag._uberHooked and bag.UpdateTextures then
                hooksecurefunc(bag, "UpdateTextures", function(self) DarkenBag(self, isBackpack) end)
                bag._uberHooked = true
            end
        end
    end

    -- Forever-specific and Classic bag extras
    if MicroMenu and MicroMenu.BorderArt then
        MicroMenu.BorderArt:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end
    
    -- Reagent bag slots (Retail / Custom)
    for i = 0, 3 do
        local rBag = _G["CharacterReagentBag"..i.."Slot"]
        if rBag then
            local nt = (rBag.GetName and rBag:GetName() and _G[rBag:GetName() .. "NormalTexture"]) or rBag.NormalTexture or (rBag.GetNormalTexture and rBag:GetNormalTexture())
            if nt then nt:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end
        end
    end
    
    -- Keyring (Classic / Forever)
    if KeyRingButton then
        local nt = (KeyRingButton.GetName and KeyRingButton:GetName() and _G[KeyRingButton:GetName() .. "NormalTexture"]) or KeyRingButton.NormalTexture or (KeyRingButton.GetNormalTexture and KeyRingButton:GetNormalTexture())
        if nt then nt:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end
    end
end

function misc:MicroButtons()
    local dc = uuidb.general.darkencolor
    local buttons = {
        "CharacterMicroButton",
        "SpellbookMicroButton",
        "TalentMicroButton",
        "AchievementMicroButton",
        "QuestLogMicroButton",
        "GuildMicroButton",
        "LFDMicroButton",
        "CollectionsMicroButton",
        "EJMicroButton",
        "StoreMicroButton",
        "MainMenuMicroButton",
        "HelpMicroButton",
    }
    
    if MicroMenu then
        for _, child in pairs({MicroMenu:GetChildren()}) do
            table.insert(buttons, child:GetName() or "")
            if not child:GetName() then
                if child.Background then child.Background:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end
                if child.NormalTexture then child.NormalTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end
            end
        end
    end

    for _, name in ipairs(buttons) do
        if name ~= "" then
            local btn = _G[name]
            if btn then
                if btn.Background then btn.Background:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end
                -- MicroButton backgrounds are sometimes just a texture called "...MicroButton-BG"
                local bgTexture = _G[name .. "-BG"] or _G[name .. "BG"]
                if bgTexture and type(bgTexture.SetVertexColor) == "function" then
                    bgTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                end
            end
        end
    end
end

function misc:AllFramesColor()
    self:EndCaps();
    self:MicroButtons();
    UberUI.playerframes:Color();
    UberUI.targetframes:Color();
    if UberUI.focusframes then UberUI.focusframes:Color() end
    if UberUI.minimap then UberUI.minimap:Color() end
    if UberUI.actionbars then UberUI.actionbars:Color() end
    if UberUI.cdManager then UberUI.cdManager:Color() end
    if UberUI.damageMeter then UberUI.damageMeter:ForceTexture() end
    if UberUI.buffsandauras then UberUI.buffsandauras:Refresh() end
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
    if UberUI.personalresource then UberUI.personalresource:ForceTexture() end
end

UberUI.misc = misc
