-- Square pixel-depth aura borders (docs/square-borders.md), shared by every
-- aura location: Player (buffsandauras.lua), Target/Focus/Boss/Compact
-- (aurakit.lua), Party (partyframes.lua) and Arena (arenaframes.lua).
--
-- Four solid edge strips, a whole number of physical pixels thick, inset over
-- the icon's edge (default) or just outside it. Modeled on EllesmereUI's
-- PP.CreateBorder. Border objects live in a weak-keyed table, never as fields
-- on the owner, so this is safe to hang off Blizzard's own aura buttons.
--
-- Each location has its own on/off, thickness and inset settings. Player's
-- keep their original names so existing saved settings carry over.

local squareborders = {}

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

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

-- Locations: "player", "target", "focus", "boss", "party", "compact", "arena".
function squareborders.IsEnabled(loc)
    local g = uuidb and uuidb.general
    return g ~= nil and g[Keys(loc)[1]] == true
end

function squareborders.Thickness(loc)
    local g = uuidb and uuidb.general
    local px = g and tonumber(g[Keys(loc)[2]]) or 2
    return math.max(1, math.min(8, math.floor(px + 0.5)))
end

function squareborders.IsInset(loc)
    local g = uuidb and uuidb.general
    return not (g and g[Keys(loc)[3]] == false)
end

---------------------------------------------------------------------------
-- Geometry
---------------------------------------------------------------------------

-- N physical pixels -> UI units in `region`'s coordinate space. Always a
-- whole number of pixels, never less than 1, so a thin border can't land
-- between pixels and blur or round away.
function squareborders.PixelsToUIUnits(region, px)
    local factor = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()) or 1
    local ok, scale = pcall(region.GetEffectiveScale, region)
    if not ok or IsSecret(scale) or type(scale) ~= "number" or scale <= 0 then scale = 1 end
    return math.max(1, math.floor(px + 0.5)) * factor / scale
end

local function NewStrip(host)
    local t = host:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(1, 1, 1, 1)
    -- No pixel-grid snapping: a 1px strip must never round to 0 and vanish
    -- on one side at fractional scales/positions. Our own textures, so this
    -- is taint-safe.
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    return t
end

-- A border object is a frame with .edges = { top, bottom, left, right }.
-- Starts hidden; callers Show() it once it's laid out and colored.
function squareborders.CreateBorder(parent)
    local sb = CreateFrame("Frame", nil, parent)
    sb:EnableMouse(false)
    sb:Hide()
    sb.edges = { NewStrip(sb), NewStrip(sb), NewStrip(sb), NewStrip(sb) }
    return sb
end

-- Per-owner border (weak-keyed by owner, `slot` for owners needing more than
-- one), created on first use.
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

-- Positions `sb` around `region` (the icon): inset puts the strips on top of
-- the region's outer edge, outset puts them just outside it.
function squareborders.Layout(sb, region, px, inset)
    local t = squareborders.PixelsToUIUnits(sb, px)
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

-- Keeps the border above the owner's own art (icon, cooldown swipe, native
-- border textures).
function squareborders.RaiseAbove(sb, frame, bonus)
    local ok, level = pcall(frame.GetFrameLevel, frame)
    if ok and type(level) == "number" and not IsSecret(level) then
        sb:SetFrameLevel(level + (bonus or 5))
    end
end

---------------------------------------------------------------------------
-- Color
---------------------------------------------------------------------------

function squareborders.SetColor(sb, r, g, b, a)
    for i = 1, 4 do
        sb.edges[i]:SetVertexColor(r, g, b, a)
    end
end

function squareborders.SetDarkColor(sb)
    local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    squareborders.SetColor(sb, dc.r, dc.g, dc.b, dc.a)
end

-- Step curve for C_UnitAuras.GetAuraDispelTypeColor, keyed by the engine's
-- dispel-type IDs (0 none, 1 Magic, 2 Curse, 3 Disease, 4 Poison, 9 Enrage,
-- 11 Bleed), valued with Blizzard's own AuraUtil border colors. Anything
-- Blizzard has no color for (Enrage, unknown IDs) falls on a "None" point.
-- This is the secret-safe path: the returned color may be secret, but
-- SetVertexColor accepts it (same as Blizzard_CustomAuraButton does).
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

-- Blizzard's dispel-type color for a debuff, as r, g, b, a (possibly secret
-- values -- only ever pass them straight to SetVertexColor). Prefers the
-- engine curve when a usable (non-secret) aura instance ID is known, since
-- that works whether or not the dispel type itself is secret; otherwise uses
-- dispelName directly when it's readable; otherwise Blizzard's "None" color.
-- Used for both the square strips and the tinted rounded ring.
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
        -- IsSecret first: boolean-testing a secret value errors in addon code.
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

-- Registers each edge strip with the button's AddDispelTypeTexture, so the
-- ENGINE decides visibility and color from the real (otherwise secret) aura
-- data. AddDispelTypeTexture keeps a list, so several textures per button are
-- fine. It's denied outright while aura data is secret (loading screens), so
-- this retries every style pass until all four strips are in; each strip is
-- only ever registered once. Returns true once fully registered.
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

-- Debuffs: PreserveAsset keeps our solid strip texture and has the engine
-- apply AuraUtil.SetAuraBorderColor with the real dispel type.
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

-- Buffs: the square version of the "Show Dispels" stealable border -- white
-- strips (CustomAsset forces vertex color to white) that the engine only
-- shows on buffs that are actually stealable.
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
