local addon, ns = ...
local buffsandauras = {}

function buffsandauras:StyleAuraButton(button)
    if not button or not button.Icon then
        return
    end

    if uuidb.general.buffauraborders and button:IsShown() then
        local inset = 0.07
        for _, region in pairs({ button:GetRegions() }) do
            -- Check if the region is a Texture object
            if region:IsObjectType("Texture") then
                -- This is the object we need!
                local iconTexture = region

                UberUI.general:ApplyIconZoom(iconTexture, uuidb.general.zoomiconbuffs)
                break
            end
        end
    else
        if button.DebuffBorder then
            button.DebuffBorder:Hide()
        end
        if button.TempEnchantBorder then
            button.TempEnchantBorder:Hide()
        end
        if button.NormalTexture then
            button.NormalTexture:Hide()
        end
    end
end

function buffsandauras:Refresh()
    if BuffFrame then
        if BuffFrame.auraFrames then
            for _, button in ipairs(BuffFrame.auraFrames) do
                self:StyleAuraButton(button)
            end
        else
            for i = 1, 32 do
                local btn = _G["BuffButton"..i]
                if btn then self:StyleAuraButton(btn) end
            end
        end
    end

    if DebuffFrame then
        if DebuffFrame.auraFrames then
            for _, button in ipairs(DebuffFrame.auraFrames) do
                self:StyleAuraButton(button)
            end
        else
            for i = 1, 16 do
                local btn = _G["DebuffButton"..i]
                if btn then self:StyleAuraButton(btn) end
            end
        end
    end

    self:ColorAuras(true)
end

function buffsandauras:ColorAuras(force)
    local dc = uuidb.general.darkencolor;
    local tx = MultiBarBottomRightButton1NormalTexture and MultiBarBottomRightButton1NormalTexture:GetAtlas()

    local function HandleAuras(frame)
        if not frame then return end
        local frameName = frame:GetName();
        for _, v in pairs({ frame:GetChildren() }) do
            if (force) then
                v.styled = nil;
            end

            if not v.styled and v.Icon then
                if uuidb.general.buffauraborders then
                    -- v.Icon:SetTexCoord(.05, .95, .05, .95);
                else
                    -- v.Icon:SetTexCoord(0, 1, 0, 1);
                end
                v.styled = true;
            end
        end
    end

    HandleAuras(TargetFrame);

    if FocusFrame and (not FocusFrame.smallSize) then
        HandleAuras(FocusFrame);
    end
end

if AuraFrameMixin then
    hooksecurefunc(AuraFrameMixin, "UpdateAuraButtons", function(self)
        for _, button in ipairs(self.auraFrames) do
            UberUI.buffsandauras:StyleAuraButton(button)
        end
    end)
end

UberUI.buffsandauras = buffsandauras
