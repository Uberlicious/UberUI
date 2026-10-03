local addon, ns = ...

-- Custom aura containers for compact party/raid frames.
--
-- In 12.1 native compact auras are drawn by the forbidden
-- Blizzard_PrivateAurasUI addon, so they're switched off with the player's
-- raid frame CVars (saved, and restored when a feature is set to "none").
-- The containers apply Blizzard's own rules (AuraUtil.ProcessAura via
-- SetAuraProcessingPolicy + processedAuraType filters, Blizzard's sorts), and
-- include private auras. Sizes/positions mirror
-- PrivateAuraUnitFrameLayoutTemplates. Nothing here writes to Blizzard's
-- frames; per-frame state is in weak tables.

local aurakit = UberUI.aurakit
local compactauras = {}

local NATIVE_UNIT_FRAME_HEIGHT = 36
local NATIVE_UNIT_FRAME_WIDTH = 72
local NATIVE_AURA_SIZE = 11
local NATIVE_BIG_DEFENSIVE_SIZE = NATIVE_AURA_SIZE * 2
-- Stack count reference: Blizzard's compact aura template is 17x17
-- (CompactUnitFrame.xml) and NumberFontNormalSmall was sized for that; the
-- 11px native icon is a shrink the font never followed, which drew the count
-- as tall as the icon. So the count scales against 17 (34 for the doubled
-- big defensive).
local COUNT_REF_SIZE = 17
local COUNT_REF_BIG_DEFENSIVE = COUNT_REF_SIZE * 2
local AURA_SCALE_MIN, AURA_SCALE_MAX = 0.5, 2
local BIG_DEFENSIVE_SCALE_MIN, BIG_DEFENSIVE_SCALE_MAX = 0.5, 1
local AURA_BOTTOM_OFFSET = 2
local AURA_EDGE_OFFSET = 3
local AURA_SPACING = 1

local MAX_BUFFS = 6
-- Max Debuffs setting range; 3 is Blizzard's, 6 is two full rows.
local MAX_DEBUFFS_MIN, MAX_DEBUFFS_MAX, MAX_DEBUFFS_DEFAULT = 3, 6, 3
-- Blizzard_PrivateAurasUI's BOSS_DEBUFF_SCALE_INCREASE.
local LARGE_DEBUFF_SCALE = 1.5

local CVAR_BUFFS = "raidFramesDisplayBuffs"
local CVAR_DEBUFFS = "raidFramesDisplayDebuffs"
local CVAR_BIG_DEFENSIVE = "raidFramesCenterBigDefensive"
local CVAR_ONLY_DISPELLABLE = "raidFramesDisplayOnlyDispellableDebuffs"
local CVAR_LARGER_ROLE_DEBUFFS = "raidFramesDisplayLargerRoleSpecificDebuffs"

local frameState = setmetatable({}, { __mode = "k" })
local pendingBuild = setmetatable({}, { __mode = "k" })
local pendingCVars = false
local supported = nil

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

local function GetStyle(key, default)
    return (uuidb and uuidb.general and uuidb.general[key]) or default
end

local function BuffStyle() return GetStyle("aurastyle_compactbuffs", "both") end
local function DebuffStyle() return GetStyle("aurastyle_compactdebuffs", "zoom") end

local function BuffsEnabled() return BuffStyle() ~= "none" end
local function DebuffsEnabled() return DebuffStyle() ~= "none" end
local function BigDefensiveEnabled()
    return uuidb and uuidb.general and uuidb.general.compactbigdefensive ~= false
end

local function MaxDebuffs()
    local n = tonumber(uuidb and uuidb.general and uuidb.general.compactmaxdebuffs) or MAX_DEBUFFS_DEFAULT
    return Clamp(math.floor(n + 0.5), MAX_DEBUFFS_MIN, MAX_DEBUFFS_MAX)
end

local function LargerRoleDebuffs()
    return C_CVar.GetCVarBool(CVAR_LARGER_ROLE_DEBUFFS) == true
end

-- Needs 12.1 (AuraContainer, ProcessAura policy, Edit Mode aura sizes); older
-- clients keep native auras and the CVars are never touched.
local function IsSupported()
    if supported ~= nil then return supported end
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        if C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        end
    end
    supported = C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer")
        and CustomAuraContainerAuraProcessingPolicy ~= nil
        and AuraContainerSortMethod ~= nil
        and EditModeManagerFrame ~= nil
        and EditModeManagerFrame.GetRaidFrameIconScale ~= nil
        and Enum.EditModeUnitFrameSetting ~= nil
        and Enum.EditModeUnitFrameSetting.BuffIconSize ~= nil
        and Enum.RaidAuraOrganizationType ~= nil
    return supported
end

-- Party/raid members only (not arena frames or nameplates).
local function IsCompactGroupFrame(frame)
    if not frame or type(frame) ~= "table" or not frame.GetName then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    local name = frame:GetName()
    if not name then return false end
    return name:find("^CompactPartyFrameMember%d+$") ~= nil
        or name:find("^CompactRaidFrame%d+$") ~= nil
        or name:find("^CompactRaidGroup%d+Member%d+$") ~= nil
end

-------------------------------------------------------------------------------
-- Native aura CVars
-------------------------------------------------------------------------------

local function SetNativeCVar(cvar, oursActive)
    uuidb.cuf.nativecvars = uuidb.cuf.nativecvars or {}
    local saved = uuidb.cuf.nativecvars
    if oursActive then
        if saved[cvar] == nil then
            saved[cvar] = C_CVar.GetCVar(cvar)
        end
        if C_CVar.GetCVar(cvar) ~= "0" then
            C_CVar.SetCVar(cvar, "0")
        end
    elseif saved[cvar] ~= nil then
        C_CVar.SetCVar(cvar, saved[cvar])
        saved[cvar] = nil
    end
end

-- Blizzard re-runs its compact frame setup from its own CVAR_UPDATE handler.
-- Kept out of combat.
function compactauras:ApplyNativeCVars()
    if not IsSupported() or not (uuidb and uuidb.cuf) then return end
    if InCombatLockdown() then
        pendingCVars = true
        return
    end
    pendingCVars = false
    SetNativeCVar(CVAR_BUFFS, BuffsEnabled())
    SetNativeCVar(CVAR_DEBUFFS, DebuffsEnabled())
    SetNativeCVar(CVAR_BIG_DEFENSIVE, BigDefensiveEnabled())
end

-- Turning one of those options back on in Blizzard's settings while ours is
-- active would draw Blizzard's auras on top of ours. Keep the value as the
-- one restored when ours is turned off, and switch the native display back
-- off.
local MANAGED_CVARS = {
    [CVAR_BUFFS] = BuffsEnabled,
    [CVAR_DEBUFFS] = DebuffsEnabled,
    [CVAR_BIG_DEFENSIVE] = BigDefensiveEnabled,
}

local function OnManagedCVarChanged(cvar, value)
    local active = MANAGED_CVARS[cvar]
    if not active or not active() or value == nil or tostring(value) == "0" then return end
    if not (uuidb and uuidb.cuf) then return end
    uuidb.cuf.nativecvars = uuidb.cuf.nativecvars or {}
    uuidb.cuf.nativecvars[cvar] = tostring(value)
    compactauras:ApplyNativeCVars()
end

-------------------------------------------------------------------------------
-- Sizes and layout (mirrors Blizzard_PrivateAurasUI)
-------------------------------------------------------------------------------

local function IconScale(groupType, setting, minScale, maxScale)
    local ok, scale = pcall(EditModeManagerFrame.GetRaidFrameIconScale, EditModeManagerFrame, groupType, 1, setting)
    if not ok or type(scale) ~= "number" then scale = 1 end
    return Clamp(scale, minScale, maxScale)
end

local function GetFrameMetrics(frame)
    local groupType = frame.groupType
    local settings = Enum.EditModeUnitFrameSetting

    local okW, width = pcall(EditModeManagerFrame.GetRaidFrameWidth, EditModeManagerFrame, groupType, NATIVE_UNIT_FRAME_WIDTH)
    local okH, height = pcall(EditModeManagerFrame.GetRaidFrameHeight, EditModeManagerFrame, groupType, NATIVE_UNIT_FRAME_HEIGHT)
    if not okW or type(width) ~= "number" then width = NATIVE_UNIT_FRAME_WIDTH end
    if not okH or type(height) ~= "number" then height = NATIVE_UNIT_FRAME_HEIGHT end
    local componentScale = math.min(height / NATIVE_UNIT_FRAME_HEIGHT, width / NATIVE_UNIT_FRAME_WIDTH)

    local okO, organization = pcall(EditModeManagerFrame.GetRaidFrameAuraOrganizationType, EditModeManagerFrame, groupType)
    if not okO or organization == nil then organization = Enum.RaidAuraOrganizationType.Legacy end

    local powerBarHeight = frame.powerBarUsedHeight
    if type(powerBarHeight) ~= "number" then powerBarHeight = 0 end

    local debuffSize = NATIVE_AURA_SIZE * IconScale(groupType, settings.DebuffIconSize, AURA_SCALE_MIN, AURA_SCALE_MAX)

    return {
        buffSize = NATIVE_AURA_SIZE * IconScale(groupType, settings.BuffIconSize, AURA_SCALE_MIN, AURA_SCALE_MAX),
        debuffSize = debuffSize,
        -- Boss and role debuffs, with Blizzard's "Display Larger Role-Specific
        -- Debuffs" option.
        largeDebuffSize = LargerRoleDebuffs() and debuffSize * LARGE_DEBUFF_SCALE or debuffSize,
        bigDefensiveSize = NATIVE_BIG_DEFENSIVE_SIZE * componentScale *
            IconScale(groupType, settings.BigDefensiveIconSize, BIG_DEFENSIVE_SCALE_MIN, BIG_DEFENSIVE_SCALE_MAX),
        organization = organization,
        bottomY = AURA_BOTTOM_OFFSET + powerBarHeight,
    }
end

local LEFT, RIGHT = -1, 1
local UP, DOWN = 1, -1

-- Anchor, offsets, growth directions and icons per row.
local function GetLayouts(metrics)
    local by = metrics.bottomY
    local types = Enum.RaidAuraOrganizationType
    if metrics.organization == types.BuffsTopDebuffsBottom then
        return {
            buffs = { point = "TOPRIGHT", x = -AURA_EDGE_OFFSET, y = -AURA_EDGE_OFFSET, h = LEFT, v = DOWN, perRow = 6 },
            debuffs = { point = "BOTTOMRIGHT", x = -AURA_EDGE_OFFSET, y = by, h = LEFT, v = UP, perRow = 3 },
        }
    end
    -- Legacy and BuffsRightDebuffsLeft place auras identically.
    return {
        buffs = { point = "BOTTOMRIGHT", x = -AURA_EDGE_OFFSET, y = by, h = LEFT, v = UP, perRow = 3 },
        debuffs = { point = "BOTTOMLEFT", x = AURA_EDGE_OFFSET, y = by, h = RIGHT, v = UP, perRow = 3 },
    }
end

local function LineSize(size, perRow)
    -- +0.5 so rounding never pushes a row's last icon onto the next row.
    return perRow * size + (perRow - 1) * AURA_SPACING + 0.5
end

-- Debuff rows also fit one large boss/role debuff beside the normal ones.
local function DebuffLineSize(metrics, perRow)
    return LineSize(metrics.debuffSize, perRow) + (metrics.largeDebuffSize - metrics.debuffSize)
end

local function PlaceContainer(container, frame, layout, lineSize)
    if not container then return end
    container:ClearAllPoints()
    container:SetPoint(layout.point, frame, layout.point, layout.x, layout.y)
    pcall(container.SetFlowLayoutAnchorPoint, container, layout.point)
    pcall(container.SetFlowLayoutGrowthDirection, container, layout.h, layout.v)
    pcall(container.SetFlowLayoutMaximumLineSize, container, lineSize)
end

-------------------------------------------------------------------------------
-- Button styling
-------------------------------------------------------------------------------

function compactauras:UpdateAuraButtonStyle(button)
    if not button then return end
    local style = button.isBuff and BuffStyle() or DebuffStyle()
    aurakit.ApplyAuraButtonStyle(button, {
        style = style,
        showDispel = false,
        squareLoc = "compact",
    })
    aurakit.UpdateDurationText(button, uuidb and uuidb.general and uuidb.general.compactauraduration)
end

local function StyleFn(btn)
    compactauras:UpdateAuraButtonStyle(btn)
end

-------------------------------------------------------------------------------
-- Container construction
-------------------------------------------------------------------------------

local function OnlyDispellable()
    return C_CVar.GetCVarBool(CVAR_ONLY_DISPELLABLE) == true
end

local function DebuffProcessOptions()
    return {
        displayOnlyDispellableDebuffs = OnlyDispellable(),
        ignoreBuffs = true,
        ignoreDebuffs = false,
        ignoreDispelDebuffs = false,
    }
end

local function BuffProcessOptions()
    return {
        displayOnlyDispellableDebuffs = false,
        ignoreBuffs = false,
        ignoreDebuffs = true,
        ignoreDispelDebuffs = true,
    }
end

-- Debuffs, in one row like Blizzard's, in its priority order: boss/role
-- debuffs (larger with Blizzard's option), then ProcessAura's "Dispel" type,
-- then its "Debuff" type. Blizzard caps all of them together; a container
-- can't share a cap between groups, so Max Debuffs caps each group.
-- ProcessAura types every aura exactly once, so nothing shows twice.
--
-- The boss group has no processedAuraType filter (Debuff or Dispel can't be
-- expressed as one), so it relies on HARMFUL boss/role auras always being
-- one of the two; only a dispellable-by-me boss aura without a dispel type
-- would slip through.
local DEBUFF_GROUP_KEYS = { "bossdebuffs", "dispels", "debuffs" }

local function BuildDebuffs(frame, metrics)
    local changed = AuraUtil.AuraUpdateChangedType
    local maxDebuffs = MaxDebuffs()
    local container = aurakit.BuildGroupedAuraContainer({
        parentFrame = frame,
        frameLevelBonus = 22,
        spacing = AURA_SPACING,
        maxLineSize = DebuffLineSize(metrics, 3),
        countRefSize = COUNT_REF_SIZE,
        processAura = DebuffProcessOptions(),
        updateStyleFn = StyleFn,
        groups = {
            {
                key = "bossdebuffs", filter = "HARMFUL", isBuff = false,
                size = metrics.largeDebuffSize, maxFrameCount = maxDebuffs,
                sortMethod = AuraContainerSortMethod.UnitFrameDebuff,
                candidateFilters = { isBossOrRoleAura = true },
            },
            {
                key = "dispels", filter = "HARMFUL", isBuff = false,
                size = metrics.debuffSize, maxFrameCount = maxDebuffs,
                sortMethod = AuraContainerSortMethod.UnitFrameDebuff,
                candidateFilters = { processedAuraType = changed.Dispel, isBossOrRoleAura = false },
            },
            {
                key = "debuffs", filter = "HARMFUL", isBuff = false,
                size = metrics.debuffSize, maxFrameCount = maxDebuffs,
                sortMethod = AuraContainerSortMethod.UnitFrameDebuff,
                candidateFilters = { processedAuraType = changed.Debuff, isBossOrRoleAura = false },
            },
        },
    })
    if container then container.uuMaxDebuffs = maxDebuffs end
    return container
end

local function ApplyMaxDebuffs(container)
    if not (container and container.SetAuraGroupMaxFrameCount) then return end
    local maxDebuffs = MaxDebuffs()
    if container.uuMaxDebuffs == maxDebuffs then return end
    container.uuMaxDebuffs = maxDebuffs
    for _, key in ipairs(DEBUFF_GROUP_KEYS) do
        pcall(container.SetAuraGroupMaxFrameCount, container, key, maxDebuffs)
    end
end

-- Buffs: ProcessAura's "Buff" (Blizzard's ShouldDisplayBuff).
local function BuildBuffs(frame, metrics)
    return aurakit.BuildGroupedAuraContainer({
        parentFrame = frame,
        frameLevelBonus = 20,
        spacing = AURA_SPACING,
        maxLineSize = LineSize(metrics.buffSize, 3),
        countRefSize = COUNT_REF_SIZE,
        processAura = BuffProcessOptions(),
        updateStyleFn = StyleFn,
        groups = {
            {
                key = "buffs", filter = "HELPFUL", isBuff = true,
                size = metrics.buffSize, maxFrameCount = MAX_BUFFS,
                candidateFilters = { processedAuraType = AuraUtil.AuraUpdateChangedType.Buff },
            },
        },
    })
end

-- Big Defensive: one centered icon, Blizzard's BigDefensive sort, buff style.
-- maxDuration (secret-safe) drops permanent auras the BIG_DEFENSIVE flag
-- also covers (e.g. Devotion Aura); real ones are short (~6-15 s).
local BIG_DEFENSIVE_MAX_DURATION = 60
local function BuildBigDefensive(frame, metrics)
    return aurakit.BuildGroupedAuraContainer({
        parentFrame = frame,
        frameLevelBonus = 21,
        spacing = 0,
        maxLineSize = metrics.bigDefensiveSize + 0.5,
        countRefSize = COUNT_REF_BIG_DEFENSIVE,
        updateStyleFn = StyleFn,
        groups = {
            {
                key = "bigdefensive", filter = "HELPFUL|BIG_DEFENSIVE", isBuff = true,
                size = metrics.bigDefensiveSize, maxFrameCount = 1,
                sortMethod = AuraContainerSortMethod.BigDefensive,
                candidateFilters = { maxDuration = BIG_DEFENSIVE_MAX_DURATION },
            },
        },
    })
end

local function GetUnit(frame)
    return frame.displayedUnit or frame.unit
end

local function PointAtUnit(container, unit)
    if not container then return end
    local target = unit or "none"
    if container:GetUnit() ~= target then
        pcall(container.SetUnit, container, target)
    end
end

-- Positions, sizes, visibility and unit for one frame's containers.
local function UpdateFrame(frame)
    local state = frameState[frame]
    if not state then return end

    local metrics = GetFrameMetrics(frame)
    local layouts = GetLayouts(metrics)
    local unit = GetUnit(frame)

    -- Aura buttons can't be resized in combat, and SetGroupedContainerSizes
    -- records the new size before trying, so a size change made in combat
    -- would never be retried. Leave sizes and placement for
    -- PLAYER_REGEN_ENABLED; unit and visibility still update now.
    local inCombat = InCombatLockdown()
    if inCombat then
        pendingBuild[frame] = true
    else
        pendingBuild[frame] = nil
    end

    local function apply(container, enabled)
        if not container then return end
        if enabled then
            PointAtUnit(container, unit)
            container:Show()
        else
            container:Hide()
        end
    end

    if state.debuffs then
        if not inCombat then
            aurakit.SetGroupedContainerSizes(state.debuffs, {
                bossdebuffs = metrics.largeDebuffSize,
                dispels = metrics.debuffSize,
                debuffs = metrics.debuffSize,
            }, StyleFn)
            ApplyMaxDebuffs(state.debuffs)
            PlaceContainer(state.debuffs, frame, layouts.debuffs, DebuffLineSize(metrics, layouts.debuffs.perRow))
        end
        apply(state.debuffs, DebuffsEnabled())
    end
    if state.buffs then
        if not inCombat then
            aurakit.SetGroupedContainerSizes(state.buffs, { buffs = metrics.buffSize }, StyleFn)
            PlaceContainer(state.buffs, frame, layouts.buffs, LineSize(metrics.buffSize, layouts.buffs.perRow))
        end
        apply(state.buffs, BuffsEnabled())
    end
    if state.bigDefensive then
        if not inCombat then
            aurakit.SetGroupedContainerSizes(state.bigDefensive, { bigdefensive = metrics.bigDefensiveSize }, StyleFn)
            state.bigDefensive:ClearAllPoints()
            state.bigDefensive:SetPoint("CENTER", frame, "CENTER", 0, 0)
            pcall(state.bigDefensive.SetFlowLayoutAnchorPoint, state.bigDefensive, "CENTER")
            pcall(state.bigDefensive.SetFlowLayoutMaximumLineSize, state.bigDefensive, metrics.bigDefensiveSize + 0.5)
        end
        apply(state.bigDefensive, BigDefensiveEnabled())
    end
end

-- Creates missing enabled containers. Out of combat only; frames first seen
-- in combat keep native auras until PLAYER_REGEN_ENABLED.
local function EnsureFrame(frame)
    if not IsSupported() or not IsCompactGroupFrame(frame) then return end

    local wantDebuffs, wantBuffs, wantBigDefensive = DebuffsEnabled(), BuffsEnabled(), BigDefensiveEnabled()
    local state = frameState[frame]
    local needsBuild = (wantDebuffs and not (state and state.debuffs))
        or (wantBuffs and not (state and state.buffs))
        or (wantBigDefensive and not (state and state.bigDefensive))

    if needsBuild then
        if InCombatLockdown() then
            pendingBuild[frame] = true
        else
            pendingBuild[frame] = nil
            if not state then
                state = {}
                frameState[frame] = state
            end
            local metrics = GetFrameMetrics(frame)
            if wantDebuffs and not state.debuffs then state.debuffs = BuildDebuffs(frame, metrics) end
            if wantBuffs and not state.buffs then state.buffs = BuildBuffs(frame, metrics) end
            if wantBigDefensive and not state.bigDefensive then state.bigDefensive = BuildBigDefensive(frame, metrics) end
        end
    end

    UpdateFrame(frame)
end

-------------------------------------------------------------------------------
-- Frame discovery and refresh
-------------------------------------------------------------------------------

local function ForEachExistingCompactFrame(callback)
    for i = 1, 5 do
        local f = _G["CompactPartyFrameMember" .. i]
        if f then callback(f) end
    end
    for i = 1, 80 do
        local f = _G["CompactRaidFrame" .. i]
        if f then callback(f) end
    end
    for g = 1, 8 do
        for m = 1, 5 do
            local f = _G["CompactRaidGroup" .. g .. "Member" .. m]
            if f then callback(f) end
        end
    end
end

-- For the options preview: buff and debuff icon sizes (in the frame's units),
-- the count font's reference size, and that frame's effective scale, from
-- the first existing compact frame (shown ones first). nil when there's none.
function compactauras:GetPreviewSizes()
    local found, fallback
    ForEachExistingCompactFrame(function(f)
        if found or not f.groupType or f:IsForbidden() then return end
        if f:IsVisible() then found = f else fallback = fallback or f end
    end)
    local frame = found or fallback
    if not frame then return nil end
    local ok, m = pcall(GetFrameMetrics, frame)
    if not ok or not m then return nil end
    return m.buffSize, m.debuffSize, COUNT_REF_SIZE, frame:GetEffectiveScale()
end

-- Called from the options panel whenever a compact aura setting changes.
function compactauras:Refresh()
    if not IsSupported() then return end
    self:ApplyNativeCVars()
    ForEachExistingCompactFrame(EnsureFrame)
    for _, state in pairs(frameState) do
        for _, key in ipairs({ "debuffs", "buffs", "bigDefensive" }) do
            local container = state[key]
            if container then
                aurakit.RefreshGroupButtons(container, container.uuGroupKeys, StyleFn)
            end
        end
    end
end

local function UpdateProcessPolicies()
    if not CustomAuraContainerAuraProcessingPolicy then return end
    local policy = CustomAuraContainerAuraProcessingPolicy.ProcessAura
    local options = DebuffProcessOptions()
    for _, state in pairs(frameState) do
        if state.debuffs then
            pcall(state.debuffs.SetAuraProcessingPolicy, state.debuffs, policy, options)
        end
    end
end

local hooked = false
local function InstallHooks()
    if hooked then return end
    hooked = true

    -- Unit assignment: frames are reused as the roster changes.
    if CompactUnitFrame_SetUnit then
        hooksecurefunc("CompactUnitFrame_SetUnit", function(frame)
            if IsCompactGroupFrame(frame) then EnsureFrame(frame) end
        end)
    end
    -- Vehicle swaps change displayedUnit without a SetUnit call.
    if CompactUnitFrame_UpdateAll then
        hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame)
            local state = frameState[frame]
            if not state then return end
            local unit = GetUnit(frame)
            PointAtUnit(state.debuffs, unit)
            PointAtUnit(state.buffs, unit)
            PointAtUnit(state.bigDefensive, unit)
        end)
    end
    -- Blizzard's setup re-runs on Edit Mode size, organization, frame size and
    -- power bar changes.
    if DefaultCompactUnitFrameSetup then
        hooksecurefunc("DefaultCompactUnitFrameSetup", function(frame)
            if frameState[frame] then UpdateFrame(frame) end
        end)
    end
    -- Edit Mode's buff/debuff/big defensive icon size sliders don't re-run the
    -- setup; they call this on every frame instead. Deferred and batched: it
    -- fires once per frame per slider step, inside Edit Mode's update chain.
    if CompactUnitFrame_UpdateAllFromEditMode then
        local pending = {}
        local queued = false
        hooksecurefunc("CompactUnitFrame_UpdateAllFromEditMode", function(frame)
            if not frameState[frame] then return end
            pending[frame] = true
            if queued then return end
            queued = true
            C_Timer.After(0, function()
                queued = false
                for f in pairs(pending) do
                    pending[f] = nil
                    if frameState[f] then UpdateFrame(f) end
                end
            end)
        end)
    end
end

local f = UberUI:CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CVAR_UPDATE")
f:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        if not IsSupported() then return end
        InstallHooks()
        compactauras:Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not IsSupported() then return end
        if pendingCVars then compactauras:ApplyNativeCVars() end
        for frame in pairs(pendingBuild) do
            EnsureFrame(frame)
        end
    elseif event == "CVAR_UPDATE" then
        -- Not IsSupported(): an early CVAR_UPDATE would cache "unsupported".
        if supported ~= true then return end
        if arg1 == CVAR_ONLY_DISPELLABLE then
            UpdateProcessPolicies()
        elseif arg1 == CVAR_LARGER_ROLE_DEBUFFS then
            for frame in pairs(frameState) do UpdateFrame(frame) end
        elseif MANAGED_CVARS[arg1] then
            OnManagedCVarChanged(arg1, arg2)
        end
    end
end)

UberUI.compactauras = compactauras
