local addon, ns = ...

-- /uuidebuggamepad: lists WoW Forever's gamepad UI so it can be darkened
-- (dev tool; remove before release like the profiler).
--
--   /uuidebuggamepad                    which gamepad addons are loaded, and
--                                       every global gamepad frame
--   /uuidebuggamepad <frame> [depth]    tree of that frame: child frames and
--                                       their textures (atlas/file, layer,
--                                       vertex color). <frame> may be a
--                                       dotted path (Frame.Key.Key);
--                                       depth defaults to 3.
--
-- Gamepad addons are Forever-only except SmartNavigation/SharedUtility
-- (wow-ui-source origin/forever .tocs).

local IsSecret = UberUI.util.IsSecret

local GAMEPAD_ADDONS = {
    "Blizzard_Gamepad", "Blizzard_GamepadActionBars", "Blizzard_GamepadSharedUtility",
    "Blizzard_GamepadSmartNavigation", "Blizzard_GamepadSoftCursor", "Blizzard_GamepadTargeting",
}
-- Global name patterns for the frames those addons create.
local NAME_PATTERNS = { "Gamepad", "SmartNavigation", "SoftCursor", "RaidTargeting" }
local MAX_LINES = 4000

local function S(v)
    if IsSecret(v) then return "<secret>" end
    return tostring(v)
end

local function Call(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return false end
    return pcall(fn, obj, ...)
end

local function IsUIObject(v)
    return type(v) == "table" and type(rawget(v, 0)) == "userdata" and type(v.GetObjectType) == "function"
end

local function Num(v)
    if IsSecret(v) or type(v) ~= "number" then return S(v) end
    return string.format("%.2f", v)
end

-- The parentKey a child is stored under on its parent, if any.
local function KeyOn(parent, child)
    if type(parent) ~= "table" then return nil end
    for k, v in pairs(parent) do
        if v == child and type(k) == "string" then return k end
    end
end

local function Label(obj, parent)
    local _, name = Call(obj, "GetName")
    local key = KeyOn(parent, obj)
    local _, objType = Call(obj, "GetObjectType")
    local parts = { S(objType) }
    if key then parts[#parts + 1] = "." .. key end
    if name and not IsSecret(name) then parts[#parts + 1] = "\"" .. name .. "\"" end
    return table.concat(parts, " ")
end

local function DescribeTexture(tex, parent)
    local _, layer, sub = Call(tex, "GetDrawLayer")
    local _, atlas = Call(tex, "GetAtlas")
    local _, file = Call(tex, "GetTexture")
    local _, r, g, b, a = Call(tex, "GetVertexColor")
    local _, shown = Call(tex, "IsShown")
    local _, alpha = Call(tex, "GetAlpha")
    local art = (atlas and not IsSecret(atlas)) and ("atlas=" .. atlas) or ("file=" .. S(file))
    return string.format("%s  %s  layer=%s/%s  color=%s,%s,%s,%s  alpha=%s  shown=%s",
        Label(tex, parent), art, S(layer), S(sub), Num(r), Num(g), Num(b), Num(a), Num(alpha), S(shown))
end

local function BuildTree(root, maxDepth)
    local lines = {}
    local function add(s)
        if #lines < MAX_LINES then lines[#lines + 1] = s
        elseif #lines == MAX_LINES then lines[#lines + 1] = "... (truncated)" end
    end

    local function walk(frame, parent, depth)
        local indent = string.rep("  ", depth)
        local _, forbidden = Call(frame, "IsForbidden")
        if forbidden == true then
            add(indent .. Label(frame, parent) .. "  <forbidden>")
            return
        end
        local _, shown = Call(frame, "IsShown")
        local _, visible = Call(frame, "IsVisible")
        local _, w, h = Call(frame, "GetSize")
        local _, strata = Call(frame, "GetFrameStrata")
        local _, level = Call(frame, "GetFrameLevel")
        add(string.format("%s%s  shown=%s visible=%s size=%sx%s strata=%s level=%s",
            indent, Label(frame, parent), S(shown), S(visible), Num(w), Num(h), S(strata), S(level)))

        local okR, regions = pcall(function() return { frame:GetRegions() } end)
        if okR then
            for _, region in ipairs(regions) do
                local _, isTex = Call(region, "IsObjectType", "Texture")
                if isTex == true then
                    add(indent .. "  - " .. DescribeTexture(region, frame))
                end
            end
        end

        if depth >= maxDepth then
            local okC, kids = pcall(function() return { frame:GetChildren() } end)
            if okC and #kids > 0 then add(indent .. "  (" .. #kids .. " child frames below max depth)") end
            return
        end
        local okC, kids = pcall(function() return { frame:GetChildren() } end)
        if okC then
            for _, child in ipairs(kids) do walk(child, frame, depth + 1) end
        end
    end

    walk(root, nil, 0)
    return table.concat(lines, "\n")
end

local function BuildSummary()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    add("Forever client = " .. tostring(UberUI.util.IsForeverClient and UberUI.util.IsForeverClient()))
    add("---- gamepad addons ----")
    for _, name in ipairs(GAMEPAD_ADDONS) do
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded(name)
        add(string.format("  %s loaded=%s", name, tostring(loaded)))
    end

    add("")
    add("---- global gamepad frames (/uuidebuggamepad <name> for a tree) ----")
    local found = {}
    for name, v in pairs(_G) do
        if type(name) == "string" and IsUIObject(v) then
            for _, pattern in ipairs(NAME_PATTERNS) do
                if name:find(pattern, 1, true) then
                    found[#found + 1] = name
                    break
                end
            end
        end
    end
    table.sort(found)
    for _, name in ipairs(found) do
        local obj = _G[name]
        local _, objType = Call(obj, "GetObjectType")
        local _, shown = Call(obj, "IsShown")
        local _, parent = Call(obj, "GetParent")
        local _, parentName = Call(parent, "GetName")
        local okC, kids = pcall(function() return { obj:GetChildren() } end)
        add(string.format("  %s  %s  shown=%s parent=%s children=%s", name, S(objType), S(shown),
            parentName and S(parentName) or tostring(parent and "<unnamed>" or nil),
            okC and tostring(#kids) or "?"))
    end
    if #found == 0 then add("  (none -- not the Forever client, or gamepad UI not loaded)") end
    return table.concat(lines, "\n")
end

-- "Frame.Key.Key" -> object.
local function Resolve(path)
    local obj
    for part in path:gmatch("[^%.]+") do
        if obj == nil then obj = _G[part] else obj = type(obj) == "table" and obj[part] or nil end
        if obj == nil then return nil end
    end
    return obj
end

SLASH_UUIDEBUGGAMEPAD1 = "/uuidebuggamepad"
SlashCmdList["UUIDEBUGGAMEPAD"] = function(msg)
    local path, depth = (msg or ""):match("^%s*(%S*)%s*(%d*)")
    local ok, report
    if path == "" then
        ok, report = pcall(BuildSummary)
    else
        local root = Resolve(path)
        if not IsUIObject(root) then
            report = "No frame at '" .. path .. "'."
            ok = true
        else
            ok, report = pcall(BuildTree, root, tonumber(depth) or 3)
            if ok then report = "==== " .. path .. " ====\n" .. report end
        end
    end
    if not ok then report = "ERROR building gamepad report: " .. tostring(report) end
    UberUI.ShowDebugReport(report)
end
