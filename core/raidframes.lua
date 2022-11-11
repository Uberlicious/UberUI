local addon, ns = ...
local raidframes = {}

local hookRaid = false;

raidframes = CreateFrame("Frame");
raidframes:RegisterEvent("ADDON_LOADED");
raidframes:RegisterEvent("PLAYER_ENTERING_WORLD");
raidframes:RegisterEvent("RAID_ROSTER_UPDATE");
raidframes:SetScript("OnEvent", function(self, event)
    raidframes:HealthManaBarTexture();
    raidframes:AddHooks();
end)

function raidframes:HealthManaBarTexture()
    local dc = uuidb.general.darkencolor;
    local texture = uuidb.general.raidbartextures and uuidb.statusbars[uuidb.general.raidbartexture] or
        uuidb.statusbars[uuidb.general.texture];
    for i = 1, 8 do
        local group = _G["CompactRaidGroup" .. i];
        if (group ~= nil) then
            for _, borderSection in pairs({ group.borderFrame:GetRegions() }) do
                borderSection:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
            end
            if (uuidb.general.raidbartextures and uuidb.general.raidbartexture == "Blizzard") then return end
            if (uuidb.general.raidbartextures or uuidb.general.texture ~= "Blizzard") then
                for m = 1, MEMBERS_PER_RAID_GROUP do
                    local member = _G[group:GetName() .. "Member" .. m];
                    if (member ~= nil) then
                        member.healthBar:SetStatusBarTexture(texture);
                    end
                end
            end
            if (uuidb.general.secondarybartextures and uuidb.general.secondarybartexture == "Blizzard") then return end
            if (uuidb.general.secondarybartextures or uuidb.general.texture ~= "Blizzard") then
                for i = 1, MEMBERS_PER_RAID_GROUP do
                    local member = _G[group:GetName() .. "Member" .. i];
                    local texture = uuidb.general.secondarybartextures and
                        uuidb.statusbars[uuidb.general.secondarybartexture] or
                        uuidb.general.raidbartextures and
                        uuidb.statusbars[uuidb.general.raidbartexture] or
                        uuidb.statusbars[uuidb.general.texture];
                    member.myHealPrediction:SetTexture(texture);
                    member.otherHealPrediction:SetTexture(texture);
                    member.totalAbsorb:SetTexture(texture);
                    member.totalAbsorb:SetVertexColor(.6, .9, .9, 1);
                end
            end
        end
    end
end

function raidframes:AddHooks()
    -- hook to  make sure raid gets textured on show event
    if (hookRaid == false) then
        CompactRaidFrameManager.container:HookScript("OnShow", function(self)
            raidframes:HealthManaBarTexture();
        end)
        hookRaid = true;
    end
end

UberUI.raidframes = raidframes;
