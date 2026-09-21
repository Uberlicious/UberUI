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
targetframes:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        targetframes:SetupCustomAuraContainer()
    end
    targetframes:Color();
    targetframes:HealthBarColor();
    targetframes:HealthManaBarTexture();
    targetframes:PvPIcon();
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        targetframes:UpdateAuras();
        C_Timer.After(0.05, function()
            targetframes:UpdateAuras()
            targetframes:HealthBarColor()
        end)
    elseif event == "UNIT_AURA" then
        targetframes:UpdateAuras();
        C_Timer.After(0.05, function() targetframes:UpdateAuras() end)
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

local function IsSecret(v)
    return (issecretvalue and issecretvalue(v))
end

local function SafeBool(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    return (v == true)
end

function targetframes:UpdateAuraButtonStyle(button)
    if not button or IsSecret(button) then return end
    local okF, isForbid = pcall(button.IsForbidden, button)
    if okF and SafeBool(isForbid) then return end

    local isBuff = button.isBuff
    local style = "both"
    if uuidb and uuidb.general then
        style = isBuff and (uuidb.general.aurastyle_targetbuffs or "both") or (uuidb.general.aurastyle_targetdebuffs or "zoom")
    end
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    for _, key in ipairs({"Border", "border", "DebuffBorder", "DispelBorder", "BorderOverlay", "Overlay", "IconBorder", "AuraBorder"}) do
        local tex = button[key]
        if tex and not IsSecret(tex) then
            pcall(function()
                tex:Hide()
                tex:SetAlpha(0)
            end)
        end
    end

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
        pcall(button.cooldown.SetDrawSwipe, button.cooldown, false)
        pcall(button.cooldown.SetDrawEdge, button.cooldown, false)
    end

    if button.borderHost then
        pcall(function()
            local pad = 3
            if button.elementSize and button.elementSize >= 20 then
                pad = 4
            end
            button.borderHost:ClearAllPoints()
            button.borderHost:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
            button.borderHost:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)

            if button.borderTex then
                button.borderTex:ClearAllPoints()
                button.borderTex:SetAllPoints(button.borderHost)
            end

            if isBuff then
                if darkBorderEnabled then
                    button.borderHost:Show()
                    if button.borderTex then
                        button.borderTex:SetAtlas("ui-debuff-border-default-noicon")
                        button.borderTex:SetDesaturated(true)
                        local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
                        button.borderTex:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                    end
                else
                    button.borderHost:Hide()
                end
            else
                -- Debuffs
                if darkBorderEnabled then
                    if button.ClearDispelTypeTextures then
                        pcall(button.ClearDispelTypeTextures, button)
                    end
                    button.borderHost:Show()
                    if button.borderTex then
                        button.borderTex:SetAtlas("ui-debuff-border-default-noicon")
                        button.borderTex:SetDesaturated(true)
                        local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
                        button.borderTex:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                    end
                elseif zoomEnabled then
                    -- Zoom only: keep original debuff type coloring, resized to fit icon
                    button.borderHost:Show()
                    if button.borderTex then
                        button.borderTex:SetDesaturated(false)
                        button.borderTex:ClearAllPoints()
                        button.borderTex:SetAllPoints(button.borderHost)
                    end
                    if button.GetDispelTypeTextureCount and button:GetDispelTypeTextureCount() == 0 and button.AddDispelTypeTexture then
                        local dispelStyle = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle and (Enum.CustomAuraButtonDispelTypeTextureStyle.Border or Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset)
                        if dispelStyle then
                            pcall(button.AddDispelTypeTexture, button, button.borderTex, {
                                style = dispelStyle,
                                showWhenHarmful = true,
                                showWhenHelpful = false,
                                showWithoutDispelType = true,
                            })
                            button.borderTex:ClearAllPoints()
                            button.borderTex:SetAllPoints(button.borderHost)
                        end
                    end
                else
                    button.borderHost:Hide()
                end
            end
        end)
    end
end

local TOP_X = 25
local TOP_Y = 26
local LARGE_AURA_SIZE = 21
local SMALL_AURA_SIZE = 15
local AURA_SPACING = 3

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

local function RefreshContainerButtons(container)
    if not container or not container.allButtons then return end
    for button in pairs(container.allButtons) do
        targetframes:UpdateAuraButtonStyle(button)
    end
end

function targetframes:UpdateAuraPositions()
    if self.customAuras then
        self.customAuras:ClearAllPoints()
        self.customAuras:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", TOP_X, TOP_Y)
    end
end

function targetframes:UpdateAuras()
    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local blizzAuras = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual and TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras

    if bothNone then
        if self.customAuras then self.customAuras:Hide() end
        if blizzAuras then
            blizzAuras:Show()
            blizzAuras:SetAlpha(1)
        end
        return
    end

    if not self.customAuras then
        self:SetupCustomAuraContainer()
    end

    if blizzAuras then
        blizzAuras:Hide()
        blizzAuras:SetAlpha(0)
    end

    if not self.customAuras then return end

    if not TargetFrame:IsShown() then
        self.customAuras:Hide()
        return
    end

    self.customAuras:Show()

    local isFriend = false
    if UnitExists("target") then
        local okU, isSelf = pcall(UnitIsUnit, "player", "target")
        if okU and SafeBool(isSelf) then
            isFriend = true
        else
            local okF, isF = pcall(UnitIsFriend, "player", "target")
            if okF and not IsSecret(isF) then
                isFriend = isF and true or false
            end
        end
    end

    local function UnitHasAura(unit, filter)
        if not UnitExists(unit) then return false end
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, filter)
            if ok and not IsSecret(aura) and aura ~= nil then return true end
        end
        if UnitAura then
            local ok, name = pcall(UnitAura, unit, 1, filter)
            if ok and not IsSecret(name) and name ~= nil then return true end
        end
        return false
    end

    local function CheckAuras(isBuff, isMine)
        local filter = (isBuff and "HELPFUL" or "HARMFUL") .. (isMine and "|PLAYER" or "")
        if UnitHasAura("target", filter) then
            return true
        end
        if self.customAuras and self.customAuras.allButtons then
            for btn in pairs(self.customAuras.allButtons) do
                if btn and not IsSecret(btn) then
                    local okS, isShown = pcall(btn.IsShown, btn)
                    if okS and SafeBool(isShown) and btn.isBuff == isBuff then
                        if isMine == nil or btn.isMine == isMine then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    if self.customAuras and self.customAuras.SetAuraGroupLayout then
        local layoutBuffsMine, layoutBuffsOther, layoutDebuffsMine, layoutDebuffsOther
        if isFriend then
            local hasBuffs = CheckAuras(true, nil)
            local hasDebuffsMine = CheckAuras(false, true)
            layoutBuffsMine = MakeGroupLayout(LARGE_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 1)
            layoutBuffsOther = MakeGroupLayout(SMALL_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 2)
            layoutDebuffsMine = MakeGroupLayout(LARGE_AURA_SIZE, AURA_SPACING, AURA_SPACING, hasBuffs, 3)
            layoutDebuffsOther = MakeGroupLayout(SMALL_AURA_SIZE, AURA_SPACING, AURA_SPACING, (not hasDebuffsMine) and hasBuffs, 4)
        else
            local hasDebuffs = CheckAuras(false, nil)
            local hasBuffsMine = CheckAuras(true, true)
            layoutDebuffsMine = MakeGroupLayout(LARGE_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 1)
            layoutDebuffsOther = MakeGroupLayout(SMALL_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 2)
            layoutBuffsMine = MakeGroupLayout(LARGE_AURA_SIZE, AURA_SPACING, AURA_SPACING, hasDebuffs, 3)
            layoutBuffsOther = MakeGroupLayout(SMALL_AURA_SIZE, AURA_SPACING, AURA_SPACING, (not hasBuffsMine) and hasDebuffs, 4)
        end
        pcall(self.customAuras.SetAuraGroupLayout, self.customAuras, "buffs_mine", layoutBuffsMine)
        pcall(self.customAuras.SetAuraGroupLayout, self.customAuras, "buffs_other", layoutBuffsOther)
        pcall(self.customAuras.SetAuraGroupLayout, self.customAuras, "debuffs_mine", layoutDebuffsMine)
        pcall(self.customAuras.SetAuraGroupLayout, self.customAuras, "debuffs_other", layoutDebuffsOther)
    end

    if self.customAuras and self.customAuras.SetAuraGroupFilterString then
        pcall(self.customAuras.SetAuraGroupFilterString, self.customAuras, "buffs_mine", "HELPFUL|PLAYER")
        pcall(self.customAuras.SetAuraGroupFilterString, self.customAuras, "buffs_other", "HELPFUL|!PLAYER")
        pcall(self.customAuras.SetAuraGroupFilterString, self.customAuras, "debuffs_mine", "HARMFUL|PLAYER")
        pcall(self.customAuras.SetAuraGroupFilterString, self.customAuras, "debuffs_other", "HARMFUL|!PLAYER")
    end

    local maxBuffs = (styleBuffs ~= "none") and 32 or 0
    local maxDebuffs = (styleDebuffs ~= "none") and 16 or 0
    if self.customAuras.SetAuraGroupMaxFrameCount then
        pcall(self.customAuras.SetAuraGroupMaxFrameCount, self.customAuras, "buffs_mine", maxBuffs)
        pcall(self.customAuras.SetAuraGroupMaxFrameCount, self.customAuras, "buffs_other", maxBuffs)
        pcall(self.customAuras.SetAuraGroupMaxFrameCount, self.customAuras, "debuffs_mine", maxDebuffs)
        pcall(self.customAuras.SetAuraGroupMaxFrameCount, self.customAuras, "debuffs_other", maxDebuffs)
    end

    pcall(self.customAuras.UpdateAllAuras, self.customAuras)
    RefreshContainerButtons(self.customAuras)
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
            blizzAuras:Show()
            blizzAuras:SetAlpha(1)
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

    blizzAuras:Hide()
    blizzAuras:SetAlpha(0)
    if not self.blizzHooked then
        self.blizzHooked = true
        hooksecurefunc(blizzAuras, "Show", function(self)
            local sBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetbuffs) or "both"
            local sDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_targetdebuffs) or "zoom"
            if sBuffs ~= "none" or sDebuffs ~= "none" then
                self:Hide()
                self:SetAlpha(0)
            end
        end)
    end

    local function InitAuraButton(container, button, isBuff, size, isMine)
        if container then
            if not container.allButtons then container.allButtons = {} end
            container.allButtons[button] = true
            button.container = container
        end
        button:SetSize(size, size)
        button.isBuff = isBuff
        button.elementSize = size
        button.isMine = isMine

        for _, key in ipairs({"Border", "border", "DebuffBorder", "DispelBorder", "BorderOverlay", "Overlay"}) do
            local tex = button[key]
            if tex and not IsSecret(tex) then
                pcall(function()
                    tex:Hide()
                    tex:SetAlpha(0)
                end)
            end
        end

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

        local pad = (size >= 20) and 4 or 3
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

        if isBuff and button.AddDispelTypeTexture and Enum and Enum.CustomAuraButtonDispelTypeStealableFilter and Enum.CustomAuraButtonDispelTypeTextureStyle then
            pcall(button.AddDispelTypeTexture, button, stealable, {
                style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                showWhenHelpful = true,
                showWhenHarmful = false,
                showWithoutDispelType = true,
                stealableFilter = Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable,
            })
        end

        if not isBuff and button.AddDispelTypeTexture then
            local dispelStyle = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle and (Enum.CustomAuraButtonDispelTypeTextureStyle.Border or Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset)
            if dispelStyle then
                pcall(button.AddDispelTypeTexture, button, borderTex, {
                    style = dispelStyle,
                    showWhenHarmful = true,
                    showWhenHelpful = false,
                    showWithoutDispelType = true,
                })
                borderTex:ClearAllPoints()
                borderTex:SetAllPoints(borderHost)
            end
        end

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
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", TargetFrame, "BOTTOMLEFT", TOP_X, TOP_Y)
            container:SetFlowLayoutAnchorPoint("TOPLEFT")
            container:SetFlowLayoutGrowthDirection(1, -1)
            container:SetFlowLayoutMaximumLineSize(122)
            container:SetFlowLayoutPadding(0, 0, 0, 0)
            if container.SetFlowLayoutSpacing then
                pcall(container.SetFlowLayoutSpacing, container, AURA_SPACING, AURA_SPACING + 2)
            end

            container:AddAuraGroup("buffs_mine", "HELPFUL|PLAYER", {
                maxFrameCount = (styleBuffs ~= "none") and 32 or 0,
                initializeFrame = function(btn) InitAuraButton(container, btn, true, LARGE_AURA_SIZE, true) end,
                layout = MakeGroupLayout(LARGE_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 1),
            })

            container:AddAuraGroup("buffs_other", "HELPFUL|!PLAYER", {
                maxFrameCount = (styleBuffs ~= "none") and 32 or 0,
                initializeFrame = function(btn) InitAuraButton(container, btn, true, SMALL_AURA_SIZE, false) end,
                layout = MakeGroupLayout(SMALL_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 2),
            })

            container:AddAuraGroup("debuffs_mine", "HARMFUL|PLAYER", {
                maxFrameCount = (styleDebuffs ~= "none") and 16 or 0,
                initializeFrame = function(btn) InitAuraButton(container, btn, false, LARGE_AURA_SIZE, true) end,
                layout = MakeGroupLayout(LARGE_AURA_SIZE, AURA_SPACING, AURA_SPACING, true, 3),
            })

            container:AddAuraGroup("debuffs_other", "HARMFUL|!PLAYER", {
                maxFrameCount = (styleDebuffs ~= "none") and 16 or 0,
                initializeFrame = function(btn) InitAuraButton(container, btn, false, SMALL_AURA_SIZE, false) end,
                layout = MakeGroupLayout(SMALL_AURA_SIZE, AURA_SPACING, AURA_SPACING, false, 4),
            })

            if container.ApplyLayout then
                hooksecurefunc(container, "ApplyLayout", function()
                    RefreshContainerButtons(container)
                end)
            end

            container:SetUnit("target")
            container:UpdateAllAuras()
        end
    end

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

if TargetFrame_UpdateAuras then
    hooksecurefunc("TargetFrame_UpdateAuras", function(self)
        if targetframes and targetframes.UpdateAuras then
            targetframes:UpdateAuras()
        end
    end)
end

local function HookAuraContainer(container)
    if not container then return end
    if container.ApplyLayout then
        hooksecurefunc(container, "ApplyLayout", function(self)
            if targetframes and targetframes.UpdateAuras then
                targetframes:UpdateAuras()
            end
        end)
    end
    if container.UpdateAllAuras then
        hooksecurefunc(container, "UpdateAllAuras", function(self)
            if targetframes and targetframes.UpdateAuras then
                targetframes:UpdateAuras()
            end
        end)
    end
end

local targetAuras = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual and TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras
HookAuraContainer(targetAuras)

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
end

hooksecurefunc("UnitFrameHealthBar_Update", function(statusbar, unit)
    if statusbar and (unit == "target" or unit == "targettarget") and targetframes and targetframes.HealthBarColor then
        targetframes:HealthBarColor()
    end
end)

function targetframes:PvPIcon()
    if TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual then
        UberUI.general:PvPIcon(TargetFrame.TargetFrameContent.TargetFrameContentContextual);
    elseif TargetFrameTextureFramePVPIcon then
        UberUI.general:PvPIcon(TargetFrameTextureFramePVPIcon);
    end
end

UberUI.targetframes = targetframes
