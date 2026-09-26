-- Centralized functions for UberUI

function UberUI:CreateFrame(frameType, frameName, parent, template)
    -- This function wraps the global CreateFrame.
    -- It allows for centralized control and can be expanded later
    -- to add debugging or frame management.
    local frame = CreateFrame(frameType, frameName, parent, template)
    return frame
end

local general = {}

function general:PvPIcon(frame)
    if frame then
        local dc = uuidb and uuidb.general and uuidb.general.darkencolor
        if dc then
            if frame.PvpBackgroundCircle and frame.PvpBackgroundCircle.SetVertexColor then
                frame.PvpBackgroundCircle:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
            if frame.PvPBackgroundCircle and frame.PvPBackgroundCircle.SetVertexColor then
                frame.PvPBackgroundCircle:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
            -- PlayerFrame has no PvPBackgroundCircle of its own -- its PvP
            -- status badge is PrestigePortrait (the round backdrop behind
            -- the honor icon), which needs the same darken treatment.
            if frame.PrestigePortrait and frame.PrestigePortrait.SetVertexColor then
                frame.PrestigePortrait:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
        end
    end
end

-- Hide Honor: hides the whole PvP badge (icon + background + Prestige art)
-- on the Player, Target, and Focus frames.
--
-- CONFIRMED (via wow-ui-source origin/live vs origin/forever): retail 12.1
-- and WoW Forever 1.60.1 are NOT on the same PvP-indicator code here. Forever
-- already has Blizzard's newer shared abstraction -- each frame exposes
-- GetPvPIndicatorElements(), and Player/Target/Focus all funnel through one
-- UnitFrameUtil.UpdateUnitPvPIndicator delegate ("also safe for addons to
-- use"). Retail 12.1 does not have that abstraction at all (zero references
-- in origin/live) -- it still sets PVPIcon/PvpIcon/PrestigePortrait/
-- PrestigeBadge directly inline inside PlayerFrame_UpdatePvPStatus and
-- TargetFrameMixin:CheckFaction. Both function NAMES exist unchanged on both
-- clients (only their bodies differ), so we hook those directly as the
-- universal fallback, and additionally hook the new delegate when present.
-- Whichever path actually runs on a given client, it converges on the same
-- ApplyHideHonor(elements) call.
--
-- UPDATE (origin/forever, Sept 2026): Forever's Camelot game type now loads
-- Camelot/PlayerFrame.lua + Camelot/TargetFrame.lua overrides that draw the
-- badge with PvpBackgroundCircle/PvpBackgroundIcon instead and never touch
-- the Mainline PVPIcon/PrestigePortrait/PrestigeBadge regions (which still
-- exist, permanently hidden). Both sets are collected below.
--
-- ApplyHideHonor must NEVER Show() anything Blizzard didn't. It used to do
-- SetShown(not hide), which with the setting off force-showed every badge
-- element on every target/flag/roster event -- unflagged units got a badge on
-- retail, and Forever got the never-used Mainline badge art popping up.
local PvPBadgeElementKeys = {
    "pvpIcon", "pvpBackground", "prestigePortrait", "prestigeBadge",
    "pvpBackgroundCircle", "pvpBackgroundIcon",
}

-- Texture -> { unit, frame }, for badge textures that were visible (i.e.
-- Blizzard showed them) when we hid them. Turning Hide Honor off re-shows only
-- these, and only if Blizzard's own show conditions still hold, so we never
-- resurrect a badge Blizzard wouldn't show. Anything stale gets fixed by
-- Blizzard's own next PvP update.
local hiddenByHideHonor = {}

local function IsSecret(val)
    return issecretvalue and issecretvalue(val)
end

-- Mirrors the show conditions in PlayerFrame_UpdatePvPStatus /
-- TargetFrameMixin:CheckFaction / PartyMemberFrameMixin:UpdatePvPStatus
-- (identical on origin/live and origin/forever's Camelot overrides): game
-- rule not disabling it, the frame's showPVP (target/focus only -- small
-- focus clears it), and FFA or faction-flagged PvP. Unknown/secret -> false.
local function BlizzardWouldShowBadge(record)
    local unit, frame = record.unit, record.frame
    if not unit or not UnitExists(unit) then return false end
    if C_GameRules and C_GameRules.IsGameRuleActive and Enum.GameRule
        and Enum.GameRule.UnitFramePvPContextualDisabled
        and C_GameRules.IsGameRuleActive(Enum.GameRule.UnitFramePvPContextualDisabled) then
        return false
    end
    if frame and frame.CheckFaction and not frame.showPVP then return false end
    local ffa = UnitIsPVPFreeForAll(unit)
    if IsSecret(ffa) then return false end
    if ffa then return true end
    local faction = UnitFactionGroup(unit)
    local pvp = UnitIsPVP(unit)
    if IsSecret(faction) or IsSecret(pvp) then return false end
    return faction ~= nil and faction ~= "Neutral" and pvp and true or false
end

local function ApplyHideHonor(elements, unit, frame)
    if not elements then return end
    local hide = uuidb and uuidb.general and uuidb.general.hidehonor
    if hide then
        -- If Blizzard just re-decided this badge (something is visible), its
        -- previous choice (e.g. icon vs. prestige badge) is stale -- drop it.
        local anyShown = false
        for _, key in ipairs(PvPBadgeElementKeys) do
            local tex = elements[key]
            if tex and tex.IsShown and tex:IsShown() then anyShown = true break end
        end
        for _, key in ipairs(PvPBadgeElementKeys) do
            local tex = elements[key]
            if tex and tex.IsShown then
                if tex:IsShown() then
                    hiddenByHideHonor[tex] = { unit = unit, frame = frame }
                    tex:Hide()
                elseif anyShown then
                    hiddenByHideHonor[tex] = nil
                end
            end
        end
    elseif next(hiddenByHideHonor) then
        for _, key in ipairs(PvPBadgeElementKeys) do
            local tex = elements[key]
            local record = tex and hiddenByHideHonor[tex]
            if record then
                hiddenByHideHonor[tex] = nil
                if BlizzardWouldShowBadge(record) then
                    tex:Show()
                end
            end
        end
    end
end

-- Player: Forever's PlayerFrame_GetPvPIndicatorElements() when present;
-- otherwise read the Mainline PVPIcon/PrestigePortrait/PrestigeBadge fields
-- retail's inline code uses, plus Forever Camelot's PvpBackground* regions.
local function GetPlayerPvPBadgeElements()
    if PlayerFrame_GetPvPIndicatorElements then
        return PlayerFrame_GetPvPIndicatorElements()
    end
    local contextual = PlayerFrame_GetPlayerFrameContentContextual and PlayerFrame_GetPlayerFrameContentContextual()
    local main = PlayerFrame and PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
    if not contextual and not main then return nil end
    return {
        pvpIcon = contextual and contextual.PVPIcon,
        prestigePortrait = contextual and contextual.PrestigePortrait,
        prestigeBadge = contextual and contextual.PrestigeBadge,
        pvpBackgroundCircle = main and main.PvpBackgroundCircle,
        pvpBackgroundIcon = main and main.PvpBackgroundIcon,
    }
end

-- Target/Focus (frame = TargetFrame or FocusFrame): same idea, using each
-- frame's own GetPvPIndicatorElements method when present, otherwise reading
-- TargetFrameContentContextual's PvpIcon/PrestigePortrait/PrestigeBadge the
-- way retail's inline CheckFaction code does (plus Camelot's PvpBackground*).
local function GetFramePvPBadgeElements(frame)
    if not frame then return nil end
    if frame.GetPvPIndicatorElements then
        return frame:GetPvPIndicatorElements()
    end
    local contextual = frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentContextual
    if not contextual then return nil end
    return {
        pvpIcon = contextual.PvpIcon,
        prestigePortrait = contextual.PrestigePortrait,
        prestigeBadge = contextual.PrestigeBadge,
        pvpBackgroundCircle = contextual.PvpBackgroundCircle,
        pvpBackgroundIcon = contextual.PvpBackgroundIcon,
    }
end

-- Non-compact party member frames have their own, much simpler PvP icon --
-- PartyMemberOverlay.PVPIcon, no background/prestige art -- set by
-- PartyMemberFrameMixin:UpdatePvPStatus (core/partyframes.lua's own aura/
-- color code never touches this, so it needed separate coverage here).
local function GetPartyMemberPvPBadgeElements(p)
    local overlay = p and p.PartyMemberOverlay
    if not overlay then return nil end
    return { pvpIcon = overlay.PVPIcon }
end

-- hooksecurefunc can never be undone, so we don't install these until Hide
-- Honor is actually turned on -- installed lazily (once) from RefreshHideHonor
-- below the first time it runs with the setting enabled, the same pattern
-- nameplates.lua uses for its raid-target-icon hooks. This means enabling the
-- setting live (no reload) still gets full coverage; only re-disabling it
-- leaves the (now harmless, since ApplyHideHonor no-ops when hidehonor is
-- false) hooks installed for the rest of the session.
local hideHonorHooksInstalled = false
local function EnsureHideHonorHooks()
    if hideHonorHooksInstalled then return end
    hideHonorHooksInstalled = true

    -- Forever's shared delegate, when present.
    if UnitFrameUtil and UnitFrameUtil.UpdateUnitPvPIndicator then
        hooksecurefunc(UnitFrameUtil, "UpdateUnitPvPIndicator", function(elements, unitToken)
            ApplyHideHonor(elements, unitToken)
        end)
    end

    -- Retail 12.1's separate per-frame update functions -- present under the
    -- same names on Forever too, so these hooks are harmless (redundant with
    -- the delegate hook above) there, and load-bearing on retail.
    if PlayerFrame_UpdatePvPStatus then
        hooksecurefunc("PlayerFrame_UpdatePvPStatus", function()
            ApplyHideHonor(GetPlayerPvPBadgeElements(), "player")
        end)
    end
    if TargetFrameMixin and TargetFrameMixin.CheckFaction then
        hooksecurefunc(TargetFrameMixin, "CheckFaction", function(self)
            ApplyHideHonor(GetFramePvPBadgeElements(self), self.unit, self)
        end)
    end
    if PartyMemberFrameMixin and PartyMemberFrameMixin.UpdatePvPStatus then
        hooksecurefunc(PartyMemberFrameMixin, "UpdatePvPStatus", function(self)
            ApplyHideHonor(GetPartyMemberPvPBadgeElements(self), self.unit)
        end)
    end
end

function general:RefreshHideHonor()
    if uuidb and uuidb.general and uuidb.general.hidehonor then
        EnsureHideHonorHooks()
    end
    ApplyHideHonor(GetPlayerPvPBadgeElements(), "player")
    ApplyHideHonor(GetFramePvPBadgeElements(TargetFrame), "target", TargetFrame)
    ApplyHideHonor(GetFramePvPBadgeElements(FocusFrame), "focus", FocusFrame)
    if UberUI.partyframes and UberUI.partyframes.IteratePartyFrames then
        for _, p in pairs(UberUI.partyframes:IteratePartyFrames()) do
            ApplyHideHonor(GetPartyMemberPvPBadgeElements(p), p.unit)
        end
    end
end

-- Belt-and-suspenders: don't rely solely on successfully hooking Blizzard's
-- internal update functions (a mixin method hook can be shadowed if some
-- other addon -- or a future Blizzard refactor -- assigns a per-instance
-- override that shadows the shared mixin table, and we have no reliable way
-- to detect that from here). Directly watching the actual game events that
-- drive every PvP-badge update (targeting, focusing, faction/flag changes,
-- roster changes) and re-running RefreshHideHonor ourselves means the hide
-- holds even if a specific internal hook above turns out not to fire.
local hideHonorWatcher = CreateFrame("Frame")
hideHonorWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
hideHonorWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
hideHonorWatcher:RegisterEvent("PLAYER_FOCUS_CHANGED")
hideHonorWatcher:RegisterEvent("UNIT_FACTION")
hideHonorWatcher:RegisterEvent("PLAYER_FLAGS_CHANGED")
hideHonorWatcher:RegisterEvent("GROUP_ROSTER_UPDATE")
hideHonorWatcher:SetScript("OnEvent", function()
    general:RefreshHideHonor()
end)

local function SafeBool(val)
    if val == nil or IsSecret(val) then return false end
    return val and true or false
end

function general:SetHealthColor(healthBar, unit, db)
    if healthBar == nil or not db then return end

    local isFriendly = false
    local isEnemy = false
    local isPlayer = false

    local okU, isSelf = pcall(UnitIsUnit, "player", unit)
    if okU and SafeBool(isSelf) then
        isFriendly = true
        isPlayer = true
    else
        local okP, isP = pcall(UnitIsPlayer, unit)
        if okP and not IsSecret(isP) then
            isPlayer = isP and true or false
        end

        local okF, isF = pcall(UnitIsFriend, "player", unit)
        if okF and not IsSecret(isF) then
            isFriendly = isF and true or false
            isEnemy = not isFriendly
        else
            local okE, isE = pcall(UnitCanAttack, "player", unit)
            if okE and not IsSecret(isE) then
                isEnemy = isE and true or false
                isFriendly = not isEnemy
            end
        end
    end

    if isPlayer then
        local _, class = UnitClass(unit)
        local classColor = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (GetClassColorObj and GetClassColorObj(class)) or RAID_CLASS_COLORS[class])
        if classColor then
            if (db.classcolorfriendly and db.classcolorenemy) or
               (db.classcolorenemy and isEnemy) or
               (db.classcolorfriendly and isFriendly) then
                healthBar:SetStatusBarDesaturated(true)
                healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
                return
            end
        end
    end

    local useHostilityColor = uuidb and uuidb.general and uuidb.general.hostilitycolor
    if useHostilityColor then
        local reaction
        local okR, r = pcall(UnitReaction, unit, "player")
        if okR and not IsSecret(r) and type(r) == "number" then
            reaction = r
        end

        healthBar:SetStatusBarDesaturated(true)
        if reaction and reaction >= 5 then
            healthBar:SetStatusBarColor(0, 1, 0) -- Friendly
        elseif reaction == 4 then
            healthBar:SetStatusBarColor(1, 1, 0) -- Neutral
        elseif isFriendly then
            healthBar:SetStatusBarColor(0, 1, 0) -- Friendly fallback
        else
            healthBar:SetStatusBarColor(1, 0, 0) -- Hostile
        end
        return
    end

    -- Default to friendly color if no other condition is met
    healthBar:SetStatusBarDesaturated(true)
    if isEnemy then
        healthBar:SetStatusBarColor(1, 0, 0)
    else
        healthBar:SetStatusBarColor(0, 1, 0)
    end
end

-- Offensive dispel capability (Purge/Dispel Magic on an enemy/Spellsteal),
-- shared by targetframe.lua and focusframe.lua rather than duplicated per
-- file. Stock Blizzard only shows the stealable/dispellable indicator to
-- classes that can act on it, and there's no direct Blizzard API for "can I
-- offensively dispel" -- so this checks known-spell state
-- (C_SpellBook.IsSpellKnown) against the Purge/Dispel Magic/Spellsteal
-- family instead of a class table, so it stays correct as more specs gain
-- the ability. Classic-safe IDs only; retail-only specs/spells (e.g. Demon
-- Hunter) are added separately -- IsSpellKnown just returns false where they
-- don't apply, so this is purely additive.
local OFFENSIVE_MAGIC_DISPEL_SPELLS = {
    370,    -- Purge (Shaman)
    528,    -- Dispel Magic (Priest)
    30449,  -- Spellsteal (Mage)
}

if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
    local retailOnly = {
        378773, -- Greater Purge (Shaman)
        32375,  -- Mass Dispel (Priest)
        278326, -- Consume Magic (Demon Hunter)
        19801,  -- Tranquilizing Shot (Hunter)
    }
    for _, spellID in ipairs(retailOnly) do
        table.insert(OFFENSIVE_MAGIC_DISPEL_SPELLS, spellID)
    end
end

local playerCanOffensiveDispel = false
local function RefreshPlayerCanOffensiveDispel()
    local bank = Enum and Enum.SpellBookSpellBank
    if not (C_SpellBook and C_SpellBook.IsSpellKnown and bank) then
        playerCanOffensiveDispel = false
        return
    end
    for _, spellID in ipairs(OFFENSIVE_MAGIC_DISPEL_SPELLS) do
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID, bank.Player)
        if ok and known then
            playerCanOffensiveDispel = true
            return
        end
    end
    playerCanOffensiveDispel = false
end

-- Talents/specs can change known spells mid-session, so re-check instead of
-- computing once at load.
local dispelCapabilityWatcher = CreateFrame("Frame")
dispelCapabilityWatcher:RegisterEvent("SPELLS_CHANGED")
dispelCapabilityWatcher:RegisterEvent("TRAIT_CONFIG_UPDATED")
dispelCapabilityWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
dispelCapabilityWatcher:SetScript("OnEvent", RefreshPlayerCanOffensiveDispel)
RefreshPlayerCanOffensiveDispel()

function general:PlayerCanOffensiveDispel()
    return playerCanOffensiveDispel
end

-- Blizzard's own StealableBorder texture (same one stock target/focus frames
-- use, see TargetFrameAuraButton.xml), used as a CustomAsset dispel-type
-- texture map so every dispel-type key renders the same fixed indicator.
local STEALABLE_ASSET = { asset = "Interface\\TargetingFrame\\UI-TargetingFrame-Stealable" }
local STEALABLE_DISPEL_ASSET_MAP = {
    Magic = STEALABLE_ASSET,
    Curse = STEALABLE_ASSET,
    Poison = STEALABLE_ASSET,
    Disease = STEALABLE_ASSET,
    Bleed = STEALABLE_ASSET,
    None = STEALABLE_ASSET,
}

function general:GetStealableDispelAssetMap()
    return STEALABLE_DISPEL_ASSET_MAP
end

-- Safer ApplyIconZoom in Uber UI/core/generalfunctions.lua
function general:ApplyIconZoom(textureObject, enable)
    -- Check if the object is actually a texture before attempting the call
    if textureObject and textureObject:IsObjectType("Texture") then
        if enable then
            local inset = 0.07
            textureObject:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
        else
            textureObject:SetTexCoord(0, 1, 0, 1)
        end
    else
        -- This will help you track down which object is being passed incorrectly
        print("ApplyIconZoom received non-Texture object: " .. tostring(textureObject))
    end
end

-- Shared icon-inset convention used by every aura style implementation
-- (target/focus/party/arena/nameplate): whenever zoom or a border is active,
-- the icon insets 1px inward from its parent so the crop and the border read
-- as one cohesive unit instead of the border framing a boundary the icon no
-- longer visually fills. Native ("None") keeps the icon at its own
-- full-bleed anchor. Safe even on a masked icon (e.g. nameplate auras): the
-- icon shrinking inside an unmoved mask just crops slightly more, not a
-- misaligned crop.
function general:ApplyAuraIconInset(icon, insetEnabled)
    if not icon then return end
    local parent = icon:GetParent()
    if not parent then return end
    icon:ClearAllPoints()
    if insetEnabled then
        icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, 1)
    else
        icon:SetAllPoints(parent)
    end
end

-- Divider pieces between buttons on the main action bar (retail and
-- Forever) and Forever's bags bar. Both bars keep them in two frame pools
-- (HorizontalDividersPool / VerticalDividersPool) that UpdateDividers()
-- releases and re-acquires whenever the visible buttons change, so callers
-- re-run this from a post-hook on UpdateDividers. The dividers are
-- three-slice layouts: TopEdge/Center/BottomEdge on a horizontal bar,
-- LeftEdge/Center/RightEdge on a vertical one.
local DIVIDER_PIECES = { "TopEdge", "Center", "BottomEdge", "LeftEdge", "RightEdge" }

function general:DarkenDividers(bar)
    if not bar then return end
    local dc = uuidb.general.darkencolor
    for _, poolKey in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
        local pool = bar[poolKey]
        if pool and pool.EnumerateActive then
            for divider in pool:EnumerateActive() do
                for _, key in ipairs(DIVIDER_PIECES) do
                    local piece = divider[key]
                    if piece and piece.SetVertexColor then
                        piece:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                    end
                end
            end
        end
    end
end

-- Hooks bar:UpdateDividers once so new dividers get darkened as Blizzard
-- creates them, then darkens the ones already showing.
function general:HookDividers(bar)
    if not bar or not bar.UpdateDividers then return end
    if not self.hookedDividerBars then
        self.hookedDividerBars = setmetatable({}, { __mode = "k" })
    end
    if not self.hookedDividerBars[bar] then
        self.hookedDividerBars[bar] = true
        hooksecurefunc(bar, "UpdateDividers", function(b) general:DarkenDividers(b) end)
    end
    self:DarkenDividers(bar)
end

UberUI.general = general
