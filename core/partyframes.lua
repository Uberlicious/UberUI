local addon, ns = ...
local partyframes = {}

partyframes = CreateFrame("frame")
partyframes:RegisterEvent("ADDON_LOADED")
partyframes:RegisterEvent("PLAYER_LOGIN")
partyframes:RegisterEvent("PLAYER_ENTERING_WORLD")
partyframes:RegisterEvent("GROUP_ROSTER_UPDATE")
partyframes:RegisterEvent("RAID_ROSTER_UPDATE")
partyframes:RegisterEvent("PLAYER_LEAVE_COMBAT")
partyframes:SetScript("OnEvent", function(self, event)
    partyframes:Color();
    partyframes:HealthBarColor();
    partyframes:HealthManaBarTexture()
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
        if (p.HealthBar ~= nil) then
            local idx = p.unit;
            if (UnitIsConnected(idx)) then
                local classColor = RAID_CLASS_COLORS[select(2, UnitClass(idx))];
                if (classColor ~= nil) then
                    p.HealthBar:SetStatusBarDesaturated(true);
                    p.HealthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, classColor.a);
                end
            end
        end
    end
end

function partyframes:HealthManaBarTexture()
    for _, p in pairs({ PartyFrame:GetChildren() }) do
        if (p.HealthBar ~= nil) then
            local idx = p.unit;
            if (UnitIsConnected(idx)) then
                local classColor = RAID_CLASS_COLORS[select(2, UnitClass(idx))];
                if (uuidb.general.texture ~= "Blizzard") then
                    local texture = uuidb.statusbars[uuidb.general.texture];
                    p.HealthBar:SetStatusBarTexture(texture);
                    p.MyHealPredictionBar:SetTexture(texture);
                    p.OtherHealPredictionBar:SetTexture(texture);
                    p.TotalAbsorbBar:SetTexture(texture);
                    p.TotalAbsorbBar:SetVertexColor(.6, .9, .9, 1);
                    local partyPowerType = UnitPowerType(idx);
                    if (partyPowerType < 4) then
                        p.ManaBar:SetStatusBarTexture(texture);
                        local pc = PowerBarColor[partyPowerType];
                        p.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
                    end
                elseif (uuidb.general.secondarybartextures) then
                    local texture = uuidb.statusbars[uuidb.general.secondarybartexture];
                    p.MyHealPredictionBar:SetTexture(texture);
                    p.OtherHealPredictionBar:SetTexture(texture);
                    p.TotalAbsorbBar:SetTexture(texture);
                    p.TotalAbsorbBar:SetVertexColor(.6, .9, .9, 1);
                end
            end
        end
    end
end

UberUI.partyframes = partyframes
