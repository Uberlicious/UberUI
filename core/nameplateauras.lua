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
local SPACING = 3                         -- 22 + 3 = Blizzard's 25px pitch
-- Extra gap from the health bar: our borders draw outside the icon.
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

local IsSecret = UberUI.util.IsSecret

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

-- Duration text in Blizzard's nameplate look. The duration is secret, so the
-- engine formats it (whole seconds, rounded up) and colors it from a step
-- curve on the remaining time: expiring color up to the threshold, normal up
-- to 60 s, transparent above (Blizzard shows no number over a minute). The
-- curve is copied at registration, so settings changes re-register.
local function DurationSettings()
    local g = uuidb and uuidb.general or {}
    local threshold = tonumber(g.nameplatedurationthreshold) or 5
    if threshold < 0 then threshold = 0 end
    return g.nameplatedurationcolor or "ffffffff", g.nameplatedurationexpiringcolor or "ffff3333", threshold
end

local function HexColor(hex, fallback)
    return UberUI.util.HexColor(hex) or fallback
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

-- Pandemic highlight on debuffs: the engine shows the region
-- (AddPandemicRegion) only inside the refresh window and while data is
-- secret; its shown state is secret to us, so we only style its children.
local PANDEMIC_DEFAULT_COLOR = "ffff3030"
local pandemicHosts = setmetatable({}, { __mode = "k" }) -- button -> host frame

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

    host:HookScript("OnShow", function()
        HideDebuffBorders(button)
        local SB = UberUI.squareborders
        if host.uuSquare and button.icon and SB then
            SB.LayoutDispelFor(host.uuSquare, button.icon, SQUARE_LOC)
            local g = uuidb and uuidb.general or {}
            local color = HexColor(g.nameplatepandemiccolor, nil) or HexColor(PANDEMIC_DEFAULT_COLOR)
            SB.SetColor(host.uuSquare, color.r, color.g, color.b, 1)
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
    pcall(ApplyDurationText, button)
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
