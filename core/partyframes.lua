local addon, ns = ...
local partyframes = {}

partyframes = UberUI:CreateFrame("frame")
partyframes:RegisterEvent("ADDON_LOADED")
partyframes:RegisterEvent("PLAYER_ENTERING_WORLD")
partyframes:RegisterEvent("GROUP_ROSTER_UPDATE")

partyframes:SetScript("OnEvent", function(self, event)
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
    partyframes:Color();
    partyframes:HealthBarColor();
    partyframes:HealthManaBarTexture();
    partyframes:ZoomAuras();
end)

function partyframes:IteratePartyFrames()
    local frames = {}
    if PartyFrame then
        for _, p in pairs({ PartyFrame:GetChildren() }) do
            -- Filter out EditMode selection frames and other non-unit frames
            if p.unit or p.layoutIndex or (p.GetName and p:GetName() and p:GetName():find("MemberFrame")) then
                table.insert(frames, p)
            end
        end
    else
        for i = 1, 4 do
            local p = _G["PartyMemberFrame"..i]
            if p then table.insert(frames, p) end
        end
    end
    return frames
end

function partyframes:Color()
    local dc = uuidb.general.darkencolor;
    for _, p in pairs(self:IteratePartyFrames()) do
        local tex = p.Texture
        if not tex and p.GetName and p:GetName() then
            tex = _G[p:GetName().."Texture"]
        end
        if (tex ~= nil) then
            tex:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        end
    end
end

function partyframes:HealthBarColor()
    if (not uuidb.partyframes.classcolor) then return end
    for _, p in pairs(self:IteratePartyFrames()) do
        local healthBar = p.HealthBarContainer and p.HealthBarContainer.HealthBar
        if not healthBar and p.GetName and p:GetName() then
            healthBar = _G[p:GetName().."HealthBar"]
        end
        if healthBar then
            local idx = p.unit or p:GetAttribute("unit") or (p.GetID and p:GetID() and "party"..p:GetID());
            if (idx and UnitIsConnected(idx)) then
                local _, class = UnitClass(idx)
                local classColor = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (GetClassColorObj and GetClassColorObj(class)) or RAID_CLASS_COLORS[class]);
                if (classColor ~= nil) then
                    healthBar:SetStatusBarDesaturated(true);
                    healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, classColor.a);
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

    for _, p in pairs(self:IteratePartyFrames()) do
        local healthBar = p.HealthBarContainer and p.HealthBarContainer.HealthBar
        if not healthBar and p.GetName and p:GetName() then
            healthBar = _G[p:GetName().."HealthBar"]
        end
        local manaBar = p.ManaBar
        if not manaBar and p.GetName and p:GetName() then
            manaBar = _G[p:GetName().."ManaBar"]
        end
        if healthBar then
            local idx = p.unit or p:GetAttribute("unit") or (p.GetID and p:GetID() and "party"..p:GetID());
            if textureToApply then
                healthBar:SetStatusBarTexture(textureToApply);
                if idx then
                    local partyPowerType = UnitPowerType(idx);
                    if (partyPowerType ~= nil and partyPowerType < 4) then
                        if manaBar then
                            manaBar:SetStatusBarTexture(textureToApply);
                            local pc = PowerBarColor[partyPowerType];
                            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
                        end
                    end
                end
            end
        end
    end
end

function partyframes:ZoomAuras()
    local enable = uuidb.general.zoomiconparty
    local frames = self:IteratePartyFrames()
    if #frames == 0 then return end

    for _, p in pairs(frames) do
        -- Main party member debuffs
        if p.AuraFrameContainer then
            for _, child in pairs({ p.AuraFrameContainer:GetChildren() }) do
                if child.Icon then UberUI.general:ApplyIconZoom(child.Icon, enable) end
            end
        else
            for i = 1, 4 do
                if p.GetName and p:GetName() then
                    local debuff = _G[p:GetName().."Debuff"..i]
                    if debuff and debuff.Icon then UberUI.general:ApplyIconZoom(debuff.Icon, enable) end
                end
            end
        end

        -- Pet debuffs
        if p.PetFrame then
            if p.PetFrame.AuraFrameContainer then
                for _, child in pairs({ p.PetFrame.AuraFrameContainer:GetChildren() }) do
                    if child.Icon then UberUI.general:ApplyIconZoom(child.Icon, enable) end
                end
            else
                for i = 1, 4 do
                    if p.PetFrame.GetName and p.PetFrame:GetName() then
                        local debuff = _G[p.PetFrame:GetName().."Debuff"..i]
                        if debuff and debuff.Icon then UberUI.general:ApplyIconZoom(debuff.Icon, enable) end
                    end
                end
            end
        end
    end

    if PartyMemberBuffTooltip then
        local dc = uuidb.general.darkencolor
        if PartyMemberBuffTooltip.NineSlice then
            PartyMemberBuffTooltip.NineSlice:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        end
        if PartyMemberBuffTooltip.BuffContainer then
            for _, child in pairs({ PartyMemberBuffTooltip.BuffContainer:GetChildren() }) do
                if child.Icon then UberUI.general:ApplyIconZoom(child.Icon, enable) end
            end
        end
        if PartyMemberBuffTooltip.DebuffContainer then
            for _, child in pairs({ PartyMemberBuffTooltip.DebuffContainer:GetChildren() }) do
                if child.Icon then UberUI.general:ApplyIconZoom(child.Icon, enable) end
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
