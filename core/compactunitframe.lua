local addon, ns = ...
local cuf = {}

cuf = UberUI:CreateFrame("Frame");
cuf:RegisterEvent("ADDON_LOADED")
cuf:SetScript("OnEvent", function(self)
    self:set_hook();
    self:HideRaidFrameTitles();
end)

local default_hook = false

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

    local hsbt = self.healthBar:GetStatusBarTexture()
    local psbt = self.powerBar:GetStatusBarTexture()
    -- print("Before:", self:GetName(), hsbt:GetDrawLayer(), psbt:GetDrawLayer(), self.aggroHighlight:GetDrawLayer())
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

UberUI.cuf = cuf
