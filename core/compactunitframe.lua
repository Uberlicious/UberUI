local addon, ns = ...
local cuf = {}

cuf = UberUI:CreateFrame("Frame")
cuf:RegisterEvent("ADDON_LOADED")
cuf:RegisterEvent("PLAYER_ENTERING_WORLD")
cuf:RegisterEvent("PLAYER_REGEN_DISABLED")
cuf:SetScript("OnEvent", function(self, event)
    self:set_hook()
    self:HideRaidFrameTitles()
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            cuf:UpdateAllAuras()
        end)
    elseif event == "PLAYER_REGEN_DISABLED" then
        if cuf.testMode then
            cuf:ToggleTestMode(false)
        end
    end
end)

local default_hook = false

local function IsSecret(v)
    return (issecretvalue and issecretvalue(v))
end

local function SafeBool(v)
    if v == nil or IsSecret(v) then return false end
    return (v == true)
end

cuf.default = function(self)
    if not self or not self.healthBar or self:IsForbidden() then return end

    -- Only apply to raid and party frames
    local frameName = self:GetName()
    if not frameName or not (frameName:find("CompactRaid") or frameName:find("CompactParty") or frameName:find("CompactArena")) then
        return
    end

    local textureToApply
    if uuidb.general.raidbartextures and uuidb.general.raidbartexture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.raidbartexture]
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply then
        self.healthBar:SetStatusBarTexture(textureToApply)
        local sbt = self.healthBar:GetStatusBarTexture()
        if sbt then
            sbt:SetDrawLayer("BORDER", 3)
        end

        if self.powerBar then
            self.powerBar:SetStatusBarTexture(textureToApply)
            self.powerBar:SetFrameLevel(self.healthBar:GetFrameLevel())
        end

        if self.aggroHighlight then
            self.aggroHighlight:SetDrawLayer("ARTWORK", 4)
        end

        if self.roleIcon then
            self.roleIcon:SetDrawLayer("ARTWORK", 4)
        end
    end

    -- Secondary texture logic
    local secondaryTextureToApply
    if uuidb.general.secondarybartextures and uuidb.general.secondarybartexture ~= "Blizzard" then
        secondaryTextureToApply = uuidb.statusbars[uuidb.general.secondarybartexture]
    else
        secondaryTextureToApply = textureToApply -- Fallback to main texture decision
    end

    if secondaryTextureToApply then
        if self.myHealPrediction then self.myHealPrediction:SetTexture(secondaryTextureToApply) end
        if self.otherHealPrediction then self.otherHealPrediction:SetTexture(secondaryTextureToApply) end
        if self.totalAbsorb then
            self.totalAbsorb:SetTexture(secondaryTextureToApply)
            self.totalAbsorb:SetVertexColor(.6, .9, .9, 1)
        end
    end
end

function cuf:set_hook()
    if not default_hook then
        if type(CompactUnitFrame_UpdateHealthColor) == "function" then
            hooksecurefunc("CompactUnitFrame_UpdateHealthColor", cuf.default)
        elseif CompactUnitFrameMixin and type(CompactUnitFrameMixin.UpdateHealthColor) == "function" then
            hooksecurefunc(CompactUnitFrameMixin, "UpdateHealthColor", cuf.default)
        end
        if type(CompactUnitFrame_UpdateAll) == "function" then
            hooksecurefunc("CompactUnitFrame_UpdateAll", cuf.HideRaidFrameTitles)
        elseif CompactUnitFrameMixin and type(CompactUnitFrameMixin.UpdateAll) == "function" then
            hooksecurefunc(CompactUnitFrameMixin, "UpdateAll", cuf.HideRaidFrameTitles)
        end
        default_hook = true
    end
end

function cuf:HideRaidFrameTitles()
    if not uuidb or not uuidb.cuf then return end
    for i = 1, 8 do
        local frame = _G["CompactRaidGroup" .. i]
        if frame and frame.title then
            if uuidb.cuf.hideRaidTitle then
                frame.title:Hide()
            else
                frame.title:Show()
            end
        end
    end
end

-- =========================================================================
-- COMPACT UNIT FRAME AURA STYLING
-- =========================================================================

local function StyleCompactBuff(buffFrame)
    if not buffFrame or IsSecret(buffFrame) then return end
    local okF, isForbid = pcall(buffFrame.IsForbidden, buffFrame)
    if okF and SafeBool(isForbid) then return end

    local style = (uuidb and uuidb.general and uuidb.general.aurastyle_compactbuffs) or "both"
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    local icon = buffFrame.icon or buffFrame.Icon
    if icon and icon.SetTexCoord then
        icon:ClearAllPoints()
        if zoomEnabled or darkBorderEnabled then
            icon:SetPoint("TOPLEFT", buffFrame, "TOPLEFT", 1, -1)
            icon:SetPoint("BOTTOMRIGHT", buffFrame, "BOTTOMRIGHT", -1, 1)
        else
            icon:SetAllPoints(buffFrame)
        end
        if zoomEnabled then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
    end

    local cd = buffFrame.cooldown
    local baseLevel = (cd and cd.GetFrameLevel and cd:GetFrameLevel()) or buffFrame:GetFrameLevel()
    local borderHost = buffFrame.borderHost
    if not borderHost then
        borderHost = CreateFrame("Frame", nil, buffFrame)
        borderHost:EnableMouse(false)
        buffFrame.borderHost = borderHost
    end
    borderHost:SetFrameLevel(baseLevel + 2)

    local borderTex = buffFrame.borderTex
    if not borderTex then
        borderTex = borderHost:CreateTexture(nil, "OVERLAY")
        borderTex:SetAllPoints(borderHost)
        borderTex:SetAtlas("ui-debuff-border-default-noicon")
        borderTex:SetDesaturated(true)
        buffFrame.borderTex = borderTex
    end

    if darkBorderEnabled then
        local pad = 1
        local target = icon or buffFrame
        borderHost:ClearAllPoints()
        borderHost:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
        borderHost:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
        local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        borderTex:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        borderHost:Show()
    else
        borderHost:Hide()
    end

    if buffFrame.count and buffFrame.count.SetDrawLayer then
        buffFrame.count:SetDrawLayer("OVERLAY", 7)
    end
end

local function StyleCompactDebuff(debuffFrame)
    if not debuffFrame or IsSecret(debuffFrame) then return end
    local okF, isForbid = pcall(debuffFrame.IsForbidden, debuffFrame)
    if okF and SafeBool(isForbid) then return end

    local style = (uuidb and uuidb.general and uuidb.general.aurastyle_compactdebuffs) or "zoom"
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    local icon = debuffFrame.icon or debuffFrame.Icon
    if icon and icon.SetTexCoord then
        icon:ClearAllPoints()
        if zoomEnabled or darkBorderEnabled then
            icon:SetPoint("TOPLEFT", debuffFrame, "TOPLEFT", 1, -1)
            icon:SetPoint("BOTTOMRIGHT", debuffFrame, "BOTTOMRIGHT", -1, 1)
        else
            icon:SetAllPoints(debuffFrame)
        end
        if zoomEnabled then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
    end

    local cd = debuffFrame.cooldown
    local baseLevel = (cd and cd.GetFrameLevel and cd:GetFrameLevel()) or debuffFrame:GetFrameLevel()
    local borderHost = debuffFrame.borderHost
    if not borderHost then
        borderHost = CreateFrame("Frame", nil, debuffFrame)
        borderHost:EnableMouse(false)
        debuffFrame.borderHost = borderHost
    end
    borderHost:SetFrameLevel(baseLevel + 2)

    local borderTex = debuffFrame.borderTex
    if not borderTex then
        borderTex = borderHost:CreateTexture(nil, "OVERLAY")
        borderTex:SetAllPoints(borderHost)
        borderTex:SetAtlas("ui-debuff-border-default-noicon")
        borderTex:SetDesaturated(true)
        debuffFrame.borderTex = borderTex
    end

    local pad = 1
    local blizzBorder = debuffFrame.border or debuffFrame.Border
    local target = icon or debuffFrame

    if darkBorderEnabled then
        if blizzBorder then blizzBorder:SetAlpha(0) end
        borderHost:ClearAllPoints()
        borderHost:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
        borderHost:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
        local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        borderTex:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        borderHost:Show()
    elseif zoomEnabled then
        borderHost:Hide()
        if blizzBorder then
            blizzBorder:ClearAllPoints()
            blizzBorder:SetPoint("TOPLEFT", target, "TOPLEFT", -pad, pad)
            blizzBorder:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", pad, -pad)
            blizzBorder:SetAlpha(1)
            blizzBorder:Show()
        end
    else
        borderHost:Hide()
        if blizzBorder then
            blizzBorder:ClearAllPoints()
            blizzBorder:SetPoint("TOPLEFT", debuffFrame, "TOPLEFT", -1, 1)
            blizzBorder:SetPoint("BOTTOMRIGHT", debuffFrame, "BOTTOMRIGHT", 1, -1)
            blizzBorder:SetAlpha(1)
        end
    end

    if debuffFrame.count and debuffFrame.count.SetDrawLayer then
        debuffFrame.count:SetDrawLayer("OVERLAY", 7)
    end
end

local function ColorCompactFrameAuras(frame)
    if not frame or IsSecret(frame) then return end
    local okF, isForbid = pcall(frame.IsForbidden, frame)
    if okF and SafeBool(isForbid) then return end

    if frame.buffFrames then
        for _, bf in ipairs(frame.buffFrames) do
            if bf and bf:IsShown() then
                StyleCompactBuff(bf)
            end
        end
    end
    if frame.debuffFrames then
        for _, df in ipairs(frame.debuffFrames) do
            if df and df:IsShown() then
                StyleCompactDebuff(df)
            end
        end
    end
end

-- Secure hooks for individual aura setters
if type(CompactUnitFrame_UtilSetBuff) == "function" then
    hooksecurefunc("CompactUnitFrame_UtilSetBuff", function(buffFrame, aura)
        StyleCompactBuff(buffFrame)
    end)
end

if type(CompactUnitFrame_UtilSetDebuff) == "function" then
    hooksecurefunc("CompactUnitFrame_UtilSetDebuff", function(debuffFrame, aura)
        StyleCompactDebuff(debuffFrame)
    end)
end

if type(CompactUnitFrame_UpdateAuras) == "function" then
    hooksecurefunc("CompactUnitFrame_UpdateAuras", ColorCompactFrameAuras)
end
if CompactUnitFrameMixin and type(CompactUnitFrameMixin.UpdateAuras) == "function" then
    hooksecurefunc(CompactUnitFrameMixin, "UpdateAuras", ColorCompactFrameAuras)
end

function cuf:UpdateAllAuras()
    local function StyleFrames(parent)
        if not parent or IsSecret(parent) then return end
        local okF, isForbid = pcall(parent.IsForbidden, parent)
        if okF and SafeBool(isForbid) then return end

        if parent.buffFrames then
            for _, bf in ipairs(parent.buffFrames) do
                if bf and bf:IsShown() then
                    StyleCompactBuff(bf)
                end
            end
        end
        if parent.debuffFrames then
            for _, df in ipairs(parent.debuffFrames) do
                if df and df:IsShown() then
                    StyleCompactDebuff(df)
                end
            end
        end
    end

    if CompactPartyFrame and CompactPartyFrame.memberUnitFrames then
        for _, memberFrame in ipairs(CompactPartyFrame.memberUnitFrames) do
            StyleFrames(memberFrame)
        end
    end

    if CompactRaidFrameContainer and CompactRaidFrameContainer.ApplyToFrames then
        pcall(CompactRaidFrameContainer.ApplyToFrames, CompactRaidFrameContainer, "normal", StyleFrames)
    end

    for i = 1, 5 do
        local f = _G["CompactPartyFrameMember" .. i]
        if f then StyleFrames(f) end
    end
    for i = 1, 40 do
        local f = _G["CompactRaidFrame" .. i]
        if f then StyleFrames(f) end
    end
    for g = 1, 8 do
        for m = 1, 5 do
            local f = _G["CompactRaidGroup" .. g .. "Member" .. m]
            if f then StyleFrames(f) end
        end
    end
end

cuf.ForceZoom = cuf.UpdateAllAuras

-- =========================================================================
-- MANUAL RAID / PARTY FRAME TEST PREVIEW
-- =========================================================================

local previewFrame = nil

local function CreateCUFPreview()
    if previewFrame then return previewFrame end

    local f = CreateFrame("Frame", "UberUI_CUFTestPreview", UIParent, "BackdropTemplate")
    f:SetSize(130, 52)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)

    -- Background
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    f:SetBackdropBorderColor(dc.r, dc.g, dc.b, 1)
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.85)

    -- Title / drag header
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 4)
    title:SetText("|cff00ff00UberUI CUF Preview|r (|cffaaaaaaDrag to move|r)")
    f.title = title

    -- Health Bar
    local hb = CreateFrame("StatusBar", nil, f)
    hb:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    hb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 10)
    local texPath = (uuidb and uuidb.general and uuidb.statusbars and uuidb.general.raidbartexture and uuidb.statusbars[uuidb.general.raidbartexture])
        or (uuidb and uuidb.general and uuidb.statusbars and uuidb.general.texture and uuidb.statusbars[uuidb.general.texture])
        or "Interface\\TargetingFrame\\UI-StatusBar"
    hb:SetStatusBarTexture(texPath)
    hb:SetMinMaxValues(0, 100)
    hb:SetValue(82)
    hb:SetStatusBarColor(0.2, 0.75, 0.3)
    f.healthBar = hb

    -- Power Bar
    local pb = CreateFrame("StatusBar", nil, f)
    pb:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", 0, -1)
    pb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    pb:SetStatusBarTexture(texPath)
    pb:SetMinMaxValues(0, 100)
    pb:SetValue(65)
    pb:SetStatusBarColor(0.0, 0.5, 1.0)
    f.powerBar = pb

    -- Name text
    local name = hb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("CENTER", hb, "CENTER", 0, 6)
    name:SetText("Raid Member")
    name:SetTextColor(1, 1, 1)
    f.name = name

    -- Helper to create styled test aura icon
    local function CreateTestAura(parent, size, isBuff, iconTex, dispelType, stackCount)
        local btn = CreateFrame("Frame", nil, parent)
        btn:SetSize(size, size)

        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        icon:SetTexture(iconTex)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.icon = icon

        local borderHost = CreateFrame("Frame", nil, btn)
        borderHost:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
        borderHost:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
        borderHost:SetFrameLevel(btn:GetFrameLevel() + 2)
        borderHost:EnableMouse(false)

        local borderTex = borderHost:CreateTexture(nil, "OVERLAY")
        borderTex:SetAllPoints(borderHost)
        borderTex:SetAtlas("ui-debuff-border-default-noicon")

        local style = isBuff and ((uuidb and uuidb.general and uuidb.general.aurastyle_compactbuffs) or "both")
            or ((uuidb and uuidb.general and uuidb.general.aurastyle_compactdebuffs) or "zoom")
        local darkBorder = (style == "both" or style == "border")

        if isBuff then
            if darkBorder then
                borderTex:SetDesaturated(true)
                borderTex:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                borderHost:Show()
            else
                borderHost:Hide()
            end
        else
            -- Debuff
            if darkBorder then
                borderTex:SetDesaturated(true)
                borderTex:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                borderHost:Show()
            else
                borderTex:SetDesaturated(false)
                if dispelType == "Magic" then
                    borderTex:SetVertexColor(0.2, 0.6, 1.0)
                elseif dispelType == "Poison" then
                    borderTex:SetVertexColor(0.0, 0.8, 0.0)
                elseif dispelType == "Curse" then
                    borderTex:SetVertexColor(0.6, 0.0, 1.0)
                elseif dispelType == "Disease" then
                    borderTex:SetVertexColor(0.6, 0.4, 0.0)
                else
                    borderTex:SetVertexColor(0.8, 0.0, 0.0)
                end
                borderHost:Show()
            end
        end

        if stackCount and stackCount > 1 then
            local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            count:SetDrawLayer("OVERLAY", 7)
            count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
            count:SetText(tostring(stackCount))
        end

        return btn
    end

    -- 3 Test Buffs (bottom right, growing left)
    local buffSize = 14
    local b1 = CreateTestAura(f, buffSize, true, "Interface\\Icons\\Spell_Holy_WordFortitude", nil, 1)
    b1:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 11)

    local b2 = CreateTestAura(f, buffSize, true, "Interface\\Icons\\Spell_Holy_MagicalSentry", nil, 1)
    b2:SetPoint("RIGHT", b1, "LEFT", -2, 0)

    local b3 = CreateTestAura(f, buffSize, true, "Interface\\Icons\\Spell_Nature_Rejuvenation", nil, 3)
    b3:SetPoint("RIGHT", b2, "LEFT", -2, 0)

    -- 2 Test Debuffs (bottom left, growing right)
    local debuffSize = 14
    local d1 = CreateTestAura(f, debuffSize, false, "Interface\\Icons\\Spell_Shadow_CurseOfTounges", "Curse", 1)
    d1:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 11)

    local d2 = CreateTestAura(f, debuffSize, false, "Interface\\Icons\\Ability_Creature_Poison_02", "Poison", 1)
    d2:SetPoint("LEFT", d1, "RIGHT", 2, 0)

    f.UpdateStyles = function()
        local curDc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        f:SetBackdropBorderColor(curDc.r, curDc.g, curDc.b, 1)
        local curTex = (uuidb and uuidb.general and uuidb.statusbars and uuidb.general.raidbartexture and uuidb.statusbars[uuidb.general.raidbartexture])
            or (uuidb and uuidb.general and uuidb.statusbars and uuidb.general.texture and uuidb.statusbars[uuidb.general.texture])
            or "Interface\\TargetingFrame\\UI-StatusBar"
        hb:SetStatusBarTexture(curTex)
        pb:SetStatusBarTexture(curTex)
    end

    previewFrame = f
    return f
end

function cuf:ToggleTestMode(enable)
    if enable == nil then
        enable = not cuf.testMode
    end
    cuf.testMode = enable

    local preview = CreateCUFPreview()
    if enable then
        preview:UpdateStyles()
        preview:Show()
        print("|cff00ff00[UberUI]|r Test raid frame preview shown (standalone preview with test buffs/debuffs). Drag to move, type |cffffff00/uui testraid|r to hide.")
    else
        preview:Hide()
        print("|cff00ff00[UberUI]|r Test raid frame preview hidden.")
    end
end

UberUI.cuf = cuf
