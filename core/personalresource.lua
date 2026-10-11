local addon, ns = ...
local prd = {}

local IsSecret = UberUI.util.IsSecret

-- Region getters can return secret values (e.g. the heal prediction
-- textures); compare only plain ones.
local function Plain(v)
    if IsSecret(v) then return nil end
    return v
end
local function DrawLayer(region)
    local ok, layer = pcall(region.GetDrawLayer, region)
    return ok and Plain(layer) or nil
end
local function Atlas(region)
    local ok, atlas = pcall(region.GetAtlas, region)
    return ok and Plain(atlas) or nil
end

local function GetMaskTexture()
    if uuidb and uuidb.masks and uuidb.masks.cdm_mask then
        return uuidb.masks.cdm_mask
    end
    return [[Interface\AddOns\Uber UI\textures\statusbars\cdm_bar_mask.tga]]
end

local MASK_OPTS = {
    insetL = 0,  -- left crop
    insetT = 0,  -- top crop (raise top edge)
    insetR = 0,  -- right crop (pull right edge inward more)
    insetB = -1, -- bottom crop
    shiftX = 0,  -- whole mask shift on X
    shiftY = 0,  -- whole mask shift on Y (raise mask slightly)
}

function prd:StyleStatusBar(healthBar)
    if not healthBar then return end

    local textureToApply
    if uuidb.general.personalresourcebartextures and uuidb.general.personalresourcebartexture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.personalresourcebartexture]
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    if textureToApply and type(textureToApply) == "string" then
        healthBar:SetStatusBarTexture(textureToApply)

        local sbt = healthBar:GetStatusBarTexture()
        if sbt then
            sbt:SetDrawLayer("ARTWORK", 1)
        end

        local bgRegions = { healthBar:GetRegions() }
        for _, region in ipairs(bgRegions) do
            if region:IsObjectType("Texture") and DrawLayer(region) == "BACKGROUND" then
                local dc = uuidb.general.darkencolor
                region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
        end
    end

    -- Square bars are flat: no rounded-end mask (and drop one added before).
    if prd.SquareOn() then
        local fill = healthBar.GetStatusBarTexture and healthBar:GetStatusBarTexture()
        if fill and fill._masked and healthBar._uberMask and fill.RemoveMaskTexture then
            fill:RemoveMaskTexture(healthBar._uberMask)
            fill._masked = nil
        end
        return
    end

    if healthBar.CreateMaskTexture and healthBar.GetStatusBarTexture then
        local opts = MASK_OPTS
        local L, T, R, B = opts.insetL or 0, opts.insetT or 0, opts.insetR or 0, opts.insetB or 0
        local SX, SY = opts.shiftX or 0, opts.shiftY or 0

        if not healthBar._uberMask then
            local m = healthBar:CreateMaskTexture(nil, "OVERLAY")
            if m and m.SetTexture then
                m:SetTexture(GetMaskTexture(), "CLAMPTOBLACK", "CLAMPTOBLACK")
                if m.SetSnapToPixelGrid then m:SetSnapToPixelGrid(true) end
                if m.SetTexelSnappingBias then m:SetTexelSnappingBias(0) end
                if m.SetHorizTile then m:SetHorizTile(false) end
                if m.SetVertTile then m:SetVertTile(false) end
                healthBar._uberMask = m
            end
        end
        local m = healthBar._uberMask

        if m and m.ClearAllPoints and m.SetPoint then
            m:ClearAllPoints()
            m:SetPoint("TOPLEFT", healthBar, "TOPLEFT", L + SX, -(T - SY))
            m:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -R + SX, B + SY)
        end

        local fill = healthBar:GetStatusBarTexture()
        if fill and m and fill.AddMaskTexture and not fill._masked then
            fill:AddMaskTexture(m)
            fill._masked = true
        end
    end
end

-------------------------------------------------------------------------------
-- Square bars (squareborders location "prd"): Blizzard's rounded bar art
-- hidden, a flat fill (Blizzard_Flat unless a bar texture is chosen) over a
-- dark background, and a square border of exact pixel thickness just
-- outside each bar. Blizzard always keeps a minimum gap between bars for its
-- rounded art (GetMinimumBarPadding); with Edit Mode's bar padding at 0 the
-- lower bars are pulled up onto the bar above so neighbors share one border
-- line (JoinBar).
-------------------------------------------------------------------------------
local SQUARE_LOC = "prd"
local SQUARE_BG_ALPHA = 0.5
local BAR_ATLAS, BAR_BG_ATLAS = "UI-HUD-CoolDownManager-Bar", "UI-HUD-CoolDownManager-Bar-BG"
local squareState = setmetatable({}, { __mode = "k" }) -- bar -> { bg, flat, art, moved }

function prd.SquareOn()
    return UberUI.squareborders and UberUI.squareborders.IsEnabled(SQUARE_LOC)
end

local function HasCustomTexture()
    local g = uuidb.general
    return (g.personalresourcebartextures and g.personalresourcebartexture ~= "Blizzard")
        or (g.allbartextures and g.texture ~= "Blizzard")
end

-- "Darken Border": dark, else the native (undarkened) border tone.
local function BorderColor()
    local SB = UberUI.squareborders
    local base = SB.GetBorderBase()
    if uuidb.general.darkenpersonalresourceborder then
        local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        return dc.r * base.r, dc.g * base.g, dc.b * base.b, dc.a
    end
    return base.r, base.g, base.b, 1
end

-- Blizzard's rounded background/border art on the bar (its BG atlas).
local function BarArt(bar, st)
    if st.art then return st.art end
    for _, region in ipairs({ bar:GetRegions() }) do
        if region:IsObjectType("Texture") and Atlas(region) == BAR_BG_ATLAS then
            st.art = region
            return region
        end
    end
end

-- `joined`: sits directly under another bar, sharing its border line.
local function SquareBar(bar, on, joined)
    local SB = UberUI.squareborders
    local st = squareState[bar]
    if not st then
        if not on then return end
        st = {}
        squareState[bar] = st
    end
    local art = BarArt(bar, st)

    if not on then
        if art then
            art:SetAlpha(1)
            art:Show()
        end
        if st.bg then st.bg:Hide() end
        SB.Hide(bar, 1)
        if st.flat then
            local fill = bar:GetStatusBarTexture()
            if fill then fill:SetAtlas(BAR_ATLAS) end
            st.flat = nil
        end
        return
    end

    -- Hidden, not just faded: a texture's alpha is its vertex color alpha,
    -- so any SetVertexColor would bring faded art back. Blizzard never
    -- re-shows it.
    if art then
        art:SetAlpha(0)
        art:Hide()
    end
    if not st.bg then
        st.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
        st.bg:SetColorTexture(0, 0, 0, 1)
        st.bg:SetAllPoints(bar)
        st.bg:SetSnapToPixelGrid(false)
        st.bg:SetTexelSnappingBias(0)
    end
    st.bg:SetVertexColor(0, 0, 0, SQUARE_BG_ALPHA)
    st.bg:Show()
    -- Blizzard's own fill is rounded; a chosen bar texture is applied by
    -- StyleStatusBar instead.
    if not HasCustomTexture() then
        local bars = uuidb.statusbars or {}
        bar:SetStatusBarTexture(bars["Blizzard_Flat"] or "Interface\\AddOns\\Uber UI\\textures\\statusbars\\nameplate")
        st.flat = true
    end

    local sb = SB.Get(bar, 1)
    SB.Layout(sb, bar, SB.Thickness(SQUARE_LOC), false)
    SB.SetColor(sb, BorderColor())
    SB.RaiseAbove(sb, bar, 2)
    -- Joined: the bar above's bottom line is the shared one.
    sb.edges[1]:SetShown(not joined)
    sb:Show()
end

-- Joined bars: Blizzard anchors a lower bar `GetBarPadding()` below the one
-- above it, never less than its minimum gap. To share one border line, the
-- lower bar is re-anchored (our own SetPoint, never Blizzard's update
-- functions) so its top sits on the upper bar's bottom border line. Undone
-- by re-applying Blizzard's own anchor rule (UpdatePowerBarAnchor /
-- UpdateAdditionalBarAnchors) -- not by reading GetPoint, whose values
-- can't be relied on here.
local function BlizzardAnchor(frame, bar)
    local padding = tonumber(frame:GetBarPadding()) or 0
    if bar == frame.PowerBar then
        if frame.hideHealth then return frame, "TOP", 0 end
        return frame.HealthBarsContainer, "BOTTOM", -padding
    elseif bar == frame.AlternatePowerBar then
        if not frame.hidePower then return frame.PowerBar, "BOTTOM", -padding end
        if not frame.hideHealth then return frame.HealthBarsContainer, "BOTTOM", -padding end
        return frame, "TOP", 0
    end
end

local function JoinBar(frame, bar, rel)
    local st = squareState[bar]
    if rel then
        local y = -UberUI.squareborders.PixelsToUIUnits(bar, UberUI.squareborders.Thickness(SQUARE_LOC))
        bar:ClearAllPoints()
        bar:SetPoint("TOP", rel, "BOTTOM", 0, y)
        st.moved = true
    elseif st and st.moved then
        local anchor, relPoint, y = BlizzardAnchor(frame, bar)
        if anchor then
            bar:ClearAllPoints()
            bar:SetPoint("TOP", anchor, relPoint, 0, y)
        end
        st.moved = nil
    end
end

function prd:ApplySquare(frame)
    if not frame then return end
    local on = prd.SquareOn()
    -- Edit Mode's own padding (GetBarPadding adds Blizzard's minimum gap).
    local padding = frame.GetBarPadding and tonumber(frame:GetBarPadding())
    local minimum = frame.GetMinimumBarPadding and tonumber(frame:GetMinimumBarPadding()) or 0
    local join = on and padding ~= nil and padding - minimum <= 0
    local container = frame.HealthBarsContainer
    -- { bar, the frame Blizzard anchors the next bar to, shown }
    local stack = {
        { container and container.healthBar, container, container and container:IsShown() },
        { frame.PowerBar, frame.PowerBar, frame.PowerBar and frame.PowerBar:IsShown() },
        { frame.AlternatePowerBar, frame.AlternatePowerBar, frame.AlternatePowerBar and frame.AlternatePowerBar:IsShown() },
    }
    local aboveRel
    for i, entry in ipairs(stack) do
        local bar, anchor, shown = entry[1], entry[2], entry[3]
        if bar then
            shown = shown and bar:IsShown()
            local joinRel = shown and join and i > 1 and aboveRel or nil
            local ok, err = pcall(function()
                SquareBar(bar, on and shown, joinRel ~= nil)
                JoinBar(frame, bar, joinRel)
            end)
            if not ok then UberUI:ReportError("PRD square bars", err) end
            if shown then aboveRel = anchor end
        end
    end
end

function prd:StylePRD(frame)
    if not frame then return end

    if frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar then
        local healthBar = frame.HealthBarsContainer.healthBar
        self:StyleStatusBar(healthBar)

        -- Secondary texture logic for absorbs and heals
        local secondaryTextureToApply
        if uuidb.general.secondarybartextures and uuidb.general.secondarybartexture ~= "Blizzard" then
            secondaryTextureToApply = uuidb.statusbars[uuidb.general.secondarybartexture]
        else
            if uuidb.general.personalresourcebartextures and uuidb.general.personalresourcebartexture ~= "Blizzard" then
                secondaryTextureToApply = uuidb.statusbars[uuidb.general.personalresourcebartexture]
            elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
                secondaryTextureToApply = uuidb.statusbars[uuidb.general.texture]
            end
        end

        if secondaryTextureToApply then
            if healthBar.myHealPrediction then
                healthBar.myHealPrediction:SetTexture(secondaryTextureToApply)
                if CUF_MY_HEAL_PREDICTION_COLOR then
                    healthBar.myHealPrediction:SetVertexColor(CUF_MY_HEAL_PREDICTION_COLOR:GetRGBA())
                else
                    healthBar.myHealPrediction:SetVertexColor(11/255, 136/255, 105/255, 1)
                end
            end
            if healthBar.otherHealPrediction then
                healthBar.otherHealPrediction:SetTexture(secondaryTextureToApply)
                if CUF_OTHER_HEAL_PREDICTION_COLOR then
                    healthBar.otherHealPrediction:SetVertexColor(CUF_OTHER_HEAL_PREDICTION_COLOR:GetRGBA())
                else
                    healthBar.otherHealPrediction:SetVertexColor(21/255, 89/255, 72/255, 1)
                end
            end
            if healthBar.totalAbsorb then
                healthBar.totalAbsorb:SetTexture(secondaryTextureToApply)
                healthBar.totalAbsorb:SetVertexColor(.6, .9, .9, 1)
            end
        end
    end

    if frame.PowerBar then
        self:StyleStatusBar(frame.PowerBar)
    end

    if frame.AlternatePowerBar then
        self:StyleStatusBar(frame.AlternatePowerBar)
    end

    self:ApplySquare(frame)
end

-- Setup hooks installed lazily once their setting is active. They go on the
-- frame itself: Blizzard_PersonalResourceDisplay builds PersonalResourceDisplayFrame
-- (copying the mixin's functions onto it) before its ADDON_LOADED, so a hook
-- on PersonalResourceDisplayMixin would never run for it.
local function HookTarget()
    if PersonalResourceDisplayFrame and type(PersonalResourceDisplayFrame.Setup) == "function" then
        return PersonalResourceDisplayFrame
    end
    if PersonalResourceDisplayMixin and type(PersonalResourceDisplayMixin.Setup) == "function" then
        return PersonalResourceDisplayMixin
    end
end

-- Darkens the bar border art (atlased on the StatusBars themselves in 12.1),
-- or restores what it darkened when the setting is off. Square bars hide
-- that art and color their own border instead (SquareBar).
local darkenedArt = setmetatable({}, { __mode = "k" }) -- texture -> true

local function SetDarkened(region, darken, dc)
    if darken then
        region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        darkenedArt[region] = true
    elseif darkenedArt[region] then
        region:SetVertexColor(1, 1, 1, 1)
        darkenedArt[region] = nil
    end
end

-- Class resource art on the PRD's own class frame instance. Retail builds it
-- from the same templates as the player frame's class bars, so this matches
-- what playerframe.lua darkens there (frame: textures on the class frame
-- itself; points: textures on each resource point). Forever never creates
-- one (its PRD GetClassFrameInfo returns nil), so this is a no-op there.
-- Points come from a pool that grows when max power changes, so
-- UpdateMaxPower is hooked (once darkening is on) to catch new ones.
local CLASS_RESOURCE_ART = {
    PALADIN = { frame = { "Background", "ActiveTexture" } }, -- PaladinPowerBarFrameTemplate
    ROGUE   = { points = { "BGActive", "BGInactive" } },     -- RogueComboPointTemplate
    DRUID   = { points = { "BG_Active", "BG_Inactive", "BGActive", "BGInactive" } }, -- DruidComboPointTemplate (Forever: RogueComboPointTemplate)
    WARLOCK = { points = { "Background" } },                 -- ShardTemplate
    MONK    = { points = { "Chi_BG", "Chi_BG_Active" } },    -- MonkLightEnergyTemplate
}
local classFrameHooked = setmetatable({}, { __mode = "k" })
local function DarkenClassPoints(frame, darken, dc)
    local classFrame = frame.classFrame
    local art = CLASS_RESOURCE_ART[select(2, UnitClass("player"))]
    if not (classFrame and art) then return end
    local function Darken(owner, keys)
        for _, key in ipairs(keys) do
            local region = owner[key]
            if type(region) == "table" and region.SetVertexColor then SetDarkened(region, darken, dc) end
        end
    end
    if art.frame then Darken(classFrame, art.frame) end
    if art.points then
        if darken and not classFrameHooked[classFrame] and type(classFrame.UpdateMaxPower) == "function" then
            classFrameHooked[classFrame] = true
            hooksecurefunc(classFrame, "UpdateMaxPower", function()
                C_Timer.After(0, function() UberUI.personalresource:DarkenBorder(frame) end)
            end)
        end
        for _, point in ipairs({ classFrame:GetChildren() }) do
            Darken(point, art.points)
        end
    end
end

function prd:DarkenBorder(frame)
    if not frame then return end
    local dc = uuidb.general.darkencolor
    DarkenClassPoints(frame, uuidb.general.darkenpersonalresourceborder, dc)
    -- Square bars hide the art and color their own border (SquareBar);
    -- leave it alone there (vertex alpha would un-hide it).
    if prd.SquareOn() then return end
    local darken = uuidb.general.darkenpersonalresourceborder
    for _, bar in ipairs({ frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar or false,
            frame.PowerBar or false, frame.AlternatePowerBar or false }) do
        -- The fill shares the bar atlas but is colored by Blizzard; skip it.
        local fill = bar and bar:GetStatusBarTexture()
        for _, region in ipairs(bar and { bar:GetRegions() } or {}) do
            local atlas = region ~= fill and region:IsObjectType("Texture") and Atlas(region)
            if atlas == BAR_ATLAS or atlas == BAR_BG_ATLAS then
                SetDarkened(region, darken, dc)
            end
        end
    end
end

local darkenHookInstalled = false
local function EnsureDarkenHook()
    if darkenHookInstalled then return end
    local target = HookTarget()
    if not target then return end
    if not (uuidb and uuidb.general and uuidb.general.darkenpersonalresourceborder) then return end
    darkenHookInstalled = true

    hooksecurefunc(target, "Setup", function(self)
        UberUI.personalresource:DarkenBorder(self)
    end)
end

local function IsPRDTextureActive()
    if not uuidb or not uuidb.general then return false end
    local g = uuidb.general
    return (g.personalresourcebartextures and g.personalresourcebartexture ~= "Blizzard")
        or (g.allbartextures and g.texture ~= "Blizzard")
        or (g.secondarybartextures and g.secondarybartexture ~= "Blizzard")
end

local textureHookInstalled = false
local function EnsureTextureHook()
    if textureHookInstalled then return end
    local target = HookTarget()
    if not target then return end
    if not IsPRDTextureActive() then return end
    textureHookInstalled = true

    hooksecurefunc(target, "Setup", function(self)
        UberUI.personalresource:StylePRD(self)
    end)
end

-- Square bars: re-applied after Setup and when Edit Mode changes the bar
-- padding or which bars show (deferred out of Blizzard's update).
local squareHookInstalled = false
local squareQueued = false
local function QueueSquare(frame)
    if squareQueued then return end
    squareQueued = true
    C_Timer.After(0, function()
        squareQueued = false
        UberUI.personalresource:ApplySquare(frame)
    end)
end

local function EnsureSquareHook()
    if squareHookInstalled or not prd.SquareOn() then return end
    local frame = PersonalResourceDisplayFrame
    if not frame then return end
    squareHookInstalled = true
    for _, method in ipairs({ "Setup", "SetBarPadding", "UpdatePowerBarAnchor", "UpdateAdditionalBarAnchors" }) do
        if type(frame[method]) == "function" then
            hooksecurefunc(frame, method, function(self) QueueSquare(self) end)
        end
    end
end

local function RegisterPRDHooks()
    EnsureDarkenHook()
    EnsureTextureHook()
    EnsureSquareHook()
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == "Blizzard_PersonalResourceDisplay" then
        RegisterPRDHooks()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if (C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_PersonalResourceDisplay")) or PersonalResourceDisplayMixin then
            RegisterPRDHooks()
        end
        if PersonalResourceDisplayFrame then
            UberUI.personalresource:StylePRD(PersonalResourceDisplayFrame)
            UberUI.personalresource:DarkenBorder(PersonalResourceDisplayFrame)
        end
    end
end)
-- Options refresh. Applies everything directly -- never by calling
-- Blizzard's own Setup/Update functions (CLAUDE.md).
function prd:ForceTexture()
    RegisterPRDHooks()
    local frame = PersonalResourceDisplayFrame
    if frame then
        self:StylePRD(frame)
        self:DarkenBorder(frame)
    end
end

UberUI.personalresource = prd
