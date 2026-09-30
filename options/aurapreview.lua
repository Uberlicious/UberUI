--[[--------------------------------------------------------------------
	Uber UI options -- aura preview row
	A strip of sample buffs and debuffs at the top of every location's aura
	settings (opt.AddAuraOptions), drawn from that location's current
	settings: Zoom, Buff/Debuff Border, Border Shape/Thickness/Position,
	Thicker Dispel Borders, Darkness Level, stack count and duration text.
	Square borders use the real squareborders code; the rounded look uses the
	same border art the aura buttons do (core/aurakit.lua).

	Icons are drawn at the size they appear on screen: the location's icon
	size times its frame's effective scale (Edit Mode frame size, UI Scale,
	nameplate scale), converted into the options panel's scale. Locations
	with two sizes show yours large and others' small.
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

local SPACING = 14        -- room for an 8px outside border on both icons
local GROUP_GAP = 26      -- between the buffs and the debuffs
local EDGE = 14
local WIDTH = 340
local STAGE_HEIGHT = 58
local MAX_ICON = 44       -- larger icons are scaled down to fit the strip
local CAPTION_HEIGHT = 14
local ROUND_ATLAS = "ui-debuff-border-default-noicon"
local DURATION_REF_SIZE = 25 -- Blizzard's nameplate aura (aurakit's reference)

-- mine: drawn at the location's large ("your auras") size.
local SAMPLES = {
    -- Earth Shield: a buff that actually stacks (charges).
    { buff = true, mine = true, icon = "Interface\\Icons\\Spell_Nature_SkinofEarth", stack = 6, caption = "Buff" },
    { buff = true, icon = "Interface\\Icons\\Spell_Nature_Riptide", duration = 14, caption = "Buff" },
    { dispel = "Magic", mine = true, icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", duration = 12, caption = "Magic" },
    { dispel = "Curse", icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", stack = 8, duration = 16, caption = "Curse" }, -- Agony: ramps up to 10 stacks; both texts at once
    -- In its pandemic window on nameplates (the only location that highlights it).
    { dispel = "Poison", mine = true, icon = "Interface\\Icons\\Spell_Nature_CorrosiveBreath", duration = 3, pandemic = true, caption = "Poison" },
    { dispel = "None", icon = "Interface\\Icons\\Ability_Gouge", caption = "Physical" },
}

-- Locations that can show duration text: the setting that turns it on, or
-- true for always on.
local DURATION = {
    player = true, -- Blizzard's own "12 s" text, under the icon or centered
    target = "targetauraduration",
    focus = "focusauraduration",
    compact = "compactauraduration",
    nameplate = true,
}

local function G() return uuidb and uuidb.general or {} end

-- Rounded-border geometry per location, matching the code that draws it
-- (sizes in the frame's units). Default: the shared aura buttons
-- (aurakit.ApplyAuraButtonStyle): icon inset 1 when zoomed or bordered,
-- ring padded 3 (2 under 20px) around the button.
-- Pad of the rounded ring around the button, in frame units; dark and
-- dispel-colored rings share it. Player's grows while zoomed
-- (general:ZoomBorderGrow, 1 per 30px of icon).
local function ZoomGrow(zoom, size)
    if not zoom then return 0 end
    return math.max(1, math.floor(size / 30 + 0.5))
end

local ROUND_GEOMETRY = {
    default = {
        inset = function() return 1 end,
        pad = function(size) return size >= 20 and 3 or 2 end,
        countX = 1, countY = 0,
    },
    -- Player buffs/debuffs (buffsandauras.lua): Blizzard's own buttons, the
    -- icon never inset, the ring padded a sixth of the icon's width (Blizzard's
    -- 40px DebuffBorder on a 30px icon).
    player = {
        inset = function() return 0 end,
        pad = function(size, zoom) return math.max(2, math.floor(size * 5 / 30 + 0.5)) + ZoomGrow(zoom, size) end,
        countX = -2, countY = 2, countFont = "NumberFontNormal",
    },
    -- Party (partyframes.lua): Blizzard's DebuffBorder from
    -- PartyAuraFrameTemplate, 1px out, recolored for dark / dispel.
    party = {
        inset = function() return 0 end,
        pad = function() return 1 end,
        file = "Interface\\Buttons\\UI-Debuff-Overlays",
        texCoords = { 0.296875, 0.5703125, 0, 0.515625 },
        countX = 5, countY = 0, countJustify = "RIGHT", -- PartyAuraFrameTemplate
    },
    -- Arena trackers (arenaframes.lua): the DR tray / CC remover borders are
    -- that same overlay art 1px out.
    arena = {
        inset = function() return 1 end,
        pad = function() return 1 end,
        file = "Interface\\Buttons\\UI-Debuff-Overlays",
        texCoords = { 0.296875, 0.5703125, 0, 0.515625 },
        countX = 1, countY = 0,
    },
    nameplate = {
        inset = function() return 1 end,
        pad = function(size) return size >= 20 and 3 or 2 end,
        countX = 3, countY = -2, -- Blizzard_NamePlateAuras.xml
    },
}

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Eff(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return nil end
    local e = Plain(frame:GetEffectiveScale())
    return (type(e) == "number" and e > 0) and e or nil
end

-- A live region's width and effective scale, if it has a usable one.
local function Measure(region)
    if not region or (region.IsForbidden and region:IsForbidden()) then return nil end
    local w, e = Plain(region:GetWidth()), Eff(region)
    if type(w) == "number" and w > 0 and e then return w, e end
    return nil
end

local function FirstAuraIcon(auraFrame)
    local frames = auraFrame and auraFrame.auraFrames
    if type(frames) ~= "table" then return nil end
    for _, f in ipairs(frames) do
        if f.Icon and f:IsShown() then return f.Icon end
    end
    return nil
end

-- Per location: { eff, buffLarge, buffSmall, debuffLarge, debuffSmall,
-- countRef } -- sizes in the frame's own units, countRef the size at which
-- the stack count is drawn unscaled. Kept in step with each core file's
-- sizes (targetframe.lua, bossframes.lua, nameplateauras.lua, ...).
local function Fixed(frame, large, small, fallbackFrame)
    local eff = Eff(frame) or Eff(fallbackFrame) or Eff(UIParent) or 1
    return { eff = eff, buffLarge = large, buffSmall = small, debuffLarge = large, debuffSmall = small, countRef = large }
end

-- Nameplates ignore UI Scale and have their own scale, and each plate is
-- also scaled on its own by Blizzard (target, distance) -- constantly. So
-- that per-plate scale is taken back out of a live plate's scale (the size
-- at full plate scale); the last reading is kept for when no plate is up.
-- region(unitFrame) picks the part to measure (default the aura frame).
local nameplateEff = {}
function opt.NameplateBaseScale(key, region)
    key = key or "auras"
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local uf = not plate:IsForbidden() and plate.UnitFrame
        local r = uf and (region and region(uf) or uf.AurasFrame or uf)
        local e, pe = Eff(r), Eff(plate)
        local base = Eff(plate:GetParent()) or Eff(WorldFrame)
        if e and pe and base then
            nameplateEff[key] = e / pe * base
            break
        end
    end
    return nameplateEff[key] or Eff(WorldFrame)
end
opt.PreviewEff = function(frame) return Eff(frame) end

local SIZES = {
    player = function()
        local bw, be = Measure(FirstAuraIcon(BuffFrame))
        local dw, de = Measure(FirstAuraIcon(DebuffFrame))
        local eff = be or de or Eff(BuffFrame) or Eff(UIParent) or 1
        -- Scale the debuff size into the buff frame's units.
        local buff = bw or 30
        local debuff = dw and (dw * de / eff) or 30
        return { eff = eff, buffLarge = buff, buffSmall = buff, debuffLarge = debuff, debuffSmall = debuff,
                 countRef = buff, fixedCount = true }
    end,
    target = function() return Fixed(TargetFrame, 21, 17) end,
    focus = function() return Fixed(FocusFrame, 21, 17) end,
    boss = function() return Fixed(Boss1TargetFrame, 15, 11) end,
    party = function()
        local s = Fixed(PartyFrame and PartyFrame.MemberFrame1, 15, 15, PartyFrame)
        s.fixedCount = true
        return s
    end,
    compact = function()
        local ca = UberUI.compactauras
        if ca and ca.GetPreviewSizes then
            local buff, debuff, ref, eff = ca:GetPreviewSizes()
            if buff and eff then
                return { eff = eff, buffLarge = buff, buffSmall = buff, debuffLarge = debuff, debuffSmall = debuff, countRef = ref }
            end
        end
        local s = Fixed(nil, 11, 11)
        s.countRef = 17 -- compactauras.lua COUNT_REF_SIZE
        return s
    end,
    arena = function()
        local m = _G.CompactArenaFrameMember1
        local w, e = Measure(m and m.DebuffFrame and m.DebuffFrame.Icon)
        if w then
            return { eff = e, buffLarge = 26, buffSmall = 26, debuffLarge = w, debuffSmall = w, countRef = w, fixedCount = true }
        end
        local s = Fixed(_G.CompactArenaFrame, 26, 26)
        s.fixedCount = true
        return s
    end,
    nameplate = function()
        local s = Fixed(nil, 22, 22, WorldFrame)
        s.eff = opt.NameplateBaseScale() or s.eff
        return s
    end,
}

local function LocationSizes(loc)
    local f = SIZES[loc]
    local ok, s = pcall(f or function() return nil end)
    if ok and s then return s end
    return Fixed(nil, 24, 24)
end

local function Unsnap(region)
    if region.SetSnapToPixelGrid then region:SetSnapToPixelGrid(false) end
    if region.SetTexelSnappingBias then region:SetTexelSnappingBias(0) end
end

-- The cooldown countdown font the duration text uses (aurakit reads it off
-- the aura button's own Cooldown).
local countdownFont
local function CountdownFont(parent)
    if countdownFont == nil then
        countdownFont = false
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, parent, "CooldownFrameTemplate")
        local fs = ok and cd and cd.GetCountdownFontString and cd:GetCountdownFontString()
        local font, size, flags
        if fs then font, size, flags = fs:GetFont() end
        if not font and NumberFontNormal then font, size, flags = NumberFontNormal:GetFont() end
        if font then countdownFont = { font, size, flags } end
        if ok and cd then cd:Hide() end
    end
    return countdownFont or nil
end

local function DurationColors()
    local g = G()
    local threshold = tonumber(g.nameplatedurationthreshold) or 5
    local HexColor = UberUI.util and UberUI.util.HexColor
    local n = HexColor and HexColor(g.nameplatedurationcolor or "ffffffff")
    local e = HexColor and HexColor(g.nameplatedurationexpiringcolor or "ffff3333")
    return n or CreateColor(1, 1, 1, 1), e or CreateColor(1, 0.2, 0.2, 1), threshold
end

local function ShowsDuration(loc)
    local d = DURATION[loc]
    if d == true then return true end
    return d and G()[d] == true or false
end

-- A sample aura button. Player's are built from Blizzard's own player aura
-- template (AuraButtonArtTemplate: 30x40 with the icon at the top, Count
-- and Duration where Blizzard puts them), so their stock text placement is
-- Blizzard's own. The others mirror the shared aura buttons (aurakit).
--
-- Buttons work in their frame's own units and are scaled as a whole
-- (SetScale) to the on-screen size, so offsets and fonts scale exactly like
-- the real frames'.
local function NewIcon(stage, info, loc)
    local b
    if loc == "player" then
        local ok, f = pcall(CreateFrame, "Frame", nil, stage, "AuraButtonArtTemplate")
        if ok and f and f.Icon and f.Count and f.Duration then
            b = f
            b.isTemplate = true
            b.icon, b.count, b.duration = f.Icon, f.Count, f.Duration
            for _, key in ipairs({ "DebuffBorder", "TempEnchantBorder", "Symbol" }) do
                if f[key] then f[key]:Hide() end
            end
        end
    end
    if not b then
        b = CreateFrame("Frame", nil, stage)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.text = CreateFrame("Frame", nil, b)
        b.text:SetAllPoints()
        b.text:SetFrameLevel(b:GetFrameLevel() + 5)
        b.count = b.text:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.duration = b.text:CreateFontString(nil, "OVERLAY")
    end
    b.info = info
    b.icon:SetTexture(info.icon)
    Unsnap(b.icon)

    -- Rounded border: Blizzard's art, darkened (dark) or tinted through a
    -- mask (dispel color), on a host padded out around the icon's box.
    b.round = CreateFrame("Frame", nil, b)
    b.round:SetFrameLevel(b:GetFrameLevel() + 2)
    b.roundDark = b.round:CreateTexture(nil, "OVERLAY")
    b.roundDark:SetAllPoints()
    b.roundDark:SetAtlas(ROUND_ATLAS)
    Unsnap(b.roundDark)
    b.roundColor = b.round:CreateTexture(nil, "OVERLAY", nil, 2)
    b.roundColor:SetAllPoints()
    b.roundColor:SetColorTexture(1, 1, 1, 1)
    Unsnap(b.roundColor)
    local mask = b.round:CreateMaskTexture()
    mask:SetAtlas(ROUND_ATLAS)
    mask:SetAllPoints(b.round)
    Unsnap(mask)
    b.roundColor:AddMaskTexture(mask)

    b.square = UberUI.squareborders.CreateBorder(b)
    b.square:SetFrameLevel(b:GetFrameLevel() + 3)
    return b
end

local function StyleFor(o, isBuff)
    local g = G()
    if isBuff then return g[o.buffKey] or "both" end
    return g[o.debuffKey] or "zoom"
end

-- frameSize: the icon's size in its frame's own units. The button is scaled
-- to the screen by the caller, so everything here is in frame units.
local function UpdateIcon(b, o, frameSize, sizes)
    local SB = UberUI.squareborders
    local info = b.info
    local isBuff = info.buff
    local style = StyleFor(o, isBuff)
    local zoom = style == "both" or style == "zoom"
    local dark = style == "both" or style == "border"
    local square = style ~= "none" and SB.IsEnabled(o.loc)
    local geo = ROUND_GEOMETRY[o.loc] or ROUND_GEOMETRY.default

    -- Layers relative to the button, every redraw: explicit frame levels
    -- don't follow when the settings list moves the preview to another row
    -- (a different level), which left the borders under the icon.
    local level = b:GetFrameLevel()
    b.round:SetFrameLevel(level + 2)
    b.square:SetFrameLevel(level + 3)
    if b.text then b.text:SetFrameLevel(level + 5) end

    local t = UberUI.aurakit and UberUI.aurakit.TextSettings(o.loc)
        or { duration = 1, stack = 1, anchor = "BOTTOMRIGHT", x = 0, y = 0 }

    -- The box the borders go around: Blizzard's icon texture on the player
    -- template (its own anchor, TOP of the button, is left alone), else the
    -- button, with the icon inset inside it like aurakit.ApplyAuraButtonStyle.
    local box
    if b.isTemplate then
        -- Duration Inside Icon drops the row space under the icon.
        b:SetSize(frameSize, t.center and frameSize or frameSize * 40 / 30)
        b.icon:SetSize(frameSize, frameSize)
        box = b.icon
    else
        b:SetSize(frameSize, frameSize)
        b.icon:ClearAllPoints()
        local inset = geo.inset()
        if (dark or zoom) and not square and inset > 0 then
            b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
            b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
        else
            b.icon:SetAllPoints(b)
        end
        box = b
    end
    if zoom then
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        b.icon:SetTexCoord(0, 1, 0, 1)
    end

    local dc = G().darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    local dr, dg, db = SB.GetDispelColor(info.dispel)

    b.round:Hide()
    b.square:Hide()
    -- The rounded host always sits where it would (the pandemic ring
    -- anchors to it, like nameplateauras.lua's borderHost).
    do
        local pad = geo.pad(frameSize, zoom)
        b.round:ClearAllPoints()
        b.round:SetPoint("TOPLEFT", box, "TOPLEFT", -pad, pad)
        b.round:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", pad, -pad)
    end
    -- How far a border reaches past the icon (Player's duration text is
    -- pushed out past it, as buffsandauras.lua does).
    local borderReach = 0
    if square then
        -- Buffs: dark or none. Debuffs: dark or dispel colored (optionally
        -- 1px thicker). Thickness is in screen pixels (squareborders reads
        -- the effective scale).
        if dark then
            local th = SB.LayoutFor(b.square, b.icon, o.loc)
            SB.SetDarkColor(b.square)
            b.square:Show()
            if not SB.IsInset(o.loc) then borderReach = th end
        elseif not isBuff then
            local th = SB.LayoutDispelFor(b.square, b.icon, o.loc)
            SB.SetColor(b.square, dr, dg, db, 1)
            b.square:Show()
            if not SB.IsInset(o.loc) then borderReach = th end
        end
    elseif dark or not isBuff then
        -- Buffs without the dark border have none (Blizzard's look); debuffs
        -- are dark or dispel colored.
        local pad = geo.pad(frameSize, zoom)
        borderReach = math.max(0, pad - 5) -- buffsandauras.lua RING_TEXT_TUCK
        b.round:ClearAllPoints()
        b.round:SetPoint("TOPLEFT", box, "TOPLEFT", -pad, pad)
        b.round:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", pad, -pad)
        if geo.file then
            -- Blizzard's own border texture, tinted in place for both looks.
            b.roundDark:SetTexture(geo.file)
            b.roundDark:SetTexCoord(unpack(geo.texCoords))
            b.roundDark:SetDesaturated(dark)
            if dark then
                b.roundDark:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            else
                b.roundDark:SetVertexColor(dr, dg, db, 1)
            end
            b.roundDark:Show()
            b.roundColor:Hide()
        elseif dark then
            b.roundDark:SetAtlas(ROUND_ATLAS)
            b.roundDark:SetDesaturated(true)
            b.roundDark:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            b.roundDark:Show()
            b.roundColor:Hide()
        else
            b.roundColor:SetVertexColor(dr, dg, db, 1)
            b.roundColor:Show()
            b.roundDark:Hide()
        end
        b.round:Show()
    end

    -- Nameplate pandemic highlight (nameplateauras.lua StylePandemic): the
    -- debuff's own border hidden, the highlight drawn by the same
    -- aurakit.StyleHighlight, covering the border in the highlight color for
    -- Proc Glow / Marching Ants.
    local g = G()
    local pandemic = o.loc == "nameplate" and info.pandemic and g.nameplatepandemic ~= false
    if pandemic then
        b.round:Hide()
        b.square:Hide()
        local pr, pg, pb
        if g.nameplatepandemicclasscolor then
            local _, class = UnitClass("player")
            local cc = UberUI.util.ClassColor(class)
            if cc then pr, pg, pb = cc.r, cc.g, cc.b end
        end
        if not pr then
            local col = UberUI.util.HexColor(g.nameplatepandemiccolor) or UberUI.util.HexColor("ffff3030")
            pr, pg, pb = col.r, col.g, col.b
        end
        local kind = g.nameplatepandemicstyle or "border"
        b.pandemicHost = b.pandemicHost or CreateFrame("Frame", nil, b)
        local host = b.pandemicHost
        host:SetAllPoints(b)
        host:SetFrameLevel(b:GetFrameLevel() + 4)
        UberUI.aurakit.StyleHighlight(host, {
            kind = kind,
            r = pr, g = pg, b = pb,
            occlude = kind ~= "border" and { r = 0, g = 0, b = 0 } or nil, -- black cover under a glow
            square = style ~= "none" and SB.IsEnabled(o.loc),
            loc = o.loc, icon = b.icon,
            ringFrom = b.round,
            center = b, size = frameSize,
            pixelInside = g.nameplatepixelposition == "inside",
        })
        host:Show()
    elseif b.pandemicHost then
        b.pandemicHost:Hide()
    end
    if b.cap then b.cap:SetText(pandemic and "Pandemic" or info.caption) end

    -- Stack count: the location's count font, scaled with the icon against
    -- its reference size (Blizzard's own buttons never scale it), times
    -- Stack Text Size, at the chosen anchor + offset (the stock offset only
    -- in the stock bottom-right corner) -- as the real buttons apply it.
    if info.stack then
        local fontObject = _G[geo.countFont or "NumberFontNormalSmall"] or NumberFontNormalSmall
        b.count:SetFontObject(fontObject)
        local font, fsize, flags = fontObject:GetFont()
        if font then
            local scale = sizes.fixedCount and 1 or (frameSize / sizes.countRef)
            b.count:SetFont(font, math.max(4, fsize * scale * t.stack), flags)
        end
        local bx, by = 0, 0
        if t.anchor == "BOTTOMRIGHT" then bx, by = geo.countX, geo.countY end
        b.count:ClearAllPoints()
        b.count:SetPoint(t.anchor, box, t.anchor, bx + t.x, by + t.y)
        if t.anchor == "BOTTOMRIGHT" and t.x == 0 and t.y == 0 then
            b.count:SetJustifyH(geo.countJustify or "CENTER")
        else
            b.count:SetJustifyH((t.anchor:find("LEFT") and "LEFT") or (t.anchor:find("RIGHT") and "RIGHT") or "CENTER")
        end
        b.count:SetText(tostring(info.stack))
        b.count:Show()
    else
        b.count:Hide()
    end

    if not (info.duration and ShowsDuration(o.loc)) then
        b.duration:Hide()
        return
    end
    b.duration:ClearAllPoints()
    if o.loc == "player" then
        -- Blizzard's text ("12 s", GameFontNormalSmall with its shadow) with
        -- its top on the icon's bottom, or centered on the icon and outlined;
        -- only its size changes.
        b.duration:SetFontObject(GameFontNormalSmall)
        local font, fsize, flags = GameFontNormalSmall:GetFont()
        if font and (t.duration ~= 1 or t.center) then
            b.duration:SetFont(font, math.max(4, fsize * t.duration), t.center and "OUTLINE" or flags)
        end
        if t.center then
            b.duration:SetShadowOffset(0, 0)
            b.duration:SetPoint("CENTER", b.icon, "CENTER", 0, 0)
        else
            b.duration:SetPoint("TOP", b.icon, "BOTTOM", 0, -borderReach)
        end
        b.duration:SetText(string.format(_G.SECOND_ONELETTER_ABBR or "%d s", info.duration))
        b.duration:Show()
        return
    end
    -- Elsewhere: the countdown font scaled by icon size against Blizzard's
    -- 25px nameplate aura (aurakit.UpdateDurationText), times Duration Text
    -- Size, centered, colored by the duration colors.
    local f = CountdownFont(b)
    b.duration:SetShadowOffset(0, 0)
    if f then
        b.duration:SetFont(f[1], math.max(4, f[2] * frameSize / DURATION_REF_SIZE * t.duration), f[3])
    else
        b.duration:SetFontObject(NumberFontNormal)
    end
    b.duration:SetPoint("CENTER", b.icon, "CENTER", 0, 0)
    local normal, expiring, threshold = DurationColors()
    local c = info.duration <= threshold and expiring or normal
    b.duration:SetTextColor(c.r, c.g, c.b, 1)
    b.duration:SetText(tostring(info.duration))
    b.duration:Show()
end

local function UpdatePreview(preview)
    local o = preview.o
    local sizes = LocationSizes(o.loc)
    local peff = preview:GetEffectiveScale()
    local r = (peff and peff > 0) and (sizes.eff / peff) or 1

    local frameSizes, total, biggest = {}, EDGE * 2, 0
    for i, b in ipairs(preview.icons) do
        local info = b.info
        local s
        if info.buff then
            s = info.mine and sizes.buffLarge or sizes.buffSmall
        else
            s = info.mine and sizes.debuffLarge or sizes.debuffSmall
        end
        frameSizes[i] = s
        total = total + s * r
        biggest = math.max(biggest, s * r)
    end
    for i = 1, #preview.icons - 1 do
        local a, b = preview.icons[i].info, preview.icons[i + 1].info
        total = total + ((a.buff and not b.buff) and GROUP_GAP or SPACING)
    end

    -- Shrink everything together if the real sizes don't fit the strip.
    local fit = math.min(1, MAX_ICON / math.max(biggest, 1), WIDTH / math.max(total, 1))
    r = r * fit
    preview.fitNote:SetShown(fit < 0.999)

    local x = EDGE
    for i, b in ipairs(preview.icons) do
        local size = frameSizes[i]
        b:SetScale(r)
        pcall(UpdateIcon, b, o, size, sizes)
        -- Anchor offsets are in the button's (scaled) units. The icon is
        -- vertically centered in the strip; the player template's icon sits
        -- at the top of its taller button.
        b:ClearAllPoints()
        if b.isTemplate then
            b:SetPoint("TOPLEFT", preview.stage, "LEFT", x / r, size / 2)
        else
            b:SetPoint("LEFT", preview.stage, "LEFT", x / r, 0)
        end
        -- Caption under the strip, centered under the icon.
        b.cap:ClearAllPoints()
        b.cap:SetWidth(80)
        b.cap:SetPoint("TOPLEFT", preview.stage, "BOTTOMLEFT", x + size * r / 2 - 40, -2)
        -- Step to the next icon: the usual gap, or wider if the two
        -- captions would otherwise run into each other at small sizes.
        local nextB = preview.icons[i + 1]
        local step = size * r + ((b.info.buff and nextB and not nextB.info.buff) and GROUP_GAP or SPACING)
        if nextB then
            local need = (b.cap:GetStringWidth() + nextB.cap:GetStringWidth()) / 2 + 6
                - (size * r + frameSizes[i + 1] * r) / 2 + size * r
            step = math.max(step, need)
        end
        x = x + step
    end
end

local function CreateAuraPreview(parent, o, samples)
    local preview = CreateFrame("Frame", nil, parent)
    preview.o = o
    preview:SetSize(WIDTH, STAGE_HEIGHT + CAPTION_HEIGHT)

    local stage = CreateFrame("Frame", nil, preview)
    stage:SetPoint("TOPLEFT")
    stage:SetPoint("TOPRIGHT")
    stage:SetHeight(STAGE_HEIGHT)
    preview.stage = stage

    preview.fitNote = stage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    preview.fitNote:SetPoint("TOPRIGHT", stage, "TOPRIGHT", -4, -2)
    preview.fitNote:SetText("scaled to fit")
    preview.fitNote:Hide()

    preview.icons = {}
    for i, info in ipairs(samples or SAMPLES) do
        local b = NewIcon(stage, info, o.loc)
        -- Caption on the panel under the strip, so it reads as a label.
        local cap = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        cap:SetJustifyH("CENTER")
        cap:SetText(info.caption)
        b.cap = cap
        preview.icons[i] = b
    end

    preview.Update = UpdatePreview
    preview:SetScript("OnShow", UpdatePreview)
    return preview
end

-- Nameplate pandemic: one of your debuffs normally, then in its pandemic
-- window, plus another dispel type in its window -- the black cover under a
-- glow hides either border color.
local PANDEMIC_SAMPLES = {
    { dispel = "Magic", mine = true, icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", duration = 12, caption = "Normal" },
    { dispel = "Magic", mine = true, icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", duration = 4, pandemic = true, caption = "Pandemic" },
    { dispel = "Poison", mine = true, icon = "Interface\\Icons\\Spell_Nature_CorrosiveBreath", duration = 3, pandemic = true, caption = "Pandemic" },
}

function opt.AddNameplatePandemicPreview(page, o)
    opt.AddPreview(page, {
        name = "Pandemic Preview",
        tooltip = "One of your nameplate debuffs normally and in its pandemic window, drawn with the pandemic settings above and your nameplate aura settings, at the size nameplates appear on screen.",
        height = STAGE_HEIGHT + CAPTION_HEIGHT + 12,
        create = function(parent)
            if not (UberUI.squareborders and UberUI.squareborders.CreateBorder) then return nil end
            return CreateAuraPreview(parent, o, PANDEMIC_SAMPLES)
        end,
    })
end

-- o: the AddAuraOptions table (loc, label, buffKey, debuffKey).
function opt.AddAuraPreview(page, o)
    local twoSizes = o.loc == "target" or o.loc == "focus" or o.loc == "boss"
    opt.AddPreview(page, {
        name = o.label .. " Preview",
        tooltip = "Sample " .. o.label .. " buffs and debuffs drawn with the settings below, at the size they appear on screen"
            .. (twoSizes and " (your auras large, others' small)" or "")
            .. ". Earth Shield and Agony show stack counts"
            .. (DURATION[o.loc] and "; Riptide, Magic, Agony and Poison show duration text when it's on (Agony with its stack count, Poison in the expiring color)" or "")
            .. ".",
        height = STAGE_HEIGHT + CAPTION_HEIGHT + 12,
        create = function(parent)
            if not (UberUI.squareborders and UberUI.squareborders.CreateBorder) then return nil end
            return CreateAuraPreview(parent, o)
        end,
    })
end
