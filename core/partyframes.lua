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
    -- Main texture logic
    local textureToApply
    if uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    -- Secondary texture logic
    local secondaryTextureToApply
    if uuidb.general.secondarybartextures then
        if uuidb.general.secondarybartexture ~= "Blizzard" then
            secondaryTextureToApply = uuidb.statusbars[uuidb.general.secondarybartexture]
        end
    else
        secondaryTextureToApply = textureToApply -- Fallback
    end

    for _, p in pairs({ PartyFrame:GetChildren() }) do
        if (p.HealthBar ~= nil) then
            local idx = p.unit;
            if (UnitIsConnected(idx)) then
                if textureToApply then
                    p.HealthBar:SetStatusBarTexture(textureToApply);
                    local partyPowerType = UnitPowerType(idx);
                    if (partyPowerType < 4) then
                        p.ManaBar:SetStatusBarTexture(textureToApply);
                        local pc = PowerBarColor[partyPowerType];
                        p.ManaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
                    end
                end
                if secondaryTextureToApply then
                    p.myHealPredictionBar:SetTexture(secondaryTextureToApply);
                    p.otherHealPredictionBar:SetTexture(secondaryTextureToApply);
                    p.totalAbsorbBar:SetTexture(secondaryTextureToApply);
                    p.totalAbsorbBar:SetVertexColor(.6, .9, .9, 1);
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
