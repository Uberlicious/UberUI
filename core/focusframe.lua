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
local focusframes = UberUI:CreateFrame("frame")
focusframes:RegisterEvent("ADDON_LOADED")
focusframes:RegisterEvent("PLAYER_LOGIN")
focusframes:RegisterEvent("PLAYER_ENTERING_WORLD")
focusframes:RegisterEvent("PLAYER_TARGET_CHANGED")
focusframes:RegisterEvent("PLAYER_FOCUS_CHANGED")
focusframes:RegisterEvent("PLAYER_REGEN_ENABLED")
focusframes:RegisterEvent("UNIT_TARGET")
focusframes:RegisterUnitEvent("UNIT_HEALTH", "focus")
focusframes:RegisterUnitEvent("UNIT_MAXHEALTH", "focus")
focusframes:RegisterUnitEvent("UNIT_DISPLAYPOWER", "focus")
focusframes:RegisterUnitEvent("UNIT_POWER_UPDATE", "focus")
focusframes:RegisterUnitEvent("UNIT_MAXPOWER", "focus")
focusframes:RegisterUnitEvent("UNIT_AURA", "focus")
focusframes:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        focusframes:SetupCustomAuraContainer()
    end
    focusframes:Color();
    focusframes:HealthBarColor();
    focusframes:HealthManaBarTexture();
    focusframes:PvPIcon();
    if event == "PLAYER_FOCUS_CHANGED" then
        focusframes:UpdateAuras();
        C_Timer.After(0.05, function()
            focusframes:UpdateAuras()
            focusframes:HealthBarColor()
        end)
    elseif event == "UNIT_AURA" then
        focusframes:UpdateAuras();
        C_Timer.After(0.05, function() focusframes:UpdateAuras() end)
    end
end)

function focusframes:Color()
    if not FocusFrame then return end
    if FocusFrame.TargetFrameContainer then
        ApplyDarkenColor(FocusFrame.TargetFrameContainer.FrameTexture)
    elseif FocusFrameTextureFrameTexture then
        ApplyDarkenColor(FocusFrameTextureFrameTexture)
    end
    
    if FocusFrame then
        if FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain then
            if FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelTextFrame and FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelTextFrame.LevelBackgroundCircle then
                ApplyDarkenColor(FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelTextFrame.LevelBackgroundCircle)
            end
            if FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelBackground then
                ApplyDarkenColor(FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelBackground)
            end
            if FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelBackgroundCircle then
                ApplyDarkenColor(FocusFrame.TargetFrameContent.TargetFrameContentMain.LevelBackgroundCircle)
            end
            if FocusFrame.TargetFrameContent.TargetFrameContentMain.PvPBackgroundCircle then
                ApplyDarkenColor(FocusFrame.TargetFrameContent.TargetFrameContentMain.PvPBackgroundCircle)
            end
        end
        if FocusFrame.LevelBackgroundCircle then
            ApplyDarkenColor(FocusFrame.LevelBackgroundCircle)
        end
        if FocusFrame.LevelBackground then
            ApplyDarkenColor(FocusFrame.LevelBackground)
        end
        if _G["FocusFrameLevelBackground"] then
            ApplyDarkenColor(_G["FocusFrameLevelBackground"])
        end
    end
    
    if FocusFrameSpellBar and FocusFrameSpellBar.Border then
        ApplyDarkenColor(FocusFrameSpellBar.Border)
    end
    
    if FocusFrameToTTextureFrameTexture then
        ApplyDarkenColor(FocusFrameToTTextureFrameTexture)
    end
    
    if FocusFrameToT and FocusFrameToT.FrameTexture then
        ApplyDarkenColor(FocusFrameToT.FrameTexture)
    elseif FocusFrameToTTextureFrameTexture then
        ApplyDarkenColor(FocusFrameToTTextureFrameTexture)
    end

    if FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain and FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor then
        if uuidb.general.hiderepcolor then
            FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Hide()
        else
            FocusFrame.TargetFrameContent.TargetFrameContentMain.ReputationColor:Show()
        end
    end
end

function focusframes:HealthBarColor()
    if not FocusFrame then return end
    local healthBar = (FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain and FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar) or FocusFrameHealthBar;
    if healthBar then
        UberUI.general:SetHealthColor(healthBar, "focus", uuidb.focusframes);
    end

    local totHealthBar = (FocusFrameToT and FocusFrameToT.HealthBar) or FocusFrameToTHealthBar;
    if totHealthBar then
        UberUI.general:SetHealthColor(totHealthBar, "focustarget", uuidb.focusframes);
    end
end

function focusframes:HealthManaBarTexture()
    if not FocusFrame then return end
    local focusFrameMain = FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentMain;
    local healthBar = (focusFrameMain and focusFrameMain.HealthBarsContainer.HealthBar) or FocusFrameHealthBar;
    local manaBar = (focusFrameMain and focusFrameMain.ManaBar) or FocusFrameManaBar;
    
    local totHealthBar = (FocusFrameToT and FocusFrameToT.HealthBar) or FocusFrameToTHealthBar;
    local totManaBar = (FocusFrameToT and FocusFrameToT.ManaBar) or FocusFrameToTManaBar;

    local textureToApply
    if uuidb.general.focusbartextures then
        if uuidb.general.focusbartexture ~= "Blizzard" then
            textureToApply = uuidb.statusbars[uuidb.general.focusbartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply then
        if healthBar then healthBar:SetStatusBarTexture(textureToApply); end
        if totHealthBar then totHealthBar:SetStatusBarTexture(textureToApply); end

        local focusPowerType = UnitPowerType("focus");
        if (focusPowerType and focusPowerType < 4) and manaBar then
            manaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[focusPowerType];
            manaBar:SetStatusBarDesaturated(true)
            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
        end

        local focusTotPowerType = UnitPowerType("focustarget");
        if (focusTotPowerType and focusTotPowerType < 4) and totManaBar then
            totManaBar:SetStatusBarTexture(textureToApply);
            local pc = PowerBarColor[focusTotPowerType];
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
            healthBar.TotalAbsorbBar.Fill:SetVertexColor(.6, .9, .9, 1);
        end
    end
end

function focusframes:PvPIcon()
    if not FocusFrame then return end
    if FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual then
        UberUI.general:PvPIcon(FocusFrame.TargetFrameContent.TargetFrameContentContextual);
    elseif FocusFrameTextureFramePVPIcon then
        UberUI.general:PvPIcon(FocusFrameTextureFramePVPIcon);
    end
end

-- Focus Frame Aura Container Constants
local FOCUS_TOP_X = 25
local FOCUS_TOP_Y = 26
local FOCUS_LARGE_AURA_SIZE = 17
local FOCUS_SMALL_AURA_SIZE = 13
local FOCUS_AURA_SPACING = 3

local function IsSecret(v)
    return (issecretvalue and issecretvalue(v))
end

local function SafeBool(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    return (v == true)
end

function focusframes:UpdateAuraButtonStyle(button)
    if not button or IsSecret(button) then return end
    local okF, isForbid = pcall(button.IsForbidden, button)
    if okF and SafeBool(isForbid) then return end

    local isBuff = button.isBuff
    local style = "both"
    if uuidb and uuidb.general then
        style = isBuff and (uuidb.general.aurastyle_focusbuffs or "both") or (uuidb.general.aurastyle_focusdebuffs or "zoom")
    end
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    for _, key in ipairs({"Border", "border", "DebuffBorder", "DispelBorder", "BorderOverlay", "Overlay"}) do
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
            button.borderHost:ClearAllPoints()
            button.borderHost:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
            button.borderHost:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)

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
                        button.borderTex:SetVertexColor(1, 1, 1, 1)
                    end
                    if button.GetDispelTypeTextureCount and button:GetDispelTypeTextureCount() == 0 and button.AddDispelTypeTexture then
                        local dispelStyle = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.Border
                        if dispelStyle then
                            pcall(button.AddDispelTypeTexture, button, button.borderTex, {
                                style = dispelStyle,
                                showWhenHarmful = true,
                                showWhenHelpful = false,
                                showWithoutDispelType = true,
                            })
                            if button.UpdateAuraDisplay then
                                pcall(button.UpdateAuraDisplay, button)
                            end
                        end
                    end
                else
                    button.borderHost:Hide()
                end
            end
        end)
    end
end

local function MakeGroupLayout(elementSize, spacingX, spacingY, forceNewLine, layoutIndex)
    return {
        elementWidth = elementSize,
        elementHeight = elementSize,
        elementSpacing = spacingX or FOCUS_AURA_SPACING,
        lineSpacing = (spacingY or FOCUS_AURA_SPACING) + 2,
        groupSpacing = 0,
        groupLineSpacing = (spacingY or FOCUS_AURA_SPACING) + 2,
        forceNewLine = forceNewLine or false,
        layoutIndex = layoutIndex,
    }
end

local function RefreshContainerButtons(container)
    if not container or not container.allButtons then return end
    for button in pairs(container.allButtons) do
        focusframes:UpdateAuraButtonStyle(button)
    end
end

function focusframes:UpdateAuraPositions()
    if self.customAuras and FocusFrame then
        self.customAuras:ClearAllPoints()
        self.customAuras:SetPoint("TOPLEFT", FocusFrame, "BOTTOMLEFT", FOCUS_TOP_X, FOCUS_TOP_Y)
    end
end

function focusframes:UpdateAuras()
    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local blizzAuras = FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual and FocusFrame.TargetFrameContent.TargetFrameContentContextual.Auras

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

    if not FocusFrame or not FocusFrame:IsShown() then
        self.customAuras:Hide()
        return
    end

    self.customAuras:Show()

    local isFriend = false
    if UnitExists("focus") then
        local okU, isSelf = pcall(UnitIsUnit, "player", "focus")
        if okU and SafeBool(isSelf) then
            isFriend = true
        else
            local okF, isF = pcall(UnitIsFriend, "player", "focus")
            if okF and not IsSecret(isF) then
                isFriend = isF and true or false
            end
        end
    end

    local function GetGroupVisibleCount(groupKey)
        if not self.customAuras then return 0 end
        local ok, grp = pcall(self.customAuras.GetAuraGroup, self.customAuras, groupKey)
        if ok and grp and grp.GetFramesByIndex then
            local okF, frames = pcall(grp.GetFramesByIndex, grp)
            if okF and type(frames) == "table" then
                return #frames
            end
        end
        return 0
    end

    if self.customAuras and self.customAuras.SetAuraGroupLayout then
        local layoutBuffsMine, layoutBuffsOther, layoutDebuffsMine, layoutDebuffsOther
        if isFriend then
            local hasBuffs = (GetGroupVisibleCount("buffs_mine") > 0) or (GetGroupVisibleCount("buffs_other") > 0)
            local hasDebuffsMine = (GetGroupVisibleCount("debuffs_mine") > 0)
            layoutBuffsMine = MakeGroupLayout(FOCUS_LARGE_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, false, 1)
            layoutBuffsOther = MakeGroupLayout(FOCUS_SMALL_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, false, 2)
            layoutDebuffsMine = MakeGroupLayout(FOCUS_LARGE_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, hasBuffs, 3)
            layoutDebuffsOther = MakeGroupLayout(FOCUS_SMALL_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, (not hasDebuffsMine) and hasBuffs, 4)
        else
            local hasDebuffs = (GetGroupVisibleCount("debuffs_mine") > 0) or (GetGroupVisibleCount("debuffs_other") > 0)
            local hasBuffsMine = (GetGroupVisibleCount("buffs_mine") > 0)
            layoutDebuffsMine = MakeGroupLayout(FOCUS_LARGE_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, false, 1)
            layoutDebuffsOther = MakeGroupLayout(FOCUS_SMALL_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, false, 2)
            layoutBuffsMine = MakeGroupLayout(FOCUS_LARGE_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, hasDebuffs, 3)
            layoutBuffsOther = MakeGroupLayout(FOCUS_SMALL_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, (not hasBuffsMine) and hasDebuffs, 4)
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

function focusframes:ForceZoom()
    self:UpdateAuras()
end

function focusframes:SetupCustomAuraContainer()
    local styleBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusbuffs) or "both"
    local styleDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusdebuffs) or "zoom"
    local bothNone = (styleBuffs == "none" and styleDebuffs == "none")

    local blizzAuras = FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual and FocusFrame.TargetFrameContent.TargetFrameContentContextual.Auras

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

    if not FocusFrame or not blizzAuras then return end

    blizzAuras:Hide()
    blizzAuras:SetAlpha(0)
    if not self.blizzHooked then
        self.blizzHooked = true
        hooksecurefunc(blizzAuras, "Show", function(self)
            local sBuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusbuffs) or "both"
            local sDebuffs = (uuidb and uuidb.general and uuidb.general.aurastyle_focusdebuffs) or "zoom"
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
        icon:SetAllPoints(button)
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

        local pad = 3
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
        stealable:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
        stealable:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
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
            local dispelStyle = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle and Enum.CustomAuraButtonDispelTypeTextureStyle.Border
            if dispelStyle then
                pcall(button.AddDispelTypeTexture, button, borderTex, {
                    style = dispelStyle,
                    showWhenHarmful = true,
                    showWhenHelpful = false,
                    showWithoutDispelType = true,
                })
            end
        end

        focusframes:UpdateAuraButtonStyle(button)
    end

    if not self.customAuras then
        local okC, container = pcall(function()
            return CreateFrame("AuraContainer", "UberUI_FocusAuras", FocusFrame, "CustomAuraContainerTemplate")
        end)
        if okC and container then
            self.customAuras = container

            container:SetSize(1, 1)
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", FocusFrame, "BOTTOMLEFT", FOCUS_TOP_X, FOCUS_TOP_Y)
            container:SetFlowLayoutAnchorPoint("TOPLEFT")
            container:SetFlowLayoutGrowthDirection(1, -1)
            container:SetFlowLayoutMaximumLineSize(122)
            container:SetFlowLayoutPadding(0, 0, 0, 0)
            if container.SetFlowLayoutSpacing then
                pcall(container.SetFlowLayoutSpacing, container, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING + 2)
            end

            container:AddAuraGroup("buffs_mine", "HELPFUL|PLAYER", {
                maxFrameCount = (styleBuffs ~= "none") and 32 or 0,
                initializeFrame = function(btn) InitAuraButton(container, btn, true, FOCUS_LARGE_AURA_SIZE, true) end,
                layout = MakeGroupLayout(FOCUS_LARGE_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, false, 1),
            })

            container:AddAuraGroup("buffs_other", "HELPFUL|!PLAYER", {
                maxFrameCount = (styleBuffs ~= "none") and 32 or 0,
                initializeFrame = function(btn) InitAuraButton(container, btn, true, FOCUS_SMALL_AURA_SIZE, false) end,
                layout = MakeGroupLayout(FOCUS_SMALL_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, false, 2),
            })

            container:AddAuraGroup("debuffs_mine", "HARMFUL|PLAYER", {
                maxFrameCount = (styleDebuffs ~= "none") and 16 or 0,
                initializeFrame = function(btn) InitAuraButton(container, btn, false, FOCUS_LARGE_AURA_SIZE, true) end,
                layout = MakeGroupLayout(FOCUS_LARGE_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, true, 3),
            })

            container:AddAuraGroup("debuffs_other", "HARMFUL|!PLAYER", {
                maxFrameCount = (styleDebuffs ~= "none") and 16 or 0,
                initializeFrame = function(btn) InitAuraButton(container, btn, false, FOCUS_SMALL_AURA_SIZE, false) end,
                layout = MakeGroupLayout(FOCUS_SMALL_AURA_SIZE, FOCUS_AURA_SPACING, FOCUS_AURA_SPACING, false, 4),
            })

            if container.ApplyLayout then
                hooksecurefunc(container, "ApplyLayout", function()
                    RefreshContainerButtons(container)
                end)
            end

            container:SetUnit("focus")
            container:UpdateAllAuras()
        end
    end

    if FocusFrame and FocusFrame:IsShown() then
        if self.customAuras then self.customAuras:Show() end
    else
        if self.customAuras then self.customAuras:Hide() end
    end

    if not self.focusFrameHooked and FocusFrame then
        self.focusFrameHooked = true
        FocusFrame:HookScript("OnShow", function()
            if focusframes.customAuras then
                focusframes.customAuras:Show()
                focusframes.customAuras:UpdateAllAuras()
            end
            focusframes:UpdateAuras()
        end)
        FocusFrame:HookScript("OnHide", function()
            if focusframes.customAuras then focusframes.customAuras:Hide() end
        end)
    end
end

-- Initialize immediately if FocusFrame is already present
focusframes:SetupCustomAuraContainer()

if FocusFrame and FocusFrame.UpdateAuras then
    hooksecurefunc(FocusFrame, "UpdateAuras", function(self)
        if focusframes and focusframes.UpdateAuras then
            focusframes:UpdateAuras()
        end
    end)
end

if FocusFrame_UpdateAuras then
    hooksecurefunc("FocusFrame_UpdateAuras", function(self)
        if focusframes and focusframes.UpdateAuras then
            focusframes:UpdateAuras()
        end
    end)
end

local focusAuras = FocusFrame and FocusFrame.TargetFrameContent and FocusFrame.TargetFrameContent.TargetFrameContentContextual and FocusFrame.TargetFrameContent.TargetFrameContentContextual.Auras
if focusAuras then
    if focusAuras.ApplyLayout then
        hooksecurefunc(focusAuras, "ApplyLayout", function(self)
            if focusframes and focusframes.UpdateAuras then
                focusframes:UpdateAuras()
            end
        end)
    end
    if focusAuras.UpdateAllAuras then
        hooksecurefunc(focusAuras, "UpdateAllAuras", function(self)
            if focusframes and focusframes.UpdateAuras then
                focusframes:UpdateAuras()
            end
        end)
    end
end

if FocusFrame then
    if FocusFrame.CheckFaction then
        hooksecurefunc(FocusFrame, "CheckFaction", function(self)
            if focusframes and focusframes.HealthBarColor then
                focusframes:HealthBarColor()
            end
        end)
    end
    if FocusFrame.Update then
        hooksecurefunc(FocusFrame, "Update", function(self)
            if focusframes then
                focusframes:HealthBarColor()
                focusframes:HealthManaBarTexture()
            end
        end)
    end
end

UberUI.focusframes = focusframes
