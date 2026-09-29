-- Square pixel-depth aura borders (docs/square-borders.md), shared by every
-- aura location. Four solid edge strips a whole number of physical pixels
-- thick, inset over the icon's edge or just outside it. Kept in a weak table,
-- never as fields on the owner. Each location has its own on/off, thickness
-- and inset settings (Player's keep their original names).

local squareborders = {}

local IsSecret = UberUI.util.IsSecret

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local LOCATION_KEYS = {
    player = { "squareauraborders_player", "squareauraborders_thickness", "squareauraborders_inset" },
}

local function Keys(loc)
    local k = LOCATION_KEYS[loc]
    if not k then
        k = { "squareauraborders_" .. loc, "squareauraborders_" .. loc .. "_thickness",
              "squareauraborders_" .. loc .. "_inset" }
        LOCATION_KEYS[loc] = k
    end
    return k
end
squareborders.Keys = Keys

-- Locations: "player", "target", "focus", "boss", "party", "compact", "arena", "nameplate", "cdm".
function squareborders.IsEnabled(loc)
    local g = uuidb and uuidb.general
    return g ~= nil and g[Keys(loc)[1]] == true
end

function squareborders.Thickness(loc)
    local g = uuidb and uuidb.general
    local px = g and tonumber(g[Keys(loc)[2]]) or 1
    return math.max(1, math.min(8, math.floor(px + 0.5)))
end

function squareborders.IsInset(loc)
    local g = uuidb and uuidb.general
    return not (g and g[Keys(loc)[3]] == false)
end

---------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------

-- N physical pixels -> UI units in `region`'s space: whole pixels, at least 1.
function squareborders.PixelsToUIUnits(region, px)
    local factor = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()) or 1
    local ok, scale = pcall(region.GetEffectiveScale, region)
    if not ok or IsSecret(scale) or type(scale) ~= "number" or scale <= 0 then scale = 1 end
    return math.max(1, math.floor(px + 0.5)) * factor / scale
end

local function NewStrip(host)
    local t = host:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(1, 1, 1, 1)
    -- Unsnapped so a 1px strip never rounds to 0 at fractional positions.
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    return t
end

-- A border: a frame with .edges = { top, bottom, left, right }, hidden until
-- the caller lays it out and shows it.
function squareborders.CreateBorder(parent)
    local sb = CreateFrame("Frame", nil, parent)
    sb:EnableMouse(false)
    sb:Hide()
    sb.edges = { NewStrip(sb), NewStrip(sb), NewStrip(sb), NewStrip(sb) }
    return sb
end

-- Per-owner border (`slot` for owners needing several), created on first use.
local borders = setmetatable({}, { __mode = "k" })

function squareborders.Get(owner, slot)
    slot = slot or 1
    local set = borders[owner]
    if not set then
        set = {}
        borders[owner] = set
    end
    local sb = set[slot]
    if not sb then
        sb = squareborders.CreateBorder(owner)
        set[slot] = sb
    elseif sb:GetParent() ~= owner then
        sb:SetParent(owner)
    end
    return sb
end

function squareborders.Find(owner, slot)
    local set = borders[owner]
    return set and set[slot or 1]
end

function squareborders.Hide(owner, slot)
    local sb = squareborders.Find(owner, slot)
    if sb then sb:Hide() end
end

-- Inset puts the strips over the region's edge, outset just outside it.
function squareborders.Layout(sb, region, px, inset)
    local t = squareborders.PixelsToUIUnits(region or sb, px)
    local o = inset and 0 or t
    sb:ClearAllPoints()
    sb:SetPoint("TOPLEFT", region, "TOPLEFT", -o, o)
    sb:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", o, -o)
    local top, bottom, left, right = sb.edges[1], sb.edges[2], sb.edges[3], sb.edges[4]
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", sb, "TOPLEFT")
    top:SetPoint("TOPRIGHT", sb, "TOPRIGHT")
    top:SetHeight(t)
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", sb, "BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT", sb, "BOTTOMRIGHT")
    bottom:SetHeight(t)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", sb, "TOPLEFT", 0, -t)
    left:SetPoint("BOTTOMLEFT", sb, "BOTTOMLEFT", 0, t)
    left:SetWidth(t)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", sb, "TOPRIGHT", 0, -t)
    right:SetPoint("BOTTOMRIGHT", sb, "BOTTOMRIGHT", 0, t)
    right:SetWidth(t)
    return t
end

-- Layout from a location's own settings; returns the thickness in UI units.
function squareborders.LayoutFor(sb, region, loc)
    return squareborders.Layout(sb, region, squareborders.Thickness(loc), squareborders.IsInset(loc))
end

-- Dispel-colored borders can optionally be drawn 1px thicker than the dark
-- border so the color reads better at small sizes. On by default (matches
-- the original, unconditional behavior); one option, not per-location, since
-- the bonus itself was never per-location either.
function squareborders.DispelThicknessBonusEnabled()
    local g = uuidb and uuidb.general
    return g ~= nil and g.squaredispelborderthicker == true
end

function squareborders.DispelThickness(loc)
    local bonus = squareborders.DispelThicknessBonusEnabled() and 1 or 0
    return squareborders.Thickness(loc) + bonus
end

function squareborders.LayoutDispelFor(sb, region, loc)
    return squareborders.Layout(sb, region, squareborders.DispelThickness(loc), squareborders.IsInset(loc))
end

function squareborders.RaiseAbove(sb, frame, bonus)
    local ok, level = pcall(frame.GetFrameLevel, frame)
    if ok and type(level) == "number" and not IsSecret(level) then
        sb:SetFrameLevel(level + (bonus or 5))
    end
end

---------------------------------------------------------------------------
-- Color
---------------------------------------------------------------------------

-- Base colors to match Blizzard's native frame art (Forever copper:
-- 0.60/0.45/0.35; neutral silver: 0.5).
local BORDER_BASE_COPPER = { r = 0.60, g = 0.45, b = 0.35 }
local BORDER_BASE_SILVER = { r = 0.50, g = 0.50, b = 0.50 }

function squareborders.GetBorderBase()
    return UberUI.util.IsForeverClient() and BORDER_BASE_COPPER or BORDER_BASE_SILVER
end

function squareborders.SetColor(sb, r, g, b, a)
    for i = 1, 4 do
        sb.edges[i]:SetVertexColor(r, g, b, a)
    end
end

function squareborders.SetDarkColor(sb)
    local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    local base = squareborders.GetBorderBase()
    squareborders.SetColor(sb, dc.r * base.r, dc.g * base.g, dc.b * base.b, dc.a)
end

-- Step curve for C_UnitAuras.GetAuraDispelTypeColor over the engine's
-- dispel-type IDs, valued with Blizzard's AuraUtil border colors. The result
-- may be secret, but SetVertexColor accepts it.
local dispelColorCurve
function squareborders.GetDispelColorCurve()
    if dispelColorCurve ~= nil then return dispelColorCurve or nil end
    dispelColorCurve = false
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType
        and C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor
        and AuraUtil and AuraUtil.GetAuraBorderColor) then
        return nil
    end
    pcall(function()
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        for _, p in ipairs({ { 0, "None" }, { 1, "Magic" }, { 2, "Curse" }, { 3, "Disease" },
                             { 4, "Poison" }, { 5, "None" }, { 11, "Bleed" }, { 12, "None" } }) do
            curve:AddPoint(p[1], AuraUtil.GetAuraBorderColor(p[2]))
        end
        dispelColorCurve = curve
    end)
    return dispelColorCurve or nil
end

-- Blizzard's dispel color as r, g, b, a (possibly secret: only pass to
-- SetVertexColor). Engine curve when the aura instance ID is readable, else
-- dispelName when readable, else Blizzard's "None" color.
function squareborders.GetDispelColor(dispelName, unit, auraInstanceID)
    if unit and auraInstanceID and not IsSecret(auraInstanceID) and not IsSecret(unit) then
        local curve = squareborders.GetDispelColorCurve()
        if curve then
            local okC, color = pcall(C_UnitAuras.GetAuraDispelTypeColor, unit, auraInstanceID, curve)
            if okC and color then
                return color:GetRGBA()
            end
        end
    end
    if AuraUtil and AuraUtil.GetAuraBorderColor then
        local key = "None"
        if not IsSecret(dispelName) and type(dispelName) == "string" and dispelName ~= "" then
            key = dispelName
        end
        local okC, color = pcall(AuraUtil.GetAuraBorderColor, key)
        if okC and color then
            return color:GetRGBA()
        end
    end
    return 0.8, 0, 0, 1
end

function squareborders.ApplyDispelColor(sb, dispelName, unit, auraInstanceID)
    squareborders.SetColor(sb, squareborders.GetDispelColor(dispelName, unit, auraInstanceID))
end

---------------------------------------------------------------------------
-- Engine-colored strips for CustomAuraContainer buttons (aurakit.lua)
---------------------------------------------------------------------------

-- Registers each strip with AddDispelTypeTexture so the engine decides
-- visibility and color from the secret aura data. Refused while aura data is
-- secret, so callers retry every style pass. True once all four are in.
function squareborders.RegisterEngineStrips(button, sb, options)
    if sb.engineRegistered then return true end
    if type(button.AddDispelTypeTexture) ~= "function" then return false end
    sb.engineCount = sb.engineCount or 0
    while sb.engineCount < 4 do
        local ok = pcall(button.AddDispelTypeTexture, button, sb.edges[sb.engineCount + 1], options)
        if not ok then return false end
        sb.engineCount = sb.engineCount + 1
    end
    sb.engineRegistered = true
    return true
end

-- Debuffs: PreserveAsset keeps our strip and the engine colors it.
function squareborders.DebuffEngineOptions()
    local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    if not (styles and styles.PreserveAsset) then return nil end
    return {
        style = styles.PreserveAsset,
        showWhenHarmful = true,
        showWhenHelpful = false,
        showWithoutDispelType = true,
    }
end

-- Buffs: white strips (CustomAsset) the engine only shows on stealable buffs.
local WHITE_ASSET = { asset = "Interface\\Buttons\\WHITE8X8" }
local WHITE_DISPEL_ASSET_MAP = {
    Magic = WHITE_ASSET, Curse = WHITE_ASSET, Poison = WHITE_ASSET,
    Disease = WHITE_ASSET, Bleed = WHITE_ASSET, None = WHITE_ASSET,
}

function squareborders.StealableEngineOptions()
    local styles = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
    if not (styles and styles.CustomAsset) then return nil end
    return {
        style = styles.CustomAsset,
        showWhenHarmful = false,
        showWhenHelpful = true,
        showWithoutDispelType = true,
        stealableFilter = Enum.CustomAuraButtonDispelTypeStealableFilter and
            Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable,
        customDispelAssetMap = WHITE_DISPEL_ASSET_MAP,
    }
end

UberUI.squareborders = squareborders
