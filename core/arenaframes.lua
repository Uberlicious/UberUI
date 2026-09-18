local addon, ns = ...
arenaframes = {}

local arenaframes = UberUI:CreateFrame("Frame")
arenaframes:RegisterEvent("PLAYER_ENTERING_WORLD")
arenaframes:RegisterEvent("ZONE_CHANGED_NEW_AREA")
arenaframes:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
arenaframes:SetScript("OnEvent", function(self, event, addon)
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
    arenaframes:LoopFrames();
    arenaframes:NameplateNumbers();
    arenaframes:SetVisibility();
    arenaframes:HideOldArenaFrames();
end)

function arenaframes:ShowArenaFrames()
    if CompactArenaFrame and CompactArenaFrame:GetAlpha() ~= 1 then
        CompactArenaFrame:SetAlpha(1);
    end
end

function arenaframes:HideArena()
    if CompactArenaFrame then
        CompactArenaFrame:SetAlpha(0);
    end
end

function arenaframes:SetVisibility()
    if uuidb.general.hidearenaframes == true then
        arenaframes:HideArena();
    end

    if not uuidb.general.hidearenaframes then
        arenaframes:ShowArenaFrames();
    end
end

function arenaframes:HideOldArenaFrames()
    for i = 1, 5 do
        if _G["ArenaEnemyMatchFrame" .. i] then
            _G["ArenaEnemyMatchFrame" .. i]:SetAlpha(uuidb.general.hidearenaframes and 0 or 1);
        end
        if _G["ArenaEnemyPrepFrame" .. i] then
            _G["ArenaEnemyPrepFrame" .. i]:SetAlpha(uuidb.general.hidearenaframes and 0 or 1);
        end
        if _G["ArenaEnemyMatchFrame" .. i .. "PetFrame"] then
            _G["ArenaEnemyMatchFrame" .. i .. "PetFrame"]:SetAlpha(uuidb.general.hidearenaframes and 0 or 1);
        end
        if _G["ArenaEnemyFrame" .. i] then
            _G["ArenaEnemyFrame" .. i]:SetAlpha(uuidb.general.hidearenaframes and 0 or 1);
        end
    end
end

uui_nn_hook = false
function arenaframes:NameplateNumbers()
    -- Hook removed or untouched for now
    uui_nn_hook = true
end

function arenaframes:LoopFrames()
    for i = 1, 5 do
        if (uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard") then
            self:HealthManaBarTexture(i);
        end
    end
end

function arenaframes:HealthManaBarTexture(target)
    if not CompactArenaFrame then return end
    local texture = uuidb.statusbars[uuidb.general.texture];
    local dc = uuidb.general.darkencolor;
    if _G["CompactArenaFrameMember" .. target] and _G["CompactArenaFrameMember" .. target].roleIcon then
        _G["CompactArenaFrameMember" .. target].roleIcon:SetDrawLayer("ARTWORK", 4);
    end
    
    local stealthedFrame = CompactArenaFrame["StealthedUnitFrame" .. target]
    if stealthedFrame and stealthedFrame.BarTexture then
        stealthedFrame.BarTexture:SetTexture(texture)
    end

    if CompactArenaFrame.PreMatchFramesContainer then
        for _, i in pairs({ CompactArenaFrame.PreMatchFramesContainer:GetChildren() }) do
            if i.BarTexture then i.BarTexture:SetTexture(texture); end
            if i.SpecPortraitBorderTexture then i.SpecPortraitBorderTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end
        end
    end
end

UberUI.arenaframes = arenaframes
