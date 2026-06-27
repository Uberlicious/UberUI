local addon, ns = ...
local prd = {}

local function GetMaskTexture()
    if uuidb and uuidb.masks and uuidb.masks.cdm_mask then
        return uuidb.masks.cdm_mask
    end
    return [[Interface\AddOns\Uber UI\textures\statusbars\cdm_bar_mask.tga]]
end

local MASK_OPTS = {
    insetL = 0,  -- left crop
    insetT = 0,  -- top crop (raise top edge)
    insetR = 0,  -- right crop (pull right edge inward more)
    insetB = -1, -- bottom crop
    shiftX = 0,  -- whole mask shift on X
    shiftY = 0,  -- whole mask shift on Y (raise mask slightly)
}

function prd:StyleStatusBar(healthBar)
    if not healthBar then return end

    -- 1. Apply Status Bar Texture
    local textureToApply
    if uuidb.general.personalresourcebartextures and uuidb.general.personalresourcebartexture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.personalresourcebartexture]
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply and type(textureToApply) == "string" then
        healthBar:SetStatusBarTexture(textureToApply)

        -- Force draw layer to ensure it shows over atlases
        local sbt = healthBar:GetStatusBarTexture()
        if sbt then
            sbt:SetDrawLayer("ARTWORK", 1)
        end

        -- Handle Background
        local bgRegions = { healthBar:GetRegions() }
        for _, region in ipairs(bgRegions) do
            if region:IsObjectType("Texture") and region:GetDrawLayer() == "BACKGROUND" then
                local dc = uuidb.general.darkencolor
                region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
        end
    end

    -- MASKING LOGIC
    if healthBar.CreateMaskTexture and healthBar.GetStatusBarTexture then
        local opts = MASK_OPTS
        local L, T, R, B = opts.insetL or 0, opts.insetT or 0, opts.insetR or 0, opts.insetB or 0
        local SX, SY = opts.shiftX or 0, opts.shiftY or 0

        if not healthBar._uberMask then
            local m = healthBar:CreateMaskTexture(nil, "OVERLAY")
            if m and m.SetTexture then
                m:SetTexture(GetMaskTexture(), "CLAMPTOBLACK", "CLAMPTOBLACK")
                if m.SetSnapToPixelGrid then m:SetSnapToPixelGrid(true) end
                if m.SetTexelSnappingBias then m:SetTexelSnappingBias(0) end
                if m.SetHorizTile then m:SetHorizTile(false) end
                if m.SetVertTile then m:SetVertTile(false) end
                healthBar._uberMask = m
            end
        end
        local m = healthBar._uberMask

        if m and m.ClearAllPoints and m.SetPoint then
            m:ClearAllPoints()
            m:SetPoint("TOPLEFT", healthBar, "TOPLEFT", L + SX, -(T - SY))
            m:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -R + SX, B + SY)
        end

        -- Apply the mask to the fill texture
        local fill = healthBar:GetStatusBarTexture()
        if fill and m and fill.AddMaskTexture and not fill._masked then
            fill:AddMaskTexture(m)
            fill._masked = true
        end
    end
end

function prd:StylePRD(frame)
    if not frame then return end

    -- Style Health Bar
    if frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar then
        local healthBar = frame.HealthBarsContainer.healthBar
        self:StyleStatusBar(healthBar)

        -- Secondary texture logic for absorbs and heals
        local secondaryTextureToApply
        if uuidb.general.secondarybartextures and uuidb.general.secondarybartexture ~= "Blizzard" then
            secondaryTextureToApply = uuidb.statusbars[uuidb.general.secondarybartexture]
        else
            if uuidb.general.personalresourcebartextures and uuidb.general.personalresourcebartexture ~= "Blizzard" then
                secondaryTextureToApply = uuidb.statusbars[uuidb.general.personalresourcebartexture]
            elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
                secondaryTextureToApply = uuidb.statusbars[uuidb.general.texture]
            end
        end

        if secondaryTextureToApply then
            if healthBar.myHealPrediction then
                healthBar.myHealPrediction:SetTexture(secondaryTextureToApply)
            end
            if healthBar.otherHealPrediction then
                healthBar.otherHealPrediction:SetTexture(secondaryTextureToApply)
            end
            if healthBar.totalAbsorb then
                healthBar.totalAbsorb:SetTexture(secondaryTextureToApply)
                healthBar.totalAbsorb:SetVertexColor(.6, .9, .9, 1)
            end
        end
    end

    -- Style Power Bar
    if frame.PowerBar then
        self:StyleStatusBar(frame.PowerBar)
    end

    -- Style Alternate Power Bar
    if frame.AlternatePowerBar then
        self:StyleStatusBar(frame.AlternatePowerBar)
    end
end

-- Hook for Class Colors
local function RegisterPRDHooks()
    if prd.hooksRegistered then return end
    prd.hooksRegistered = true

    -- Hook for Darkening Borders (In 12.1, PRD borders are actually atlased on the StatusBar)
    if PersonalResourceDisplayMixin and type(PersonalResourceDisplayMixin.Setup) == "function" then
        hooksecurefunc(PersonalResourceDisplayMixin, "Setup", function(self)
            if uuidb.general.darkenpersonalresourceborder then
                local dc = uuidb.general.darkencolor

                -- Darken Health Bar border/background
                if self.HealthBarsContainer and self.HealthBarsContainer.healthBar then
                    local regions = { self.HealthBarsContainer.healthBar:GetRegions() }
                    for _, region in ipairs(regions) do
                        if region:GetObjectType() == "Texture" and (region:GetAtlas() == "UI-HUD-CoolDownManager-Bar" or region:GetAtlas() == "UI-HUD-CoolDownManager-Bar-BG") then
                            region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                        end
                    end
                end

                -- Darken Power Bar border/background
                if self.PowerBar then
                    local regions = { self.PowerBar:GetRegions() }
                    for _, region in ipairs(regions) do
                        if region:GetObjectType() == "Texture" and (region:GetAtlas() == "UI-HUD-CoolDownManager-Bar" or region:GetAtlas() == "UI-HUD-CoolDownManager-Bar-BG") then
                            region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                        end
                    end
                end
            end
        end)
    end

    -- Hook to apply textures when the PRD is loaded/updated
    if PersonalResourceDisplayMixin and type(PersonalResourceDisplayMixin.Setup) == "function" then
        hooksecurefunc(PersonalResourceDisplayMixin, "Setup", function(self)
            UberUI.personalresource:StylePRD(self)
        end)
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == "Blizzard_PersonalResourceDisplay" then
        RegisterPRDHooks()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if (C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_PersonalResourceDisplay")) or PersonalResourceDisplayMixin then
            RegisterPRDHooks()
        end
        if PersonalResourceDisplayFrame then
            UberUI.personalresource:StylePRD(PersonalResourceDisplayFrame)
        end
    end
end)
function prd:ForceTexture()
    -- Apply the update to the PRD if it currently exists
    if PersonalResourceDisplayFrame then
        self:StylePRD(PersonalResourceDisplayFrame)
        if PersonalResourceDisplayFrame.UpdateHealthColor then
            PersonalResourceDisplayFrame:UpdateHealthColor()
        end
        if PersonalResourceDisplayFrame.Setup then
            PersonalResourceDisplayFrame:Setup()
        end
    end
end

UberUI.personalresource = prd
