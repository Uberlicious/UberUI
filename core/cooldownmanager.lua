local addon, ns = ...
local cdManager = UberUI:CreateFrame("frame")

-- Get mask from config (fallback to hardcoded if not available)
local function GetMaskTexture()
    if uuidb and uuidb.masks and uuidb.masks.cdm_mask then
        return uuidb.masks.cdm_mask
    end
    return [[Interface\AddOns\Uber UI\textures\statusbars\cdm_bar_mask.tga]]
end

-- Tuning knobs:
--   insetL/T/R/B: how much to crop in from each side (px)
--   shiftX/shiftY: move the whole mask without changing its size (px)
--     +X = move right,  -X = move left
--     +Y = move up,     -Y = move down
local MASK_OPTS = {
    insetL = 0,  -- left crop
    insetT = -2, -- top crop (raise top edge)
    insetR = 0,  -- right crop (pull right edge inward more)
    insetB = -2, -- bottom crop
    shiftX = 0,  -- whole mask shift on X
    shiftY = 0,  -- whole mask shift on Y (raise mask slightly)
}

local function ApplyMask(bar, opts)
    opts = opts or MASK_OPTS
    local L, T, R, B = opts.insetL or 0, opts.insetT or 0, opts.insetR or 0, opts.insetB or 0
    local SX, SY = opts.shiftX or 0, opts.shiftY or 0

    -- Create/reuse the mask
    if not bar._uberMask then
        local m = bar:CreateMaskTexture(nil, "OVERLAY")
        m:SetTexture(GetMaskTexture(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if m.SetSnapToPixelGrid then m:SetSnapToPixelGrid(true) end
        if m.SetTexelSnappingBias then m:SetTexelSnappingBias(0) end
        if m.SetHorizTile then m:SetHorizTile(false) end
        if m.SetVertTile then m:SetVertTile(false) end
        bar._uberMask = m
    end
    local m = bar._uberMask

    -- Position the mask relative to the BAR (not the BG)
    m:ClearAllPoints()
    -- Note: Y offsets: negative goes down for TOP anchors; positive goes up for BOTTOM anchors.
    m:SetPoint("TOPLEFT", bar, "TOPLEFT", L + SX, -(T - SY))
    m:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -R + SX, B + SY)
end

function cdManager:Texture()
    -- Safety checks
    if not BuffBarCooldownViewer then return end
    if not BuffBarCooldownViewer:IsShown() then return end
    if not uuidb or not uuidb.statusbars or not uuidb.general then return end

    local applyCustomLook = false
    local texture = nil

    if uuidb.cooldown.bartextures and uuidb.cooldown.bartexture ~= "Blizzard" then
        applyCustomLook = true
        texture = uuidb.statusbars[uuidb.cooldown.bartexture]
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        applyCustomLook = true
        texture = uuidb.statusbars[uuidb.general.texture]
    end

    if not texture then return end

    if not BuffBarCooldownViewer then return end
    local children = { BuffBarCooldownViewer:GetChildren() }
    if #children == 0 then return end

    for _, f in ipairs(children) do
        if f and f.Bar then
            local bar = f.Bar

            -- Find/create the fill we want to clip (only the fill is masked)
            local fill
            if bar:GetObjectType() == "StatusBar" then
                bar:SetStatusBarTexture(texture)
                fill = bar:GetStatusBarTexture()
            else
                for _, r in ipairs({ bar:GetRegions() }) do
                    if r:IsObjectType("Texture") and r:GetDrawLayer() == "ARTWORK" then
                        fill = r; break
                    end
                end
                if not fill then
                    fill = bar:CreateTexture(nil, "ARTWORK")
                end
                fill:SetAllPoints(bar)
                fill:SetTexture(texture)
            end

            -- Place the mask with custom insets + shift
            ApplyMask(bar, MASK_OPTS)

            -- Apply the mask ONLY to the fill
            if fill and bar._uberMask and not fill._masked then
                fill:AddMaskTexture(bar._uberMask)
                fill._masked = true
            end

            -- Keep mask aligned on resize and fix tiling on update
            if not bar._uberStyler then
                bar._uberStyler = true
                bar:HookScript("OnSizeChanged", function(self)
                    if self._uberMask then ApplyMask(self, MASK_OPTS) end
                end)
            end
        end
    end
end

function cdManager:Color()
    if not uuidb or not uuidb.general then return end

    if uuidb.cooldown.borders == false then
        local function DestroyBorders(viewer)
            if not viewer then return end
            for _, f in ipairs({ viewer:GetChildren() }) do
                if f.uberBorder then
                    f.uberBorder:Hide()
                    f.uberBorder = nil
                    f.styled = nil
                end
            end
        end
        if BuffBarCooldownViewer then DestroyBorders(BuffBarCooldownViewer) end
        if BuffIconCooldownViewer then DestroyBorders(BuffIconCooldownViewer) end
        if UtilityCooldownViewer then DestroyBorders(UtilityCooldownViewer) end
        if EssentialCooldownViewer then DestroyBorders(EssentialCooldownViewer) end
        return
    end

    local dc = uuidb.general.darkencolor

    -- Same border atlas AND the same proportional padding formula the rest
    -- of the addon's aura borders use (buffsandauras.lua's StyleAuraButton:
    -- 5px of padding at a 30px reference icon width), instead of a fixed
    -- pixel offset tuned for one specific icon size. Cooldown Viewer icons
    -- have their own user-adjustable size/padding per category in Edit Mode,
    -- so the border has to be computed from -- and kept in sync with -- each
    -- icon's actual current width, not a hardcoded constant.
    local AURA_BORDER_ATLAS = "ui-debuff-border-default-noicon"

    -- Tighter than the 5/30 ratio buffsandauras.lua uses elsewhere -- the
    -- border extends outward past the icon's own bounds on every side, and
    -- Cooldown Viewer icons can sit right next to each other (icon padding
    -- set to 0), so a bigger pad here means neighboring borders overlap.
    local function GetBorderPad(anchor)
        local width = anchor.GetWidth and anchor:GetWidth()
        if type(width) ~= "number" or width <= 0 then return 3 end
        return math.max(1, math.floor(width * (3 / 30) + 0.5))
    end

    local function PositionBorder(border, anchor)
        local pad = GetBorderPad(anchor)
        border:ClearAllPoints()
        border:SetPoint("TOPLEFT", anchor, "TOPLEFT", -pad, pad)
        border:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", pad, -pad)
    end

    local function CreateBorder(parent, anchor)
        local holder
        if anchor:IsObjectType("Frame") then
            holder = anchor
        else -- is a region
            holder = anchor:GetParent()
        end

        local borderTexture = holder:CreateTexture(nil, "OVERLAY", nil, -8)
        borderTexture:SetAtlas(AURA_BORDER_ATLAS)
        borderTexture:SetDesaturated(true)
        borderTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        PositionBorder(borderTexture, anchor)

        -- Edit Mode's icon size/padding sliders resize the icon frame
        -- directly and don't otherwise notify us -- keep the border in sync
        -- with that instead of only ever sizing it once at creation.
        if not holder._uberBorderSized then
            holder._uberBorderSized = true
            holder:HookScript("OnSizeChanged", function()
                PositionBorder(borderTexture, anchor)
            end)
        end

        return borderTexture
    end

    -- Safety checks for BuffBarCooldownViewer
    if BuffBarCooldownViewer and BuffBarCooldownViewer:IsShown() then
        local children = { BuffBarCooldownViewer:GetChildren() }
        for _, f in ipairs(children) do
            if f and f.Bar then
                -- Tint bar background
                for _, r in ipairs({ f.Bar:GetRegions() }) do
                    if r:IsObjectType("Texture") and r:GetDrawLayer() == "BACKGROUND" then
                        r:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                    end
                end
            end

            if f and not f.styled and f.Icon then
                local iconFrame = f.Icon
                local iconTexture
                for _, region in ipairs({ iconFrame:GetRegions() }) do
                    if region:IsObjectType("Texture") then
                        iconTexture = region
                        break
                    end
                end

                if iconTexture then
                    f.uberBorder = CreateBorder(f, iconFrame)
                    f.styled = true
                end
            end
        end
    end

    local function ApplyBordersToIconViewer(viewer)
        if viewer then
            local children = { viewer:GetChildren() }
            for _, f in ipairs(children) do
                if f and not f.styled and f.Icon then
                    local icon = f.Icon
                    if icon:IsObjectType("Frame") then
                        -- Handle case where f.Icon is a frame
                        local iconFrame = icon
                        local iconTexture
                        for _, region in ipairs({ iconFrame:GetRegions() }) do
                            if region:IsObjectType("Texture") then
                                iconTexture = region
                                break
                            end
                        end

                        if iconTexture then
                            f.uberBorder = CreateBorder(f, iconFrame)
                            f.styled = true
                        end
                    elseif icon:IsObjectType("Texture") then
                        -- Handle case where f.Icon is a texture
                        local iconTexture = icon
                        f.uberBorder = CreateBorder(f, iconTexture)
                        f.styled = true
                    end
                end
            end
        end
    end

    ApplyBordersToIconViewer(BuffIconCooldownViewer)
    ApplyBordersToIconViewer(UtilityCooldownViewer)
    ApplyBordersToIconViewer(EssentialCooldownViewer)
end

-------------------------------------------------------------------------------
-- Square icons ("Cooldown Manager Icon Shape: Square")
--
-- Blizzard draws every Cooldown Manager icon (Essential, Utility, tracked
-- buff icons, and the icon on tracked buff bars -- CooldownViewer.xml) through
-- a rounded mask (UI-HUD-CoolDownManager-Mask), with a ring overlay
-- (UI-HUD-CoolDownManager-IconOverlay) and a rounded-corner cooldown swipe.
-- Square mode takes the mask off the icon, hides the ring, zooms the icon
-- like our aura icons (the mask used to crop Blizzard's built-in icon edge),
-- gives the swipe a plain square texture, and draws a square border
-- (core/squareborders.lua, location "cdm": thickness / inside-outside) in
-- the darkness color in place of our rounded one. All of it is undone when
-- switching back. Blizzard only sets the mask, ring and swipe texture in XML
-- and re-sets the icon with SetTexture (which keeps texcoords), so nothing
-- needs re-applying on its updates; new item frames are styled as the
-- viewers lay them out (RefreshLayout hook below).
-------------------------------------------------------------------------------
local SB = UberUI.squareborders
local SQUARE_LOC = "cdm"
local RING_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local SWIPE_ROUNDED = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local SWIPE_SQUARE = "Interface\\Buttons\\WHITE8X8"
local squareState = setmetatable({}, { __mode = "k" }) -- item frame -> { masks, ring }
local function SquareOn()
    return SB and SB.IsEnabled(SQUARE_LOC)
end

-- The icon texture and the frame holding it: the icon itself on the icon
-- viewers, a nested .Icon frame on buff bars.
local function GetIconParts(f)
    local icon = f and f.Icon
    if not icon then return nil end
    if icon:IsObjectType("Frame") then
        return icon.Icon, icon
    end
    return icon, f
end

local function FindRing(holder)
    for _, region in ipairs({ holder:GetRegions() }) do
        if region:IsObjectType("Texture") and region.GetAtlas and region:GetAtlas() == RING_ATLAS then
            return region
        end
    end
end

local sizeHooked = setmetatable({}, { __mode = "k" })  -- icon holder -> true

-- Blizzard's mask only shows the middle of each icon frame: in the 64px mask
-- art (Interface/HUD/UICooldownManagerMask) the opaque area starts 3px in
-- from every edge. The viewers rely on that -- they place icon frames 4 units
-- closer than their size (CooldownViewerMixin:GetAdditionalPaddingOffset) so
-- the visible icons just touch. Square icons are inset by the same 3/64 per
-- side, or unmasked icons overlap their neighbors.
local MASK_INSET = 3 / 64

-- Tracked auras that are harmful (e.g. your DoTs on the target) get
-- Blizzard's dispel-type border (DebuffBorder, rounded per-type art --
-- CooldownViewerItemDebuffBorderMixin). In Square mode that art is hidden and
-- our square border takes the aura's dispel color instead (Blizzard's "None"
-- red for auras with no type), at the colored-border thickness. The color
-- comes from squareborders.GetDispelColor, which falls back to "None" if the
-- aura data is secret (instanced combat). Re-applied after each of Blizzard's
-- UpdateFromAuraData calls (hook installed on first Square use).
local debuffHooked = setmetatable({}, { __mode = "k" }) -- DebuffBorder -> item frame

local function SafeShown(region)
    local ok, shown = pcall(region.IsShown, region)
    if not ok or (issecretvalue and issecretvalue(shown)) then return false end
    return shown and true or false
end

-- "Cooldown Manager Debuff Border: Dark": harmful tracked auras (DoTs in the
-- Tracked Buffs section) get the same dark border as everything else instead
-- of Blizzard's dispel color (red for no type), so only the pandemic
-- highlight stands out.
local function DebuffBorderDark()
    return uuidb and uuidb.cooldown and uuidb.cooldown.debuffborder == "dark"
end

local function UpdateSquareDebuffColor(f)
    local db = f.DebuffBorder
    local sb = SB.Find(f, 1)
    local tex = GetIconParts(f)
    if not (db and tex) then return end
    if not squareState[f] then
        -- Rounded: Blizzard's own dispel border, unless Dark was chosen.
        db:SetAlpha(DebuffBorderDark() and 0 or 1)
        return
    end
    db:SetAlpha(0)
    -- Blizzard shows the DebuffBorder FRAME for every tracked aura and only
    -- shows its Texture for harmful ones (AuraUtil.SetAuraBorderAtlasFromAura).
    if not DebuffBorderDark() and SafeShown(db) and db.Texture and SafeShown(db.Texture) then
        sb = sb or SB.Get(f, 1)
        local unit = f.GetAuraDataUnit and f:GetAuraDataUnit()
        local aura = f.GetAuraDataCached and f:GetAuraDataCached()
        local dispelName, id
        if aura and not (issecretvalue and issecretvalue(aura)) then
            dispelName, id = aura.dispelName, aura.auraInstanceID
        end
        SB.LayoutDispelFor(sb, tex, SQUARE_LOC)
        SB.ApplyDispelColor(sb, dispelName, unit, id)
        SB.RaiseAbove(sb, f.Cooldown or f, 2)
        sb:Show()
    elseif sb then
        if uuidb.cooldown.borders == false then
            sb:Hide()
        else
            SB.LayoutFor(sb, tex, SQUARE_LOC)
            SB.SetDarkColor(sb)
            sb:Show()
        end
    end
end

local function EnsureDebuffHook(f)
    local db = f.DebuffBorder
    if not db or not db.UpdateFromAuraData or debuffHooked[db] then return end
    debuffHooked[db] = f
    hooksecurefunc(db, "UpdateFromAuraData", function(self)
        local item = debuffHooked[self]
        C_Timer.After(0, function()
            if item then pcall(UpdateSquareDebuffColor, item) end
        end)
    end)
end

local function LayoutSquareIcon(f, tex, holder)
    local ok, w = pcall(holder.GetWidth, holder)
    if not ok or type(w) ~= "number" or w <= 0 then return end
    local inset = w * MASK_INSET
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", holder, "TOPLEFT", inset, -inset)
    tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -inset, inset)
    if f.Cooldown then
        f.Cooldown:ClearAllPoints()
        f.Cooldown:SetAllPoints(tex)
    end
    local sb = SB.Find(f, 1)
    if sb and sb:IsShown() then SB.LayoutFor(sb, tex, SQUARE_LOC) end
    pcall(UpdateSquareDebuffColor, f)
end

local function ApplySquareIcon(f, square)
    local tex, holder = GetIconParts(f)
    if not tex then return end
    local state = squareState[f]

    if not square then
        if not state then return end
        for _, m in ipairs(state.masks) do pcall(tex.AddMaskTexture, tex, m) end
        if state.ring then state.ring:SetAlpha(1) end
        tex:SetTexCoord(0, 1, 0, 1)
        tex:ClearAllPoints()
        tex:SetAllPoints(holder)
        if f.Cooldown then
            pcall(f.Cooldown.SetSwipeTexture, f.Cooldown, SWIPE_ROUNDED)
            f.Cooldown:ClearAllPoints()
            f.Cooldown:SetAllPoints(f)
        end
        SB.Hide(f, 1)
        squareState[f] = nil
        if f.DebuffBorder then f.DebuffBorder:SetAlpha(1) end
        return
    end

    if not state then
        state = { masks = {} }
        -- Take Blizzard's rounded mask(s) off the icon, remembered for undo.
        local n = tex.GetNumMaskTextures and tex:GetNumMaskTextures() or 0
        for i = n, 1, -1 do
            local m = tex:GetMaskTexture(i)
            if m then
                state.masks[#state.masks + 1] = m
                tex:RemoveMaskTexture(m)
            end
        end
        state.ring = FindRing(holder)
        squareState[f] = state
    end
    if state.ring then state.ring:SetAlpha(0) end
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Edit Mode's icon size changes resize the frame directly.
    if not sizeHooked[holder] then
        sizeHooked[holder] = true
        holder:HookScript("OnSizeChanged", function()
            if squareState[f] then pcall(LayoutSquareIcon, f, tex, holder) end
        end)
    end
    if f.Cooldown then pcall(f.Cooldown.SetSwipeTexture, f.Cooldown, SWIPE_SQUARE) end

    if uuidb.cooldown.borders == false then
        SB.Hide(f, 1)
    else
        local sb = SB.Get(f, 1)
        SB.LayoutFor(sb, tex, SQUARE_LOC)
        SB.RaiseAbove(sb, f.Cooldown or holder, 2)
        SB.SetDarkColor(sb)
        sb:Show()
    end
    EnsureDebuffHook(f)
    LayoutSquareIcon(f, tex, holder)
end

-------------------------------------------------------------------------------
-- Pandemic highlight ("Cooldown Manager Pandemic Highlight")
--
-- Blizzard decides the pandemic window itself (CooldownViewerItemMixin:
-- CheckPandemicTimeDisplay) and calls ShowPandemicStateFrame /
-- HidePandemicStateFrame on the item; its own art (PandemicIcon, a pooled
-- CooldownPandemicFXTemplate) is rounded. With any style but "Blizzard", that
-- art is faded out and our highlight (aurakit.StyleHighlight -- the same
-- Border / Proc Glow / Marching Ants as nameplate auras, in the chosen color,
-- square when the icons are) is shown instead. No aura data is read, so it
-- works in combat and while aura data is secret. Hooks go on only once a
-- non-Blizzard style is picked; ShowPandemicStateFrame runs every frame while
-- in the window, so the hook only acts on changes, deferred a frame.
-------------------------------------------------------------------------------
local aurakit = UberUI.aurakit
local PANDEMIC_DEFAULT_COLOR = "ffff2626"
local pandemicHosts = setmetatable({}, { __mode = "k" })  -- item frame -> host
local pandemicHooked = setmetatable({}, { __mode = "k" }) -- item frame -> true

local function PandemicStyle()
    return (uuidb and uuidb.cooldown and uuidb.cooldown.pandemicstyle) or "blizzard"
end

local function PandemicColor()
    local hex = uuidb and uuidb.cooldown and uuidb.cooldown.pandemiccolor
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x%x%x$") then hex = PANDEMIC_DEFAULT_COLOR end
    local ok, c = pcall(CreateColorFromHexString, hex)
    if ok and c then return c.r, c.g, c.b end
    return 1, 0.15, 0.15
end

local function StylePandemicHost(f)
    local tex, holder = GetIconParts(f)
    if not tex then return nil end
    local host = pandemicHosts[f]
    if not host then
        host = CreateFrame("Frame", nil, f)
        host:SetAllPoints(holder)
        host:SetFrameLevel((f.Cooldown or holder):GetFrameLevel() + 4)
        host:EnableMouse(false)
        host:Hide()
        pandemicHosts[f] = host
    end
    local ok, w = pcall(tex.GetWidth, tex)
    local r, g, b = PandemicColor()
    aurakit.StyleHighlight(host, {
        kind = PandemicStyle(),
        r = r, g = g, b = b,
        square = squareState[f] ~= nil,
        loc = SQUARE_LOC, icon = tex,
        ringFrom = holder, ringX = -2,
        center = tex, size = (ok and type(w) == "number" and w > 0) and w or 36,
    })
    return host
end

-- Our highlight and Blizzard's art for the item's current pandemic state.
local function UpdatePandemic(f)
    local inWindow = f.PandemicIcon ~= nil and SafeShown(f.PandemicIcon)
    local custom = PandemicStyle() ~= "blizzard"
    if f.PandemicIcon then f.PandemicIcon:SetAlpha(custom and 0 or 1) end
    local host = pandemicHosts[f]
    if custom and inWindow then
        host = StylePandemicHost(f)
        if host then host:Show() end
    elseif host then
        host:Hide()
    end
end

local pandemicPending = setmetatable({}, { __mode = "k" })
local function QueuePandemic(f)
    if pandemicPending[f] then return end
    pandemicPending[f] = true
    C_Timer.After(0, function()
        pandemicPending[f] = nil
        pcall(UpdatePandemic, f)
    end)
end

local function EnsurePandemicHooks(f)
    if pandemicHooked[f] or not f.ShowPandemicStateFrame then return end
    pandemicHooked[f] = true
    hooksecurefunc(f, "ShowPandemicStateFrame", function(self)
        -- Every frame while in the window: only act when ours isn't up yet.
        local host = pandemicHosts[self]
        if PandemicStyle() ~= "blizzard" and host and host:IsShown() then return end
        QueuePandemic(self)
    end)
    if f.HidePandemicStateFrame then
        hooksecurefunc(f, "HidePandemicStateFrame", function(self) QueuePandemic(self) end)
    end
end

local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local function ForEachItemFrame(fn)
    for _, name in ipairs(VIEWERS) do
        local viewer = _G[name]
        if viewer then
            for _, f in ipairs({ viewer:GetChildren() }) do
                if f and f.Icon then fn(f) end
            end
        end
    end
end

-- Debug (/uuidebugcdm): what each tracked buff icon is actually drawing.
function cdManager:DebugReport()
    local lines = { "==== cooldown manager icon report ====",
        "square: " .. tostring(SquareOn()) .. "  pandemic style: " .. PandemicStyle() }
    local function fmt(v)
        if issecretvalue and issecretvalue(v) then return "<secret>" end
        if type(v) == "number" then return string.format("%.2f", v) end
        return tostring(v)
    end
    for _, name in ipairs({ "BuffIconCooldownViewer", "EssentialCooldownViewer" }) do
        local viewer = _G[name]
        if viewer then
            lines[#lines + 1] = "-- " .. name
            local n = 0
            for _, f in ipairs({ viewer:GetChildren() }) do
                if f.Icon and n < 8 then
                    local okS, shown = pcall(f.IsShown, f)
                    if okS and shown == true then
                        n = n + 1
                        local db = f.DebuffBorder
                        local sb = SB.Find(f, 1)
                        local r, g, b
                        if sb and sb.edges then r, g, b = sb.edges[1]:GetVertexColor() end
                        local host = pandemicHosts[f]
                        local spell = f.GetSpellID and f:GetSpellID()
                        lines[#lines + 1] = string.format(
                            "  spell=%s debuffFrame=%s debuffTex=%s dbAlpha=%s | our border shown=%s color=%s,%s,%s | pandemicIcon=%s ourHost=%s",
                            fmt(spell), fmt(db and db:IsShown()), fmt(db and db.Texture and db.Texture:IsShown()),
                            fmt(db and db:GetAlpha()), fmt(sb and sb:IsShown()), fmt(r), fmt(g), fmt(b),
                            fmt(f.PandemicIcon ~= nil), fmt(host and host:IsShown()))
                    end
                end
            end
        end
    end
    return table.concat(lines, "\n")
end

function cdManager:StyleIcons()
    if not (uuidb and uuidb.cooldown and SB) then return end
    local square = SquareOn()
    ForEachItemFrame(function(f)
        pcall(ApplySquareIcon, f, square)
        if DebuffBorderDark() then EnsureDebuffHook(f) end
        if debuffHooked[f.DebuffBorder or 0] then pcall(UpdateSquareDebuffColor, f) end
        if PandemicStyle() ~= "blizzard" then EnsurePandemicHooks(f) end
        if pandemicHooked[f] then
            -- Restyle a highlight that's up (settings change) or put
            -- Blizzard's art back.
            if pandemicHosts[f] then pcall(StylePandemicHost, f) end
            pcall(UpdatePandemic, f)
        end
        -- Our rounded border (Color) only in Rounded mode.
        if f.uberBorder then f.uberBorder:SetShown(not square) end
    end)
end

-- New item frames appear when a viewer lays out (spec change, Edit Mode
-- count/size change, settings changes): style them once it's done.
local layoutHooked = false
local stylePending = false
local function QueueStyle()
    if stylePending then return end
    stylePending = true
    C_Timer.After(0, function()
        stylePending = false
        cdManager:Texture()
        cdManager:Color()
        cdManager:StyleIcons()
    end)
end

local function EnsureLayoutHooks()
    if layoutHooked then return end
    layoutHooked = true
    for _, name in ipairs(VIEWERS) do
        local viewer = _G[name]
        if viewer and viewer.RefreshLayout then
            hooksecurefunc(viewer, "RefreshLayout", QueueStyle)
        end
    end
end

-- Register the specific callback we need
local function RegisterCooldownCallbacks()
    if cdManager._callbackRegistered then return end

    -- This is the specific callback that fires when hovering items in settings
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnEnterItem", function(cooldownItem)
        QueueStyle()
    end, cdManager)

    -- Also register for data changes (when items added/removed)
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
        QueueStyle()
    end, cdManager)

    cdManager._callbackRegistered = true
end

-- Wait for CooldownViewer to load
cdManager:RegisterEvent("ADDON_LOADED")
cdManager:RegisterEvent("PLAYER_ENTERING_WORLD")

cdManager:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon == "Blizzard_CooldownViewer" then
        local function applyStyling()
            cdManager:Texture()
            cdManager:Color()
            cdManager:StyleIcons()
        end
        EnsureLayoutHooks()

        -- Hook OnShow for all relevant viewers to apply styling when they are enabled
        if BuffBarCooldownViewer then BuffBarCooldownViewer:HookScript("OnShow", applyStyling) end
        if BuffIconCooldownViewer then BuffIconCooldownViewer:HookScript("OnShow", applyStyling) end
        if UtilityCooldownViewer then UtilityCooldownViewer:HookScript("OnShow", applyStyling) end
        if EssentialCooldownViewer then EssentialCooldownViewer:HookScript("OnShow", applyStyling) end

        -- Give it a moment to fully initialize
        C_Timer.After(0.5, function()
            RegisterCooldownCallbacks()
            -- Apply initial styling
            applyStyling()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Apply styling on world enter (after everything is loaded)
        C_Timer.After(1, function()
            if EventRegistry then
                RegisterCooldownCallbacks()
            end
            self:Texture()
            self:Color()
            self:StyleIcons()
        end)
    end
end)

-- Public function for manual refresh
function cdManager:Refresh()
    self:Texture()
    self:Color()
    self:StyleIcons()
end

UberUI.cdManager = cdManager
