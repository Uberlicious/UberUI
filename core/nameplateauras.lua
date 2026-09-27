local addon, ns = ...

-- Nameplate auras in our own aurakit containers (docs/nameplate-auras.md).
-- Off by default ("Uber UI Nameplate Auras" on the Nameplates page).
--
-- Why containers and not Blizzard's buttons: nameplate aura data is secret
-- under combat/encounter/PvP restrictions, so styling Blizzard's own
-- NamePlateAuraItem buttons means reading fields that crash when touched.
-- A CustomAuraContainer lets the engine classify and filter the auras and
-- color the dispel borders itself.
--
-- Nameplates come and go constantly and a container costs ~12 ms to build
-- (the engine pre-creates buttons in batches of 10), far too slow to build
-- per plate. So, like EllesmereUI: a pool of prebuilt "bundles" (a holder +
-- debuff/buff/crowd-control containers), built behind the loading screen --
-- 16 at login, topped up to 25 entering a party/raid instance, one more on
-- demand when a plate finds the pool empty (even in combat: a one-off hitch,
-- never missing auras). Frames can't be freed, so the pool never shrinks.
-- Attaching a bundle to a plate is ~0.1 ms.
--
-- Mirrors Blizzard_NamePlateAuras.lua (retail 12.1 and Forever 1.60.1):
--   debuffs  HARMFUL|INCLUDE_NAME_PLATE_ONLY, not crowd control, only
--            nameplateShowPersonal auras (unless the show-all-personal CVar),
--            yours only on enemies; max 12, rows of Blizzard's stride
--   buffs    enemies: important or dispellable (Blizzard: stealable -- the
--            engine's DISPELLABLE token works while aura data is secret, an
--            isStealable compare doesn't); friends: yours only; max 2 each
--   cc       crowd control, or nameplateShowAll; max 2 each
-- Which categories show per unit type comes from Blizzard's own nameplate
-- CVars, the same ones its options panel writes. The loss-of-control icon
-- (enemy/friendly players) stays Blizzard's: it reads C_LossOfControl,
-- which containers can't.
--
-- Placement: each container sits exactly where Blizzard's own list frame
-- does, and the holder is parented to the plate's AurasFrame, so Blizzard's
-- show/hide (simplified plates, name-only, widgets-only), fade and scale all
-- carry over. Blizzard's three list frames are faded to 0 while a bundle is
-- attached and put back when it leaves.
--
-- Rules followed (CLAUDE.md): nothing is created or hooked unless the
-- feature is on; per-plate hooks go on Blizzard's AurasFrame instances only
-- when a bundle first attaches to them; every write triggered from a
-- nameplate event or hook is deferred a frame. Every frame that anchors to a
-- nameplate is born with DisableUntrustedLayoutScriptsTemplate.

local aurakit = UberUI.aurakit
local nameplateauras = {}

local SQUARE_LOC = "nameplate"
local ICON_SIZE = 22
local SPACING = 3                         -- 22 + 3 = Blizzard's 25px pitch
-- Extra gap between the health bar and our containers (buffs left, CC right,
-- debuffs above): our borders sit outside the icon (rounded art ~3px), so at
-- Blizzard's own spacing they ran onto the health bar.
local SIDE_GAP = 3
local DEBUFF_MAX = 12
local BUFF_MAX, CC_MAX = 2, 2
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

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function Enabled()
    return uuidb and uuidb.general and uuidb.general.nameplateauras == true
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

-- Duration text, Blizzard's nameplate look (NamePlateAuraItemMixin:SetAura):
-- the Cooldown's own countdown font, whole seconds, centered. The duration
-- is secret, so formatting and color go to the engine: a formatter rounding
-- up to whole seconds, and a step color curve on the REMAINING duration --
-- the expiring color from 0 to the threshold, the normal color up to 60 s,
-- transparent above that (Blizzard shows no number on auras over a minute;
-- the binding takes a single curve, so this is by time remaining: a long
-- aura shows its number for its last minute). Colors are hex strings from
-- the options' color swatches. The curve is copied at registration, so a
-- settings change re-registers each button's text.
local function DurationSettings()
    local g = uuidb and uuidb.general or {}
    local threshold = tonumber(g.nameplatedurationthreshold) or 5
    if threshold < 0 then threshold = 0 end
    return g.nameplatedurationcolor or "ffffffff", g.nameplatedurationexpiringcolor or "ffff3333", threshold
end

local function HexColor(hex, fallback)
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x%x%x$") then return fallback end
    local ok, c = pcall(CreateColorFromHexString, hex)
    if ok and c then return c end
    return fallback
end

local durationFormatter
local durationOptions, durationOptionsKey
local function GetDurationTextOptions()
    local normal, expiring, threshold = DurationSettings()
    local key = normal .. "|" .. expiring .. "|" .. threshold
    if durationOptionsKey == key then return durationOptions, key end
    durationOptionsKey = key
    durationOptions = nil
    pcall(function()
        local opts = {}
        if durationFormatter == nil then
            durationFormatter = false
            if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum.NumericRuleFormatRounding then
                local formatter = C_StringUtil.CreateNumericRuleFormatter()
                formatter:AddBreakpoint({ threshold = 0, step = 1, rounding = Enum.NumericRuleFormatRounding.Up, format = "%d" })
                durationFormatter = formatter
            end
        end
        if durationFormatter then opts.textFormatter = durationFormatter end
        if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum.DurationTextBindingProperty then
            local n = HexColor(normal, CreateColor(1, 1, 1, 1))
            local e = HexColor(expiring, CreateColor(1, 0.2, 0.2, 1))
            local curve = C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            curve:AddPoint(0, CreateColor(e.r, e.g, e.b, 1))
            if threshold > 0 and threshold < 60 then
                curve:AddPoint(threshold, CreateColor(n.r, n.g, n.b, 1))
            end
            curve:AddPoint(60.001, CreateColor(n.r, n.g, n.b, 0))
            opts.textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration }
        end
        durationOptions = opts
    end)
    return durationOptions, key
end

local function ApplyDurationText(button)
    local text = button.uuDuration
    if not text then return end
    local opts, key = GetDurationTextOptions()
    if button.uuDurationKey == key then return end
    if opts and pcall(button.SetDurationText, button, text, opts) then
        button.uuDurationKey = key
    elseif not button.uuDurationKey then
        pcall(button.SetDurationText, button, text) -- engine default, retried next style pass
    end
end

local function AddDurationText(button)
    if not button.SetDurationText or button.uuDuration then return end
    local parent = button.textHolder or button
    local text = parent:CreateFontString(nil, "OVERLAY")
    -- The Cooldown's own countdown font, like Blizzard's icons use.
    local cdText = button.cooldown and button.cooldown.GetCountdownFontString and button.cooldown:GetCountdownFontString()
    local font, size, flags
    if cdText then font, size, flags = cdText:GetFont() end
    if font then
        text:SetFont(font, size, flags)
    else
        text:SetFontObject(NumberFontNormal)
    end
    text:SetPoint("CENTER", button.icon or button, "CENTER", 0, 0)
    button.uuDuration = text
    ApplyDurationText(button)
end

-- Pandemic highlight on debuffs: shown only while the aura can be refreshed
-- without losing time (its pandemic window). The engine decides that --
-- CustomAuraButton:AddPandemicRegion (retail 12.1 and Forever 1.60.1) shows
-- the region only between expiration - carried-over duration
-- (GetRefreshExtendedDuration - GetAuraBaseDuration) and expiration, so it
-- only ever lights on refreshable auras and works while aura data is
-- secret. The region's shown state is secret to us: we only ever style its
-- children. Styles: the aura's own border shape in a color, or one of
-- Blizzard's animated glows (a looping FlipBook, which runs in the engine).
local PANDEMIC_DEFAULT_COLOR = "ffff2626"
local pandemicHosts = setmetatable({}, { __mode = "k" }) -- button -> host frame

local function GetPandemicHost(button)
    local host = pandemicHosts[button]
    if host then return host end
    host = CreateFrame("Frame", nil, button)
    host:SetAllPoints(button)
    local base = button.borderHost and button.borderHost:GetFrameLevel() or button:GetFrameLevel()
    host:SetFrameLevel(base + 2) -- over the dispel border, under the text
    host:EnableMouse(false)
    host:Hide()
    pandemicHosts[button] = host
    return host
end

local function StylePandemic(button, style)
    if button.isBuff or button.groupKey ~= "debuffs" then return end
    local g = uuidb and uuidb.general or {}
    local on = g.nameplatepandemic ~= false
    local host = pandemicHosts[button]
    if not host then
        if not on then return end
        host = GetPandemicHost(button)
    end
    if on and not host.registered and button.AddPandemicRegion then
        if pcall(button.AddPandemicRegion, button, host) then host.registered = true end
    end

    local SB = UberUI.squareborders
    -- Hex string from the options' color swatch.
    local color = HexColor(g.nameplatepandemiccolor, nil) or HexColor(PANDEMIC_DEFAULT_COLOR)
    aurakit.StyleHighlight(host, {
        kind = on and (g.nameplatepandemicstyle or "border") or "none",
        r = color.r, g = color.g, b = color.b,
        square = style ~= "none" and SB and SB.IsEnabled(SQUARE_LOC),
        loc = SQUARE_LOC, icon = button.icon,
        ringFrom = button.borderHost,
        center = button, size = button.elementSize or ICON_SIZE,
    })
end

local function StyleButton(button)
    local g = uuidb and uuidb.general or {}
    local style = button.isBuff and (g.aurastyle_nameplatebuffs or "both") or (g.aurastyle_nameplatedebuffs or "zoom")
    local showDispel = g.nameplatebuffs_showdispel ~= false
    -- stealableRing: a thin white border on purgeable buffs (rounded, or
    -- square borders' white strips) instead of Blizzard's glow, which ran
    -- over the health bar.
    aurakit.ApplyAuraButtonStyle(button, {
        style = style,
        squareLoc = SQUARE_LOC,
        showDispel = showDispel,
        stealableRing = true,
    })
    pcall(StylePandemic, button, style)
    pcall(ApplyDurationText, button)
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
    return c
end

-- Returns true if the group was added.
local function AddGroup(c, key, filter, maxCount, isBuff, candidates, index)
    local options = {
        maxFrameCount = maxCount,
        initializeFrame = function(button)
            aurakit.InitAuraButton(c, button, key, isBuff, ICON_SIZE, false, StyleButton)
            AddDurationText(button)
        end,
        layout = aurakit.MakeGroupLayout(ICON_SIZE, SPACING, SPACING, false, index, true),
    }
    if candidates then options.candidateFilters = candidates end
    return (pcall(c.AddAuraGroup, c, key, filter, options))
end

local function BuildBundle()
    -- The template gives the holder the aspect it needs to anchor into a
    -- nameplate; it can only be given at creation.
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
        -- Client without the DISPELLABLE token: Blizzard's own isStealable
        -- rule (empty while aura data is secret, e.g. instanced PvP).
        dispellableToken = false
        AddGroup(b.buffs, "dispellable", "HELPFUL|INCLUDE_NAME_PLATE_ONLY|!IMPORTANT", BUFF_MAX, true,
            { isStealable = true }, 2)
    end

    b.cc = NewContainer(holder)
    AddGroup(b.cc, "cc", "HARMFUL|INCLUDE_NAME_PLATE_ONLY|CROWD_CONTROL", CC_MAX, false, nil, 1)
    AddGroup(b.cc, "showall", "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL", CC_MAX, false,
        { nameplateShowAll = true }, 2)

    -- Growth: debuffs up and to the right from the health bar's top-left;
    -- buffs leftward from beside the health bar; CC rightward.
    pcall(b.debuffs.SetFlowLayoutAnchorPoint, b.debuffs, "BOTTOMLEFT")
    pcall(b.debuffs.SetFlowLayoutGrowthDirection, b.debuffs, 1, 1)
    pcall(b.buffs.SetFlowLayoutAnchorPoint, b.buffs, "BOTTOMRIGHT")
    pcall(b.buffs.SetFlowLayoutGrowthDirection, b.buffs, -1, 1)
    pcall(b.cc.SetFlowLayoutAnchorPoint, b.cc, "BOTTOMLEFT")
    pcall(b.cc.SetFlowLayoutGrowthDirection, b.cc, 1, 1)
    local oneRow = 2 * (ICON_SIZE + SPACING)
    pcall(b.buffs.SetFlowLayoutMaximumLineSize, b.buffs, oneRow * 2)
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

-- Aura data is secret behind the loading screen, where the pool is built,
-- so the engine refuses aurakit's dispel-border registrations there. The
-- style pass retries them; run one per bundle, a bundle per frame, once the
-- world is up.
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

-- Per-unit filters, shown categories, scale and stride. Re-run whenever
-- Blizzard re-evaluates the plate (friend/enemy, player, CVars, aura scale).
local function Bind(b, unit)
    local aurasFrame = b.aurasFrame
    if not aurasFrame then return end
    local isFriend = UnitIsFriend("player", unit)

    -- Blizzard: debuffs on enemies must be yours; buffs on friends must be
    -- yours, and friends get no important/dispellable split.
    pcall(b.debuffs.SetAuraGroupFilterString, b.debuffs, "debuffs",
        isFriend and "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL"
        or "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL|PLAYER")
    pcall(b.buffs.SetAuraGroupFilterString, b.buffs, "important",
        isFriend and "HELPFUL|INCLUDE_NAME_PLATE_ONLY|PLAYER" or "HELPFUL|INCLUDE_NAME_PLATE_ONLY|IMPORTANT")
    pcall(b.buffs.SetAuraGroupMaxFrameCount, b.buffs, "dispellable", isFriend and 0 or BUFF_MAX)

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
    -- Debuffs lifted by the same gap: their borders draw outside the icon
    -- and the bottom row ran onto the health bar.
    pcall(place, b.debuffs, "BOTTOMLEFT", af.DebuffListFrame, 0, SIDE_GAP)
    pcall(place, b.buffs, "RIGHT", af.BuffListFrame, -SIDE_GAP)
    pcall(place, b.cc, "LEFT", af.CrowdControlListFrame, SIDE_GAP)
end

local QueueRebind

local function EnsureAurasFrameHooks(aurasFrame)
    if hookedAuras[aurasFrame] then return end
    hookedAuras[aurasFrame] = true
    -- UpdateShownState runs on unit/friend/player/simplified changes and
    -- every aura-display CVar change; UpdateAuraScale on aura scale changes.
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
        -- Deferred (we may be inside Blizzard's removal chain), and skipped
        -- if the plate already got a new bundle by then.
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

-- Options page: the on/off checkbox.
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

-- Options page: aura style / border / purgeable-highlight changes.
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
        -- Deferred out of Blizzard's OnNamePlateAdded chain. A token can be
        -- removed and re-added before this runs; the sequence number drops
        -- the stale attach.
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
        -- Behind the loading screen (~12 ms a bundle).
        GrowPool(POOL_SIZE)
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = arg1, arg2
        local _, instanceType = IsInInstance()
        if instanceType == "party" or instanceType == "raid" then
            -- M+ and raid trash pulls are the biggest plate counts; top up
            -- during the zoning screen.
            GrowPool(POOL_TARGET_INSTANCE)
        end
        if isLogin or isReload then QueueRestyleAll() end
    end
end)

UberUI.nameplateauras = nameplateauras
