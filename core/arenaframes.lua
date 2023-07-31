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

local origParent = nil

function arenaframes:HideFrame(frame)
    frame:SetScript("OnShow", frame.Hide)
    frame:Hide()
end

function arenaframes:ShowFrame(frame)
    frame:SetScript("OnShow", frame.Show)
    frame:Show()
end

function arenaframes:HideArena()
    if (CompactArenaFrame == nil) then return end
    if (uuidb.general.hidearenaframes) then
        arenaframes:HideFrame(arenaframes)
        local f = _G["CompactArenaFrame"]
        if origParent == nil then
            origParent = f:GetParent()
        end
        if not f then return end
        f:SetParent(arenaframes)
        arenaframes:HideFrame(f)
    else
        if origParent ~= nil then
            arenaframes:ShowFrame(arenaframes)
            local f = _G["CompactArenaFrame"]
            if not f then return end
            f:SetParent(origParent)
            arenaframes:ShowFrame(f)
            origParent = nil
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
        if (uuidb.general.texture ~= "Blizzard") then
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
