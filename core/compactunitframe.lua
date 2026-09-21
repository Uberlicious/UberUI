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
        local pad = 2
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

    local pad = 2
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

local origAreRaidFramesForcedShown = nil
local origGetNumRaidMembersForcedShown = nil
local origArePartyFramesForcedShown = nil

function cuf:ToggleTestMode(enable)
    if InCombatLockdown() then
        print("|cffff0000[UberUI]|r Cannot toggle raid test mode while in combat.")
        return
    end

    if enable == nil then
        enable = not cuf.testMode
    end
    cuf.testMode = enable

    if not EditModeManagerFrame then
        print("|cffff0000[UberUI]|r EditModeManagerFrame not found.")
        return
    end

    if not origAreRaidFramesForcedShown then
        origAreRaidFramesForcedShown = EditModeManagerFrame.AreRaidFramesForcedShown
    end
    if not origGetNumRaidMembersForcedShown then
        origGetNumRaidMembersForcedShown = EditModeManagerFrame.GetNumRaidMembersForcedShown
    end
    if not origArePartyFramesForcedShown then
        origArePartyFramesForcedShown = EditModeManagerFrame.ArePartyFramesForcedShown
    end

    if enable then
        EditModeManagerFrame.AreRaidFramesForcedShown = function(self) return true end
        EditModeManagerFrame.GetNumRaidMembersForcedShown = function(self) return 5 end
        EditModeManagerFrame.ArePartyFramesForcedShown = function(self) return true end

        if CompactRaidFrameContainer then
            pcall(CompactRaidFrameContainer.TryUpdate, CompactRaidFrameContainer)
            pcall(CompactRaidFrameContainer.Show, CompactRaidFrameContainer)
        end
        if CompactPartyFrame then
            pcall(CompactPartyFrame.Show, CompactPartyFrame)
            if CompactPartyFrame.RefreshMembers then
                pcall(CompactPartyFrame.RefreshMembers, CompactPartyFrame)
            end
        end
        C_Timer.After(0.1, function()
            cuf:UpdateAllAuras()
        end)
        print("|cff00ff00[UberUI]|r Test raid/party frames shown (forced preview with 5 members). Use |cffffff00/uui testraid|r to hide.")
    else
        if origAreRaidFramesForcedShown then
            EditModeManagerFrame.AreRaidFramesForcedShown = origAreRaidFramesForcedShown
        end
        if origGetNumRaidMembersForcedShown then
            EditModeManagerFrame.GetNumRaidMembersForcedShown = origGetNumRaidMembersForcedShown
        end
        if origArePartyFramesForcedShown then
            EditModeManagerFrame.ArePartyFramesForcedShown = origArePartyFramesForcedShown
        end

        if CompactRaidFrameContainer then
            pcall(CompactRaidFrameContainer.TryUpdate, CompactRaidFrameContainer)
        end
        if CompactPartyFrame and CompactPartyFrame.UpdateVisibility then
            pcall(CompactPartyFrame.UpdateVisibility, CompactPartyFrame)
        end
        print("|cff00ff00[UberUI]|r Test raid/party frames hidden.")
    end
end

UberUI.cuf = cuf
