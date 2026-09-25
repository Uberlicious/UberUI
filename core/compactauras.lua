local addon, ns = ...

-- Custom aura containers for compact party/raid frames (CompactPartyFrame
-- and CompactRaidFrame members), built on the same aurakit button styling
-- as target/focus.
--
-- Why the native auras are switched off with CVars rather than hidden: in
-- 12.1 the compact frames have no Lua aura buttons anymore. Buffs, debuffs,
-- dispel icons and the center Big Defensive are all rendered by the
-- forbidden Blizzard_PrivateAurasUI addon, which addon code can't touch.
-- The only supported way to stop them drawing is the player's own raid
-- frame options (raidFramesDisplayBuffs / raidFramesDisplayDebuffs /
-- raidFramesCenterBigDefensive). The original values are saved and put
-- back when a feature is set to "none". The dispel overlay and dispel type
-- icons are driven by separate options, so they stay native either way.
--
-- Which auras show: the containers run Blizzard's own compact-frame rules
-- (AuraUtil.ProcessAura) inside the container's secure code via
-- SetAuraProcessingPolicy(ProcessAura) + processedAuraType candidate
-- filters, and sort with Blizzard's UnitFrameDebuff/BigDefensive orders.
-- That's why these groups look nothing like target/focus's PLAYER/!PLAYER
-- split. Private (boss) auras are included automatically: custom aura
-- containers read the private aura source too.
--
-- Positions/sizes mirror PrivateAuraUnitFrameLayoutTemplates in
-- Blizzard_PrivateAurasUI.lua: buffs/debuffs are 11px * the Edit Mode
-- icon size % (not frame size), the Big Defensive is 22px * frame
-- component scale * its own Edit Mode %.
--
-- Taint: nothing here writes to Blizzard's frames or tables. All per-frame
-- state lives in the weak-keyed table below, and hooks only touch our own
-- containers.

local aurakit = UberUI.aurakit
local compactauras = {}

local NATIVE_UNIT_FRAME_HEIGHT = 36
local NATIVE_UNIT_FRAME_WIDTH = 72
local NATIVE_AURA_SIZE = 11
local NATIVE_BIG_DEFENSIVE_SIZE = NATIVE_AURA_SIZE * 2
local AURA_SCALE_MIN, AURA_SCALE_MAX = 0.5, 2
local BIG_DEFENSIVE_SCALE_MIN, BIG_DEFENSIVE_SCALE_MAX = 0.5, 1
local AURA_BOTTOM_OFFSET = 2
local AURA_EDGE_OFFSET = 3
local AURA_SPACING = 1

local MAX_BUFFS = 6
local MAX_DEBUFFS = 5
local MAX_DISPEL_DEBUFFS = 3

local CVAR_BUFFS = "raidFramesDisplayBuffs"
local CVAR_DEBUFFS = "raidFramesDisplayDebuffs"
local CVAR_BIG_DEFENSIVE = "raidFramesCenterBigDefensive"
local CVAR_ONLY_DISPELLABLE = "raidFramesDisplayOnlyDispellableDebuffs"

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

-- Needs 12.1: AuraContainer, the ProcessAura policy and the Edit Mode aura
-- size settings. Anything older keeps Blizzard's native compact auras and
-- we never touch the CVars.
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

-- Party/raid members only: arena frames are PvP frames with their own
-- rules, and nameplates share the CompactUnitFrame functions.
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

-- The CVar change fires CVAR_UPDATE, and Blizzard's compact frame profiles
-- re-run their setup from their own (untainted) event handler -- not
-- inside this call. Still kept out of combat.
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

    return {
        buffSize = NATIVE_AURA_SIZE * IconScale(groupType, settings.BuffIconSize, AURA_SCALE_MIN, AURA_SCALE_MAX),
        debuffSize = NATIVE_AURA_SIZE * IconScale(groupType, settings.DebuffIconSize, AURA_SCALE_MIN, AURA_SCALE_MAX),
        bigDefensiveSize = NATIVE_BIG_DEFENSIVE_SIZE * componentScale *
            IconScale(groupType, settings.BigDefensiveIconSize, BIG_DEFENSIVE_SCALE_MIN, BIG_DEFENSIVE_SCALE_MAX),
        organization = organization,
        bottomY = AURA_BOTTOM_OFFSET + powerBarHeight,
    }
end

local LEFT, RIGHT = -1, 1
local UP, DOWN = 1, -1

-- anchor point, x, y (y is filled in from bottomY when bottom-anchored),
-- growth directions, icons per row.
local function GetLayouts(metrics)
    local by = metrics.bottomY
    local types = Enum.RaidAuraOrganizationType
    if metrics.organization == types.BuffsTopDebuffsBottom then
        return {
            buffs = { point = "TOPRIGHT", x = -AURA_EDGE_OFFSET, y = -AURA_EDGE_OFFSET, h = LEFT, v = DOWN, perRow = 6 },
            debuffs = { point = "BOTTOMRIGHT", x = -AURA_EDGE_OFFSET, y = by, h = LEFT, v = UP, perRow = 3 },
        }
    end
    -- Legacy and BuffsRightDebuffsLeft place buffs/debuffs identically;
    -- they only differ in name/role icon and dispel icon placement, which
    -- stay native.
    return {
        buffs = { point = "BOTTOMRIGHT", x = -AURA_EDGE_OFFSET, y = by, h = LEFT, v = UP, perRow = 3 },
        debuffs = { point = "BOTTOMLEFT", x = AURA_EDGE_OFFSET, y = by, h = RIGHT, v = UP, perRow = 3 },
    }
end

local function LineSize(size, perRow)
    -- +0.5 so rounding never pushes the last icon of a row onto the next.
    return perRow * size + (perRow - 1) * AURA_SPACING + 0.5
end

local function PlaceContainer(container, frame, layout, size)
    if not container then return end
    container:ClearAllPoints()
    container:SetPoint(layout.point, frame, layout.point, layout.x, layout.y)
    pcall(container.SetFlowLayoutAnchorPoint, container, layout.point)
    pcall(container.SetFlowLayoutGrowthDirection, container, layout.h, layout.v)
    pcall(container.SetFlowLayoutMaximumLineSize, container, LineSize(size, layout.perRow))
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
    })
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

-- Debuffs: ProcessAura sorts harmful auras into "Debuff" (boss, role,
-- priority and regular debuffs) and "Dispel" (debuffs someone in the group
-- can dispel). Blizzard shows both in the same row, so this container has
-- one group for each. If the engine's aura data doesn't flag isRaid, every
-- debuff simply classifies as "Debuff" and lands in the first group.
local function BuildDebuffs(frame, metrics)
    local changed = AuraUtil.AuraUpdateChangedType
    return aurakit.BuildGroupedAuraContainer({
        parentFrame = frame,
        frameLevelBonus = 22,
        spacing = AURA_SPACING,
        maxLineSize = LineSize(metrics.debuffSize, 3),
        processAura = DebuffProcessOptions(),
        updateStyleFn = StyleFn,
        groups = {
            {
                key = "debuffs", filter = "HARMFUL", isBuff = false,
                size = metrics.debuffSize, maxFrameCount = MAX_DEBUFFS,
                sortMethod = AuraContainerSortMethod.UnitFrameDebuff,
                candidateFilters = { processedAuraType = changed.Debuff },
            },
            {
                key = "dispels", filter = "HARMFUL", isBuff = false,
                size = metrics.debuffSize, maxFrameCount = MAX_DISPEL_DEBUFFS,
                sortMethod = AuraContainerSortMethod.UnitFrameDebuff,
                candidateFilters = { processedAuraType = changed.Dispel },
            },
        },
    })
end

-- Buffs: ProcessAura's "Buff" = Blizzard's ShouldDisplayBuff (your own
-- castable, non-self-only buffs plus spells Blizzard flags for your spec).
local function BuildBuffs(frame, metrics)
    return aurakit.BuildGroupedAuraContainer({
        parentFrame = frame,
        frameLevelBonus = 20,
        spacing = AURA_SPACING,
        maxLineSize = LineSize(metrics.buffSize, 3),
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

-- Big Defensive: one centered icon, most important first (Blizzard's own
-- BigDefensive sort). Styled with the buff style.
local function BuildBigDefensive(frame, metrics)
    return aurakit.BuildGroupedAuraContainer({
        parentFrame = frame,
        frameLevelBonus = 21,
        spacing = 0,
        maxLineSize = metrics.bigDefensiveSize + 0.5,
        updateStyleFn = StyleFn,
        groups = {
            {
                key = "bigdefensive", filter = "HELPFUL|BIG_DEFENSIVE", isBuff = true,
                size = metrics.bigDefensiveSize, maxFrameCount = 1,
                sortMethod = AuraContainerSortMethod.BigDefensive,
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
        aurakit.SetGroupedContainerSizes(state.debuffs, { debuffs = metrics.debuffSize, dispels = metrics.debuffSize }, StyleFn)
        PlaceContainer(state.debuffs, frame, layouts.debuffs, metrics.debuffSize)
        apply(state.debuffs, DebuffsEnabled())
    end
    if state.buffs then
        aurakit.SetGroupedContainerSizes(state.buffs, { buffs = metrics.buffSize }, StyleFn)
        PlaceContainer(state.buffs, frame, layouts.buffs, metrics.buffSize)
        apply(state.buffs, BuffsEnabled())
    end
    if state.bigDefensive then
        aurakit.SetGroupedContainerSizes(state.bigDefensive, { bigdefensive = metrics.bigDefensiveSize }, StyleFn)
        state.bigDefensive:ClearAllPoints()
        state.bigDefensive:SetPoint("CENTER", frame, "CENTER", 0, 0)
        pcall(state.bigDefensive.SetFlowLayoutAnchorPoint, state.bigDefensive, "CENTER")
        pcall(state.bigDefensive.SetFlowLayoutMaximumLineSize, state.bigDefensive, metrics.bigDefensiveSize + 0.5)
        apply(state.bigDefensive, BigDefensiveEnabled())
    end
end

-- Creates whichever containers are enabled and don't exist yet. Container
-- creation is kept out of combat; frames first seen in combat are queued
-- and keep their (native) auras until PLAYER_REGEN_ENABLED.
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
    -- Re-run on Blizzard's own setup: Edit Mode size %, organization type,
    -- frame size and power bar changes all come through here.
    if DefaultCompactUnitFrameSetup then
        hooksecurefunc("DefaultCompactUnitFrameSetup", function(frame)
            if frameState[frame] then UpdateFrame(frame) end
        end)
    end
end

local f = UberUI:CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CVAR_UPDATE")
f:SetScript("OnEvent", function(self, event, arg1)
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
        if arg1 == CVAR_ONLY_DISPELLABLE then
            UpdateProcessPolicies()
        end
    end
end)

-- For /uuidebugcompact (uuidebug.lua).
function compactauras:GetDebugInfo()
    local info = {
        supported = IsSupported(),
        pendingCVars = pendingCVars,
        frames = {},
        pending = {},
    }
    for frame, state in pairs(frameState) do
        info.frames[#info.frames + 1] = { frame = frame, state = state }
    end
    for frame in pairs(pendingBuild) do
        info.pending[#info.pending + 1] = frame
    end
    return info
end

UberUI.compactauras = compactauras
