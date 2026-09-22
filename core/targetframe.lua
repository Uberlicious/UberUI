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

function targetframes:UpdateAuraButtonStyle(button, forcedIsBuff)
    if not button or IsSecret(button) or SafeIsForbidden(button) then return end

    local isBuff = forcedIsBuff
    if isBuff == nil then
        -- Dynamically ask the button or its parent group what kind of aura it's holding right now
        if button.isBuff ~= nil and button.targetForWhichItWasSet == UnitGUID("target") then
            isBuff = button.isBuff
        else
            local isEnemy = IsEnemyTarget()
            local groupKey = button.groupKey or (button.auraGroup and button.auraGroup:GetGroupName())
            if groupKey == "secondary" then
                isBuff = isEnemy     -- On enemy, secondary is buff. On friend, secondary is debuff.
            else
                isBuff = not isEnemy -- On enemy, primary is debuff. On friend, primary is buff.
            end
        end
    end
    button.isBuff = isBuff
    button.targetForWhichItWasSet = UnitGUID("target")

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
            -- frame behavior ourselves on our own borderTex: no border at all on
            -- buffs, and a border tinted with the real dispel-type color on
            -- debuffs -- using the exact same AuraUtil.SetAuraBorderColor call
            -- and DEBUFF_TYPE_*_COLOR values Blizzard's own target frame code
            -- uses for this (see TargetFrameMixin's aura update handler).
            local function GetAuraDispelName()
                local auraData = button.auraData
                if auraData == nil or IsSecret(auraData) then return nil end
                local ok, dispelName = pcall(function() return auraData.dispelName end)
                if not ok or IsSecret(dispelName) then return nil end
                return dispelName
            end

            local function ApplyDarkBorder()
                button.borderHost:Show()
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
            end

            local function ApplyNativeDebuffBorder()
                button.borderHost:Show()
                if button.borderTex then
                    button.borderTex:Show()
                    button.borderTex:SetAtlas("ui-debuff-border-default-noicon")
                    button.borderTex:SetDesaturated(false)
                    local dispelName = GetAuraDispelName()
                    local colored = false
                    if AuraUtil and AuraUtil.SetAuraBorderColor then
                        colored = pcall(AuraUtil.SetAuraBorderColor, button.borderTex, dispelName)
                    end
                    if not colored then
                        -- Fallback if Blizzard's own helper is unavailable for
                        -- some reason -- plain white leaves the base atlas
                        -- showing as-is rather than an incorrect color.
                        button.borderTex:SetVertexColor(1, 1, 1, 1)
                    end
                end
            end

            if isBuff then
                -- Buff styling (Applies to friendly buffs and enemy secondary buffs)
                if darkBorderEnabled then
                    ApplyDarkBorder()
                else
                    ApplyNoBorder()
                end

                local isStealable = false
                pcall(function()
                    if SafeBool(button.isStealable) then isStealable = true end
                    if button.Stealable and button.Stealable.IsShown and SafeBool(button.Stealable:IsShown()) then isStealable = true end
                end)
                if isStealable and button.stealable then
                    button.stealable:Show()
                elseif button.stealable then
                    button.stealable:Hide()
                end
            else
                -- Debuff styling (Applies to enemy debuffs and friendly secondary debuffs)
                if button.stealable then button.stealable:Hide() end

                if darkBorderEnabled then
                    ApplyDarkBorder()
                else
                    ApplyNativeDebuffBorder()
                end
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

-- Restyle every aura button currently active in a group, using the container's own
-- authoritative group membership (GetFramesByIndex) rather than any addon-cached
-- per-button state such as button.groupKey. Blizzard's AuraContainer recycles pooled
-- button widgets between groups as the target's hostility changes, and a recycled
-- widget does NOT get run back through our initializeFrame callback, so a cached
-- button.groupKey can go stale the moment a widget is handed to a different group.
-- That staleness was why target frame borders would silently stop drawing after
-- switching from an enemy target to a friendly one (or vice versa): whichever
-- hostility was targeted first got buttons freshly created with correct state, but
-- the recycled buttons used for the opposite hostility kept believing they were
-- still in their original role.
local function ForEachActiveAuraButton(container, isEnemy, callback)
    if not container or not container.auraGroups then return end

    local function visitGroup(groupKey, isBuff)
        local group = container.auraGroups[groupKey]
        if group and group.GetFramesByIndex then
            local ok, frames = pcall(group.GetFramesByIndex, group)
            if ok and frames and not IsSecret(frames) then
                for _, btn in ipairs(frames) do
                    callback(btn, isBuff)
                end
            end
        end
    end

    if isEnemy then
        visitGroup("primary_mine", false)
        visitGroup("primary_other", false)
        visitGroup("secondary", true)
    else
        visitGroup("primary_mine", true)
        visitGroup("primary_other", true)
        visitGroup("secondary", false)
    end
end

local function RefreshContainerButtons(container)
    if not container then return end
    ForEachActiveAuraButton(container, IsEnemyTarget(), function(btn, isBuff)
        targetframes:UpdateAuraButtonStyle(btn, isBuff)
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
local function UpdateSpellbar(frameObj, container)
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

    if not container or not container.allButtons or not container:IsShown() then
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
        local container = getContainer and getContainer()
        if container then
            UpdateSpellbar(frameObj, container)
        end
    end)
end

function targetframes:UpdateAuraPositions()
    if not self.customAuras or not TargetFrame then return end
    local buffsOnTop = TargetFrame.buffsOnTop
    self.customAuras:ClearAllPoints()
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
        self.customAuras:SetPoint("BOTTOMLEFT", ref, "TOPLEFT", offsetX, startY)
        if self.customAuras.SetFlowLayoutAnchorPoint then
            pcall(self.customAuras.SetFlowLayoutAnchorPoint, self.customAuras, "BOTTOMLEFT")
        end
        if self.customAuras.SetFlowLayoutGrowthDirection then
            pcall(self.customAuras.SetFlowLayoutGrowthDirection, self.customAuras, 1, 1)
        end
    else
        self.customAuras:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", TOP_X, TOP_Y)
        if self.customAuras.SetFlowLayoutAnchorPoint then
            pcall(self.customAuras.SetFlowLayoutAnchorPoint, self.customAuras, "TOPLEFT")
        end
        if self.customAuras.SetFlowLayoutGrowthDirection then
            pcall(self.customAuras.SetFlowLayoutGrowthDirection, self.customAuras, 1, -1)
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
        if self.customAuras then self.customAuras:Hide() end
        if blizzAuras then
            blizzAuras:SetAlpha(1)
            blizzAuras:EnableMouse(true)
        end
        isUpdatingAuras = false
        return
    end

    if not self.customAuras then
        self:SetupCustomAuraContainer()
    end

    if blizzAuras then
        blizzAuras:SetAlpha(0)
        blizzAuras:EnableMouse(false)
    end

    if not self.customAuras then
        isUpdatingAuras = false
        return
    end

    if not TargetFrame:IsShown() or not UnitExists("target") then
        self.customAuras:Hide()
        isUpdatingAuras = false
        return
    end

    self.customAuras:Show()
    self:UpdateAuraPositions()

    local isEnemy = IsEnemyTarget()
    local maxBuffs = (styleBuffs ~= "none") and 32 or 0
    local maxDebuffs = (styleDebuffs ~= "none") and 16 or 0

    -- Dynamically update group filter strings based on current target hostility
    if isEnemy then
        pcall(self.customAuras.SetAuraGroupFilterString, self.customAuras, "primary_mine", "HARMFUL|PLAYER")
        pcall(self.customAuras.SetAuraGroupFilterString, self.customAuras, "primary_other", "HARMFUL|!PLAYER")
        pcall(self.customAuras.SetAuraGroupFilterString, self.customAuras, "secondary", "HELPFUL")

        pcall(self.customAuras.SetAuraGroupMaxFrameCount, self.customAuras, "primary_mine", maxDebuffs)
        pcall(self.customAuras.SetAuraGroupMaxFrameCount, self.customAuras, "primary_other", maxDebuffs)
        pcall(self.customAuras.SetAuraGroupMaxFrameCount, self.customAuras, "secondary", maxBuffs)
    else
        pcall(self.customAuras.SetAuraGroupFilterString, self.customAuras, "primary_mine", "HELPFUL|PLAYER")
        pcall(self.customAuras.SetAuraGroupFilterString, self.customAuras, "primary_other", "HELPFUL|!PLAYER")
        pcall(self.customAuras.SetAuraGroupFilterString, self.customAuras, "secondary", "HARMFUL")

        pcall(self.customAuras.SetAuraGroupMaxFrameCount, self.customAuras, "primary_mine", maxBuffs)
        pcall(self.customAuras.SetAuraGroupMaxFrameCount, self.customAuras, "primary_other", maxBuffs)
        pcall(self.customAuras.SetAuraGroupMaxFrameCount, self.customAuras, "secondary", maxDebuffs)
    end

    pcall(self.customAuras.UpdateAllAuras, self.customAuras)

    -- Force a final button style pass with correct hostility context for buffs vs debuffs
    ForEachActiveAuraButton(self.customAuras, isEnemy, function(btn, isBuff)
        targetframes:UpdateAuraButtonStyle(btn, isBuff)
    end)

    UpdateSpellbar(TargetFrame, self.customAuras)

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
        if self.customAuras then self.customAuras:Hide() end
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

        local stealable = button.stealable or button:CreateTexture(nil, "OVERLAY")
        stealable:ClearAllPoints()
        stealable:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
        stealable:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
        stealable:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
        stealable:SetBlendMode("ADD")
        stealable:Hide()
        button.stealable = stealable

        targetframes:UpdateAuraButtonStyle(button)
    end

    if not self.customAuras then
        local okC, container = pcall(function()
            return CreateFrame("AuraContainer", "UberUI_TargetAuras", TargetFrame, "CustomAuraContainerTemplate")
        end)
        if okC and container then
            self.customAuras = container
            self.customBuffs = container
            self.customDebuffs = container

            container:SetSize(1, 1)
            if TargetFrame and TargetFrame.GetFrameLevel then
                container:SetFrameLevel(TargetFrame:GetFrameLevel() + 20)
            end
            targetframes:UpdateAuraPositions()
            container:SetFlowLayoutMaximumLineSize(122)
            container:SetFlowLayoutPadding(0, 0, 0, 0)
            if container.SetFlowLayoutSpacing then
                pcall(container.SetFlowLayoutSpacing, container, AURA_SPACING, AURA_SPACING + 2)
            end

            container:AddAuraGroup("primary_mine", "HARMFUL|PLAYER", {
                maxFrameCount = 16,
                initializeFrame = function(btn) InitAuraButton(container, btn, "primary_mine", false, LARGE_AURA_SIZE, true) end,
                layout = MakeGroupLayout(LARGE_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 1),
            })

            container:AddAuraGroup("primary_other", "HARMFUL|!PLAYER", {
                maxFrameCount = 16,
                initializeFrame = function(btn) InitAuraButton(container, btn, "primary_other", false, SMALL_AURA_SIZE, false) end,
                layout = MakeGroupLayout(SMALL_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 2),
            })

            container:AddAuraGroup("secondary", "HELPFUL", {
                maxFrameCount = 32,
                initializeFrame = function(btn) InitAuraButton(container, btn, "secondary", true, SMALL_AURA_SIZE, false) end,
                layout = MakeGroupLayout(SMALL_AURA_SIZE, AURA_SPACING, AURA_SPACING, true, 3),
            })

            if container.ApplyLayout then
                hooksecurefunc(container, "ApplyLayout", function()
                    if isUpdatingAuras then return end
                    RefreshContainerButtons(container)
                    UpdateSpellbar(TargetFrame, container)
                    isUpdatingAuras = false
                end)
            end

            container:SetUnit("target")
            container:UpdateAllAuras()

            if okC and container then
                self.customAuras = container
                self.customBuffs = container
                self.customDebuffs = container

                container:SetSize(1, 1)
                if TargetFrame and TargetFrame.GetFrameLevel then
                    container:SetFrameLevel(TargetFrame:GetFrameLevel() + 20)
                end
                targetframes:UpdateAuraPositions()
                container:SetFlowLayoutMaximumLineSize(122)
                container:SetFlowLayoutPadding(0, 0, 0, 0)
                if container.SetFlowLayoutSpacing then
                    pcall(container.SetFlowLayoutSpacing, container, AURA_SPACING, AURA_SPACING + 2)
                end

                -- HOOK 1: Intercept UpdateAllAuras to force button styling on every container refresh
                if container.UpdateAllAuras then
                    hooksecurefunc(container, "UpdateAllAuras", function()
                        if isUpdatingAuras then return end
                        RefreshContainerButtons(container)
                    end)
                end

                -- HOOK 2: Intercept group-level updates if available
                if container.UpdateAuraGroup then
                    hooksecurefunc(container, "UpdateAuraGroup", function()
                        if isUpdatingAuras then return end
                        RefreshContainerButtons(container)
                    end)
                end
            end
        end
    end

    HookSpellbarAdjustPosition(TargetFrame.spellbar or TargetFrameSpellBar, TargetFrame, function() return targetframes.customAuras end)

    if TargetFrame:IsShown() then
        if self.customAuras then self.customAuras:Show() end
    else
        if self.customAuras then self.customAuras:Hide() end
    end

    if not self.targetFrameHooked then
        self.targetFrameHooked = true
        TargetFrame:HookScript("OnShow", function()
            if targetframes.customAuras then
                targetframes.customAuras:Show()
                targetframes.customAuras:UpdateAllAuras()
            end
            targetframes:UpdateAuras()
        end)
        TargetFrame:HookScript("OnHide", function()
            if targetframes.customAuras then targetframes.customAuras:Hide() end
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
            HookSpellbarAdjustPosition(self.spellbar or TargetFrameSpellBar, TargetFrame, function() return targetframes.customAuras end)
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
