-- Friendly name health: shows friendly player health around their name on
-- Blizzard's nameplates (name-only plates in the open world / cities;
-- Blizzard locks friendly plates in instances). Ported from NameHealthColor.
--
-- Styles: "underline" (thin health bar under the name), "dot" (small dot
-- beside the name), "name" (tints the name text; full health = class color).
--
-- Health is a secret value, so all color logic lives in curves evaluated by
-- UnitHealthPercent. Hooks and events are only installed while the feature
-- is on, and every write is deferred out of Blizzard's update chain.

local addon, ns = ...
local namehealth = {}

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FULL_STEP = 0.995 -- above this counts as "full" when hiding at full

-- All in screen pixels.
local UNDERLINE_GAP = 1   -- space between name and bar
local UNDERLINE_INSET = 2 -- screen pixels trimmed off each end
local DOT_GAP = 3

-- Health color curve: health (0 to 1), then R, G, B. The "name" style swaps
-- the 100% point for the unit's class color.
local POINTS = {
    { 0.00, 1.0, 0.1, 0.1 }, -- red
    { 0.35, 1.0, 0.5, 0.0 }, -- orange
    { 0.65, 1.0, 1.0, 0.2 }, -- yellow
    { 1.00, 0.1, 1.0, 0.1 }, -- green
}

local function Settings()
    return uuidb and uuidb.general
end

local function Style()
    local g = Settings()
    local s = g and g.namehealthstyle
    return (s == "underline" or s == "dot" or s == "name") and s or nil
end

local function UnderlineAbove()
    local g = Settings()
    return g and g.namehealthunderlineside == "ABOVE"
end

-- Gap between name and bar: the base gap plus the Underline Offset setting
-- (screen pixels; negative tucks the bar into the text's outline).
local function UnderlineGap(px)
    local g = Settings()
    return (UNDERLINE_GAP + (tonumber(g and g.namehealthunderlineoffset) or 0)) * px
end

local function DotSide()
    local g = Settings()
    local v = g and g.namehealthdotside
    return (v == "RIGHT" or v == "TOP" or v == "BOTTOM") and v or "LEFT"
end

-- Gap between name and dot: the base gap plus the Dot Offset setting.
local function DotGap(px)
    local g = Settings()
    return (DOT_GAP + (tonumber(g and g.namehealthdotoffset) or 0)) * px
end

-- Anchors a dot on `side` of `anchor` (the name's text box).
local function PlaceDot(dot, anchor, px)
    local side, gap = DotSide(), DotGap(px)
    dot:ClearAllPoints()
    if side == "RIGHT" then
        dot:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
    elseif side == "TOP" then
        dot:SetPoint("BOTTOM", anchor, "TOP", 0, gap)
    elseif side == "BOTTOM" then
        dot:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
    else
        dot:SetPoint("RIGHT", anchor, "LEFT", -gap, 0)
    end
end

local function HideAtFull()
    local g = Settings()
    return not g or g.namehealthhidefull ~= false
end

---------------------------------------------------------------------------
-- Curves
---------------------------------------------------------------------------
local colorCurve, colorCurveHideFull
local nameCurves = {}

local function GetColorCurve()
    local hideFull = HideAtFull()
    if colorCurve and colorCurveHideFull == hideFull then return colorCurve end
    local c = C_CurveUtil.CreateColorCurve()
    c:SetType(Enum.LuaCurveType.Linear)
    local top = POINTS[#POINTS]
    for _, p in ipairs(POINTS) do
        if p[1] < 1 or not hideFull then
            c:AddPoint(p[1], CreateColor(p[2], p[3], p[4], 1))
        end
    end
    if hideFull then
        -- Hold the top color until just below full, then fade to invisible.
        c:AddPoint(FULL_STEP, CreateColor(top[2], top[3], top[4], 1))
        c:AddPoint(1.0, CreateColor(top[2], top[3], top[4], 0))
    end
    colorCurve, colorCurveHideFull = c, hideFull
    return c
end

local function GetNameCurve(classFile)
    local key = classFile or "?"
    local c = nameCurves[key]
    if c then return c end
    c = C_CurveUtil.CreateColorCurve()
    c:SetType(Enum.LuaCurveType.Linear)
    for _, p in ipairs(POINTS) do
        if p[1] < 1 then
            c:AddPoint(p[1], CreateColor(p[2], p[3], p[4]))
        end
    end
    local cc = classFile and C_ClassColor.GetClassColor(classFile)
    if cc then
        c:AddPoint(1.0, CreateColor(cc.r, cc.g, cc.b))
    else
        c:AddPoint(1.0, CreateColor(1, 1, 1))
    end
    nameCurves[key] = c
    return c
end

---------------------------------------------------------------------------
-- Widgets (one set per nameplate UnitFrame; plates are recycled)
---------------------------------------------------------------------------
local widgets = setmetatable({}, { __mode = "k" })

-- Pixel-perfect: sizes and gaps are whole screen pixels, and the textures
-- snap to the pixel grid, so an N px line is N px wherever it lands (both
-- edges share the same fractional position and round together).
local function Snap(region)
    if region and region.SetSnapToPixelGrid then pcall(region.SetSnapToPixelGrid, region, true) end
end

-- Frames anchored into a nameplate need this template in 12.x.
local function PlateFrame(parent)
    local ok, f = pcall(CreateFrame, "Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate")
    if not ok or not f then f = CreateFrame("Frame", nil, parent) end
    return f
end

local function NewDot(owner)
    local dot = owner:CreateTexture(nil, "OVERLAY")
    dot:SetTexture(WHITE)
    Snap(dot)
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    -- Both on the same layer; guarded anyway, since anchoring onto a
    -- scale-free layer's regions can be refused (a square dot beats none).
    if pcall(mask.SetAllPoints, mask, dot) then
        Snap(mask)
        dot:AddMaskTexture(mask)
    end
    return dot
end

local function GetWidgets(uf)
    local w = widgets[uf]
    if w then return w end

    -- Drawn on a layer fixed at scale 1, independent of the plate's (which
    -- Blizzard animates and distance-scales), so a pixel stays one pixel.
    w = PlateFrame(uf)
    if w.SetIgnoreParentScale then
        pcall(w.SetIgnoreParentScale, w, true)
        pcall(w.SetScale, w, 1)
    end
    w:SetAllPoints(uf)
    w:SetFrameLevel(uf:GetFrameLevel() + 10)

    -- Invisible box that hugs the actual text, so everything anchors to it.
    -- On the plate's own scale, so it can be sized in the text's units.
    w.box = PlateFrame(uf)

    w.dot = NewDot(w)

    local bar = CreateFrame("StatusBar", nil, w)
    bar:SetStatusBarTexture(WHITE)
    Snap(bar:GetStatusBarTexture())
    w.underline = bar

    widgets[uf] = w
    return w
end

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- One real screen pixel in a region's coordinates, so sizes land on whole
-- pixels instead of rounding unevenly.
local function OnePixel(region)
    local eff = Plain(region:GetEffectiveScale())
    if PixelUtil and PixelUtil.GetPixelToUIUnitFactor and eff and eff > 0 then
        return PixelUtil.GetPixelToUIUnitFactor() / eff
    end
    return 1
end

-- Size the box to the rendered text, respecting the name's justification.
local function Layout(w, fs, style)
    local g = Settings()
    local width = Plain(fs:GetStringWidth()) or fs:GetWidth()
    local height = Plain(fs:GetStringHeight()) or fs:GetHeight()
    local j = fs:GetJustifyH()
    local p = (j == "LEFT" or j == "RIGHT") and j or "CENTER"
    w.box:ClearAllPoints()
    w.box:SetPoint(p, fs, p)
    w.box:SetSize(width, height)

    -- Pixels in the drawing layer's space (where the offsets apply).
    local px = OnePixel(w)
    if style == "underline" then
        -- Measured text width includes the outline and a little spacing after
        -- the last letter, so pull each end in to match the visible text.
        local inset = UNDERLINE_INSET * px
        local bar = w.underline
        local gap = UnderlineGap(px)
        bar:ClearAllPoints()
        if UnderlineAbove() then
            bar:SetPoint("BOTTOMLEFT", w.box, "TOPLEFT", inset, gap)
            bar:SetPoint("BOTTOMRIGHT", w.box, "TOPRIGHT", -inset, gap)
        else
            bar:SetPoint("TOPLEFT", w.box, "BOTTOMLEFT", inset, -gap)
            bar:SetPoint("TOPRIGHT", w.box, "BOTTOMRIGHT", -inset, -gap)
        end
        bar:SetHeight((tonumber(g.namehealthunderlinethickness) or 1) * px)
    elseif style == "dot" then
        local size = (tonumber(g.namehealthdotsize) or 8) * px
        w.dot:SetSize(size, size)
        PlaceDot(w.dot, w.box, px)
    end
    w.underline:SetShown(style == "underline")
    w.dot:SetShown(style == "dot")
end

---------------------------------------------------------------------------
-- Name tint bookkeeping
---------------------------------------------------------------------------
-- Blizzard's own last name color per fontstring, so turning the name tint
-- off (or switching style) can put it back without calling Blizzard's
-- update functions.
local blizzColor = setmetatable({}, { __mode = "k" })
local tinted = setmetatable({}, { __mode = "k" })
local applying = false -- our own SetVertexColor/SetTextColor don't re-queue

local function RestoreName(fs)
    if not tinted[fs] then return end
    tinted[fs] = nil
    local c = blizzColor[fs]
    applying = true
    if c then
        fs:SetVertexColor(c[1], c[2], c[3])
        fs:SetTextColor(c[1], c[2], c[3])
    else
        fs:SetVertexColor(1, 1, 1)
        fs:SetTextColor(1, 1, 1)
    end
    applying = false
end

---------------------------------------------------------------------------
-- Apply
---------------------------------------------------------------------------
local function IsFriendlyPlayer(unit)
    return unit and UnitIsPlayer(unit) and UnitIsFriend("player", unit)
        and not UnitIsUnit(unit, "player")
end

local EnsureNameHooks

local function Apply(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit, false)
    if not plate or plate:IsForbidden() then return end
    local uf = plate.UnitFrame
    local fs = uf and uf.name
    if not fs or uf:IsForbidden() then return end

    local style = Style()
    -- Off, or the plate got recycled for an enemy/NPC.
    if not style or not IsFriendlyPlayer(unit) then
        if widgets[uf] then widgets[uf]:Hide() end
        RestoreName(fs)
        return
    end

    EnsureNameHooks(uf, fs)

    if style == "name" then
        if widgets[uf] then widgets[uf]:Hide() end
        local _, classFile = UnitClass(unit)
        local c = UnitHealthPercent(unit, true, GetNameCurve(classFile))
        if c then
            local r, g, b = c:GetRGB()
            applying = true
            -- Blizzard colors nameplate names with SetVertexColor; set both.
            fs:SetVertexColor(r, g, b)
            fs:SetTextColor(r, g, b)
            applying = false
            tinted[fs] = true
        end
        return
    end

    RestoreName(fs)
    local w = GetWidgets(uf)
    Layout(w, fs, style)
    local c = UnitHealthPercent(unit, true, GetColorCurve())
    if c then
        local r, g, b, a = c:GetRGBA()
        if style == "underline" then
            w.underline:SetMinMaxValues(0, UnitHealthMax(unit))
            w.underline:SetValue(UnitHealth(unit))
            w.underline:GetStatusBarTexture():SetVertexColor(r, g, b, a)
        else
            w.dot:SetVertexColor(r, g, b, a)
        end
    end
    w:SetShown(fs:IsShown())
end

-- Coalesced and deferred: most triggers fire inside Blizzard's nameplate
-- update chain.
local pending = {}
local function Queue(unit)
    if not unit or pending[unit] then return end
    pending[unit] = true
    C_Timer.After(0, function()
        pending[unit] = nil
        Apply(unit)
    end)
end

---------------------------------------------------------------------------
-- Hooks (installed only once the feature is on)
---------------------------------------------------------------------------
local hookedFs = setmetatable({}, { __mode = "k" }) -- fontstring -> UnitFrame

local function OnNameChanged(self)
    if applying then return end
    local uf = hookedFs[self]
    local u = uf and uf.unit
    if u and Style() then Queue(u) end
end

local function OnNameColor(self, r, g, b)
    if applying then return end
    blizzColor[self] = { r, g, b }
    OnNameChanged(self)
end

-- Re-apply when Blizzard recolors, shows/hides, or changes the name's font.
function EnsureNameHooks(uf, fs)
    if hookedFs[fs] then
        hookedFs[fs] = uf
        return
    end
    hookedFs[fs] = uf
    -- Blizzard's color from before the hook, in case it isn't set again
    -- before the tint is turned off.
    local ok, r, g, b = pcall(fs.GetVertexColor, fs)
    if ok and r then blizzColor[fs] = { r, g, b } end
    hooksecurefunc(fs, "SetVertexColor", OnNameColor)
    hooksecurefunc(fs, "SetTextColor", OnNameColor)
    hooksecurefunc(fs, "SetFontObject", OnNameChanged)
    hooksecurefunc(fs, "Show", OnNameChanged)
    hooksecurefunc(fs, "Hide", OnNameChanged)
    hooksecurefunc(fs, "SetShown", OnNameChanged)
end

local globalHooked = false
local events = CreateFrame("Frame")

local function EnsureHooks()
    if not Style() then
        events:UnregisterEvent("UNIT_HEALTH")
        events:UnregisterEvent("UNIT_MAXHEALTH")
        events:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
        return
    end
    events:RegisterEvent("UNIT_HEALTH")
    events:RegisterEvent("UNIT_MAXHEALTH")
    events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    if not globalHooked and CompactUnitFrame_UpdateName then
        globalHooked = true
        -- Blizzard's name refresh (class color, text, font).
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
            local u = frame and frame.unit
            if u and Style() and u:find("^nameplate") then Queue(u) end
        end)
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        EnsureHooks()
        return
    end
    if not (unit and unit:find("^nameplate")) then return end
    if event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit, false)
        local uf = plate and plate.UnitFrame
        if uf and widgets[uf] then widgets[uf]:Hide() end
        return
    end
    if Style() then Queue(unit) end
end)

---------------------------------------------------------------------------
-- Options preview: sample names drawn the same way, with plain (non-secret)
-- sample health, so the curve is evaluated by hand here.
---------------------------------------------------------------------------
local SAMPLES = {
    { "Uberlicious", "PRIEST", 1.00 },
    { "Jaina", "MAGE", 0.55 },
    { "Thrall", "SHAMAN", 0.20 },
}
local SAMPLE_SPACING = 18

local function ClassRGB(classFile)
    local cc = C_ClassColor.GetClassColor(classFile)
    if cc then return cc.r, cc.g, cc.b end
    return 1, 1, 1
end

local function SampleColor(pct, classFile, style)
    local pts = POINTS
    if style == "name" then
        local r, g, b = ClassRGB(classFile)
        pts = { POINTS[1], POINTS[2], POINTS[3], { 1.00, r, g, b } }
    end
    local r, g, b = pts[#pts][2], pts[#pts][3], pts[#pts][4]
    for i = 2, #pts do
        local a, z = pts[i - 1], pts[i]
        if pct <= z[1] then
            local t = (pct - a[1]) / (z[1] - a[1])
            r = a[2] + (z[2] - a[2]) * t
            g = a[3] + (z[3] - a[3]) * t
            b = a[4] + (z[4] - a[4]) * t
            break
        end
    end
    local alpha = (style ~= "name" and HideAtFull() and pct >= FULL_STEP) and 0 or 1
    return r, g, b, alpha
end

-- Nameplate name font as it appears on screen: file, height in screen units
-- (font size x effective scale), flags. Read off a live plate when one is
-- up -- friendly players first, the plates this feature draws on -- since
-- plates ignore UI Scale and have their own scale; otherwise Blizzard's
-- nameplate font at the world frame's scale.
local function NameplateFont()
    local best
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local uf = not plate:IsForbidden() and plate.UnitFrame
        local fs = uf and not uf:IsForbidden() and uf.name
        if fs and fs:IsVisible() then
            local file, size, flags = fs:GetFont()
            local eff = Plain(fs:GetEffectiveScale())
            if file and size and eff and eff > 0 then
                local found = { file, size * eff, flags }
                if IsFriendlyPlayer(uf.unit) then return found end
                best = best or found
            end
        end
    end
    if best then return best end
    local fo = _G.SystemFont_NamePlate
    local file, size, flags
    if fo then file, size, flags = fo:GetFont() end
    if not file then return nil end
    local eff = WorldFrame and Plain(WorldFrame:GetEffectiveScale()) or 1
    return { file, size * (eff or 1), flags }
end

local PREVIEW_EDGE = 8     -- left margin before the first name's decorations
local STAGE_HEIGHT = 64    -- the dark "in the world" strip
local CAPTION_HEIGHT = 14  -- health captions under the strip, on the panel

local function UpdatePreview(preview)
    local style = Style()
    local g = Settings()
    local px = OnePixel(preview)

    -- Same on-screen text size as the real plates (the options panel is
    -- UI-scaled, plates aren't).
    local font = NameplateFont()
    local eff = preview:GetEffectiveScale()
    if font and eff and eff > 0 then
        for _, s in ipairs(preview.samples) do
            s.fs:SetFont(font[1], font[2] / eff, font[3])
        end
    end
    local thick = (tonumber(g.namehealthunderlinethickness) or 1) * px
    local size = (tonumber(g.namehealthdotsize) or 8) * px
    local side = DotSide()

    -- How far the decoration reaches past the name on each side, so the names
    -- can be spaced and centered to fit it.
    local left, right, above, below = 0, 0, 0, 0
    if style == "underline" then
        local reach = math.max(0, UnderlineGap(px) + thick)
        if UnderlineAbove() then above = reach else below = reach end
    elseif style == "dot" then
        local reach = math.max(0, DotGap(px) + size)
        if side == "LEFT" then left = reach
        elseif side == "RIGHT" then right = reach
        elseif side == "TOP" then above = reach
        else below = reach end
    end

    for i, s in ipairs(preview.samples) do
        local fs, pct, classFile = s.fs, s.pct, s.classFile
        if style == "name" then
            fs:SetTextColor(SampleColor(pct, classFile, style))
        else
            fs:SetTextColor(ClassRGB(classFile))
        end

        s.holder:ClearAllPoints()
        if i == 1 then
            -- Name + decoration vertically centered in the strip.
            s.holder:SetPoint("LEFT", preview.stage, "LEFT", PREVIEW_EDGE + left, (below - above) / 2)
        else
            s.holder:SetPoint("LEFT", preview.samples[i - 1].fs, "RIGHT", SAMPLE_SPACING + left + right, 0)
        end

        if style == "underline" then
            local inset = UNDERLINE_INSET * px
            local full = math.max(fs:GetStringWidth() - 2 * inset, px)
            s.bar:ClearAllPoints()
            if UnderlineAbove() then
                s.bar:SetPoint("BOTTOMLEFT", fs, "TOPLEFT", inset, UnderlineGap(px))
            else
                s.bar:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", inset, -UnderlineGap(px))
            end
            s.bar:SetSize(math.max(full * pct, px), thick)
            s.bar:SetVertexColor(SampleColor(pct, classFile, style))
        elseif style == "dot" then
            s.dot:SetSize(size, size)
            PlaceDot(s.dot, fs, px)
            s.dot:SetVertexColor(SampleColor(pct, classFile, style))
        end
        s.bar:SetShown(style == "underline")
        s.dot:SetShown(style == "dot")

        -- Caption centered under the name but below the strip, so it reads
        -- as a label, not part of the look: fs bottom -> strip bottom.
        local y = (below - above) / 2
        local toStripBottom = (y - fs:GetStringHeight() / 2) + STAGE_HEIGHT / 2
        s.label:ClearAllPoints()
        s.label:SetPoint("TOP", fs, "BOTTOM", 0, -(toStripBottom + 2))
    end
end

-- A dark strip with a few sample names at different health. `preview:Update()`
-- redraws it from the current settings.
function namehealth.CreatePreview(parent)
    local preview = CreateFrame("Frame", nil, parent)
    preview:SetSize(330, STAGE_HEIGHT + CAPTION_HEIGHT)
    local stage = CreateFrame("Frame", nil, preview)
    stage:SetPoint("TOPLEFT")
    stage:SetPoint("TOPRIGHT")
    stage:SetHeight(STAGE_HEIGHT)
    local bg = stage:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.55)
    preview.stage = stage

    local font = _G.SystemFont_NamePlate or GameFontHighlightSmall
    preview.samples = {}
    for i, info in ipairs(SAMPLES) do
        local s = { classFile = info[2], pct = info[3] }
        -- Positioned in UpdatePreview.
        local holder = CreateFrame("Frame", nil, stage)
        holder:SetSize(1, 1)
        s.holder = holder
        s.fs = holder:CreateFontString(nil, "OVERLAY")
        s.fs:SetFontObject(font)
        s.fs:SetText(info[1])
        s.fs:SetPoint("LEFT", holder, "LEFT", 0, 0)
        -- Health label under each name (placed in UpdatePreview).
        s.label = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        s.label:SetText(math.floor(info[3] * 100 + 0.5) .. "%")
        s.bar = holder:CreateTexture(nil, "OVERLAY")
        s.bar:SetTexture(WHITE)
        Snap(s.bar)
        s.dot = NewDot(holder)
        preview.samples[i] = s
    end

    preview.Update = UpdatePreview
    preview:SetScript("OnShow", UpdatePreview)
    return preview
end

-- Options onChange: re-evaluate hooks and every visible plate.
function namehealth:Refresh()
    if self.preview then self.preview:Update() end
    EnsureHooks()
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local u = plate.UnitFrame and plate.UnitFrame.unit
        if u then Queue(u) end
    end
end

UberUI.namehealth = namehealth
