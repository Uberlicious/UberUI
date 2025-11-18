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
        if (p.healthbar ~= nil) then
            local idx = p.unit;
            if (UnitIsConnected(idx)) then
                local classColor = RAID_CLASS_COLORS[select(2, UnitClass(idx))];
                if (classColor ~= nil) then
                    p.healthbar:SetStatusBarDesaturated(true);
                    p.healthbar:SetStatusBarColor(classColor.r, classColor.g, classColor.b,
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
        if (p.healthbar ~= nil) then
            local idx = p.unit;
            if textureToApply then
                p.healthbar:SetStatusBarTexture(textureToApply);
                local partyPowerType = UnitPowerType(idx);
                if (partyPowerType ~= nil and partyPowerType < 4) then
                    p.manabar:SetStatusBarTexture(textureToApply);
                    local pc = PowerBarColor[partyPowerType];
                    p.manabar:SetStatusBarColor(pc.r, pc.g, pc.b);
                end
            end
        end
    end
end

UberUI.partyframes = partyframes
