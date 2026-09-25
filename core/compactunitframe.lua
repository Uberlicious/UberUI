local addon, ns = ...
local cuf = {}

cuf = UberUI:CreateFrame("Frame")
cuf:RegisterEvent("ADDON_LOADED")
cuf:SetScript("OnEvent", function(self)
    self:set_hook()
    self:HideRaidFrameTitles()
end)

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

-- hooksecurefunc can't be undone, so these two independent hooks are only
-- installed once their own setting is actually active, and installed lazily
-- (idempotent Ensure* calls) if the setting is turned on later without a
-- reload -- EnsureTextureHook() is called again from
-- misc:AllFramesHealthManaTexture() (which the Raid/Secondary/All Bar
-- Textures settings already refresh through on change), and EnsureTitleHook()
-- from HideRaidFrameTitles() itself (which the Hide Raid Frame Titles
-- checkbox already calls directly on change). Both toggles work live either
-- direction; nothing here needs a reload.
local function IsCompactBarTextureActive()
    if not uuidb or not uuidb.general then return false end
    local g = uuidb.general
    return (g.raidbartextures and g.raidbartexture ~= "Blizzard")
        or (g.allbartextures and g.texture ~= "Blizzard")
        or (g.secondarybartextures and g.secondarybartexture ~= "Blizzard")
end

local textureHookInstalled = false
function cuf:EnsureTextureHook()
    if textureHookInstalled or not IsCompactBarTextureActive() then return end
    if type(CompactUnitFrame_UpdateHealthColor) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", cuf.default)
    elseif CompactUnitFrameMixin and type(CompactUnitFrameMixin.UpdateHealthColor) == "function" then
        hooksecurefunc(CompactUnitFrameMixin, "UpdateHealthColor", cuf.default)
    else
        return
    end
    textureHookInstalled = true
end

local titleHookInstalled = false
local function EnsureTitleHook()
    if titleHookInstalled or not (uuidb and uuidb.cuf and uuidb.cuf.hideRaidTitle) then return end
    if type(CompactUnitFrame_UpdateAll) == "function" then
        hooksecurefunc("CompactUnitFrame_UpdateAll", cuf.HideRaidFrameTitles)
    elseif CompactUnitFrameMixin and type(CompactUnitFrameMixin.UpdateAll) == "function" then
        hooksecurefunc(CompactUnitFrameMixin, "UpdateAll", cuf.HideRaidFrameTitles)
    else
        return
    end
    titleHookInstalled = true
end

function cuf:set_hook()
    self:EnsureTextureHook()
    EnsureTitleHook()
end

function cuf:HideRaidFrameTitles()
    EnsureTitleHook()
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

function cuf:UpdateAllAuras()
    -- CompactUnitFrame auras are locked in Blizzard's forbidden secure environment
    -- to protect secret health values from taint.
end

cuf.ForceZoom = cuf.UpdateAllAuras

UberUI.cuf = cuf
