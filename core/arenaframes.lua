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

function arenaframes:StyleDebuffFrame(debuffFrame)
    if not debuffFrame or not debuffFrame.Icon then return end
    local style = uuidb.general.aurastyle_arenadebuffs or "zoom"
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    UberUI.general:ApplyAuraIconInset(debuffFrame.Icon, zoomEnabled or darkBorderEnabled)
    UberUI.general:ApplyIconZoom(debuffFrame.Icon, zoomEnabled)

    if debuffFrame.Border then
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
    if darkBorderEnabled then
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
    if darkBorderEnabled then
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
