
function UberUI:CreateFrame(frameType, frameName, parent, template)
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
            -- The player frame's PvP backdrop is PrestigePortrait.
            if frame.PrestigePortrait and frame.PrestigePortrait.SetVertexColor then
                frame.PrestigePortrait:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
        end
    end
end

-- Hide Honor: hides the PvP badge on Player, Target, Focus and party frames.
-- Retail sets the badge regions inline (PlayerFrame_UpdatePvPStatus,
-- TargetFrameMixin:CheckFaction); Forever routes through
-- UnitFrameUtil.UpdateUnitPvPIndicator and its Camelot frames use
-- PvpBackgroundCircle/Icon instead. Both paths are hooked and both sets of
-- regions collected. Never Show() anything Blizzard didn't.
local PvPBadgeElementKeys = {
    "pvpIcon", "pvpBackground", "prestigePortrait", "prestigeBadge",
    "pvpBackgroundCircle", "pvpBackgroundIcon",
}

-- Badge textures we hid while Blizzard was showing them. Turning Hide Honor
-- off re-shows only these, and only if Blizzard would still show them.
local hiddenByHideHonor = {}

local IsSecret = UberUI.util.IsSecret

-- Blizzard's own badge show conditions (game rule, frame showPVP, FFA or
-- faction-flagged). Unknown/secret -> false.
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
        -- Something visible means Blizzard just re-decided the badge; stale
        -- records for its other elements are dropped.
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

-- frame = TargetFrame or FocusFrame.
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

-- Party member frames: just PartyMemberOverlay.PVPIcon.
local function GetPartyMemberPvPBadgeElements(p)
    local overlay = p and p.PartyMemberOverlay
    if not overlay then return nil end
    return { pvpIcon = overlay.PVPIcon }
end

-- Installed only once Hide Honor is turned on (hooks can't be removed).
local hideHonorHooksInstalled = false
local function EnsureHideHonorHooks()
    if hideHonorHooksInstalled then return end
    hideHonorHooksInstalled = true

    if UnitFrameUtil and UnitFrameUtil.UpdateUnitPvPIndicator then
        hooksecurefunc(UnitFrameUtil, "UpdateUnitPvPIndicator", function(elements, unitToken)
            ApplyHideHonor(elements, unitToken)
        end)
    end

    -- Retail's per-frame updates (redundant with the delegate on Forever).
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

-- Also re-applied on the events behind every badge update, in case a hook
-- above is shadowed by a per-instance override.
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

local SafeBool = UberUI.util.SafeBool

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
        local classColor = UberUI.util.ClassColor(class)
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

    healthBar:SetStatusBarDesaturated(true)
    if isEnemy then
        healthBar:SetStatusBarColor(1, 0, 0)
    else
        healthBar:SetStatusBarColor(0, 1, 0)
    end
end

-- Offensive dispel capability (Purge, Dispel Magic, Spellsteal, ...): there's
-- no API for it, so check whether any such spell is known.
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

-- Known spells change with talents/specs.
local dispelCapabilityWatcher = CreateFrame("Frame")
dispelCapabilityWatcher:RegisterEvent("SPELLS_CHANGED")
dispelCapabilityWatcher:RegisterEvent("TRAIT_CONFIG_UPDATED")
dispelCapabilityWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
dispelCapabilityWatcher:SetScript("OnEvent", RefreshPlayerCanOffensiveDispel)
RefreshPlayerCanOffensiveDispel()

function general:PlayerCanOffensiveDispel()
    return playerCanOffensiveDispel
end

-- Blizzard's StealableBorder texture for every dispel type (CustomAsset map).
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

function general:ApplyIconZoom(textureObject, enable)
    if textureObject and textureObject:IsObjectType("Texture") then
        if enable then
            local inset = 0.07
            textureObject:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
        else
            textureObject:SetTexCoord(0, 1, 0, 1)
        end
    end
end

-- With zoom or a border, the icon insets 1px inside its parent so crop and
-- border read as one unit; otherwise it fills its anchor.
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

-- Divider pieces on the main action bar and Forever's bags bar live in frame
-- pools that UpdateDividers() re-acquires, so this re-runs after it.
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

-- Hooks UpdateDividers once, then darkens the dividers already showing.
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
