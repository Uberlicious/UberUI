local addon, ns = ...
local buffsandauras = {}

function buffsandauras:StyleAuraButton(button)
    if not button or not button.Icon then
        return
    end

    if uuidb.general.buffauraborders then
        local dc = uuidb.general.darkencolor
        if button.DebuffBorder then
            local r, g, b, a = button.DebuffBorder:GetVertexColor()
            local noneColor = DebuffTypeColor["none"]
            if r == noneColor.r and g == noneColor.g and b == noneColor.b then
                button.DebuffBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
            button.DebuffBorder:Show()
        end
        if button.TempEnchantBorder then
            button.TempEnchantBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            button.TempEnchantBorder:Show()
        end
    else
        if button.DebuffBorder then
            button.DebuffBorder:Hide()
        end
        if button.TempEnchantBorder then
            button.TempEnchantBorder:Hide()
        end
    end
end

function buffsandauras:Refresh()
    if BuffFrame then
        for _, button in ipairs(BuffFrame.auraFrames) do
            self:StyleAuraButton(button)
        end
    end

    if DebuffFrame then
        for _, button in ipairs(DebuffFrame.auraFrames) do
            self:StyleAuraButton(button)
        end
    end

    self:ColorAuras(true)
end

function buffsandauras:ColorAuras(force)
    local dc = uuidb.general.darkencolor;
    local tx = MultiBarBottomRightButton1NormalTexture:GetAtlas()

    local function HandleAuras(frame)
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

    if (not FocusFrame.smallSize) then
        HandleAuras(FocusFrame);
    end
end

hooksecurefunc(AuraFrameMixin, "UpdateAuraButtons", function(self)
    for _, button in ipairs(self.auraFrames) do
        UberUI.buffsandauras:StyleAuraButton(button)
    end
end)

UberUI.buffsandauras = buffsandauras
