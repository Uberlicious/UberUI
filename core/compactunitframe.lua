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

-- This function will be called for each party/raid frame to color its debuff borders.
local function ColorCompactFrameAuras(frame)
    local dc = uuidb.general.darkencolor
    -- Ensure the frame and its buffFrames table exist
    if frame and frame.buffFrames then
        for i = 1, #frame.buffFrames do
            local buffFrame = frame.buffFrames[i]

            -- Create the border texture only if it doesn't already exist to prevent re-creation on each update
            -- if buffFrame and not buffFrame.uberUIBorder then
            --     -- Create a new texture as a child of the buff frame, drawn on the "OVERLAY" layer to appear above the icon
            --     local border = buffFrame:CreateTexture(nil, "OVERLAY")
            --     buffFrame.uberUIBorder = border

            --     -- Use the same texture and settings from your target frame for a consistent look
            --     border:SetTexture(130759) -- Corresponds to "Interface/Buttons/UI-Quickslot-Depress"

            --     -- Set the position and size to wrap the buff frame, creating a border effect
            --     border:SetPoint("TOPLEFT", buffFrame, "TOPLEFT", -1, 1)
            --     border:SetPoint("BOTTOMRIGHT", buffFrame, "BOTTOMRIGHT", 1, -1)

            --     -- These specific texture coordinates select the "depressed" border part of the texture sheet
            --     border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)

            --     -- Set blend mode and the dark color to match your UI's aesthetic
            --     border:SetBlendMode("BLEND")
            --     border:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            -- end
            if buffFrame.icon then
                UberUI.general:ApplyIconZoom(buffFrame.icon, uuidb.general.zoomiconcompact)
            end
        end
    end

    if frame and frame.debuffFrames then
        for i = 1, #frame.debuffFrames do
            local buffFrame = frame.debuffFrames[i]

            -- Create the border texture only if it doesn't already exist to prevent re-creation on each update
            -- if buffFrame and not buffFrame.uberUIBorder then
            --     -- Create a new texture as a child of the buff frame, drawn on the "OVERLAY" layer to appear above the icon
            --     local border = buffFrame:CreateTexture(nil, "OVERLAY")
            --     buffFrame.uberUIBorder = border

            --     -- Use the same texture and settings from your target frame for a consistent look
            --     border:SetTexture(130759) -- Corresponds to "Interface/Buttons/UI-Quickslot-Depress"

            --     -- Set the position and size to wrap the buff frame, creating a border effect
            --     border:SetPoint("TOPLEFT", buffFrame, "TOPLEFT", -1, 1)
            --     border:SetPoint("BOTTOMRIGHT", buffFrame, "BOTTOMRIGHT", 1, -1)

            --     -- These specific texture coordinates select the "depressed" border part of the texture sheet
            --     border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)

            --     -- Set blend mode and the dark color to match your UI's aesthetic
            --     border:SetBlendMode("BLEND")
            --     border:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            -- end
            if buffFrame.icon then
                UberUI.general:ApplyIconZoom(buffFrame.icon, uuidb.general.zoomiconcompact)
            end
        end
    end
end

-- Hook the secure function that Blizzard uses to update auras on all compact unit frames
-- (which includes party and raid frames).
if type(CompactUnitFrame_UpdateAuras) == "function" then
    hooksecurefunc("CompactUnitFrame_UpdateAuras", ColorCompactFrameAuras)
elseif CompactUnitFrameMixin and type(CompactUnitFrameMixin.UpdateAuras) == "function" then
    hooksecurefunc(CompactUnitFrameMixin, "UpdateAuras", ColorCompactFrameAuras)
end

function cuf:ForceZoom()
    if CompactRaidFrameContainer then
        for _, child in ipairs({ CompactRaidFrameContainer:GetChildren() }) do
            if not child:IsForbidden() then
                ColorCompactFrameAuras(child)
            end
        end
    end
    if CompactPartyFrame then
        for _, child in ipairs({ CompactPartyFrame:GetChildren() }) do
            if not child:IsForbidden() then
                ColorCompactFrameAuras(child)
            end
        end
    end
end

UberUI.cuf = cuf
