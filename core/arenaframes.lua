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

-- Arena Nameplate Numbers: shows "1"/"2"/"3" instead of the player's name on
-- enemy nameplates during an arena match, matching the arena roster's own
-- numbering. Reference: EllesmereUI PR #1701 (EllesmereGaming/EllesmereUI),
-- which does the equivalent for their own custom-built nameplates -- their
-- exact code doesn't transfer (their nameplates are fully custom; ours hooks
-- Blizzard's native ones), but the approach does: identify the nameplate's
-- arena slot via UnitIsUnit(unit, "arenaN") (a plain unit-identity
-- comparison -- Blizzard's own secrecy docs list these as "generally not
-- secret", unlike reading/comparing aura or health data), then override the
-- displayed text.
--
-- Their PR's own fix commit ("avoid comparing or reading secret strings")
-- was for a name-string-comparison FALLBACK their custom nameplate code
-- needed for a reason specific to their implementation. We don't need it:
-- UnitIsUnit alone is sufficient and avoids that whole class of risk.
--
-- Hooks CompactUnitFrame_UpdateName -- the same shared function already
-- hooked in this file's own MaybeRegisterRaidTargetScaleHooks, filtered to
-- frame.unit containing "nameplate" so this never touches the arena roster
-- frames (CompactArenaFrameMember1-5), only nameplates. Deferred via
-- C_Timer.After(0, ...), same taint-avoidance convention as every other
-- nameplate write in core/nameplates.lua: CompactUnitFrame_UpdateName runs
-- inside Blizzard's own synchronous update chain, and frame.unit is
-- re-checked fresh inside the deferred callback (not cached beforehand) so
-- a nameplate recycled for a different unit by the time the callback fires
-- self-corrects instead of mislabeling it.
--
-- Reactive, not manually triggered: toggling the setting mid-match doesn't
-- retroactively relabel already-visible nameplates until Blizzard's own code
-- next calls CompactUnitFrame_UpdateName on them (name updates aren't
-- continuous) -- calling that function ourselves to force an immediate
-- refresh would be the exact "call Blizzard's own update function directly
-- from insecure code" pattern that caused the arena taint bug earlier this
-- session, so this intentionally doesn't do that.
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

-- CompactUnitFrame_UpdateName is the busiest shared function in the addon --
-- it fires for every nameplate/party/raid/arena name update, constantly, for
-- a feature that only ever matters inside an arena instance. hooksecurefunc
-- can't be undone, so only install it if the setting is actually on; if the
-- user enables it later without reload, EnsureArenaNameplateNumberHook()
-- (called from NameplateNumbers() below, which the options/arena.lua checkbox
-- already calls on toggle) installs it lazily then -- full live on/off, no
-- reload ever required.
-- Not checked at the top level here: uuidb is still config.lua's empty
-- placeholder table at file-load time (this addon's own ADDON_LOADED/
-- PLAYER_LOGIN handler, which populates uuidb.general, hasn't run yet), so
-- uuidb.general.arenanumbers would always read nil regardless of the saved
-- value. Installed from NameplateNumbers() below instead, which this file's
-- own PLAYER_ENTERING_WORLD/etc. event handler already calls every time it
-- fires -- always after uuidb is populated -- covering both "already enabled
-- at login" and "enabled later without reload".
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

-- Called by the options/arena.lua checkbox on toggle, and by this file's own
-- event handler on every relevant event. Lazily installs the hook the first
-- time the setting is seen on; disabling it is already fully live since
-- ApplyArenaNameplateNumber() re-checks the setting on every call.
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

-- Arena frame styling: the CC (Loss of Control) tracker (memberUnitFrame.
-- DebuffFrame, styled via aurastyle_arenadebuffs) and the diminishing-returns
-- tracker (memberUnitFrame.CcRemoverFrame, styled via aurastyle_arenabuffs --
-- see that widget's own comment below for why). Neither is a general
-- multi-aura container -- Blizzard's real debuff display on arena frames is
-- the same forbidden private-aura renderer party/raid have, except
-- CompactUnitFrame_GetOptionDisplayDebuffs hardcodes it ON (unconditionally
-- true for PvP-classified frames) with no CVar to turn it off, so unlike
-- party/raid/compact we can't suppress and replace it. DebuffFrame and
-- CcRemoverFrame are separate, addon-visible, non-forbidden widgets Blizzard
-- already sizes/anchors correctly (34x34 and 27x27 fixed in
-- CompactArenaFrame.xml, no Edit Mode scaling), so -- same lesson as the
-- party frame border bug -- we retint what's there instead of drawing a
-- mismatched replacement.
--
-- Both are created once per member frame at CompactArenaFrameMixin:OnLoad
-- and never recreated. Neither one's color/crop is ever touched again by
-- Blizzard's own code afterward (ArenaUnitFrameDebuffMixin:Update only ever
-- sets Icon's texture, never Border's color -- Loss of Control debuffs have
-- no dispel type, so Blizzard hardcodes Border red in XML and leaves it;
-- ArenaUnitFrameCcRemoverMixin:SetSpellId is the same for its Icon). So
-- unlike the party frame buttons, there's no need to re-apply on every
-- content update -- once at creation, and again whenever a style dropdown
-- changes, is enough.
-- Icon inset on zoom/border is now shared -- see general:ApplyAuraIconInset
-- in core/generalfunctions.lua (used by target/focus/party/arena/nameplate
-- alike, previously duplicated locally in this file).

-- Square borders (core/squareborders.lua) for the arena trackers. Arena
-- entries carry no dispel type, so: dark square when the style includes a
-- border, otherwise the tracker's native color (red for the CC tracker, none
-- for the DR/CC-remover icons). Returns true when the square border took over
-- for this owner (caller then leaves its own border hidden).
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
        -- Alpha, not Hide(): leaves Blizzard's own shown/hidden state alone.
        debuffFrame.Border:SetAlpha(square and 0 or 1)
    end

    if debuffFrame.Border and not square then
        if darkBorderEnabled then
            local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
            debuffFrame.Border:SetDesaturated(true)
            debuffFrame.Border:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        else
            -- Native look: always red, hardcoded in XML.
            debuffFrame.Border:SetDesaturated(false)
            debuffFrame.Border:SetVertexColor(1, 0, 0, 1)
        end
    end
end

-- CcRemoverFrame is an older, separate single-icon tracker showing the last
-- CC spell used on the target and its cooldown (C_PvP.GetArenaCrowdControlInfo)
-- -- NOT the Diminishing Returns tray itself (see StyleDiminishTrayItem
-- below for that). It has no border of its own in the native template (stock
-- Blizzard look for it is just a bare icon). "Dark Border" style adds one,
-- using the same file+texcoords as the party and arena-debuff borders (a
-- plain cropped square texture, not an atlas) -- confirmed scale-safe at
-- both 15px (party) and 34px (arena debuff) already, unlike
-- "ui-debuff-border-default-noicon", which is what actually caused the party
-- frame sizing bug.
--
-- Styled via aurastyle_arenabuffs, not aurastyle_arenadebuffs -- there's no
-- real "buffs" display on arena frames yet (see the Arena Buffs option's own
-- comment), so this reuses that slot rather than adding a third arena style
-- dropdown for one small icon.
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
    if ApplyArenaSquareBorder(ccRemoverFrame, ccRemoverFrame.Icon, style, darkBorderEnabled) then
        border:Hide()
    elseif darkBorderEnabled then
        local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        border:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        border:Show()
    else
        -- Native look: no border at all.
        border:Hide()
    end
end

-- The REAL Diminishing Returns tray -- what "the DR's" actually refers to --
-- is a completely separate widget: memberUnitFrame.SpellDiminishStatusTray,
-- from its own addon (Blizzard_SpellDiminishUI), not CcRemoverFrame above.
-- It's a pooled row of one SpellDiminishStatusTrayItemTemplate icon per
-- active DR category (Stun/Root/Silence/Disorient/...), each 26x26 with no
-- border of its own. Items are acquired/reused from
-- self.trayItemPool (CreateUnsecuredFramePool) and (re)configured via
-- SetCategoryInfo every time one is assigned -- for both real DR data and
-- Edit Mode's own preview items (PopulateEditModePreviewItems calls it too)
-- -- so that's the hook point, the same role Setup plays for party's aura
-- buttons.
--
-- Styled via aurastyle_arenabuffs, same as CcRemoverFrame -- see that
-- option's own comment for why.
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

-- Re-applies current style to every arena member frame's DebuffFrame/
-- CcRemoverFrame/SpellDiminishStatusTray item that already exists -- used on
-- the style dropdown changing, and defensively on our own
-- PLAYER_ENTERING_WORLD/zone-change handler in case CompactArenaFrame was
-- (re)created since the last pass.
--
-- Each widget is pcall-wrapped independently so one member's error can't
-- silently abort the loop and skip every widget after it.
function arenaframes:RefreshAuraStyle()
    local frame = CompactArenaFrame
    if not frame or not frame.memberUnitFrames then return end
    for _, memberUnitFrame in ipairs(frame.memberUnitFrames) do
        if memberUnitFrame.DebuffFrame then
            local ok, err = pcall(self.StyleDebuffFrame, self, memberUnitFrame.DebuffFrame)
            if not ok then
                print("|cff33ff99UberUI|r arena DebuffFrame styling error: " .. tostring(err))
            end
        end
        if memberUnitFrame.CcRemoverFrame then
            local ok, err = pcall(self.StyleCcRemoverFrame, self, memberUnitFrame.CcRemoverFrame)
            if not ok then
                print("|cff33ff99UberUI|r arena CcRemoverFrame styling error: " .. tostring(err))
            end
        end
        if memberUnitFrame.SpellDiminishStatusTray and memberUnitFrame.SpellDiminishStatusTray.trayItemPool then
            for trayItem in memberUnitFrame.SpellDiminishStatusTray.trayItemPool:EnumerateActive() do
                local ok, err = pcall(self.StyleDiminishTrayItem, self, trayItem)
                if not ok then
                    print("|cff33ff99UberUI|r arena DR tray styling error: " .. tostring(err))
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

-- Fake arena frame preview, for testing arena aura styling without needing
-- a live match.
--
-- FINDING: calling CompactUnitFrame_SetUnit/_SetUpFrame directly from our
-- own (insecure) addon code -- which an earlier version of this function
-- did -- taints the whole update chain it triggers, including
-- CompactUnitFrame_UpdateInRange's `UnitInRange(frame.displayedUnit)` call.
-- That value comes back as a secret boolean once the execution is tainted,
-- and secret booleans can't be branched on by tainted code -- hence
-- "attempt to perform boolean test on ... a secret boolean value, while
-- execution tainted by 'Uber UI'". Party/raid frames never hit this because
-- they aren't PvP-classified; arena frames specifically secret-wrap their
-- range result under tainted execution. There is no addon-safe way to
-- trigger this ourselves -- unlike a hooksecurefunc reacting AFTER
-- Blizzard's own trusted code runs (safe, used everywhere else in this
-- addon), directly CALLING Blizzard's frame-update functions runs that code
-- inside OUR tainted stack instead of Blizzard's own.
--
-- The only taint-free way to get this fake data is a genuine mouse click
-- through Blizzard's own Edit Mode UI: CompactArenaFrameMixin:RefreshMembers
-- substitutes the unit token "player" for each forced-shown slot when Edit
-- Mode's "Show Arena Frames" account setting is on (see Mainline/
-- CompactArenaFrame.lua), entirely inside Blizzard's own untainted click
-- handler. So instead of faking it ourselves, this just opens Edit Mode for
-- you -- same one `/editmode` opens (ShowUIPanel(EditModeManagerFrame)) --
-- so you only need to check the box yourself once.
--
-- Retail only -- CompactArenaFrame doesn't exist on WoW Forever (Camelot).
function arenaframes:ShowFakeFrames()
    if not EditModeManagerFrame then
        print("|cff33ff99UberUI debug|r Edit Mode isn't available on this client (retail only).")
        return
    end
    if EditModeManagerFrame.CanEnterEditMode and not EditModeManagerFrame:CanEnterEditMode() then
        print("|cff33ff99UberUI debug|r can't enter Edit Mode right now (in combat?).")
        return
    end

    ShowUIPanel(EditModeManagerFrame)
    print("|cff33ff99UberUI debug|r opened Edit Mode -- go to Account Settings and check " ..
        "\"Show Arena Frames\" to preview arena frames using your own character as stand-in " ..
        "data (name/health/auras all real, live). Buff/debuff yourself to test aura styling. " ..
        "Uncheck it or close Edit Mode to restore.")
end

UberUI.arenaframes = arenaframes
