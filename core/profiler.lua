-- /uuprofile: per-feature Lua timing, for tracking down frame rate drops.
--
-- Off until started; while off, a wrapped function costs one flag check.
-- Only measures our own Lua: engine work our frames cause (aura containers
-- re-filtering, layout, masks) doesn't show up here, which is why the report
-- also tracks frame rate -- compare a run with a feature on against one with
-- it off.
--
--   /uuprofile [secs]   profile for 30 s (or secs), then show the report;
--                       typed again mid-run, stops early
--   /uuprofile report   show the report so far without stopping
--   /uuprofile npauras normal|none|enemies|nounit [secs]
--                       switch nameplate aura test mode (core/nameplateauras.lua)
--                       and start a run

local addon, ns = ...
local profiler = { on = false }

local debugprofilestop = debugprofilestop
local stats = {}  -- label -> { n, total, max } (ms)
local counts = {} -- label -> n
local elapsed, frames, worstFrame = 0, 0, 0

local function Record(label, t0, ...)
    local dt = debugprofilestop() - t0
    local s = stats[label]
    if not s then
        s = { n = 0, total = 0, max = 0 }
        stats[label] = s
    end
    s.n = s.n + 1
    s.total = s.total + dt
    if dt > s.max then s.max = dt end
    return ...
end

-- Wraps fn so its calls are timed under `label` while profiling is on.
-- Time is inclusive: a wrapped function that calls another counts both.
function profiler.Wrap(label, fn)
    return function(...)
        if not profiler.on then return fn(...) end
        return Record(label, debugprofilestop(), fn(...))
    end
end

-- Counts an occurrence (an event, a queued update) while profiling is on.
function profiler.Count(label)
    if profiler.on then counts[label] = (counts[label] or 0) + 1 end
end

-- Frame rate over the run: average from frame count, plus the worst frame.
local ticker = CreateFrame("Frame")
ticker:Hide()
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    frames = frames + 1
    if dt > worstFrame then worstFrame = dt end
end)

local DEFAULT_SECONDS = 30
local stopTimer

local function Stop()
    profiler.on = false
    ticker:Hide()
    if stopTimer then
        stopTimer:Cancel()
        stopTimer = nil
    end
end

-- Report is defined below; the timer only needs it once it fires.
local Report

local function Start(seconds)
    Stop()
    wipe(stats)
    wipe(counts)
    elapsed, frames, worstFrame = 0, 0, 0
    profiler.on = true
    ticker:Show()
    stopTimer = C_Timer.NewTimer(seconds, function()
        stopTimer = nil
        Stop()
        local ok, err = pcall(Report)
        if not ok then UberUI:ReportError("profiler report", err) end
    end)
    UIErrorsFrame:AddMessage(("Uber UI profiling for %d s -- the report opens when it's done"):format(seconds), 0.2, 1, 0.6)
end

local function AddOnMetrics(lines)
    local P, M = C_AddOnProfiler, Enum.AddOnProfilerMetric
    if not (P and M and P.GetAddOnMetric) then return end
    if P.IsEnabled and not P.IsEnabled() then
        lines[#lines + 1] = "Blizzard addon profiler: disabled"
        return
    end
    local function get(fn, ...)
        local ok, v = pcall(fn, ...)
        return ok and tonumber(v) or 0
    end
    lines[#lines + 1] = ("Blizzard addon profiler (ms per frame) -- Uber UI: recent %.3f, session %.3f, peak %.2f; frames over 5 ms: %d"):format(
        get(P.GetAddOnMetric, addon, M.RecentAverageTime),
        get(P.GetAddOnMetric, addon, M.SessionAverageTime),
        get(P.GetAddOnMetric, addon, M.PeakTime),
        get(P.GetAddOnMetric, addon, M.CountTimeOver5Ms))
    lines[#lines + 1] = ("  all addons: recent %.3f; whole game: recent %.3f"):format(
        get(P.GetOverallMetric, M.RecentAverageTime),
        get(P.GetApplicationMetric, M.RecentAverageTime))
end

function Report()
    local secs = math.max(elapsed, 0.001)
    local plates = #(C_NamePlate.GetNamePlates() or {})
    local lines = {
        ("Uber UI profile: %.1f s%s, %d nameplates now visible"):format(
            secs, profiler.on and " (still running)" or "", plates),
        ("Frame rate: %.1f average, worst frame %.1f ms"):format(frames / secs, worstFrame * 1000),
    }
    local npa = UberUI.nameplateauras
    local g = uuidb and uuidb.general or {}
    lines[#lines + 1] = ("Nameplate auras: %s (test mode %s); Friendly Name Health: %s"):format(
        g.nameplateauras and "on" or "off", npa and npa.GetTestMode and npa:GetTestMode() or "?",
        tostring(g.namehealthstyle or "off"))
    AddOnMetrics(lines)

    local labels, totalMs = {}, 0
    for label, s in pairs(stats) do
        labels[#labels + 1] = label
        totalMs = totalMs + s.total
    end
    table.sort(labels, function(a, b) return stats[a].total > stats[b].total end)

    lines[#lines + 1] = ""
    lines[#lines + 1] = ("Timed (inclusive; nested calls count twice): %.2f ms/s, %.3f ms per frame"):format(
        totalMs / secs, totalMs / math.max(frames, 1))
    lines[#lines + 1] = ("%-34s %8s %8s %10s %9s %8s"):format("function", "calls", "per sec", "total ms", "avg ms", "max ms")
    for _, label in ipairs(labels) do
        local s = stats[label]
        lines[#lines + 1] = ("%-34s %8d %8.1f %10.2f %9.4f %8.3f"):format(
            label, s.n, s.n / secs, s.total, s.total / s.n, s.max)
    end

    local names = {}
    for label in pairs(counts) do names[#names + 1] = label end
    if #names > 0 then
        table.sort(names, function(a, b) return counts[a] > counts[b] end)
        lines[#lines + 1] = ""
        lines[#lines + 1] = ("%-34s %8s %8s"):format("counter", "count", "per sec")
        for _, label in ipairs(names) do
            lines[#lines + 1] = ("%-34s %8d %8.1f"):format(label, counts[label], counts[label] / secs)
        end
    end

    UberUI.ShowDebugReport(table.concat(lines, "\n"))
end

SLASH_UUPROFILE1 = "/uuprofile"
SlashCmdList.UUPROFILE = function(msg)
    msg = strtrim(msg or ""):lower()
    local mode, modeSecs = msg:match("^npauras%s+(%a+)%s*(%d*)$")
    local secs = tonumber(msg:match("^(%d+)$"))
    if mode then
        local npa = UberUI.nameplateauras
        if npa and npa.SetTestMode and npa:SetTestMode(mode) then
            Start(tonumber(modeSecs) or DEFAULT_SECONDS)
        else
            UIErrorsFrame:AddMessage("Unknown mode -- normal, none, enemies or nounit", 1, 0.3, 0.3)
        end
    elseif msg == "report" then
        Report()
    elseif profiler.on then
        -- Typed again mid-run: stop early.
        Stop()
        Report()
    else
        Start(secs or DEFAULT_SECONDS)
    end
end

UberUI.profiler = profiler
