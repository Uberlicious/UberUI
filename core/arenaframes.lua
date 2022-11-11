local addon, ns = ...
arenaframes = {}

local arenaframes = CreateFrame("Frame")
arenaframes:RegisterEvent("ADDON_LOADED")
arenaframes:RegisterEvent("PLAYER_LOGIN")
arenaframes:RegisterEvent("PLAYER_ENTERING_WORLD")
arenaframes:RegisterEvent("PVP_MATCH_ACTIVE")
arenaframes:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
arenaframes:RegisterEvent("ARENA_OPPONENT_UPDATE")
arenaframes:RegisterEvent("GROUP_ROSTER_UPDATE")
arenaframes:SetScript("OnEvent", function(self, event, addon)
    arenaframes:LoopFrames();
    arenaframes:NameplateNumbers();
    arenaframes:HideArena();
end)

function arenaframes:HideArena()
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
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
            if IsActiveBattlefieldArena() then
                if frame.unit:find("nameplate") then
                    for i = 1, 3 do
                        if U(frame.unit, "arena" .. i) then
                            frame.name:SetText(i)
                            frame.name:SetTextColor(1, 1, 0)
                            break
                        end
                    end
                end
            end
        end)
    end
    uui_nn_hook = true
end

function arenaframes:LoopFrames()
    for i = 1, 5 do
        self:Color(i);
        if (uuidb.arenaframes.classcolor or uuidb.general.hostilitycolor) then
            self:HealthBarColor(i);
        end
        if (uuidb.general.texture ~= "Blizzard") then
            self:HealthManaBarTexture(i);
        end
    end
end

function arenaframes:Color(target)
    local dc = uuidb.general.darkencolor;
    if not IsAddOnLoaded("Shadowed Unit Frames") then
        _G["ArenaEnemyMatchFrame" .. target .. "Texture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["ArenaEnemyMatchFrame" .. target .. "PetFrameTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["ArenaEnemyMatchFrame" .. target .. "SpecBorder"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        _G["ArenaEnemyPrepFrame" .. target .. "Texture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        _G["ArenaEnemyPrepFrame" .. target .. "SpecBorder"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        local idx = _G["ArenaEnemyMatchFrame" .. target].unit;
    end
end

function arenaframes:HealthBarColor(target)
    if (not uuidb.arenaframes.classcolor or not uuidb.general.hostilitycolor) then return end
    local idx = _G["ArenaEnemyMatchFrame" .. target].unit;
    if (UnitIsConnected(idx)) then
        local classColor = RAID_CLASS_COLORS[select(2, UnitClass(idx))];
        if (uuidb.arenaframes.classcolor) then
            if (classColor ~= nil) then
                _G["ArenaEnemyMatchFrame" .. target .. "HealthBar"]:SetStatusBarDesaturated(true);
                _G["ArenaEnemyMatchFrame" .. target .. "HealthBar"]:SetStatusBarColor(classColor.r, classColor.g,
                    classColor.b, classColor.a);
            end
        end
    end
end

function arenaframes:HealthManaBarTexture(target)
    local idx = _G["ArenaEnemyMatchFrame" .. target].unit;
    local texture = uuidb.statusbars[uuidb.general.texture];
    _G["ArenaEnemyMatchFrame" .. target .. "HealthBar"]:SetStatusBarTexture(texture);
    local partyPowerType = UnitPowerType(idx);
    if (partyPowerType < 4) then
        _G["ArenaEnemyMatchFrame" .. target .. "ManaBar"]:SetStatusBarTexture(texture);
        local pc = PowerBarColor[partyPowerType];
        _G["ArenaEnemyMatchFrame" .. target .. "ManaBar"]:SetStatusBarColor(pc.r, pc.g, pc.b);
    end
end

UberUI.arenaframes = arenaframes
