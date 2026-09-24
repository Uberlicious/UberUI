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

-- StatusTrackingBarTemplate's own nested StatusBar is named ".StatusBar" on
-- retail 12.1, but that's evidently not universal -- rather than hardcode
-- another guess, walk the bar itself, its common field names, and finally
-- its direct children looking for whichever one is actually a StatusBar
-- object (that's the only thing SetStatusBarTexture can ever legally live
-- on).
local function FindStatusBarWidget(bar, depth)
    if not bar then return nil end
    if bar.GetObjectType and bar:GetObjectType() == "StatusBar" then
        return bar
    end
    if depth and depth <= 0 then return nil end
    for _, key in ipairs({ "StatusBar", "Bar", "statusBar", "Status" }) do
        local candidate = bar[key]
        if candidate then
            local found = FindStatusBarWidget(candidate, (depth or 1) - 1)
            if found then return found end
        end
    end
    if bar.GetChildren then
        local ok, kids = pcall(function() return { bar:GetChildren() } end)
        if ok then
            for _, child in ipairs(kids) do
                local found = FindStatusBarWidget(child, (depth or 1) - 1)
                if found then return found end
            end
        end
    end
    return nil
end

-- Confirmed against the live Blizzard_StatusTrackingBar source (Shared/
-- ExpBar.lua + Mainline/ExpBarOverrides.lua + Mainline/ReputationBarOverrides.lua,
-- which the "Family" toc line loads for BOTH mainline retail and Forever's
-- "camelot" game type): XP and reputation have no vertex-color tint at all.
-- ExpBarMixin:UpdateStatusBarTextures(isRested) and
-- ReputationStatusBarMixin:UpdateBarTextures(reactionLevel, overrideUseBlueBar)
-- both just swap in a different pre-colored ATLAS via self.StatusBar:SetBarTexture(...)
-- -- for XP, "rested" vs not; for reputation, one atlas per FACTION_BAR_COLORS
-- reaction level. Both mixins call this from their own :Update(), which
-- fires on essentially every XP/rep change -- so a one-shot texture swap
-- gets silently clobbered back to Blizzard's atlas the next time either
-- fires. Hooking the real function is what makes the flat texture (and a
-- matching tint) actually stick.
-- Sampled directly from the exported UIExperienceBarCamelot.BLP pixel data
-- (BLP2, uncompressed BGRA8888) at the atlas's real texture-coordinate
-- rectangle -- this client's native XP fill is actually a warm gold/amber,
-- not the blue of vanilla-era clients.
local XP_BAR_COLOR = { r = 0.89, g = 0.76, b = 0.55 }
local FACTION_REACTION_BLUE = { r = 0.10, g = 0.60, b = 0.95 } -- major faction/friendship "blue bar" case, not yet sampled

-- Disabled for now -- not working correctly, revisit later. Code below is
-- left in place (helpers, hooks, color sampling all already done) so this
-- is a one-line flip to re-enable rather than a redo.
local XP_REP_RETEXTURE_ENABLED = false

local function ApplyBarSkin(statusBar, color)
    local applyCustomLook = (uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard")
    if not applyCustomLook then return end
    local texture = uuidb.statusbars[uuidb.general.texture]
    if not (texture and statusBar and statusBar.BarTexture and statusBar.BarTexture.SetTexture) then return end
    statusBar.BarTexture:SetTexture(texture)
    if color then
        statusBar.BarTexture:SetVertexColor(color.r, color.g, color.b)
    end
end

local _uberBarHooksInstalled = false
local function EnsureBarHooks()
    if not XP_REP_RETEXTURE_ENABLED then return end
    if _uberBarHooksInstalled then return end
    _uberBarHooksInstalled = true

    if ExpBarMixin and ExpBarMixin.UpdateStatusBarTextures then
        hooksecurefunc(ExpBarMixin, "UpdateStatusBarTextures", function(self)
            ApplyBarSkin(FindStatusBarWidget(self, 2), XP_BAR_COLOR)
        end)
    end

    if ReputationStatusBarMixin and ReputationStatusBarMixin.UpdateBarTextures then
        hooksecurefunc(ReputationStatusBarMixin, "UpdateBarTextures", function(self, reactionLevel, overrideUseBlueBar)
            local color = FACTION_REACTION_BLUE
            if not overrideUseBlueBar and reactionLevel and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reactionLevel] then
                local c = FACTION_BAR_COLORS[reactionLevel]
                color = { r = c.r, g = c.g, b = c.b }
            end
            ApplyBarSkin(FindStatusBarWidget(self, 2), color)
        end)
    end
end

function misc:StatusTrackingBars()
    local dc = uuidb.general.darkencolor
    local applyCustomLook = (uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard")
    local texture = applyCustomLook and uuidb.statusbars[uuidb.general.texture]

    EnsureBarHooks()

    -- XP/reputation/honor (retail 12.1 AND Forever 1.60.1 both use this
    -- shared container system) render as children of these containers, but
    -- each child (StatusTrackingBarTemplate) is a plain Frame wrapping the
    -- actual StatusBar rather than being one itself -- see
    -- FindStatusBarWidget above.
    local containers = { MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }
    for _, container in ipairs(containers) do
        if container then
            if container.BarFrameTexture then container.BarFrameTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end

            for _, bar in ipairs({ container:GetChildren() }) do
                local isExperience = bar.barIndex and StatusTrackingBarInfo and bar.barIndex == StatusTrackingBarInfo.BarsEnum.Experience
                local isReputation = bar.barIndex and StatusTrackingBarInfo and bar.barIndex == StatusTrackingBarInfo.BarsEnum.Reputation
                if isExperience and bar.ExhaustionTick and bar.ExhaustionTick.Normal then
                    bar.ExhaustionTick.Normal:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                end

                if isExperience and XP_REP_RETEXTURE_ENABLED and texture and bar.UpdateStatusBarTextures then
                    -- ExpBarMixin:Update() only reaches UpdateStatusBarTextures
                    -- when the player is capped at max level -- for a normal
                    -- leveling character it just updates the bar's fill value
                    -- and never touches the texture at all. Call the real
                    -- function directly instead, with the same isRested
                    -- Blizzard itself would compute.
                    pcall(bar.UpdateStatusBarTextures, bar, GetRestState() == 1)
                elseif isReputation and XP_REP_RETEXTURE_ENABLED and texture and bar.Update then
                    -- ReputationStatusBarMixin:Update() calls UpdateBarTextures
                    -- unconditionally, so nudging it is enough here.
                    pcall(bar.Update, bar)
                elseif not isExperience and not isReputation and texture then
                    local statusBar = FindStatusBarWidget(bar, 2)
                    if statusBar then
                        -- Confirmed in-game: this bar's fill is exposed as
                        -- StatusBar.BarTexture (a plain Texture region), not
                        -- via a working SetStatusBarTexture() call -- set
                        -- the region directly, and still try the method as
                        -- a harmless belt-and-suspenders fallback.
                        if statusBar.BarTexture and statusBar.BarTexture.SetTexture then
                            statusBar.BarTexture:SetTexture(texture)
                        elseif statusBar.SetStatusBarTexture then
                            statusBar:SetStatusBarTexture(texture)
                        end
                    end
                end
            end
        end
    end

    -- Classic-family (Forever): XP/reputation are their own standalone
    -- StatusBar widgets, not children of a shared container.
    if XP_REP_RETEXTURE_ENABLED and texture and MainMenuExpBar and MainMenuExpBar.SetStatusBarTexture then
        MainMenuExpBar:SetStatusBarTexture(texture)
    end
    if XP_REP_RETEXTURE_ENABLED and texture and ReputationWatchBar and ReputationWatchBar.StatusBar and ReputationWatchBar.StatusBar.SetStatusBarTexture then
        ReputationWatchBar.StatusBar:SetStatusBarTexture(texture)
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

-- Finds a bag/keyring button's actual normal-texture region. Blizzard
-- names these three different ways depending on template/game type: an
-- auto-generated global ("<buttonName>NormalTexture", the classic
-- <NormalTexture> XML convention -- e.g. MainMenuBarBackpackButtonNormalTexture),
-- a parentKey field, or only reachable through the Button API's own
-- GetNormalTexture(). Tries all three so darkening doesn't silently no-op
-- if a beta client's template chain (Forever/"camelot" excludes some of
-- the templates other game types load) leaves one path broken.
local function FindBagNormalTexture(bag)
    if not bag then return nil end
    local okName, name = pcall(bag.GetName, bag)
    if okName and name and _G[name .. "NormalTexture"] then
        return _G[name .. "NormalTexture"]
    end
    if bag.NormalTexture then
        return bag.NormalTexture
    end
    if bag.GetNormalTexture then
        local ok, nt = pcall(bag.GetNormalTexture, bag)
        if ok and nt then return nt end
    end
    return nil
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

                local nt = FindBagNormalTexture(self)
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
        local nt = FindBagNormalTexture(bag)
        if nt then nt:SetVertexColor(r, g, b, dc.a) end
        if bag.IconBorder then bag.IconBorder:SetVertexColor(r, g, b, dc.a) end
        if bag.SlotHighlightTexture then bag.SlotHighlightTexture:SetVertexColor(r, g, b, dc.a) end
    end

    -- Explicit belt-and-suspenders: MainMenuBarBackpackButtonBase (the
    -- mixin/template MainMenuBarBackpackButton is supposed to inherit) is
    -- only defined for the "mainline" game type in Blizzard's own .toc --
    -- excluded for Forever's "camelot" type, whose own XML still tries to
    -- inherit from it. If that leaves GetNormalTexture() unreliable on
    -- this button specifically, the raw auto-named global still isn't.
    if MainMenuBarBackpackButtonNormalTexture then
        local r, g, b = (dc.r + 1) / 2, (dc.g + 1) / 2, (dc.b + 1) / 2
        MainMenuBarBackpackButtonNormalTexture:SetVertexColor(r, g, b, dc.a)
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
    if UberUI.nameplates then UberUI.nameplates:ForceNameplateTexture() end
    misc:StatusTrackingBars()
end

UberUI.misc = misc
