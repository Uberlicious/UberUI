local addon, ns = ...

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
    arenaframes:RefreshAuraStyle();
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

-- Arena Nameplate Numbers: "1"/"2"/"3" instead of the name on enemy
-- nameplates in an arena, matched with UnitIsUnit(unit, "arenaN") (unit
-- identity isn't secret). Applied after CompactUnitFrame_UpdateName, deferred,
-- re-reading frame.unit so a recycled plate isn't mislabeled. Toggling
-- mid-match applies on the next name update: forcing one would mean calling
-- Blizzard's update function from insecure code (taint).
local function ApplyArenaNameplateNumber(frame)
    if not frame or not frame.unit or not frame.name then return end
    if not (uuidb and uuidb.general and uuidb.general.arenanumbers) then return end

    local okType, isNameplate = pcall(string.find, frame.unit, "nameplate")
    if not okType or not isNameplate then return end

    local okInst, _, instanceType = pcall(IsInInstance)
    if not okInst or instanceType ~= "arena" then return end

    for i = 1, 3 do
        local okMatch, isMatch = pcall(UnitIsUnit, frame.unit, "arena" .. i)
        if okMatch and isMatch then
            frame.name:SetText(tostring(i))
            return
        end
    end
end

-- CompactUnitFrame_UpdateName fires constantly, so the hook is only installed
-- once the setting is on (from NameplateNumbers, after uuidb is loaded).
local arenaNameplateNumberHookInstalled = false
local function EnsureArenaNameplateNumberHook()
    if arenaNameplateNumberHookInstalled or not CompactUnitFrame_UpdateName then return end
    arenaNameplateNumberHookInstalled = true
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        if not frame or not frame.unit then return end
        local okType, isNameplate = pcall(string.find, frame.unit, "nameplate")
        if not okType or not isNameplate then return end
        C_Timer.After(0, function()
            ApplyArenaNameplateNumber(frame)
        end)
    end)
end

-- Called on toggle and from the event handler; the hook re-checks the setting.
function arenaframes:NameplateNumbers()
    if uuidb and uuidb.general and uuidb.general.arenanumbers then
        EnsureArenaNameplateNumberHook()
    end
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

-- Arena trackers: the CC tracker (DebuffFrame, aurastyle_arenadebuffs) and
-- the DR / CC remover icons (aurastyle_arenabuffs). Blizzard's real arena
-- debuff display is the forbidden private-aura renderer, always on, so we
-- restyle these fixed-size widgets instead of replacing anything. Blizzard
-- never recolors them after creation, so styling once (and on option
-- change) is enough.

-- Square borders for the arena trackers (no dispel types): dark when the
-- style has a border, else the tracker's native color. Returns true when the
-- square border took over.
local function ApplyArenaSquareBorder(owner, icon, style, darkBorderEnabled, nativeR, nativeG, nativeB)
    local SB = UberUI.squareborders
    if not SB then return false end
    if style == "none" or not SB.IsEnabled("arena") then
        SB.Hide(owner)
        return false
    end
    if not darkBorderEnabled and not nativeR then
        SB.Hide(owner)
        return true
    end
    local sb = SB.Get(owner)
    SB.LayoutFor(sb, icon, "arena")
    SB.RaiseAbove(sb, owner, 2)
    if darkBorderEnabled then
        SB.SetDarkColor(sb)
    else
        SB.SetColor(sb, nativeR, nativeG, nativeB, 1)
    end
    sb:Show()
    return true
end

function arenaframes:StyleDebuffFrame(debuffFrame)
    if not debuffFrame or not debuffFrame.Icon then return end
    local style = uuidb.general.aurastyle_arenadebuffs or "zoom"
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    UberUI.general:ApplyAuraIconInset(debuffFrame.Icon, zoomEnabled or darkBorderEnabled)
    UberUI.general:ApplyIconZoom(debuffFrame.Icon, zoomEnabled)

    local square = ApplyArenaSquareBorder(debuffFrame, debuffFrame.Icon, style, darkBorderEnabled, 1, 0, 0)
    if debuffFrame.Border then
        debuffFrame.Border:SetAlpha(square and 0 or 1)
    end

    if debuffFrame.Border and not square then
        UberUI.general:GrowRegion(debuffFrame.Border, UberUI.general:ZoomBorderGrow(zoomEnabled))
        if darkBorderEnabled then
            local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
            debuffFrame.Border:SetDesaturated(true)
            debuffFrame.Border:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        else
            debuffFrame.Border:SetDesaturated(false)
            debuffFrame.Border:SetVertexColor(1, 0, 0, 1)
        end
    end
end

-- CcRemoverFrame: the last CC used on the unit and its cooldown (not the DR
-- tray). Blizzard draws no border; "Dark Border" adds one.
local function EnsureCcRemoverBorder(ccRemoverFrame)
    if ccRemoverFrame.uuBorder then return ccRemoverFrame.uuBorder end
    local tex = ccRemoverFrame:CreateTexture(nil, "OVERLAY")
    tex:SetPoint("TOPLEFT", ccRemoverFrame, "TOPLEFT", -1, 1)
    tex:SetPoint("BOTTOMRIGHT", ccRemoverFrame, "BOTTOMRIGHT", 1, -1)
    tex:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    tex:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    tex:Hide()
    ccRemoverFrame.uuBorder = tex
    return tex
end

function arenaframes:StyleCcRemoverFrame(ccRemoverFrame)
    if not ccRemoverFrame or not ccRemoverFrame.Icon then return end
    local style = uuidb.general.aurastyle_arenabuffs or "both"
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    UberUI.general:ApplyAuraIconInset(ccRemoverFrame.Icon, zoomEnabled or darkBorderEnabled)
    UberUI.general:ApplyIconZoom(ccRemoverFrame.Icon, zoomEnabled)

    local border = EnsureCcRemoverBorder(ccRemoverFrame)
    local pad = 1 + UberUI.general:ZoomBorderGrow(zoomEnabled)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", ccRemoverFrame, "TOPLEFT", -pad, pad)
    border:SetPoint("BOTTOMRIGHT", ccRemoverFrame, "BOTTOMRIGHT", pad, -pad)
    if ApplyArenaSquareBorder(ccRemoverFrame, ccRemoverFrame.Icon, style, darkBorderEnabled) then
        border:Hide()
    elseif darkBorderEnabled then
        local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        border:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        border:Show()
    else
        border:Hide()
    end
end

-- The Diminishing Returns tray (SpellDiminishStatusTray): pooled items,
-- configured by SetCategoryInfo for real and Edit Mode preview data alike.
local function EnsureDiminishTrayItemBorder(trayItem)
    if trayItem.uuBorder then return trayItem.uuBorder end
    local tex = trayItem:CreateTexture(nil, "OVERLAY")
    tex:SetPoint("TOPLEFT", trayItem, "TOPLEFT", -1, 1)
    tex:SetPoint("BOTTOMRIGHT", trayItem, "BOTTOMRIGHT", 1, -1)
    tex:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
    tex:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
    tex:Hide()
    trayItem.uuBorder = tex
    return tex
end

function arenaframes:StyleDiminishTrayItem(trayItem)
    if not trayItem or not trayItem.Icon then return end
    local style = uuidb.general.aurastyle_arenabuffs or "both"
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    UberUI.general:ApplyAuraIconInset(trayItem.Icon, zoomEnabled or darkBorderEnabled)
    UberUI.general:ApplyIconZoom(trayItem.Icon, zoomEnabled)

    local border = EnsureDiminishTrayItemBorder(trayItem)
    local pad = 1 + UberUI.general:ZoomBorderGrow(zoomEnabled)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", trayItem, "TOPLEFT", -pad, pad)
    border:SetPoint("BOTTOMRIGHT", trayItem, "BOTTOMRIGHT", pad, -pad)
    if ApplyArenaSquareBorder(trayItem, trayItem.Icon, style, darkBorderEnabled) then
        border:Hide()
    elseif darkBorderEnabled then
        local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        border:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        border:Show()
    else
        border:Hide()
    end
end

if SpellDiminishStatusTrayItemMixin then
    hooksecurefunc(SpellDiminishStatusTrayItemMixin, "SetCategoryInfo", function(self)
        UberUI.arenaframes:StyleDiminishTrayItem(self)
    end)
end

-- Re-applies the style to every existing arena tracker. Each widget is
-- pcall-wrapped so one error doesn't skip the rest.
function arenaframes:RefreshAuraStyle()
    local frame = CompactArenaFrame
    if not frame or not frame.memberUnitFrames then return end
    for _, memberUnitFrame in ipairs(frame.memberUnitFrames) do
        if memberUnitFrame.DebuffFrame then
            local ok, err = pcall(self.StyleDebuffFrame, self, memberUnitFrame.DebuffFrame)
            if not ok then
                UberUI:ReportError("arena DebuffFrame styling", err)
            end
        end
        if memberUnitFrame.CcRemoverFrame then
            local ok, err = pcall(self.StyleCcRemoverFrame, self, memberUnitFrame.CcRemoverFrame)
            if not ok then
                UberUI:ReportError("arena CcRemoverFrame styling", err)
            end
        end
        if memberUnitFrame.SpellDiminishStatusTray and memberUnitFrame.SpellDiminishStatusTray.trayItemPool then
            for trayItem in memberUnitFrame.SpellDiminishStatusTray.trayItemPool:EnumerateActive() do
                local ok, err = pcall(self.StyleDiminishTrayItem, self, trayItem)
                if not ok then
                    UberUI:ReportError("arena DR tray styling", err)
                end
            end
        end
    end
end

if CompactArenaFrameMixin then
    hooksecurefunc(CompactArenaFrameMixin, "OnLoad", function()
        UberUI.arenaframes:RefreshAuraStyle()
    end)
end

UberUI.arenaframes = arenaframes
