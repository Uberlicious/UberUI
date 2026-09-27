local addon, ns = ...

-- Blizzard's swing timers (Blizzard_SwingTimer: main hand, off hand, ranged).
-- WoW Forever only -- retail 12.1 has no native swing timer.
--
-- Each bar (SwingTimerFrameTemplate) has a Border and a Background texture on
-- the frame and a StatusBar whose fill Blizzard sets once, in OnLoad
-- (SwingTimerMixin:InitializeBarPresentation), from a per-hand colored atlas
-- (frame.barTexture). Blizzard only ever changes the Border's ALPHA afterwards
-- (out-of-range dimming), so a vertex color and a fill texture set here
-- stick; no hooks are needed.
--
-- Custom bar textures are greyscale, so each hand gets its own fill color
-- (options color swatches). The fill texture object is retextured in place
-- -- not SetStatusBarTexture -- because Blizzard anchored the swing pip to it.

local swingtimers = {}
local retextured = setmetatable({}, { __mode = "k" }) -- fill texture -> true

local FRAMES = {
    { name = "SwingTimerMainHandFrame", colorField = "swingtimermainhandcolor", default = "ffffc21a" },
    { name = "SwingTimerOffHandFrame",  colorField = "swingtimeroffhandcolor",  default = "ff3d9eff" },
    { name = "SwingTimerRangedFrame",   colorField = "swingtimerrangedcolor",   default = "ff5cd65c" },
}
swingtimers.FRAMES = FRAMES

local function HexColor(hex, fallback)
    if type(hex) == "string" and hex:match("^%x%x%x%x%x%x%x%x$") then
        local ok, c = pcall(CreateColorFromHexString, hex)
        if ok and c then return c end
    end
    return fallback and HexColor(fallback) or nil
end

-- The custom texture in effect for swing timers, or nil for Blizzard's own.
-- Only the swing timers' own setting: they're timers, not health/power bars,
-- so the All Bars texture deliberately doesn't apply to them.
local function GetSwingTexture()
    local g = uuidb and uuidb.general
    if not (g and uuidb.statusbars) then return nil end
    if not (g.swingtimerbartextures and g.swingtimerbartexture ~= "Blizzard") then return nil end
    local tex = uuidb.statusbars[g.swingtimerbartexture]
    return type(tex) == "string" and tex or nil
end

-- Square border ("Swing Timer Border: Square"): four solid strips a whole
-- number of physical pixels thick around the bar, in the darkness color, over
-- a dark background of our own. Blizzard's rounded frame and background art
-- are cleared (texture set to nil) rather than faded: Blizzard sets their
-- alpha for out-of-range dimming (ApplyRangePresentation), and on a texture
-- the vertex color's alpha is the same value, so any fade got undone. It
-- never re-sets the art itself (only the XML does), so clearing sticks;
-- Rounded puts the atlases back. Our pieces are textures on the StatusBar,
-- whose alpha Blizzard dims along with its own, so dimming still applies.
local ART_ATLAS = { Border = "ui-swingtimerbar-frame", Background = "ui-swingtimerbar-background" }
local artCleared = setmetatable({}, { __mode = "k" }) -- texture -> true
local SQUARE_BG_ALPHA = 0.6
local squareParts = setmetatable({}, { __mode = "k" }) -- statusBar -> { bg, top, bottom, left, right }

local function NewPart(owner, layer, sublevel)
    local t = owner:CreateTexture(nil, layer, nil, sublevel)
    t:SetColorTexture(1, 1, 1, 1)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    return t
end

local function UpdateSquareBorder(frame, square, darken, dc)
    local bar = frame.StatusBar
    if not bar then return end
    local parts = squareParts[bar]
    if not square then
        if parts then
            for _, t in pairs(parts) do t:Hide() end
        end
        for key, atlas in pairs(ART_ATLAS) do
            local t = frame[key]
            if t and artCleared[t] then
                artCleared[t] = nil
                t:SetAtlas(atlas)
            end
        end
        return false
    end
    if not parts then
        parts = {
            bg = NewPart(bar, "BACKGROUND", -8),
            top = NewPart(bar, "ARTWORK", 7), bottom = NewPart(bar, "ARTWORK", 7),
            left = NewPart(bar, "ARTWORK", 7), right = NewPart(bar, "ARTWORK", 7),
        }
        squareParts[bar] = parts
    end
    for key in pairs(ART_ATLAS) do
        local t = frame[key]
        if t and not artCleared[t] then
            artCleared[t] = true
            t:SetTexture(nil)
        end
    end
    local px = tonumber(uuidb.general.swingtimersquareborder_thickness) or 1
    local SB = UberUI.squareborders
    local w = SB and SB.PixelsToUIUnits(bar, px) or px
    parts.bg:ClearAllPoints()
    parts.bg:SetAllPoints(bar)
    parts.top:ClearAllPoints()
    parts.top:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", -w, 0)
    parts.top:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", w, 0)
    parts.top:SetHeight(w)
    parts.bottom:ClearAllPoints()
    parts.bottom:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -w, 0)
    parts.bottom:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", w, 0)
    parts.bottom:SetHeight(w)
    parts.left:ClearAllPoints()
    parts.left:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
    parts.left:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 0, 0)
    parts.left:SetWidth(w)
    parts.right:ClearAllPoints()
    parts.right:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 0)
    parts.right:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 0, 0)
    parts.right:SetWidth(w)
    local r, g, b = 0, 0, 0
    if darken and dc then r, g, b = dc.r, dc.g, dc.b end
    for _, key in ipairs({ "top", "bottom", "left", "right" }) do
        parts[key]:SetVertexColor(r, g, b, 1)
    end
    parts.bg:SetVertexColor(0, 0, 0, SQUARE_BG_ALPHA)
    for _, t in pairs(parts) do t:Show() end
    return true
end

function swingtimers:Apply()
    local g = uuidb and uuidb.general
    if not g then return end
    local dc = g.darkencolor
    local darken = g.darkenswingtimers ~= false
    local tex = GetSwingTexture()

    for _, def in ipairs(FRAMES) do
        local frame = _G[def.name]
        if frame and not frame:IsForbidden() then
            if frame.Border then
                if darken and dc then
                    frame.Border:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                else
                    frame.Border:SetVertexColor(1, 1, 1, 1)
                end
            end
            -- After the border color above: square mode zeroes its alpha.
            UpdateSquareBorder(frame, g.swingtimersquareborder == true, darken, dc)

            local bar = frame.StatusBar
            -- "Swing Timer Label Shadow": the dark gradient behind the
            -- MAIN HAND / OFF HAND / RANGED label. Blizzard never touches it
            -- after load, so show/hide sticks.
            local shadow = bar and bar.TypeLabelShadow
            if shadow then shadow:SetShown(g.swingtimerlabelshadow ~= false) end

            local fill = bar and bar:GetStatusBarTexture()
            if fill then
                if tex then
                    fill:SetTexture(tex)
                    local c = HexColor(g[def.colorField], def.default)
                    fill:SetVertexColor(c.r, c.g, c.b, 1)
                    retextured[fill] = true
                elseif retextured[fill] then
                    -- Back to Blizzard's own per-hand atlas.
                    retextured[fill] = nil
                    if frame.barTexture then fill:SetAtlas(frame.barTexture) end
                    fill:SetVertexColor(1, 1, 1, 1)
                end
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_SwingTimer" and name ~= addon then return end
    if not (uuidb and uuidb.general) then return end
    swingtimers:Apply()
end)

UberUI.swingtimers = swingtimers
