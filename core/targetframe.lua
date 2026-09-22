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
targetframes:RegisterEvent("PLAYER_REGEN_ENABLED")
targetframes:RegisterEvent("UNIT_TARGET")
targetframes:RegisterUnitEvent("UNIT_HEALTH", "target")
targetframes:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
targetframes:RegisterUnitEvent("UNIT_DISPLAYPOWER", "target")
targetframes:RegisterUnitEvent("UNIT_POWER_UPDATE", "target")
targetframes:RegisterUnitEvent("UNIT_MAXPOWER", "target")
targetframes:RegisterUnitEvent("UNIT_AURA", "target")
targetframes:RegisterEvent("GROUP_ROSTER_UPDATE")
targetframes:RegisterEvent("PARTY_LEADER_CHANGED")
targetframes:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        targetframes:SetupCustomAuraContainer()
    end
    targetframes:Color()
    targetframes:HealthBarColor()
    targetframes:HealthManaBarTexture()
    targetframes:PvPIcon()
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        targetframes:UpdateAuras()
        C_Timer.After(0.05, function()
            targetframes:UpdateAuras()
            targetframes:HealthBarColor()
        end)
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
        targetframes:UpdateAuraPositions()
    elseif event == "UNIT_AURA" then
        targetframes:UpdateAuras()
        C_Timer.After(0.05, function() targetframes:UpdateAuras() end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Force a correctness pass once combat lockdown lifts, in case any
        -- styling was skipped or failed while we were in combat.
        targetframes:UpdateAuras()
    end
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
    local healthBar = (TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain and TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar) or TargetFrameHealthBar
    if healthBar then
        UberUI.general:SetHealthColor(healthBar, "target", uuidb.targetframes)
    end

    local totHealthBar = (TargetFrameToT and TargetFrameToT.HealthBar) or TargetFrameToTHealthBar
    if totHealthBar then
        UberUI.general:SetHealthColor(totHealthBar, "targettarget", uuidb.targetframes)
    end
end

function targetframes:HealthManaBarTexture()
    local targetFrameMain = TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentMain
    local healthBar = (targetFrameMain and targetFrameMain.HealthBarsContainer.HealthBar) or TargetFrameHealthBar
    local manaBar = (targetFrameMain and targetFrameMain.ManaBar) or TargetFrameManaBar

    local totHealthBar = (TargetFrameToT and TargetFrameToT.HealthBar) or TargetFrameToTHealthBar
    local totManaBar = (TargetFrameToT and TargetFrameToT.ManaBar) or TargetFrameToTManaBar

    local textureToApply
    if uuidb.general.targetbartextures then
        if uuidb.general.targetbartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.targetbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply then
        if healthBar then healthBar:SetStatusBarTexture(textureToApply) end
        if totHealthBar then totHealthBar:SetStatusBarTexture(textureToApply) end

        local targetPowerType = UnitPowerType("target")
        if (targetPowerType and targetPowerType < 4) and manaBar then
            manaBar:SetStatusBarTexture(textureToApply)
            local pc = PowerBarColor[targetPowerType]
            manaBar:SetStatusBarDesaturated(true)
            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b)
        end

        local totPowerType = UnitPowerType("targettarget")
        if (totPowerType and totPowerType < 4) and totManaBar then
            totManaBar:SetStatusBarTexture(textureToApply)
            local pc = PowerBarColor[totPowerType]
            totManaBar:SetStatusBarDesaturated(true)
            totManaBar:SetStatusBarColor(pc.r, pc.g, pc.b)
        end
    end
    local secondaryTextureToApply
    if uuidb.general.secondarybartextures then
        if uuidb.general.secondarybartexture ~= "Blizzard" then
            secondaryTextureToApply = uuidb.statusbars[uuidb.general.secondarybartexture]
        end
    else
        secondaryTextureToApply = textureToApply
    end

    if secondaryTextureToApply and healthBar then
        if healthBar.HealAbsorbBar then healthBar.HealAbsorbBar.Fill:SetTexture(secondaryTextureToApply) end
        if healthBar.MyHealPredictionBar then healthBar.MyHealPredictionBar.Fill:SetTexture(secondaryTextureToApply) end
        if healthBar.OtherHealPredictionBar then healthBar.OtherHealPredictionBar.Fill:SetTexture(secondaryTextureToApply) end
        if healthBar.TotalAbsorbBar then
            healthBar.TotalAbsorbBar.Fill:SetTexture(secondaryTextureToApply)
            healthBar.TotalAbsorbBar.Fill:SetVertexColor(.7, .9, .9, 1)
        end
    end
end

local function IsSecret(v)
    return (issecretvalue and issecretvalue(v))
end

local function SafeBool(v)
    if v == nil or IsSecret(v) then return false end
    return (v == true)
end

local function SafeIsForbidden(frame)
    if not frame or IsSecret(frame) then return true end
    local ok, isForbid = pcall(frame.IsForbidden, frame)
    if not ok then return true end
    return SafeBool(isForbid)
end

local function IsEnemyTarget()
    if not UnitExists("target") then return false end
    if UnitIsUnit("player", "target") then return false end
    if UnitCanAttack("player", "target") then return true end
    return not UnitIsFriend("player", "target")
end

-- AddDispelTypeTexture is denied outright while aura data is in a "secret"/
-- restricted window (C_Secrets.ShouldAurasBeSecret, e.g. around loading
-- screens and zone transitions) -- it doesn't error so much as refuse to take
-- effect, so a single attempt made once at button-creation time can silently
-- and permanently fail if it lands in one. We instead retry on every style
-- pass until button.dispelBorderTex actually gets set.
--
-- A button's group (see SetupCustomAuraContainer: debuffs_mine/debuffs_other
-- vs buffs_mine/buffs_other) permanently fixes whether it's a buff or debuff
-- button for its entire lifetime -- buttons are never reclassified between
-- roles -- so only one registration, matching that fixed role, is ever
-- needed per button.
-- Stock target frames show a plain, always-white stealable indicator on a
-- dispellable enemy buff -- confirmed both visually (reference screenshot,
-- everything set to "none" -- pure stock rendering) and in source
-- (Interface/AddOns/Blizzard_UnitFrame/Shared/TargetFrameAuraButton.xml:
-- StealableBorder is a plain file texture, Interface\TargetingFrame\
-- UI-TargetingFrame-Stealable, alphaMode="ADD" -- not part of the
-- dispel-type-color system at all, just a fixed-appearance texture toggled
-- by auraData.isStealable). We already build exactly that texture as
-- button.stealable (same file, same ADD blend) -- it just couldn't be shown
-- reliably because auraData.isStealable is secret to addon code for enemy
-- units. Rather than fight AddDispelTypeTexture's color system (which is
-- fundamentally about per-dispel-type coloring, the wrong tool for a plain
-- binary indicator) with a customDispelColorMap override of uncertain
-- reliability, register button.stealable itself with stealableFilter: the
-- engine decides show/hide from the real isStealable flag, and our texture's
-- own art (already correct, already additive) does the rest -- no color
-- override needed at all.
local function TryRegisterDispelBorder(button)
    if type(button.AddDispelTypeTexture) ~= "function" then return end
    if not (Enum and Enum.CustomAuraButtonDispelTypeTextureStyle) then return end

    if button.isBuff then
        if button.stealableRegistered or not button.stealable then return end
        local preserveAsset = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
        if not preserveAsset then return end
        local options = {
            style = preserveAsset,
            showWhenHarmful = false,
            showWhenHelpful = true,
            showWithoutDispelType = true,
            stealableFilter = Enum.CustomAuraButtonDispelTypeStealableFilter and
            Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable,
        }
        local okAdd, addErr = pcall(button.AddDispelTypeTexture, button, button.stealable, options)
        if okAdd then
            button.stealableRegistered = truee
        end
        button.dispelRegOk = okAdd
        button.dispelRegErr = (not okAdd) and tostring(addErr) or nil
    else
        if button.dispelBorderTex or not button.dispelBorderTexPending then return end
        -- Border: hands the engine both the atlas selection and the color
        -- (AuraUtil.SetAuraBorderAtlas + color together, the same mechanism
        -- Blizzard's own native aura frames use for debuffs), so it doesn't
        -- depend on our own art being tintable correctly.
        local borderStyle = Enum.CustomAuraButtonDispelTypeTextureStyle.Border
        if not borderStyle then return end
        local options = {
            style = borderStyle,
            showWhenHarmful = true,
            showWhenHelpful = false,
            showWithoutDispelType = true,
        }
        local okAdd, addErr = pcall(button.AddDispelTypeTexture, button, button.dispelBorderTexPending, options)
        if okAdd then
            button.dispelBorderTex = button.dispelBorderTexPending
            button.dispelBorderTexPending = nil
        end
        button.dispelRegOk = okAdd
        button.dispelRegErr = (not okAdd) and tostring(addErr) or nil
    end
end

-- isBuff is not passed in: it's fixed permanently at button creation (see
-- InitAuraButton) based on which of the four permanent aura groups the
-- button belongs to, so button.isBuff is always authoritative.
function targetframes:UpdateAuraButtonStyle(button)
    if not button or IsSecret(button) then return end
    -- Deliberately NOT bailing out on SafeIsForbidden(button) here: a
    -- forbidden AuraButton rejects some addon calls (SetSize etc.) but not
    -- necessarily all of them -- confirmed in testing, since border show/
    -- hide reliably succeeds mid-combat while other operations sometimes
    -- don't. Every actual widget call below is already individually
    -- pcall-wrapped, so bailing out here only cost us whatever WOULD have
    -- succeeded, for no added safety.
    TryRegisterDispelBorder(button)

    local isBuff = button.isBuff

    local style = "both"
    if uuidb and uuidb.general then
        style = isBuff and (uuidb.general.aurastyle_targetbuffs or "both") or
        (uuidb.general.aurastyle_targetdebuffs or "zoom")
    end

    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    if button.icon then
        pcall(function()
            button.icon:ClearAllPoints()
            if darkBorderEnabled or zoomEnabled then
                button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
                button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            else
                button.icon:SetAllPoints(button)
            end
            if zoomEnabled then
                button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                button.icon:SetTexCoord(0, 1, 0, 1)
            end
        end)
    end

    if button.elementSize then
        pcall(button.SetSize, button, button.elementSize, button.elementSize)
    end

    if button.cooldown then
        pcall(button.cooldown.SetDrawSwipe, button.cooldown, true)
        pcall(button.cooldown.SetDrawEdge, button.cooldown, true)
    end

    if button.borderHost then
        pcall(function()
            local pad = (button.elementSize and button.elementSize >= 20) and 3 or 2
            button.borderHost:ClearAllPoints()
            button.borderHost:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
            button.borderHost:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)

            if button.borderTex then
                button.borderTex:ClearAllPoints()
                button.borderTex:SetAllPoints(button.borderHost)
            end

            -- This AuraContainer widget's buttons have no native border texture
            -- field of their own to fall back on (confirmed via runtime
            -- inspection -- DebuffBorder/DispelBorder/Border/border are all nil
            -- here), so "stock" for us means reproducing Blizzard's own target
            -- frame behavior ourselves: no border at all on buffs, and a border
            -- tinted with the real dispel-type color on debuffs.
            --
            -- We can't compute that color ourselves: auraData.dispelName reads
            -- back as a secret value to addon code under 12.1's security model
            -- (Blizzard's own TargetFrameDebuffButtonPrivateMixin can read it
            -- fine because that callback runs as trusted code, not because the
            -- field itself is open). Reading it manually (the previous fix)
            -- silently always fell back to DEBUFF_DISPLAY_INFO["None"]'s color,
            -- which is why every debuff -- dispellable or not -- came out the
            -- same dark shade. The sanctioned way for addon code to get this is
            -- CustomAuraButtonSharedMixin:AddDispelTypeTexture, which hands a
            -- texture's Shown/VertexColor/TexCoords/Alpha over to Blizzard's own
            -- trusted coloring code (see Blizzard_CustomAuraButton.lua). We
            -- register button.dispelBorderTex once (below, on button
            -- creation/recycle) and from here on just show or hide the frame
            -- that hosts it -- we never touch its color again.
            local function ApplyDarkBorder()
                button.borderHost:Show()
                -- Dark/Both/Border styles normally hide the dispel overlay
                -- entirely (a deliberate, uniform darkened look). For buffs
                -- specifically, "Show Dispels for Target Buffs" lets the
                -- engine-managed white stealable border show through on top
                -- of that dark tint instead of being replaced by it --
                -- dispelBorderHost is a child frame of borderHost, so it
                -- renders above borderTex's texture automatically.
                local showDispelOverlay = isBuff and uuidb and uuidb.general and
                uuidb.general.targetbuffs_showdispel
                if button.dispelBorderHost then
                    if showDispelOverlay then
                        button.dispelBorderHost:Show()
                    else
                        button.dispelBorderHost:Hide()
                    end
                end
                if button.borderTex then
                    button.borderTex:Show()
                    button.borderTex:SetAtlas("ui-debuff-border-default-noicon")
                    button.borderTex:SetDesaturated(true)
                    local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or
                    { r = 0.4, g = 0.4, b = 0.4, a = 1 }
                    button.borderTex:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                end
            end

            local function ApplyNoBorder()
                -- Blizzard's stock target frame never draws a border on buffs.
                button.borderHost:Hide()
                if button.borderTex then button.borderTex:Hide() end
                if button.dispelBorderHost then button.dispelBorderHost:Hide() end
            end

            -- Used for both buffs (an enhancement over stock: a dispellable/
            -- stealable buff gets its own dispel-colored border, which
            -- stealableFilter on registration means the engine itself only
            -- ever shows for buffs that are actually stealable) and debuffs
            -- (the real dispel-type color, matching stock target frames).
            -- Which behavior applies is entirely decided by the fixed
            -- registration options in TryRegisterDispelBorder, not here.
            -- local function ApplyDispelColoredBorder()
            --     button.borderHost:Show()
            --     if button.borderTex then button.borderTex:Hide() end
            --     if button.dispelBorderHost then
            --         -- Engine-managed: Blizzard colors button.dispelBorderTex
            --         -- itself on every aura update once it's shown.
            --         --button.dispelBorderHost:Show()
            --     elseif button.borderTex then
            --         -- Fallback for buttons that couldn't register a dispel-type
            --         -- texture (e.g. AddDispelTypeTexture unavailable) -- plain
            --         -- white leaves the base atlas showing as-is rather than an
            --         -- incorrect color.
            --         button.borderTex:Show()
            --         button.borderTex:SetAtlas("ui-debuff-border-default-noicon")
            --         button.borderTex:SetDesaturated(true)
            --         button.borderTex:SetVertexColor(1, 1, 1, 1)
            --     end
            -- end

            if darkBorderEnabled then
                ApplyDarkBorder()
            else
                -- ApplyDispelColoredBorder()
            end

            -- button.stealable is only ever registered (see
            -- TryRegisterDispelBorder) for buffs, and once registered its
            -- Shown/VertexColor/Alpha/TexCoords become engine-controlled --
            -- we can't call :Show()/:Hide() on it ourselves anymore (that's
            -- the whole point: the engine decides visibility from the real,
            -- otherwise-secret isStealable flag). Debuff buttons' copy is
            -- never registered, so it's still safe to just leave it hidden.
            if not isBuff and button.stealable then
                button.stealable:Hide()
            end
        end)
    end
end

local TOP_X = 25
local TOP_Y = 26
local TOP_ON_TOP_X = 5
local LARGE_AURA_SIZE = 21
local SMALL_AURA_SIZE = 16
local AURA_SPACING = 1
local CONTAINER_GAP = 2

local function MakeGroupLayout(elementSize, spacingX, spacingY, forceNewLine, layoutIndex)
    return {
        elementWidth = elementSize,
        elementHeight = elementSize,
        elementSpacing = spacingX or AURA_SPACING,
        lineSpacing = (spacingY or AURA_SPACING) + 2,
        groupSpacing = -1,
        groupLineSpacing = (spacingY or AURA_SPACING) + 2,
        forceNewLine = forceNewLine or false,
        layoutIndex = layoutIndex,
    }
end

-- Restyle every aura button currently active in one of a container's two
-- permanent groups (see SetupCustomAuraContainer: each of the debuff and
-- buff containers has its own "mine"/"other" pair), using the container's
-- own authoritative group membership (GetAuraGroupFrameCount/GetAuraGroupFrame)
-- rather than any addon-cached per-button state. A group's harmful/helpful
-- identity and its container never change, so buttons are never reclassified
-- between buff and debuff roles -- each button's role is fixed for its
-- entire lifetime by which group it was created in.
local function ForEachActiveAuraButton(container, keyMine, keyOther, callback)
    if not container or type(container.GetAuraGroupFrameCount) ~= "function"
        or type(container.GetAuraGroupFrame) ~= "function" then
        return
    end

    local function visitGroup(groupKey)
        local okCount, count = pcall(container.GetAuraGroupFrameCount, container, groupKey)
        if not okCount or type(count) ~= "number" then return end
        for i = 1, count do
            local okFrame, btn = pcall(container.GetAuraGroupFrame, container, groupKey, i)
            if okFrame and btn and not IsSecret(btn) then
                callback(btn)
            end
        end
    end

    visitGroup(keyMine)
    visitGroup(keyOther)
end

local function RefreshContainerButtons(container, keyMine, keyOther)
    if not container then return end
    ForEachActiveAuraButton(container, keyMine, keyOther, function(btn)
        pcall(targetframes.UpdateAuraButtonStyle, targetframes, btn)
    end)
end

local function GetLeaderIcon(frame)
    if not frame then return nil end
    local contextual = frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentContextual
    if contextual then
        local leader = contextual.LeaderIcon
        if leader and leader:IsShown() then return leader end
        local guide = contextual.GuideIcon
        if guide and guide:IsShown() then return guide end
    end
    if frame.LeaderIcon and frame.LeaderIcon:IsShown() then return frame.LeaderIcon end
    if frame.leaderIcon and frame.leaderIcon:IsShown() then return frame.leaderIcon end
    local globalLeader = frame.GetName and _G[frame:GetName() .. "LeaderIcon"]
    if globalLeader and globalLeader:IsShown() then return globalLeader end
    return nil
end

local isAdjustingSpellbar = false
local function UpdateSpellbar(frameObj, containers)
    if InCombatLockdown() then return end
    if not frameObj then return end
    local spellbar = frameObj.spellbar or (frameObj.GetName and _G[frameObj:GetName() .. "SpellBar"])
    if not spellbar then return end

    if frameObj.buffsOnTop then
        frameObj.auraRows = 0
        frameObj.spellbarAnchor = nil
        if not isAdjustingSpellbar and spellbar.AdjustPosition then
            isAdjustingSpellbar = true
            pcall(spellbar.AdjustPosition, spellbar)
            isAdjustingSpellbar = false
        end
        return
    end

    local visibleButtons = {}
    if containers then
        for _, container in ipairs(containers) do
            if container and container.allButtons and container:IsShown() then
                for button in pairs(container.allButtons) do
                    if button and not IsSecret(button) and not SafeIsForbidden(button) then
                        local okS, isShown = pcall(button.IsShown, button)
                        if okS and SafeBool(isShown) then
                            local okB, bottom = pcall(button.GetBottom, button)
                            local okL, left = pcall(button.GetLeft, button)
                            if okB and okL and bottom and left and not IsSecret(bottom) and not IsSecret(left) then
                                table.insert(visibleButtons, { btn = button, bottom = bottom, left = left })
                            end
                        end
                    end
                end
            end
        end
    end

    if #visibleButtons == 0 then
        frameObj.auraRows = 0
        frameObj.spellbarAnchor = nil
        if not isAdjustingSpellbar and spellbar.AdjustPosition then
            isAdjustingSpellbar = true
            pcall(spellbar.AdjustPosition, spellbar)
            isAdjustingSpellbar = false
        end
        return
    end

    table.sort(visibleButtons, function(a, b)
        return a.bottom < b.bottom
    end)

    local rows = 1
    local currentBottom = visibleButtons[1].bottom
    for i = 2, #visibleButtons do
        if math.abs(visibleButtons[i].bottom - currentBottom) > 4 then
            rows = rows + 1
            currentBottom = visibleButtons[i].bottom
        end
    end

    local minBottom = visibleButtons[1].bottom
    local lowestLeftBtn = visibleButtons[1].btn
    local minLeft = visibleButtons[1].left
    for _, item in ipairs(visibleButtons) do
        if math.abs(item.bottom - minBottom) <= 4 then
            if item.left < minLeft then
                minLeft = item.left
                lowestLeftBtn = item.btn
            end
        end
    end

    frameObj.auraRows = rows
    frameObj.spellbarAnchor = lowestLeftBtn

    if not isAdjustingSpellbar and spellbar.AdjustPosition then
        isAdjustingSpellbar = true
        pcall(spellbar.AdjustPosition, spellbar)
        isAdjustingSpellbar = false
    end
end

local function HookSpellbarAdjustPosition(spellbar, frameObj, getContainer)
    if not spellbar or not spellbar.AdjustPosition or spellbar._uberUIHooked then return end
    spellbar._uberUIHooked = true
    hooksecurefunc(spellbar, "AdjustPosition", function(self)
        if isAdjustingSpellbar or InCombatLockdown() then return end
        local parent = self:GetParent()
        if parent ~= frameObj then return end
        local containers = getContainer and getContainer()
        if containers then
            UpdateSpellbar(frameObj, containers)
        end
    end)
end

-- Which container (debuffs or buffs) sits directly under the health/mana bar
-- ("primary") vs trails behind it ("secondary") swaps with target hostility:
-- debuffs primary on an enemy, buffs primary on a friendly (including self).
-- This is a plain SetPoint on a container-level frame -- not a per-AuraButton
-- call -- so unlike resizing/recoloring individual buttons, it isn't subject
-- to the forbidden/combat-secrecy restriction and can be redone reliably on
-- every target switch regardless of combat state. The secondary container is
-- anchored relative to the primary container's own edge rather than a fixed
-- offset from TargetFrame, so it automatically re-stacks whenever the
-- primary container's size changes (including collapsing to ~0 size when
-- empty, which is what makes "no buffs -> debuffs sit where buffs would
-- have been" work for free, with no addon-side row-counting needed).
function targetframes:UpdateAuraPositions()
    if not self.customDebuffs or not self.customBuffs or not TargetFrame then return end

    local primary, secondary
    if IsEnemyTarget() then
        primary, secondary = self.customDebuffs, self.customBuffs
    else
        primary, secondary = self.customBuffs, self.customDebuffs
    end

    local buffsOnTop = TargetFrame.buffsOnTop
    primary:ClearAllPoints()
    secondary:ClearAllPoints()

    if buffsOnTop then
        local ref = (TargetFrame.TargetFrameContainer and TargetFrame.TargetFrameContainer.FrameTexture) or TargetFrame
        local offsetX = (ref == TargetFrame) and TOP_X or TOP_ON_TOP_X
        local startY = -6
        local extraY = 0
        if TargetFrame.threatNumericIndicator and TargetFrame.threatNumericIndicator:IsShown() then
            local th = TargetFrame.threatNumericIndicator:GetHeight()
            if th and th > 0 then
                extraY = math.max(extraY, th)
            end
        end
        local leader = GetLeaderIcon(TargetFrame)
        if leader then
            local lh = (leader.GetHeight and leader:GetHeight()) or 0
            if not lh or lh <= 0 then lh = 18 end
            extraY = math.max(extraY, lh)
        end
        startY = startY + extraY
        primary:SetPoint("BOTTOMLEFT", ref, "TOPLEFT", offsetX, startY)
        secondary:SetPoint("BOTTOMLEFT", primary, "TOPLEFT", 0, CONTAINER_GAP)
        for _, c in ipairs({ primary, secondary }) do
            if c.SetFlowLayoutAnchorPoint then
                pcall(c.SetFlowLayoutAnchorPoint, c, "BOTTOMLEFT")
            end
            if c.SetFlowLayoutGrowthDirection then
                pcall(c.SetFlowLayoutGrowthDirection, c, 1, 1)
            end
        end
    else
        primary:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", TOP_X, TOP_Y)
        secondary:SetPoint("TOPLEFT", primary, "BOTTOMLEFT", 0, -CONTAINER_GAP)
        for _, c in ipairs({ primary, secondary }) do
            if c.SetFlowLayoutAnchorPoint then
                pcall(c.SetFlowLayoutAnchorPoint, c, "TOPLEFT")
            end
            if c.SetFlowLayoutGrowthDirection then
                pcall(c.SetFlowLayoutGrowthDirection, c, 1, -1)
            end
        end
    end
end

local isUpdatingAuras = false

function targetframes:UpdateAuras()
    if isUpdatingAuras then return end
    isUpdatingAuras = true

    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local blizzAuras = TargetFrame and TargetFrame.TargetFrameContent and
    TargetFrame.TargetFrameContent.TargetFrameContentContextual and
    TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras

    if bothNone then
        if self.customDebuffs then self.customDebuffs:Hide() end
        if self.customBuffs then self.customBuffs:Hide() end
        if blizzAuras then
            blizzAuras:SetAlpha(1)
            blizzAuras:EnableMouse(true)
        end
        isUpdatingAuras = false
        return
    end

    if not self.customDebuffs or not self.customBuffs then
        self:SetupCustomAuraContainer()
    end

    if blizzAuras then
        blizzAuras:SetAlpha(0)
        blizzAuras:EnableMouse(false)
    end

    if not self.customDebuffs or not self.customBuffs then
        isUpdatingAuras = false
        return
    end

    if not TargetFrame:IsShown() or not UnitExists("target") then
        self.customDebuffs:Hide()
        self.customBuffs:Hide()
        isUpdatingAuras = false
        return
    end

    self.customDebuffs:Show()
    self.customBuffs:Show()
    self:UpdateAuraPositions()

    -- Each group's harmful/helpful identity and container are permanent
    -- (see SetupCustomAuraContainer) -- the only thing that changes with
    -- target hostility is handled in UpdateAuraPositions (which container
    -- anchors first). All that's left here is the "none" style hiding,
    -- which is keyed to each group's fixed type, not to hostility.
    local debuffCount = (styleDebuffs ~= "none") and 16 or 0
    local buffCount = (styleBuffs ~= "none") and 32 or 0
    pcall(self.customDebuffs.SetAuraGroupMaxFrameCount, self.customDebuffs, "debuffs_mine", debuffCount)
    pcall(self.customDebuffs.SetAuraGroupMaxFrameCount, self.customDebuffs, "debuffs_other", debuffCount)
    pcall(self.customBuffs.SetAuraGroupMaxFrameCount, self.customBuffs, "buffs_mine", buffCount)
    pcall(self.customBuffs.SetAuraGroupMaxFrameCount, self.customBuffs, "buffs_other", buffCount)

    pcall(self.customDebuffs.UpdateAllAuras, self.customDebuffs)
    pcall(self.customBuffs.UpdateAllAuras, self.customBuffs)

    -- Force a final button style pass.
    ForEachActiveAuraButton(self.customDebuffs, "debuffs_mine", "debuffs_other", function(btn)
        targetframes:UpdateAuraButtonStyle(btn)
    end)
    ForEachActiveAuraButton(self.customBuffs, "buffs_mine", "buffs_other", function(btn)
        targetframes:UpdateAuraButtonStyle(btn)
    end)

    UpdateSpellbar(TargetFrame, { self.customDebuffs, self.customBuffs })

    isUpdatingAuras = false
end

function targetframes:ForceZoom()
    self:UpdateAuras()
end

function targetframes:SetupCustomAuraContainer()
    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local blizzAuras = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual and TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras

    if bothNone then
        if self.customDebuffs then self.customDebuffs:Hide() end
        if self.customBuffs then self.customBuffs:Hide() end
        if blizzAuras then
            blizzAuras:SetAlpha(1)
            blizzAuras:EnableMouse(true)
        end
        return
    end

    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        if C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        else
            return
        end
    end

    if not TargetFrame or not blizzAuras then return end

    blizzAuras:SetAlpha(0)
    blizzAuras:EnableMouse(false)

    local function InitAuraButton(container, button, groupKey, isBuff, size, isMine)
        if container then
            if not container.allButtons then container.allButtons = {} end
            container.allButtons[button] = true
            button.container = container
        end
        button:SetSize(size, size)
        button.groupKey = groupKey
        button.isBuff = isBuff
        button.elementSize = size
        button.isMine = isMine

        -- This widget type has no native border texture of its own (confirmed via
        -- runtime inspection), so we draw the border entirely on our own
        -- borderTex below; UpdateAuraButtonStyle decides per-call whether that's
        -- our dark border, Blizzard's real dispel-type color (debuffs), or none
        -- at all (buffs), matching stock target frame behavior.

        local icon = button.icon or button:CreateTexture(nil, "ARTWORK")
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button.icon = icon
        if button.SetIcon then
            pcall(button.SetIcon, button, icon)
        end

        local cd = button.cooldown or CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:ClearAllPoints()
        cd:SetAllPoints(button)
        cd:SetReverse(true)
        cd:SetDrawEdge(false)
        cd:SetDrawSwipe(false)
        cd:SetHideCountdownNumbers(true)
        button.cooldown = cd
        if button.SetDurationCooldown then
            pcall(button.SetDurationCooldown, button, cd)
        end

        local textHolder = button.textHolder or CreateFrame("Frame", nil, button)
        textHolder:ClearAllPoints()
        textHolder:SetAllPoints(button)
        textHolder:SetFrameLevel(cd:GetFrameLevel() + 5)
        textHolder:EnableMouse(false)
        button.textHolder = textHolder

        local count = button.count or textHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button.count = count
        if button.SetApplicationCount then
            pcall(button.SetApplicationCount, button, count, {})
        end

        local pad = (size >= 20) and 3 or 2
        local borderHost = button.borderHost or CreateFrame("Frame", nil, button)
        borderHost:ClearAllPoints()
        borderHost:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
        borderHost:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
        borderHost:SetFrameLevel(cd:GetFrameLevel() + 2)
        borderHost:EnableMouse(false)

        local borderTex = button.borderTex or borderHost:CreateTexture(nil, "OVERLAY")
        borderTex:ClearAllPoints()
        borderTex:SetAllPoints(borderHost)
        borderTex:SetAtlas("ui-debuff-border-default-noicon")

        button.borderHost = borderHost
        button.borderTex = borderTex

        -- Dedicated engine-colored border for stock-style debuffs (see the long
        -- comment in UpdateAuraButtonStyle). The TEXTURE is created here, once,
        -- but registering it with AddDispelTypeTexture is attempted separately
        -- on every UpdateAuraButtonStyle pass (see TryRegisterDispelBorder)
        -- until it succeeds -- Blizzard denies that call outright while aura
        -- data is in a "secret"/restricted window (C_Secrets.ShouldAurasBeSecret,
        -- e.g. around loading screens/zone transitions), and a single attempt
        -- made at button-creation time has no way to retry if it lands in one.
        -- button.isBuff is permanently fixed at this point (the group this
        -- button was created in), so exactly one dispel texture is ever
        -- needed -- TryRegisterDispelBorder picks buff-only (stealableFilter)
        -- or debuff-only (harmful-only) registration options based on it.
        if not button.dispelBorderHost then
            local dispelBorderHost = CreateFrame("Frame", nil, borderHost)
            dispelBorderHost:SetAllPoints(borderHost)
            dispelBorderHost:EnableMouse(false)
            dispelBorderHost:Hide()

            local dispelBorderTex = dispelBorderHost:CreateTexture(nil, "OVERLAY")
            dispelBorderTex:SetAllPoints(dispelBorderHost)
            dispelBorderTex:SetAtlas("ui-debuff-border-default-noicon")
            dispelBorderTex:SetDesaturated(true)
            dispelBorderTex:SetVertexColor(1,1,1,1)

            button.dispelBorderHost = dispelBorderHost
            button.dispelBorderTexPending = dispelBorderTex
        end

        local stealable = button.stealable or button:CreateTexture(nil, "OVERLAY")
        stealable:ClearAllPoints()
        stealable:SetPoint("TOPLEFT", button, "TOPLEFT", -pad-1, pad+1)
        stealable:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
        stealable:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
        stealable:SetBlendMode("ADD")
        stealable:Hide()
        button.stealable = stealable

        targetframes:UpdateAuraButtonStyle(button)
    end

    -- Two permanent, structurally-identical containers -- one for debuffs,
    -- one for buffs -- each with its own fixed "mine" (large) / "other"
    -- (small) group pair that's never reconfigured after creation. Which one
    -- anchors under the health bar (vs trailing behind the other) is decided
    -- entirely in UpdateAuraPositions via plain container-level SetPoint
    -- calls, not by touching anything in here again.
    local function BuildAuraContainer(namePrefix, mineKey, otherKey, mineFilter, otherFilter, frameLevelBonus)
        local okC, container = pcall(function()
            return CreateFrame("AuraContainer", namePrefix, TargetFrame, "CustomAuraContainerTemplate")
        end)
        if not okC or not container then return nil end

        container:SetSize(1, 1)
        if TargetFrame and TargetFrame.GetFrameLevel then
            container:SetFrameLevel(TargetFrame:GetFrameLevel() + frameLevelBonus)
        end
        container:SetFlowLayoutMaximumLineSize(122)
        container:SetFlowLayoutPadding(0, 0, 0, 0)
        if container.SetFlowLayoutSpacing then
            pcall(container.SetFlowLayoutSpacing, container, AURA_SPACING, AURA_SPACING + 2)
        end

        container:AddAuraGroup(mineKey, mineFilter, {
            maxFrameCount = 16,
            initializeFrame = function(btn) InitAuraButton(container, btn, mineKey, mineFilter:find("HELPFUL") ~= nil, LARGE_AURA_SIZE, true) end,
            layout = MakeGroupLayout(LARGE_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 1),
        })

        container:AddAuraGroup(otherKey, otherFilter, {
            maxFrameCount = 16,
            initializeFrame = function(btn) InitAuraButton(container, btn, otherKey, otherFilter:find("HELPFUL") ~= nil, SMALL_AURA_SIZE, false) end,
            layout = MakeGroupLayout(SMALL_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 2),
        })

        if container.ApplyLayout then
            hooksecurefunc(container, "ApplyLayout", function()
                if isUpdatingAuras then return end
                RefreshContainerButtons(container, mineKey, otherKey)
                UpdateSpellbar(TargetFrame, { targetframes.customDebuffs, targetframes.customBuffs })
                isUpdatingAuras = false
            end)
        end

        if container.UpdateAllAuras then
            hooksecurefunc(container, "UpdateAllAuras", function()
                if isUpdatingAuras then return end
                RefreshContainerButtons(container, mineKey, otherKey)
            end)
        end

        if container.UpdateAuraGroup then
            hooksecurefunc(container, "UpdateAuraGroup", function()
                if isUpdatingAuras then return end
                RefreshContainerButtons(container, mineKey, otherKey)
            end)
        end

        container:SetUnit("target")
        container:UpdateAllAuras()
        return container
    end

    if not self.customDebuffs then
        self.customDebuffs = BuildAuraContainer("UberUI_TargetDebuffs", "debuffs_mine", "debuffs_other", "HARMFUL|PLAYER", "HARMFUL|!PLAYER", 20)
    end
    if not self.customBuffs then
        self.customBuffs = BuildAuraContainer("UberUI_TargetBuffs", "buffs_mine", "buffs_other", "HELPFUL|PLAYER", "HELPFUL|!PLAYER", 20)
    end

    if self.customDebuffs and self.customBuffs then
        targetframes:UpdateAuraPositions()
    end

    HookSpellbarAdjustPosition(TargetFrame.spellbar or TargetFrameSpellBar, TargetFrame,
        function() return { targetframes.customDebuffs, targetframes.customBuffs } end)

    local function ShowHideBoth(shown)
        if self.customDebuffs then
            if shown then self.customDebuffs:Show() else self.customDebuffs:Hide() end
        end
        if self.customBuffs then
            if shown then self.customBuffs:Show() else self.customBuffs:Hide() end
        end
    end

    ShowHideBoth(TargetFrame:IsShown())

    if not self.targetFrameHooked then
        self.targetFrameHooked = true
        TargetFrame:HookScript("OnShow", function()
            if targetframes.customDebuffs then
                targetframes.customDebuffs:Show()
                targetframes.customDebuffs:UpdateAllAuras()
            end
            if targetframes.customBuffs then
                targetframes.customBuffs:Show()
                targetframes.customBuffs:UpdateAllAuras()
            end
            targetframes:UpdateAuras()
        end)
        TargetFrame:HookScript("OnHide", function()
            if targetframes.customDebuffs then targetframes.customDebuffs:Hide() end
            if targetframes.customBuffs then targetframes.customBuffs:Hide() end
        end)
    end
end

-- Initialize immediately if TargetFrame is already present
targetframes:SetupCustomAuraContainer()

if TargetFrame and TargetFrame.UpdateAuras then
    hooksecurefunc(TargetFrame, "UpdateAuras", function(self)
        if targetframes and targetframes.UpdateAuras then
            targetframes:UpdateAuras()
        end
    end)
end

if TargetFrame and TargetFrame.CheckPartyLeader then
    hooksecurefunc(TargetFrame, "CheckPartyLeader", function(self)
        if targetframes and targetframes.UpdateAuraPositions then
            targetframes:UpdateAuraPositions()
        end
    end)
end

if TargetFrame_UpdateAuras then
    hooksecurefunc("TargetFrame_UpdateAuras", function(self)
        if targetframes and targetframes.UpdateAuras then
            targetframes:UpdateAuras()
        end
    end)
end

if TargetFrame then
    if TargetFrame.CheckFaction then
        hooksecurefunc(TargetFrame, "CheckFaction", function(self)
            if targetframes and targetframes.HealthBarColor then
                targetframes:HealthBarColor()
            end
        end)
    end
    if TargetFrame.Update then
        hooksecurefunc(TargetFrame, "Update", function(self)
            if targetframes then
                targetframes:HealthBarColor()
                targetframes:HealthManaBarTexture()
            end
        end)
    end
    if TargetFrame.CreateSpellbar then
        hooksecurefunc(TargetFrame, "CreateSpellbar", function(self)
            HookSpellbarAdjustPosition(self.spellbar or TargetFrameSpellBar, TargetFrame,
                function() return { targetframes.customDebuffs, targetframes.customBuffs } end)
        end)
    end
    if TargetFrame.totFrame then
        TargetFrame.totFrame:HookScript("OnShow", function()
            if targetframes and targetframes.UpdateAuras then
                targetframes:UpdateAuras()
            end
        end)
        TargetFrame.totFrame:HookScript("OnHide", function()
            if targetframes and targetframes.UpdateAuras then
                targetframes:UpdateAuras()
            end
        end)
    end
end

hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
    if statusbar and (unit == "target" or unit == "targettarget") and targetframes and targetframes.HealthBarColor then
        targetframes:HealthBarColor()
    end
end)

function targetframes:PvPIcon()
    if TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual then
        UberUI.general:PvPIcon(TargetFrame.TargetFrameContent.TargetFrameContentContextual)
    elseif TargetFrameTextureFramePVPIcon then
        UberUI.general:PvPIcon(TargetFrameTextureFramePVPIcon)
    end
end

UberUI.targetframes = targetframes
