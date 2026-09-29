local addon, ns = ...

-- Nameplate auras in our own aurakit containers (docs/nameplate-auras.md),
-- off by default. Nameplate aura data is secret in combat, so instead of
-- styling Blizzard's buttons the engine classifies, filters and colors auras
-- in CustomAuraContainers.
--
-- Containers are slow to build (~12 ms), so a pool of prebuilt "bundles"
-- (holder + debuff/buff/crowd-control containers) is built behind loading
-- screens and attached to plates as they appear (~0.1 ms). The pool never
-- shrinks (frames can't be freed).
--
-- Filters mirror Blizzard_NamePlateAuras.lua: debuffs (yours on enemies,
-- max 12), buffs (enemies: important or dispellable; friends: yours; max 2
-- each), crowd control (max 2 each). Shown categories follow Blizzard's
-- nameplate CVars. The loss-of-control icon stays Blizzard's.
--
-- Each container sits where Blizzard's list frame does, in a holder parented
-- to the plate's AurasFrame, so Blizzard's show/hide, fade and scale carry
-- over; Blizzard's lists are faded out while a bundle is attached. Hooks and
-- creation only happen while the feature is on, nameplate-triggered writes
-- are deferred, and frames anchored to a plate use
-- DisableUntrustedLayoutScriptsTemplate.

local aurakit = UberUI.aurakit
local nameplateauras = {}

local SQUARE_LOC = "nameplate"
local ICON_SIZE = 22
local BLIZZARD_AURA_SIZE = NamePlateConstants and NamePlateConstants.AURA_ITEM_HEIGHT or 25
local SPACING = 3                         -- 22 + 3 = Blizzard's 25px pitch
-- Extra gap from the health bar: our borders draw outside the icon.
local SIDE_GAP = 3
local DEBUFF_MAX = 12
-- BUFF_MAX is the per-group ceiling the groups are built at (the slider's max);
-- the counts actually shown are set per unit in Bind. CC and debuff counts are
-- Blizzard's own (maxAuraItemsDisplayed in Blizzard_NamePlates.xml: 12/2/2).
local BUFF_MAX, CC_MAX = 4, 2
local BUFF_BUDGET_DEFAULT = 1
local POOL_SIZE = 16
local POOL_TARGET_INSTANCE = 25
local CONTAINER_KEYS = { "debuffs", "buffs", "cc" }
local LIST_KEYS = { debuffs = "DebuffListFrame", buffs = "BuffListFrame", cc = "CrowdControlListFrame" }
local GROUP_KEYS = { debuffs = { "debuffs" }, buffs = { "important", "dispellable" }, cc = { "cc", "showall" } }

local pool = {}                                        -- every bundle ever built
local byUnit = {}                                      -- unit token -> bundle
local seq = {}                                         -- unit token -> attach sequence
local attachedTo = setmetatable({}, { __mode = "k" })  -- AurasFrame -> bundle
local hookedAuras = setmetatable({}, { __mode = "k" }) -- AurasFrame -> true
local fadedLists = setmetatable({}, { __mode = "k" })  -- AurasFrame -> true
local dispellableToken = true                          -- false once DISPELLABLE is refused
local raidDispelToken = true                           -- false once RAID_PLAYER_DISPELLABLE is refused

local IsSecret = UberUI.util.IsSecret

local function Enabled()
    return uuidb and uuidb.general and uuidb.general.nameplateauras == true
end

-- Enemy buff settings. Read through functions, never at file scope: uuidb is
-- still config.lua's placeholder while this file loads.
local function BuffBudget()
    local g = uuidb and uuidb.general
    local n = (g and tonumber(g.nameplatebuffbudget)) or BUFF_BUDGET_DEFAULT
    return math.max(1, math.min(BUFF_MAX, math.floor(n + 0.5)))
end

local function ShowImportantBuffs()
    local g = uuidb and uuidb.general
    return not (g and g.nameplatebuffsimportant == false)
end

-- "group" (someone in your raid can dispel it -- just you when ungrouped),
-- "any" (Blizzard's own rule: anything flagged dispellable), or "off".
local function PurgeableMode()
    local g = uuidb and uuidb.general
    local v = g and g.nameplatebuffspurgeable
    if v == "off" or v == "any" then return v end
    return "group"
end

local function EnsureAuraContainerAddOn()
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        if C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        end
    end
    return C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") and AuraContainerSortMethod ~= nil
end

local function CVarBool(cvar)
    return CVarCallbackRegistry and cvar and CVarCallbackRegistry:GetCVarValueBool(cvar) or false
end

local function CVarBit(cvar, index)
    if not (CVarCallbackRegistry and cvar and index) then return false end
    return CVarCallbackRegistry:GetCVarBitfieldIndex(cvar, index) and true or false
end

local function ShowAllPersonal()
    return NamePlateConstants and CVarBool(NamePlateConstants.SHOW_ALL_PERSONAL_AURAS_CVAR) or false
end

-------------------------------------------------------------------------------
-- Styling
-------------------------------------------------------------------------------

local function HexColor(hex, fallback)
    return UberUI.util.HexColor(hex) or fallback
end

-- Pandemic highlight on debuffs: the engine shows the region
-- (AddPandemicRegion) only inside the refresh window and while data is
-- secret; its shown state is secret to us, so we only style its children.
local PANDEMIC_DEFAULT_COLOR = "ffff3030"
local pandemicHosts = setmetatable({}, { __mode = "k" }) -- button -> host frame

-- Class color when that option is on, else the configured hex color.
local function PandemicColor()
    local g = uuidb and uuidb.general or {}
    if g.nameplatepandemicclasscolor then
        local _, class = UnitClass("player")
        local cc = UberUI.util.ClassColor(class)
        if cc then return cc.r, cc.g, cc.b end
    end
    local col = HexColor(g.nameplatepandemiccolor, nil) or HexColor(PANDEMIC_DEFAULT_COLOR)
    return col.r, col.g, col.b
end

local StyleButton

local function HideDebuffBorders(button)
    button._uberInPandemic = true
    if button.borderHost then button.borderHost:Hide() end
    if button.borderTex then button.borderTex:Hide() end
    if button.roundDispelHost then button.roundDispelHost:Hide() end
    if button.dispelBorderHost then button.dispelBorderHost:Hide() end
    local SB = UberUI.squareborders
    if SB then
        local main = SB.Find(button, 1)
        if main then
            main:Hide()
            if main.edges then
                for i = 1, 4 do
                    if main.edges[i] then main.edges[i]:SetAlpha(0) end
                end
            end
        end
        local dark = SB.Find(button, 3)
        if dark then
            dark:Hide()
            if dark.edges then
                for i = 1, 4 do
                    if dark.edges[i] then dark.edges[i]:SetAlpha(0) end
                end
            end
        end
    end
end

local function GetPandemicHost(button)
    local host = pandemicHosts[button]
    if host then return host end
    host = CreateFrame("Frame", nil, button)
    host:SetAllPoints(button)
    local base = button.borderHost and button.borderHost:GetFrameLevel() or button:GetFrameLevel()
    host:SetFrameLevel(base + 3) -- over the dispel border, under the text
    host:EnableMouse(false)
    host:Hide()
    pandemicHosts[button] = host

    -- These two never fire once AddPandemicRegion has run: the engine marks
    -- the region's Shown aspect secret, so insecure handlers are not called
    -- and IsShown reads secret. Kept only for a client without that API,
    -- where the host would be an ordinary frame. Anything that must appear
    -- during the pandemic window belongs inside the host instead (see the
    -- occluder in aurakit.StyleHighlight) -- it cannot be driven from here.
    host:HookScript("OnShow", function()
        HideDebuffBorders(button)
        local SB = UberUI.squareborders
        if host.uuSquare and button.icon and SB then
            SB.LayoutDispelFor(host.uuSquare, button.icon, SQUARE_LOC)
            local pr, pg, pb = PandemicColor()
            SB.SetColor(host.uuSquare, pr, pg, pb, 1)
        end
        if host.uuRing and button.borderHost then
            host.uuRing:ClearAllPoints()
            host.uuRing:SetAllPoints(button.borderHost)
        end
    end)

    host:HookScript("OnHide", function()
        if not button._uberInPandemic then return end
        button._uberInPandemic = nil
        local SB = UberUI.squareborders
        if SB then
            local main = SB.Find(button, 1)
            if main and main.edges then
                for i = 1, 4 do
                    if main.edges[i] then main.edges[i]:SetAlpha(1) end
                end
            end
            local dark = SB.Find(button, 3)
            if dark and dark.edges then
                for i = 1, 4 do
                    if dark.edges[i] then dark.edges[i]:SetAlpha(1) end
                end
            end
        end
        local okShown, shown = pcall(button.IsShown, button)
        if okShown and shown and StyleButton then
            StyleButton(button)
        end
    end)

    if not button._uberPandemicBtnHooked then
        button._uberPandemicBtnHooked = true
        button:HookScript("OnHide", function()
            button._uberInPandemic = nil
            local SB = UberUI.squareborders
            if SB then
                local main = SB.Find(button, 1)
                if main and main.edges then
                    for i = 1, 4 do
                        if main.edges[i] then main.edges[i]:SetAlpha(1) end
                    end
                end
                local dark = SB.Find(button, 3)
                if dark and dark.edges then
                    for i = 1, 4 do
                        if dark.edges[i] then dark.edges[i]:SetAlpha(1) end
                    end
                end
            end
        end)
    end

    return host
end

local function StylePandemic(button, style)
    if button.isBuff or button.groupKey ~= "debuffs" then return end
    local g = uuidb and uuidb.general or {}
    local on = g.nameplatepandemic ~= false
    local host = pandemicHosts[button]
    if not on then
        if host then
            host:Hide()
            if button._uberInPandemic then
                button._uberInPandemic = nil
                local okShown, shown = pcall(button.IsShown, button)
                if okShown and shown and StyleButton then
                    StyleButton(button)
                end
            end
        end
        return
    end
    if not host then
        host = GetPandemicHost(button)
    end
    if on and not host.registered and button.AddPandemicRegion then
        if pcall(button.AddPandemicRegion, button, host) then host.registered = true end
    end

    local SB = UberUI.squareborders
    local pr, pg, pb = PandemicColor()
    local kind = on and (g.nameplatepandemicstyle or "border") or "none"
    -- Border style already paints over the debuff's own border in the
    -- pandemic color; Proc Glow and Marching Ants sit on top of it and would
    -- leave the dispel color showing through, so those cover it in the same
    -- pandemic color (class color included -- see PandemicColor).
    local occlude
    if on and kind ~= "border" then
        occlude = { r = pr, g = pg, b = pb }
    end
    aurakit.StyleHighlight(host, {
        kind = kind,
        r = pr, g = pg, b = pb,
        occlude = occlude,
        square = style ~= "none" and SB and SB.IsEnabled(SQUARE_LOC),
        loc = SQUARE_LOC, icon = button.icon,
        ringFrom = button.borderHost,
        center = button, size = button.elementSize or ICON_SIZE,
    })
end

StyleButton = function(button)
    local g = uuidb and uuidb.general or {}
    local style = button.isBuff and (g.aurastyle_nameplatebuffs or "both") or (g.aurastyle_nameplatedebuffs or "zoom")
    local showDispel = g.nameplatebuffs_showdispel ~= false
    -- stealableRing: thin white border on purgeable buffs instead of
    -- Blizzard's glow, which ran over the health bar.
    aurakit.ApplyAuraButtonStyle(button, {
        style = style,
        squareLoc = SQUARE_LOC,
        showDispel = showDispel,
        stealableRing = true,
    })
    pcall(StylePandemic, button, style)
    pcall(aurakit.UpdateDurationText, button, true)
    -- Every aura update restyles the button, which re-shows the dispel border;
    -- keep it hidden while the pandemic highlight is up.
    if button._uberInPandemic then pcall(HideDebuffBorders, button) end
end

-- Buttons whose engine-colored square strips haven't registered yet.
local function NeedsRegistration(button)
    local SB = UberUI.squareborders
    if not SB then return false end
    local sb = SB.Find(button, button.isBuff and 2 or 1)
    return not (sb and sb.engineRegistered)
end

local function RetryRegistrations(b)
    for _, key in ipairs(CONTAINER_KEYS) do
        local c = b[key]
        if c and c.allButtons then
            for button in pairs(c.allButtons) do
                if NeedsRegistration(button) then pcall(StyleButton, button) end
            end
        end
    end
end

local function RestyleBundle(b)
    for _, key in ipairs(CONTAINER_KEYS) do
        local c = b[key]
        if c and c.allButtons then
            for button in pairs(c.allButtons) do pcall(StyleButton, button) end
        end
    end
end

-------------------------------------------------------------------------------
-- Bundles
-------------------------------------------------------------------------------

local function NewContainer(holder)
    local c = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
    c:SetSize(1, 1)
    pcall(c.SetFlowLayoutPadding, c, 0, 0, 0, 0)
    if c.SetFlowLayoutSpacing then pcall(c.SetFlowLayoutSpacing, c, SPACING, SPACING) end
    -- Nameplates put the stack count further out than the other locations
    -- (Blizzard_NamePlateAuras.xml: BOTTOMRIGHT x=3 y=-2).
    c._uberCountOffset = { 3, -2 }
    c._uberCountScale = ICON_SIZE / BLIZZARD_AURA_SIZE
    return c
end

-- Returns true if the group was added.
local function AddGroup(c, key, filter, maxCount, isBuff, candidates, index)
    local options = {
        maxFrameCount = maxCount,
        initializeFrame = function(button)
            aurakit.InitAuraButton(c, button, key, isBuff, ICON_SIZE, false, StyleButton)
        end,
        layout = aurakit.MakeGroupLayout(ICON_SIZE, SPACING, SPACING, false, index, true),
    }
    if candidates then options.candidateFilters = candidates end
    return (pcall(c.AddAuraGroup, c, key, filter, options))
end

local function BuildBundle()
    -- The template (needed to anchor into a nameplate) can only be given at
    -- creation.
    local ok, holder = pcall(CreateFrame, "Frame", nil, UIParent, "DisableUntrustedLayoutScriptsTemplate")
    if not ok or not holder then return nil end
    holder:SetSize(1, 1)
    holder:Hide()

    local b = { holder = holder, showAllPersonal = ShowAllPersonal() }

    b.debuffs = NewContainer(holder)
    AddGroup(b.debuffs, "debuffs", "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL|PLAYER", DEBUFF_MAX, false,
        { nameplateShowAll = false, nameplateShowPersonal = (not b.showAllPersonal) or nil }, 1)

    b.buffs = NewContainer(holder)
    AddGroup(b.buffs, "important", "HELPFUL|INCLUDE_NAME_PLATE_ONLY|IMPORTANT", BUFF_MAX, true, nil, 1)
    local added = dispellableToken and AddGroup(b.buffs, "dispellable",
        "HELPFUL|INCLUDE_NAME_PLATE_ONLY|!IMPORTANT|DISPELLABLE", BUFF_MAX, true, nil, 2)
    if not added then
        -- No DISPELLABLE token on this client: Blizzard's isStealable rule
        -- (empty while aura data is secret).
        dispellableToken = false
        AddGroup(b.buffs, "dispellable", "HELPFUL|INCLUDE_NAME_PLATE_ONLY|!IMPORTANT", BUFF_MAX, true,
            { isStealable = true }, 2)
    end

    b.cc = NewContainer(holder)
    AddGroup(b.cc, "cc", "HARMFUL|INCLUDE_NAME_PLATE_ONLY|CROWD_CONTROL", CC_MAX, false, nil, 1)
    AddGroup(b.cc, "showall", "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL", CC_MAX, false,
        { nameplateShowAll = true }, 2)

    -- Debuffs grow up/right from the bar's top-left; buffs left; CC right.
    pcall(b.debuffs.SetFlowLayoutAnchorPoint, b.debuffs, "BOTTOMLEFT")
    pcall(b.debuffs.SetFlowLayoutGrowthDirection, b.debuffs, 1, 1)
    pcall(b.buffs.SetFlowLayoutAnchorPoint, b.buffs, "BOTTOMRIGHT")
    pcall(b.buffs.SetFlowLayoutGrowthDirection, b.buffs, -1, 1)
    pcall(b.cc.SetFlowLayoutAnchorPoint, b.cc, "BOTTOMLEFT")
    pcall(b.cc.SetFlowLayoutGrowthDirection, b.cc, 1, 1)
    local oneRow = 2 * (ICON_SIZE + SPACING)
    -- Buffs stay on one line, however many the budget allows: Blizzard only
    -- ever gives DebuffListFrame a stride, and BuffListFrame/CrowdControlList
    -- carry needsFixedHeight, so buff rows never wrap and the plate's height
    -- never shifts. Bind sets the real width once the budget is known.
    pcall(b.buffs.SetFlowLayoutMaximumLineSize, b.buffs, BUFF_MAX * 2 * (ICON_SIZE + SPACING))
    pcall(b.cc.SetFlowLayoutMaximumLineSize, b.cc, oneRow * 2)

    for _, key in ipairs(CONTAINER_KEYS) do
        pcall(b[key].SetUnit, b[key], "none")
    end

    pool[#pool + 1] = b
    return b
end

local function GrowPool(target)
    if not EnsureAuraContainerAddOn() then return end
    while #pool < target do
        if not BuildBundle() then return end
    end
end

-- Dispel-border registrations are refused behind the loading screen (where
-- the pool is built), so bundles are restyled once the world is up, one per
-- frame.
local restyleQueue = {}
local restyleRunning = false
local function QueueRestyleAll()
    for _, b in ipairs(pool) do restyleQueue[#restyleQueue + 1] = b end
    if restyleRunning then return end
    restyleRunning = true
    local function step()
        local b = table.remove(restyleQueue, 1)
        if not b then
            restyleRunning = false
            return
        end
        RestyleBundle(b)
        C_Timer.After(0, step)
    end
    C_Timer.After(0, step)
end

-------------------------------------------------------------------------------
-- Blizzard's own lists
-------------------------------------------------------------------------------

local function SetBlizzardListsFaded(aurasFrame, faded)
    if faded == (fadedLists[aurasFrame] == true) then return end
    fadedLists[aurasFrame] = faded or nil
    for _, key in ipairs(CONTAINER_KEYS) do
        local list = aurasFrame[LIST_KEYS[key]]
        if list then pcall(list.SetAlpha, list, faded and 0 or 1) end
    end
end

-- Which categories Blizzard shows for this unit (NamePlateAurasMixin:
-- Update*AuraFrames).
local function ShownCategories(unit)
    local C, E = NamePlateConstants, Enum
    if not (C and E and E.NamePlateEnemyNpcAuraDisplay) then return true, true, true end
    local isFriend = UnitIsFriend("player", unit)
    local isPlayer = UnitIsPlayer(unit)
    if isPlayer then
        if isFriend then
            return CVarBit(C.FRIENDLY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateFriendlyPlayerAuraDisplay.Debuffs),
                CVarBit(C.FRIENDLY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateFriendlyPlayerAuraDisplay.Buffs), false
        end
        return CVarBit(C.ENEMY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateEnemyPlayerAuraDisplay.Debuffs),
            CVarBit(C.ENEMY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateEnemyPlayerAuraDisplay.Buffs), false
    end
    if isFriend then
        return CVarBool(C.SHOW_DEBUFFS_ON_FRIENDLY_CVAR), false, false
    end
    return CVarBit(C.ENEMY_NPC_AURA_DISPLAY_CVAR, E.NamePlateEnemyNpcAuraDisplay.Debuffs),
        CVarBit(C.ENEMY_NPC_AURA_DISPLAY_CVAR, E.NamePlateEnemyNpcAuraDisplay.Buffs),
        CVarBit(C.ENEMY_NPC_AURA_DISPLAY_CVAR, E.NamePlateEnemyNpcAuraDisplay.CrowdControl)
end

-------------------------------------------------------------------------------
-- Attach / release
-------------------------------------------------------------------------------

-- Per-unit filters, shown categories, scale and stride; re-run whenever
-- Blizzard re-evaluates the plate.
local function Bind(b, unit)
    local aurasFrame = b.aurasFrame
    if not aurasFrame then return end
    local isFriend = UnitIsFriend("player", unit)

    -- Debuffs on enemies must be yours; buffs on friends must be yours, with
    -- no important/dispellable split.
    pcall(b.debuffs.SetAuraGroupFilterString, b.debuffs, "debuffs",
        isFriend and "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL"
        or "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL|PLAYER")
    pcall(b.buffs.SetAuraGroupFilterString, b.buffs, "important",
        isFriend and "HELPFUL|INCLUDE_NAME_PLATE_ONLY|PLAYER" or "HELPFUL|INCLUDE_NAME_PLATE_ONLY|IMPORTANT")

    -- Enemy buff budget. It is per category, not a shared total: the engine
    -- counts each aura group on its own and aura counts are secret to us, so
    -- one combined cap across important+purgeable isn't expressible. At the
    -- default of 1 each the worst case is 2 icons, matching Blizzard's own
    -- BuffListFrame cap. Friendlies keep Blizzard's 2 (only your own buffs
    -- show there, and the purgeable group is off).
    local importantCount, purgeableCount
    if isFriend then
        importantCount, purgeableCount = 2, 0
    else
        local budget = BuffBudget()
        local purge = PurgeableMode()
        importantCount = ShowImportantBuffs() and budget or 0
        purgeableCount = (purge ~= "off") and budget or 0
        if purgeableCount > 0 and dispellableToken then
            local anyFilter = "HELPFUL|INCLUDE_NAME_PLATE_ONLY|!IMPORTANT|DISPELLABLE"
            local wantGroup = purge == "group" and raidDispelToken
            local ok = pcall(b.buffs.SetAuraGroupFilterString, b.buffs, "dispellable",
                wantGroup and "HELPFUL|INCLUDE_NAME_PLATE_ONLY|!IMPORTANT|RAID_PLAYER_DISPELLABLE" or anyFilter)
            if not ok and wantGroup then
                -- No RAID_PLAYER_DISPELLABLE on this client; fall back to any.
                raidDispelToken = false
                pcall(b.buffs.SetAuraGroupFilterString, b.buffs, "dispellable", anyFilter)
            end
        end
    end
    pcall(b.buffs.SetAuraGroupMaxFrameCount, b.buffs, "important", importantCount)
    pcall(b.buffs.SetAuraGroupMaxFrameCount, b.buffs, "dispellable", purgeableCount)
    -- Wide enough for every icon the budget allows, so the row never wraps.
    pcall(b.buffs.SetFlowLayoutMaximumLineSize, b.buffs,
        math.max(1, importantCount + purgeableCount) * (ICON_SIZE + SPACING))

    local showAllPersonal = ShowAllPersonal()
    if showAllPersonal ~= b.showAllPersonal and b.debuffs.SetAuraGroupCandidateFilters then
        b.showAllPersonal = showAllPersonal
        pcall(b.debuffs.SetAuraGroupCandidateFilters, b.debuffs, "debuffs",
            { nameplateShowAll = false, nameplateShowPersonal = (not showAllPersonal) or nil })
    end

    -- Blizzard's own item scale and debuff stride (UpdateAuraScale).
    local scale = tonumber(aurasFrame.auraItemScale) or 1
    if scale <= 0 then scale = 1 end
    local stride = aurasFrame.DebuffListFrame and tonumber(aurasFrame.DebuffListFrame.stride) or 8
    pcall(b.debuffs.SetFlowLayoutMaximumLineSize, b.debuffs, stride * (ICON_SIZE + SPACING))

    local showDebuffs, showBuffs, showCC = ShownCategories(unit)
    local shown = { debuffs = showDebuffs, buffs = showBuffs, cc = showCC }
    for _, key in ipairs(CONTAINER_KEYS) do
        local c = b[key]
        c:SetScale(scale)
        if shown[key] then
            c:Show()
            if c:GetUnit() ~= unit then pcall(c.SetUnit, c, unit) end
        else
            c:Hide()
            if c:GetUnit() ~= "none" then pcall(c.SetUnit, c, "none") end
        end
    end
end

local function Layout(b)
    local af = b.aurasFrame
    local function place(c, point, list, x, y)
        c:ClearAllPoints()
        c:SetPoint(point, list, point, x, y or 0)
    end
    -- Debuffs lifted too: their bottom row ran onto the health bar.
    pcall(place, b.debuffs, "BOTTOMLEFT", af.DebuffListFrame, 0, SIDE_GAP)
    pcall(place, b.buffs, "RIGHT", af.BuffListFrame, -SIDE_GAP)
    pcall(place, b.cc, "LEFT", af.CrowdControlListFrame, SIDE_GAP)
end

local QueueRebind

local function EnsureAurasFrameHooks(aurasFrame)
    if hookedAuras[aurasFrame] then return end
    hookedAuras[aurasFrame] = true
    -- UpdateShownState: unit/friend/simplified/CVar changes;
    -- UpdateAuraScale: aura scale changes.
    hooksecurefunc(aurasFrame, "UpdateShownState", function(self) QueueRebind(self) end)
    if aurasFrame.UpdateAuraScale then
        hooksecurefunc(aurasFrame, "UpdateAuraScale", function(self) QueueRebind(self) end)
    end
end

local rebindPending = setmetatable({}, { __mode = "k" })
QueueRebind = function(aurasFrame)
    if rebindPending[aurasFrame] then return end
    rebindPending[aurasFrame] = true
    C_Timer.After(0, function()
        rebindPending[aurasFrame] = nil
        local b = attachedTo[aurasFrame]
        if b and b.unit and not aurasFrame:IsForbidden() then
            pcall(Bind, b, b.unit)
        end
    end)
end

local function Release(unit)
    local b = byUnit[unit]
    if not b then return end
    byUnit[unit] = nil
    local af = b.aurasFrame
    b.unit, b.aurasFrame = nil, nil
    for _, key in ipairs(CONTAINER_KEYS) do
        pcall(b[key].SetUnit, b[key], "none")
        b[key]:ClearAllPoints()
    end
    b.holder:Hide()
    pcall(b.holder.SetParent, b.holder, UIParent)
    b.inUse = nil
    if af then
        if attachedTo[af] == b then attachedTo[af] = nil end
        -- Deferred (possibly inside Blizzard's removal chain); skipped if the
        -- plate already got a new bundle.
        C_Timer.After(0, function()
            if not attachedTo[af] and not af:IsForbidden() then SetBlizzardListsFaded(af, false) end
        end)
    end
end

local function Attach(unit)
    if not Enabled() or byUnit[unit] then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return end
    local unitFrame = plate.UnitFrame
    local af = unitFrame and unitFrame.AurasFrame
    if not (af and af.DebuffListFrame) or af:IsForbidden() then return end

    -- A plate reused for a new unit before its removal was seen.
    local old = attachedTo[af]
    if old and old.unit then Release(old.unit) end

    local b
    for _, cand in ipairs(pool) do
        if not cand.inUse then b = cand break end
    end
    if not b then
        GrowPool(#pool + 1)
        b = pool[#pool]
        if not b or b.inUse then return end
    end

    b.inUse, b.unit, b.aurasFrame = true, unit, af
    byUnit[unit] = b
    attachedTo[af] = b

    if not pcall(b.holder.SetParent, b.holder, af) then
        pcall(b.holder.SetParent, b.holder, plate)
    end
    b.holder:SetFrameLevel(af:GetFrameLevel() + 5)
    b.holder:Show()
    Layout(b)
    EnsureAurasFrameHooks(af)
    SetBlizzardListsFaded(af, true)
    Bind(b, unit)
    -- Retry dispel-strip registrations the engine refused earlier (it
    -- refuses while aura data is secret); until then square mode shows a
    -- dark border.
    C_Timer.After(0, function()
        if b.unit == unit then RetryRegistrations(b) end
    end)
end

local function ReleaseAll()
    for unit in pairs(byUnit) do Release(unit) end
end

local function AttachVisible()
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        if not plate:IsForbidden() then
            local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if unit and not IsSecret(unit) then pcall(Attach, unit) end
        end
    end
end

-------------------------------------------------------------------------------
-- Public
-------------------------------------------------------------------------------

function nameplateauras:Refresh()
    if Enabled() then
        local target = POOL_SIZE
        local _, instanceType = IsInInstance()
        if instanceType == "party" or instanceType == "raid" then target = POOL_TARGET_INSTANCE end
        GrowPool(target)
        AttachVisible()
    else
        ReleaseAll()
    end
end

function nameplateauras:RefreshStyle()
    for _, b in ipairs(pool) do RestyleBundle(b) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if not Enabled() then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        -- Deferred out of Blizzard's add chain; the sequence number drops a
        -- stale attach if the token was removed and re-added meanwhile.
        local unit = arg1
        local n = (seq[unit] or 0) + 1
        seq[unit] = n
        C_Timer.After(0, function()
            if seq[unit] == n then pcall(Attach, unit) end
        end)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        seq[arg1] = (seq[arg1] or 0) + 1
        pcall(Release, arg1)
    elseif event == "PLAYER_LOGIN" then
        GrowPool(POOL_SIZE)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = arg1, arg2
        local _, instanceType = IsInInstance()
        if instanceType == "party" or instanceType == "raid" then
            -- Top up during the zoning screen (M+/raid pulls have the most plates).
            GrowPool(POOL_TARGET_INSTANCE)
        end
        if isLogin or isReload then QueueRestyleAll() end
    end
end)

UberUI.nameplateauras = nameplateauras
