-- Debug-only diagnostic for the Cooldown Manager "Centered" alignment
-- intermittently reverting on target swaps/procs/aura changes. Watches
-- Blizzard's own layout entry points (viewer:RefreshLayout, the item
-- container's :Layout, and each item frame's Show/Hide) plus the events
-- that seem to trigger it, and records a timestamped snapshot of each
-- active item's actual anchor point -- "CENTER" means our custom layout
-- last touched it, anything else (TOPLEFT etc.) means Blizzard's own grid
-- layout won the race and re-flowed it. Not wired into any saved setting;
-- purely a live diagnostic, toggled with /uicdmdebug.
local addon, ns = ...

local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local ALIGN_FIELDS = {
    EssentialCooldownViewer = "essential_align",
    UtilityCooldownViewer   = "utility_align",
    BuffIconCooldownViewer  = "bufficon_align",
    BuffBarCooldownViewer   = "buffbar_align",
}

local function GetAlignSetting(name)
    local field = ALIGN_FIELDS[name]
    local v = field and uuidb and uuidb.cooldown and uuidb.cooldown[field]
    if v == "pack" or v == "center" or v == "blizzard" then return v end
    return "blizzard"
end

local watching = false
local log = {}
local MAX_LOG = 800

local function Record(fmt, ...)
    if not watching then return end
    log[#log + 1] = string.format("%.3f  " .. fmt, GetTime(), ...)
    if #log > MAX_LOG then table.remove(log, 1) end
end

-- Primary anchor of each active item, in pool order: reveals who last
-- positioned them ("CENTER" = us, anything else = Blizzard's grid) and, via
-- the offsets, exactly how far apart the two layouts are.
local function DescribeAnchors(viewer)
    local pool = viewer and viewer.itemFramePool
    if not pool or not pool.EnumerateActive then return "?", 0 end
    local n, parts = 0, {}
    for f in pool:EnumerateActive() do
        n = n + 1
        local ok, point, _rel, _relPoint, x, y = pcall(f.GetPoint, f, 1)
        if ok and point and type(x) == "number" and type(y) == "number" then
            parts[#parts + 1] = string.format("%s[%.0f,%.0f]%s", point, x, y, f:IsShown() and "" or "(hidden)")
        else
            parts[#parts + 1] = (ok and point) or "?"
        end
    end
    return table.concat(parts, " "), n
end

local hookedViewer = setmetatable({}, { __mode = "k" })
local hookedContainer = setmetatable({}, { __mode = "k" })
local hookedItem = setmetatable({}, { __mode = "k" })

local function EnsureItemHook(name, item)
    if not item or hookedItem[item] then return end
    hookedItem[item] = true
    item:HookScript("OnShow", function()
        Record("%-22s ItemShow", name)
    end)
    item:HookScript("OnHide", function()
        Record("%-22s ItemHide", name)
    end)
    -- The item's own state transitions, i.e. what cooldownmanager.lua now
    -- reacts to. Logged here so the ordering against Container.Layout and
    -- our queue/apply lines is visible.
    for _, method in ipairs({ "OnActiveStateChanged", "OnUnitAuraAddedEvent", "OnUnitAuraRemovedEvent",
        "RefreshData", "RefreshSpellCooldown" }) do
        if item[method] then
            pcall(hooksecurefunc, item, method, function()
                Record("%-22s item:%s", name, method)
            end)
        end
    end
end

local function EnsureViewerHooks(name)
    local viewer = _G[name]
    if not viewer then return end

    if not hookedViewer[viewer] and viewer.RefreshLayout then
        hookedViewer[viewer] = true
        hooksecurefunc(viewer, "RefreshLayout", function(self)
            local anchors, n = DescribeAnchors(self)
            Record("%-22s RefreshLayout    align=%-8s count=%d anchors=%s", name, GetAlignSetting(name), n, anchors)
        end)
    end

    local ok, container = pcall(viewer.GetItemContainerFrame, viewer)
    if ok and container and not hookedContainer[container] and container.Layout then
        hookedContainer[container] = true
        hooksecurefunc(container, "Layout", function()
            local anchors, n = DescribeAnchors(viewer)
            Record("%-22s Container.Layout align=%-8s count=%d anchors=%s", name, GetAlignSetting(name), n, anchors)
        end)
    end

    if viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
        for f in viewer.itemFramePool:EnumerateActive() do
            EnsureItemHook(name, f)
        end
    end
end

local function SnapshotAll(tag)
    for _, name in ipairs(VIEWERS) do
        EnsureViewerHooks(name)
        local viewer = _G[name]
        if viewer then
            local anchors, n = DescribeAnchors(viewer)
            Record("%-22s %-16s align=%-8s count=%d anchors=%s", name, tag, GetAlignSetting(name), n, anchors)
        end
    end
end

-- Plain events (no unit filter).
local WATCH_EVENTS = {
    "PLAYER_TARGET_CHANGED",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
    "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
    "SPELL_UPDATE_COOLDOWN",
    "SPELL_UPDATE_USABLE",
    "SPELL_UPDATE_CHARGES",
    "ACTIONBAR_UPDATE_COOLDOWN",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",
}

-- Unit events, filtered to the player: casting is what the "splits" happen on.
local WATCH_UNIT_EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_EMPOWER_START",
    "UNIT_SPELLCAST_EMPOWER_STOP",
    "UNIT_AURA",
}

local watcher = CreateFrame("Frame")
watcher:SetScript("OnEvent", function(self, event, unit, _castGUID, spellID)
    if not watching then return end
    local tag = "event:" .. event
    if spellID then tag = tag .. ":" .. tostring(spellID) end
    SnapshotAll(tag)
end)

local function StartWatching()
    if watching then return end
    watching = true
    for _, e in ipairs(WATCH_EVENTS) do pcall(watcher.RegisterEvent, watcher, e) end
    for _, e in ipairs(WATCH_UNIT_EVENTS) do pcall(watcher.RegisterUnitEvent, watcher, e, "player", "target") end
    -- Our own side of the story: cooldownmanager.lua reports queue/apply here.
    UberUI.cdmDebugLog = Record
    SnapshotAll("watch-start")

    local found = {}
    for _, name in ipairs(VIEWERS) do
        if _G[name] then found[#found + 1] = name end
    end
    print("|cff33ff99Uber UI|r: CDM debug watch ON. /uicdmdebug show to view, off to stop, clear to wipe the log.")
    if #found == 0 then
        print("|cff33ff99Uber UI|r: CDM debug: none of the 4 viewer frames exist yet (Blizzard_CooldownViewer not loaded) -- open the Cooldown Manager once (Edit Mode, or let it show in combat) then run /uicdmdebug on again.")
    else
        print("|cff33ff99Uber UI|r: CDM debug: watching " .. table.concat(found, ", "))
    end
end

local function StopWatching()
    if not watching then return end
    watching = false
    UberUI.cdmDebugLog = nil
    watcher:UnregisterAllEvents()
    print("|cff33ff99Uber UI|r: CDM debug watch OFF.")
end

-------------------------------------------------------------------------------
-- Editbox report window
-------------------------------------------------------------------------------

local reportFrame

local function EnsureReportFrame()
    if reportFrame then return reportFrame end

    local f = CreateFrame("Frame", "UberUIDebugReport", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(700, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetFrameStrata("DIALOG")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.TitleText then f.TitleText:SetText("Uber UI - CDM Debug Log") end

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -32)
    scroll:SetPoint("BOTTOMRIGHT", -32, 40)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(630)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)
    f.editBox = edit

    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(90, 22)
    clearBtn:SetPoint("BOTTOMLEFT", 12, 10)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        wipe(log)
        f.editBox:SetText("")
    end)

    reportFrame = f
    return f
end

-- Shared by every Uber UI debug command: dumps go in a copyable edit box,
-- never to chat. `lines` is a table of strings or a single string.
function UberUI.ShowDebugReport(title, lines)
    local f = EnsureReportFrame()
    if f.TitleText then f.TitleText:SetText(title or "Uber UI - Debug") end
    f.editBox:SetText(type(lines) == "table" and table.concat(lines, "\n") or tostring(lines))
    f.editBox:HighlightText()
    f:Show()
end

local function ShowReport()
    local f = EnsureReportFrame()
    if f.TitleText then f.TitleText:SetText("Uber UI - CDM Debug Log") end
    if #log == 0 then
        f.editBox:SetText(watching
            and "(no events captured yet -- trigger a target swap, proc, or aura change, then run /uicdmdebug show again)"
            or "(watch is OFF and the log is empty -- run /uicdmdebug on first)")
    else
        f.editBox:SetText(table.concat(log, "\n"))
    end
    f.editBox:HighlightText()
    f:Show()
end

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------

SLASH_UBERUICDMDEBUG1 = "/uicdmdebug"
SlashCmdList["UBERUICDMDEBUG"] = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "on" then
        StartWatching()
    elseif msg == "off" then
        StopWatching()
    elseif msg == "clear" then
        wipe(log)
        print("|cff33ff99Uber UI|r: CDM debug log cleared.")
    elseif msg == "show" or msg == "" then
        ShowReport()
    else
        print("|cff33ff99Uber UI|r: /uicdmdebug on|off|show|clear")
    end
end
