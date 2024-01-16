local addon, ns = ...
local partyframes = {}

local hookParty = false;

partyframes = CreateFrame("frame")
partyframes:RegisterEvent("ADDON_LOADED")
partyframes:RegisterEvent("PLAYER_ENTERING_WORLD")
partyframes:RegisterEvent("GROUP_ROSTER_UPDATE")
partyframes:RegisterEvent("UNIT_PET");

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
    self:ColorDefaultPartyFrames();
    self:ColorTextureCompactPartyFrames();
end

function partyframes:ColorDefaultPartyFrames()
    for _, p in pairs({ PartyFrame:GetChildren() }) do
        if (p.HealthBar ~= nil) then
            local idx = p.unit;
            if (UnitIsConnected(idx)) then
                local classColor = RAID_CLASS_COLORS[select(2, UnitClass(idx))];
                if (uuidb.general.texture ~= "Blizzard") then
                    local texture = uuidb.statusbars[uuidb.general.texture];
                    p.HealthBar:SetStatusBarTexture(texture);
                    local partyPowerType = UnitPowerType(idx);
                    if (partyPowerType < 4) then
                        p.ManaBar:SetStatusBarTexture(texture);
                        local pc = PowerBarColor[partyPowerType];
                        p.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
                    end
                end
                if (not uuidb.general.secondarybartextures and not uuidb.general.secondarybartexture == "Blizzard") then
                    if (uuidb.general.secondarybartextures or uuidb.general.texture ~= "Blizzard") then
                        local texture = uuidb.statusbars[uuidb.general.secondarybartexture];
                        p.myHealPredictionBar:SetTexture(texture);
                        p.otherHealPredictionBar:SetTexture(texture);
                        p.totalAbsorbBar:SetTexture(texture);
                        p.totalAbsorbBar:SetVertexColor(.6, .9, .9, 1);
                    end
                end
            end
        end
    end
end

function partyframes:ColorTextureCompactPartyFrames()
    for i = 1, MEMBERS_PER_RAID_GROUP do
        local member = _G["CompactPartyFrameMember" .. i]
        UberUI.cuf.default(member)
    end
end

UberUI.partyframes = partyframes
