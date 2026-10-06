local addon, ns = ...

-- Threat highlight style for compact party/raid frames
-- (uuidb.general.cufthreatstyle): Blizzard's stretched RaidFrame-AgroFrame
-- texture, or one of our own -- a thin border, an inner glow, corner marks, a
-- stripe along the top -- or none.
--
-- Blizzard's own aggroHighlight keeps doing the work: after its update
-- (CompactUnitFrame_UpdateAggroHighlight) we copy its shown state and color
-- onto our textures and fade it out. Threat can be secret in combat;
-- SetAlphaFromBoolean / SetVertexColor take secret values from addon code, so
-- they're passed straight through and never compared. Our textures are on
-- the frame itself, on aggroHighlight's own layer (ARTWORK 3), so the target
-- selection (OVERLAY) still draws on top; while the frame is selected they
-- move in to just inside the selection border (measured in game: 3px solid
-- + 1px blend), otherwise they sit at the frame edge.

local compactthreat = {}

local WHITE = "Interface\\Buttons\\WHITE8X8"
local TEX = "Interface\\AddOns\\Uber UI\\textures\\"
local EDGE_INSET = 1        -- px: unselected, just inside the frame edge
local SELECTION_INSET = 4   -- px: selected, inside Blizzard's selection border
local GLOW_SIZE = 8         -- px: how far the glow reaches in
local CORNER_SIZE = 10      -- px
local LAYER, SUBLEVEL = "ARTWORK", 3

local STYLES = { blizzard = true, border = true, glow = true, corners = true, stripe = true, hidden = true }

local widgets = setmetatable({}, { __mode = "k" }) -- frame -> { textures..., style }
local hooked = false

local function Style()
    local v = uuidb and uuidb.general and uuidb.general.cufthreatstyle
    return STYLES[v] and v or "blizzard"
end

local function Thickness()
    local n = tonumber(uuidb and uuidb.general and uuidb.general.cufthreatthickness) or 2
    return math.max(1, math.min(6, math.floor(n + 0.5)))
end

-- Party/raid members only (not arena frames or nameplates, which share the
-- CompactUnitFrame_* functions).
local function IsCompactGroupFrame(frame)
    if not frame or type(frame) ~= "table" or not frame.GetName then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    local name = frame:GetName()
    if not name then return false end
    return name:find("^CompactPartyFrameMember%d+$") ~= nil
        or name:find("^CompactRaidFrame%d+$") ~= nil
        or name:find("^CompactRaidGroup%d+Member%d+$") ~= nil
end

local function Px(frame, n)
    return UberUI.squareborders.PixelsToUIUnits(frame, n)
end

-- Selection isn't secret, but if it ever were, stay clear of it.
local function InsetPixels(frame)
    local sel = frame.selectionHighlight
    if not sel then return EDGE_INSET end
    local ok, shown = pcall(sel.IsShown, sel)
    if not ok or UberUI.util.IsSecret(shown) or shown then return SELECTION_INSET end
    return EDGE_INSET
end

local function NewTexture(frame, file)
    local t = frame:CreateTexture(nil, LAYER, nil, SUBLEVEL)
    t:SetTexture(file)
    t:SetTexelSnappingBias(0)
    t:SetSnapToPixelGrid(false)
    t:Hide()
    return t
end

local function GetWidgets(frame)
    local w = widgets[frame]
    if w then return w end
    w = {
        edges = { NewTexture(frame, WHITE), NewTexture(frame, WHITE), NewTexture(frame, WHITE), NewTexture(frame, WHITE) },
        glows = {
            NewTexture(frame, TEX .. "threatglow-h"), NewTexture(frame, TEX .. "threatglow-h"),
            NewTexture(frame, TEX .. "threatglow-v"), NewTexture(frame, TEX .. "threatglow-v"),
        },
        corners = {
            NewTexture(frame, TEX .. "threatcorner"), NewTexture(frame, TEX .. "threatcorner"),
            NewTexture(frame, TEX .. "threatcorner"), NewTexture(frame, TEX .. "threatcorner"),
        },
    }
    widgets[frame] = w
    return w
end

local function HideAll(w)
    for _, list in ipairs({ w.edges, w.glows, w.corners }) do
        for _, t in ipairs(list) do t:Hide() end
    end
end

-- Positions the chosen style's textures and returns them (the ones to show).
local function Layout(frame, w, style, insetPx)
    local inset = Px(frame, insetPx)
    local t = Px(frame, Thickness())
    local shown = {}

    if style == "border" or style == "stripe" then
        local top, bottom, left, right = w.edges[1], w.edges[2], w.edges[3], w.edges[4]
        top:ClearAllPoints()
        top:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
        top:SetHeight(t)
        shown[#shown + 1] = top
        if style == "border" then
            bottom:ClearAllPoints()
            bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
            bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
            bottom:SetHeight(t)
            -- Sides run between top and bottom so corners aren't drawn twice.
            left:ClearAllPoints()
            left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
            left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
            left:SetWidth(t)
            right:ClearAllPoints()
            right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
            right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
            right:SetWidth(t)
            shown[#shown + 1] = bottom
            shown[#shown + 1] = left
            shown[#shown + 1] = right
        end
    elseif style == "glow" then
        local g = Px(frame, GLOW_SIZE)
        local left, right, top, bottom = w.glows[1], w.glows[2], w.glows[3], w.glows[4]
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
        left:SetWidth(g)
        left:SetTexCoord(0, 1, 0, 1)
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
        right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
        right:SetWidth(g)
        right:SetTexCoord(1, 0, 0, 1)
        top:ClearAllPoints()
        top:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
        top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
        top:SetHeight(g)
        top:SetTexCoord(0, 1, 0, 1)
        bottom:ClearAllPoints()
        bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset)
        bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
        bottom:SetHeight(g)
        bottom:SetTexCoord(0, 1, 1, 0)
        shown = { left, right, top, bottom }
    elseif style == "corners" then
        local c = Px(frame, CORNER_SIZE)
        local spots = {
            { "TOPLEFT", inset, -inset, 0, 1, 0, 1 },
            { "TOPRIGHT", -inset, -inset, 1, 0, 0, 1 },
            { "BOTTOMLEFT", inset, inset, 0, 1, 1, 0 },
            { "BOTTOMRIGHT", -inset, inset, 1, 0, 1, 0 },
        }
        for i, s in ipairs(spots) do
            local tex = w.corners[i]
            tex:ClearAllPoints()
            tex:SetPoint(s[1], frame, s[1], s[2], s[3])
            tex:SetSize(c, c)
            tex:SetTexCoord(s[4], s[5], s[6], s[7])
            shown[#shown + 1] = tex
        end
    end
    return shown
end

-- Copies Blizzard's highlight state onto ours (or hands it back).
local function Apply(frame)
    local ah = frame.aggroHighlight
    if not ah then return end
    local style = Style()
    local w = widgets[frame]

    if style == "blizzard" then
        if w then HideAll(w) w.style = nil end
        ah:SetAlpha(1)
        return
    end

    ah:SetAlpha(0)
    if style == "hidden" then
        if w then HideAll(w) w.style = nil end
        return
    end

    w = GetWidgets(frame)
    local insetPx = InsetPixels(frame)
    local key = style .. "|" .. Thickness() .. "|" .. insetPx
    if w.style ~= key then
        HideAll(w)
        w.shown = Layout(frame, w, style, insetPx)
        w.style = key
    end

    -- Possibly secret: passed straight through, never compared.
    local isShown = ah:IsShown()
    local r, g, b = ah:GetVertexColor()
    for _, tex in ipairs(w.shown) do
        tex:SetVertexColor(r, g, b, 1)
        tex:SetAlphaFromBoolean(isShown)
        tex:Show()
    end
end

-- Options preview: draws the current style on a mock frame (any Frame), in
-- the given threat color, the same way as on the real ones.
function compactthreat.DrawPreview(frame, r, g, b)
    local style = Style()
    local w = GetWidgets(frame)
    if not w.blizz then
        w.blizz = frame:CreateTexture(nil, LAYER, nil, SUBLEVEL)
        w.blizz:SetAtlas("RaidFrame-AgroFrame")
        w.blizz:SetAllPoints(frame)
    end
    HideAll(w)
    w.blizz:Hide()
    w.style = nil
    if style == "hidden" then return end
    if style == "blizzard" then
        w.blizz:SetVertexColor(r, g, b, 1)
        w.blizz:Show()
        return
    end
    for _, tex in ipairs(Layout(frame, w, style, InsetPixels(frame))) do
        tex:SetVertexColor(r, g, b, 1)
        tex:SetAlpha(1)
        tex:Show()
    end
end

local function ForEachGroupFrame(fn)
    for i = 1, 5 do
        local f = _G["CompactPartyFrameMember" .. i]
        if f then fn(f) end
    end
    for i = 1, 80 do
        local f = _G["CompactRaidFrame" .. i]
        if f then fn(f) end
    end
    for g = 1, 8 do
        for m = 1, 5 do
            local f = _G["CompactRaidGroup" .. g .. "Member" .. m]
            if f then fn(f) end
        end
    end
end

-- Installed only once a non-Blizzard style is picked (a hook can't be
-- removed). Deferred out of Blizzard's update chain.
local function EnsureHook()
    if hooked or not CompactUnitFrame_UpdateAggroHighlight then return end
    hooked = true
    local function Queue(frame)
        if not IsCompactGroupFrame(frame) then return end
        C_Timer.After(0, function()
            if IsCompactGroupFrame(frame) then pcall(Apply, frame) end
        end)
    end
    hooksecurefunc("CompactUnitFrame_UpdateAggroHighlight", Queue)
    -- Target changes: the inset follows the selection border.
    if CompactUnitFrame_UpdateSelectionHighlight then
        hooksecurefunc("CompactUnitFrame_UpdateSelectionHighlight", Queue)
    end
end

-- Login and the options' style / thickness controls.
function compactthreat:Refresh()
    if Style() ~= "blizzard" then EnsureHook() end
    -- With Blizzard's style and no hook yet, nothing of ours exists.
    if not hooked then return end
    ForEachGroupFrame(function(frame)
        if IsCompactGroupFrame(frame) then pcall(Apply, frame) end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() compactthreat:Refresh() end)

UberUI.compactthreat = compactthreat
