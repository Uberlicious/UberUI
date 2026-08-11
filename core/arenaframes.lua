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
    if CompactArenaFrame:GetAlpha() ~= 1 then
        CompactArenaFrame:SetAlpha(1);
    end
end

function arenaframes:HideArena()
    CompactArenaFrame:SetAlpha(0);
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
    if (uuidb.general.hidearenaframes) then
        for i = 1, 5 do
            _G["ArenaEnemyMatchFrame" .. i]:SetAlpha(0);
            _G["ArenaEnemyPrepFrame" .. i]:SetAlpha(0);
            _G["ArenaEnemyMatchFrame" .. i .. "PetFrame"]:SetAlpha(0);
        end
    else
        for i = 1, 5 do
            _G["ArenaEnemyMatchFrame" .. i]:SetAlpha(1);
            _G["ArenaEnemyPrepFrame" .. i]:SetAlpha(1);
            _G["ArenaEnemyMatchFrame" .. i .. "PetFrame"]:SetAlpha(1);
        end
    end
end

uui_nn_hook = false
function arenaframes:NameplateNumbers()
    local U = UnitIsUnit
    if not (uui_nn_hook) and (uuidb.general.arenanumbers) then
        -- hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        --     if IsActiveBattlefieldArena() then
        --         if frame.unit:find("nameplate") then
        --             for i = 1, 3 do
        --                 if U(frame.unit, "arena" .. i) then
        --                     frame.name:SetText(i)
        --                     frame.name:SetTextColor(1, 1, 0)
        --                     break
        --                 end
        --             end
        --         end
        --     end
        -- end)
    end
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
    local texture = uuidb.statusbars[uuidb.general.texture];
    local dc = uuidb.general.darkencolor;
    _G["CompactArenaFrameMember" .. target].roleIcon:SetDrawLayer("ARTWORK", 4);
    CompactArenaFrame["StealthedUnitFrame" .. target].BarTexture:SetTexture(texture)

    for _, i in pairs({ CompactArenaFrame.PreMatchFramesContainer:GetChildren() }) do
        i.BarTexture:SetTexture(texture);
        i.SpecPortraitBorderTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end
end

UberUI.arenaframes = arenaframes
