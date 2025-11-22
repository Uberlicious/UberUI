local addon, ns = ...
local partyframes = {}

partyframes = UberUI:CreateFrame("frame")
partyframes:RegisterEvent("ADDON_LOADED")
partyframes:RegisterEvent("PLAYER_ENTERING_WORLD")
partyframes:RegisterEvent("GROUP_ROSTER_UPDATE")

partyframes:SetScript("OnEvent", function(self, event)
    partyframes:Color();
    partyframes:HealthBarColor();
    partyframes:HealthManaBarTexture();
    partyframes:ZoomAuras();
end)

function partyframes:Color()
    local dc = uuidb.general.darkencolor;
    for _, p in pairs({ PartyFrame:GetChildren() }) do
        if (p.Texture ~= nil) then
            p.Texture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        end
    end
end

function partyframes:HealthBarColor()
    if (not uuidb.partyframes.classcolor) then return end
    for _, p in pairs({ PartyFrame:GetChildren() }) do
        if (p.HealthBarContainer and p.HealthBarContainer.HealthBar) then
            local idx = p.unit;
            if (UnitIsConnected(idx)) then
                local classColor = RAID_CLASS_COLORS[select(2, UnitClass(idx))];
                if (classColor ~= nil) then
                    p.HealthBarContainer.HealthBar:SetStatusBarDesaturated(true);
                    p.HealthBarContainer.HealthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b,
                        classColor.a);
                end
            end
        end
    end
end

function partyframes:HealthManaBarTexture()
    local textureToApply
    if uuidb.general.partybartextures and uuidb.general.partybartexture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.partybartexture]
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    for _, p in pairs({ PartyFrame:GetChildren() }) do
        if (p.HealthBarContainer and p.HealthBarContainer.HealthBar) then
            local idx = p.unit;
            if textureToApply then
                p.HealthBarContainer.HealthBar:SetStatusBarTexture(textureToApply);
                local partyPowerType = UnitPowerType(idx);
                if (partyPowerType ~= nil and partyPowerType < 4) then
                    if p.ManaBar then
                        p.ManaBar:SetStatusBarTexture(textureToApply);
                        local pc = PowerBarColor[partyPowerType];
                        p.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
                    end
                end
            end
        end
    end
end

function partyframes:ZoomAuras()
    local enable = uuidb.general.zoomiconparty
    if not PartyFrame then return end

    for _, p in pairs({ PartyFrame:GetChildren() }) do
        -- Main party member debuffs
        if p.AuraFrameContainer then
            for _, child in pairs({ p.AuraFrameContainer:GetChildren() }) do
                if child.Icon then
                    UberUI.general:ApplyIconZoom(child.Icon, enable)
                end
            end
        end

        -- Pet debuffs
        if p.PetFrame and p.PetFrame.AuraFrameContainer then
            for _, child in pairs({ p.PetFrame.AuraFrameContainer:GetChildren() }) do
                if child.Icon then
                    UberUI.general:ApplyIconZoom(child.Icon, enable)
                end
            end
        end
    end

    if PartyMemberBuffTooltip then
        local dc = uuidb.general.darkencolor
        PartyMemberBuffTooltip.NineSlice:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        for _, child in pairs({ PartyMemberBuffTooltip.BuffContainer:GetChildren() }) do
            if child.Icon then
                UberUI.general:ApplyIconZoom(child.Icon, enable)
            end
        end
        for _, child in pairs({ PartyMemberBuffTooltip.DebuffContainer:GetChildren() }) do
            if child.Icon then
                UberUI.general:ApplyIconZoom(child.Icon, enable)
            end
        end
    end
end

function partyframes:ForceZoom()
    self:ZoomAuras()
end

if PartyMemberFrameMixin then
    hooksecurefunc(PartyMemberFrameMixin, "OnUpdate", function(self)
        UberUI.partyframes:Color()
        UberUI.partyframes:ZoomAuras()
        UberUI.partyframes:HealthBarColor()
        UberUI.partyframes:HealthManaBarTexture()
    end)
end

if PartyMemberPetFrameMixin then
    hooksecurefunc(PartyMemberPetFrameMixin, "UpdateAuras", function(self)
        UberUI.partyframes:ZoomAuras()
    end)
end

if PartyMemberBuffTooltip then
    hooksecurefunc(PartyMemberBuffTooltip, "UpdateTooltip", function()
        UberUI.partyframes:ZoomAuras()
    end)
end



UberUI.partyframes = partyframes
