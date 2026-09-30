--[[--------------------------------------------------------------------
	Uber UI options -- Cooldown Manager and nameplate health bar previews.
	Mock items built like Blizzard's own templates (CooldownViewer.xml,
	Blizzard_NamePlates.xml: same art, anchors and keys), styled by the same
	code as the real frames (cdManager.preview, nameplates.PreviewHealthBar),
	scaled to the size they appear on screen.
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

local MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local RING_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local SWIPE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local BAR_ATLAS = "UI-HUD-CoolDownManager-Bar"
local BAR_BG_ATLAS = "UI-HUD-CoolDownManager-Bar-BG"
local PIP_ATLAS = "UI-HUD-CoolDownManager-Bar-Pip"

local WIDTH = 340
local EDGE = 14
local SPACING = 18
local CAPTION_HEIGHT = 14

local function Eff(frame) return opt.PreviewEff(frame) end

-- The first item frame of a Cooldown Manager viewer, for its scale.
local function FirstItem(viewer)
    if not viewer then return nil end
    local pool = viewer.itemFramePool
    if pool and pool.EnumerateActive then
        for f in pool:EnumerateActive() do return f end
    end
    for _, f in ipairs({ viewer:GetChildren() }) do
        if f.Icon or f.Bar then return f end
    end
    return nil
end

-- An item's on-screen scale (Edit Mode icon size is a SetScale on items).
local function ItemEff(viewerName)
    local viewer = _G[viewerName]
    return Eff(FirstItem(viewer)) or Eff(viewer) or Eff(UIParent) or 1
end

-- A static cooldown swipe at `fraction` done (paused), or none.
local function SetSwipe(cd, fraction)
    if not cd then return end
    if not fraction then
        cd:Clear()
        return
    end
    local duration = 100
    cd:SetCooldown(GetTime() - duration * fraction, duration)
    if cd.Pause then pcall(cd.Pause, cd) end
end

local function Unsnap(region)
    if region.SetSnapToPixelGrid then region:SetSnapToPixelGrid(false) end
    if region.SetTexelSnappingBias then region:SetTexelSnappingBias(0) end
end

-- Countdown font a plain Cooldown frame uses (Tracked Buffs' icons).
local defaultCountdownFont
local function DefaultCountdownFont(parent)
    if defaultCountdownFont == nil then
        defaultCountdownFont = false
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, parent, "CooldownFrameTemplate")
        local fs = ok and cd and cd.GetCountdownFontString and cd:GetCountdownFontString()
        if fs then
            local font, size, flags = fs:GetFont()
            if font then defaultCountdownFont = { font, size, flags } end
        end
        if ok and cd then cd:Hide() end
    end
    return defaultCountdownFont or nil
end

-- Blizzard's own pandemic effect (its template is plain art + animation).
local function BlizzardPandemicFX(owner, template)
    local ok, fx = pcall(CreateFrame, "Frame", nil, owner, template)
    if not ok or not fx then return nil end
    fx:Hide()
    return fx
end

---------------------------------------------------------------------------
-- Cooldown Manager icons
---------------------------------------------------------------------------

-- Per item type: CooldownViewer.xml size, ring overlay offsets, countdown
-- font and the viewer it scales with.
local ICON_TYPES = {
    essential = { size = 50, ringX = 9, ringY = 8, font = "GameFontHighlightHugeOutline", viewer = "EssentialCooldownViewer", count = "ChargeCount" },
    utility   = { size = 30, ringX = 9, ringY = 8, font = "GameFontHighlightOutline", viewer = "UtilityCooldownViewer", count = "ChargeCount", countFont = "NumberFontNormalSmall" },
    bufficon  = { size = 40, ringX = 8, ringY = 7, viewer = "BuffIconCooldownViewer", count = "Applications", reverse = true },
}

-- aura: the item is showing an aura's time (Blizzard's yellow aura swipe),
-- else a cooldown (its dark swipe). CooldownViewer.lua's CooldownViewerConstants.
local SWIPE_AURA = { 1, 0.95, 0.57, 0.7 }
local SWIPE_COOLDOWN = { 0, 0, 0, 0.7 }

local ICON_SAMPLES = {
    { type = "essential", icon = "Interface\\Icons\\Spell_Nature_Lightning", countdown = 12, swipe = 0.4, caption = "Cooldown" },
    { type = "essential", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", countdown = 5, swipe = 0.75, aura = true, pandemic = true, caption = "Pandemic" },
    { type = "bufficon", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", countdown = 14, swipe = 0.4, stack = 2, caption = "Buff" },
    { type = "utility", icon = "Interface\\Icons\\Spell_Nature_Purge", countdown = 40, swipe = 0.3, caption = "Utility" },
}

local function NewIconItem(parent, info)
    local t = ICON_TYPES[info.type]
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(t.size, t.size)
    f.layoutIndex = 1 -- a grid item (cooldownmanager.lua's IconInset)
    f.info, f.itemType = info, t

    f.Icon = f:CreateTexture(nil, "ARTWORK")
    f.Icon:SetAllPoints()
    f.Icon:SetTexture(info.icon)
    local mask = f:CreateMaskTexture()
    mask:SetAtlas(MASK_ATLAS)
    mask:SetAllPoints()
    f.Icon:AddMaskTexture(mask)

    local ring = f:CreateTexture(nil, "OVERLAY")
    ring:SetAtlas(RING_ATLAS)
    ring:SetPoint("TOPLEFT", f, "TOPLEFT", -t.ringX, t.ringY)
    ring:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", t.ringX, -t.ringY)

    f.Cooldown = CreateFrame("Cooldown", nil, f)
    f.Cooldown:SetAllPoints()
    f.Cooldown:SetSwipeTexture(SWIPE)
    if t.reverse then f.Cooldown:SetReverse(true) end
    f.Cooldown:SetSwipeColor(unpack(info.aura and SWIPE_AURA or SWIPE_COOLDOWN))
    f.Cooldown:SetDrawEdge(false)
    f.Cooldown:SetHideCountdownNumbers(true)

    f.DebuffBorder = CreateFrame("Frame", nil, f)
    f.DebuffBorder:SetPoint("TOPLEFT", f.Icon, "TOPLEFT", -3, 3)
    f.DebuffBorder:SetPoint("BOTTOMRIGHT", f.Icon, "BOTTOMRIGHT", 3, -3)
    f.DebuffBorder:Hide()

    -- Countdown (static text in the countdown font) and stack count.
    f.textHolder = CreateFrame("Frame", nil, f)
    f.textHolder:SetAllPoints()
    f.countdown = f.textHolder:CreateFontString(nil, "OVERLAY")
    f.countdown:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.stack = f.textHolder:CreateFontString(nil, "OVERLAY", t.countFont or "NumberFontNormal")
    f.stack:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)

    f.blizzFX = BlizzardPandemicFX(f, "CooldownPandemicFXTemplate")
    if f.blizzFX then
        f.blizzFX:SetPoint("TOPLEFT", f, "TOPLEFT", -6, 6)
        f.blizzFX:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 6, -6)
    end
    return f
end

local function UpdateIconItem(f)
    local info, t = f.info, f.itemType
    local level = f:GetFrameLevel()
    f.Cooldown:SetFrameLevel(level + 1)
    f.textHolder:SetFrameLevel(level + 10)
    SetSwipe(f.Cooldown, info.swipe)

    local cdm = UberUI.cdManager and UberUI.cdManager.preview
    local blizz = cdm and cdm.StyleItem(f, info.pandemic)
    if f.blizzFX then
        f.blizzFX:SetFrameStrata(f:GetFrameStrata())
        f.blizzFX:SetFrameLevel(level + 8)
        f.blizzFX:SetShown(blizz == "blizzard")
    end

    local fontName = t.font
    if fontName and _G[fontName] then
        f.countdown:SetFontObject(fontName)
    else
        local df = DefaultCountdownFont(f)
        if df then f.countdown:SetFont(df[1], df[2], df[3]) end
    end
    local r, g, b = 1, 1, 1
    if cdm then r, g, b = cdm.CountdownColor(info.countdown) end
    f.countdown:SetTextColor(r, g, b, 1)
    f.countdown:SetText(tostring(info.countdown))
    f.stack:SetText(info.stack and tostring(info.stack) or "")
end

local function UpdateIconPreview(preview)
    local peff = preview:GetEffectiveScale()
    local items, total, tallest = preview.items, EDGE * 2, 0
    local ratios = {}
    for i, f in ipairs(items) do
        local t = f.itemType
        ratios[i] = ItemEff(t.viewer) / peff
        total = total + t.size * ratios[i] + (i > 1 and SPACING or 0)
        tallest = math.max(tallest, t.size * ratios[i])
    end
    local fit = math.min(1, WIDTH / total, (preview.stageHeight - 16) / math.max(tallest, 1))
    local x = EDGE
    for i, f in ipairs(items) do
        local r = ratios[i] * fit
        f:SetScale(r)
        f:ClearAllPoints()
        f:SetPoint("LEFT", preview.stage, "LEFT", x / r, 0)
        pcall(UpdateIconItem, f)
        local w = f.itemType.size * r
        f.cap:ClearAllPoints()
        f.cap:SetWidth(90)
        f.cap:SetPoint("TOPLEFT", preview.stage, "BOTTOMLEFT", x + w / 2 - 45, -2)
        x = x + w + SPACING
    end
    preview.fitNote:SetShown(fit < 0.999)
end

---------------------------------------------------------------------------
-- Tracked Bars
---------------------------------------------------------------------------

local BAR_SAMPLES = {
    { icon = "Interface\\Icons\\Spell_Nature_Rejuvenation", name = "Rejuvenation", countdown = 11, value = 0.7, caption = "Tracked Bar" },
    { icon = "Interface\\Icons\\Ability_Druid_Disembowel", name = "Rip", countdown = 4, value = 0.2, pandemic = true, stack = 3, caption = "Pandemic" },
}

-- CooldownViewerBuffBarItemTemplate: 220x30 item, 30px icon at the left,
-- a 19px bar 2 to its right.
local function NewBarItem(parent, info)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(220, 30)
    f.info = info

    f.Icon = CreateFrame("Frame", nil, f)
    f.Icon:SetSize(30, 30)
    f.Icon:SetPoint("LEFT")
    f.Icon.Icon = f.Icon:CreateTexture(nil, "ARTWORK")
    f.Icon.Icon:SetAllPoints()
    f.Icon.Icon:SetTexture(info.icon)
    local mask = f.Icon:CreateMaskTexture()
    mask:SetAtlas(MASK_ATLAS)
    mask:SetAllPoints()
    f.Icon.Icon:AddMaskTexture(mask)
    local ring = f.Icon:CreateTexture(nil, "OVERLAY")
    ring:SetAtlas(RING_ATLAS)
    ring:SetPoint("TOPLEFT", f.Icon, "TOPLEFT", -6, 5)
    ring:SetPoint("BOTTOMRIGHT", f.Icon, "BOTTOMRIGHT", 6, -5)
    f.Icon.Applications = f.Icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    f.Icon.Applications:SetJustifyH("RIGHT")
    f.Icon.Applications:SetSize(32, 10)
    f.Icon.Applications:SetPoint("BOTTOMRIGHT", -5, 5)

    f.DebuffBorder = CreateFrame("Frame", nil, f)
    f.DebuffBorder:SetPoint("TOPLEFT", f.Icon, "TOPLEFT", -3, 3)
    f.DebuffBorder:SetPoint("BOTTOMRIGHT", f.Icon, "BOTTOMRIGHT", 3, -3)
    f.DebuffBorder:Hide()

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetHeight(19)
    bar:SetPoint("LEFT", f.Icon, "RIGHT", 2, 0)
    bar:SetPoint("RIGHT", f, "RIGHT", 0, 0)
    bar:SetStatusBarTexture(BAR_ATLAS)
    local fill = bar:GetStatusBarTexture()
    if fill then fill:SetAtlas(BAR_ATLAS) end
    bar:SetStatusBarColor(1.0, 0.5, 0.25)
    bar:SetMinMaxValues(0, 1)
    bar.BarBG = bar:CreateTexture(nil, "BACKGROUND")
    bar.BarBG:SetAtlas(BAR_BG_ATLAS)
    bar.BarBG:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
    bar.BarBG:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -7)
    bar.Pip = bar:CreateTexture(nil, "OVERLAY")
    bar.Pip:SetAtlas(PIP_ATLAS, true)
    bar.Name = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    bar.Name:SetJustifyH("LEFT")
    bar.Name:SetPoint("TOPLEFT", bar, "TOPLEFT", 5, 0)
    bar.Name:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -25, 0)
    bar.Duration = bar:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    bar.Duration:SetJustifyH("LEFT")
    bar.Duration:SetPoint("RIGHT", bar, "RIGHT", -8, 0)
    f.Bar = bar

    f.blizzFX = BlizzardPandemicFX(f, "CooldownPandemicBarFXTemplate")
    if f.blizzFX then
        f.blizzFX:SetPoint("TOPLEFT", bar, "TOPLEFT", -9, 10)
        f.blizzFX:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 9, -10)
    end
    return f
end

local function UpdateBarItem(f)
    local info, bar = f.info, f.Bar
    local level = f:GetFrameLevel()
    bar:SetFrameLevel(level + 1)
    f.Icon:SetFrameLevel(level + 2)
    f.DebuffBorder:SetFrameLevel(level + 3)
    bar:SetStatusBarColor(1.0, 0.5, 0.25)
    bar:SetValue(info.value)
    bar.Name:SetText(info.name)
    f.Icon.Applications:SetText(info.stack and tostring(info.stack) or "")

    local cdm = UberUI.cdManager and UberUI.cdManager.preview
    local blizz = cdm and cdm.StyleItem(f, info.pandemic)
    local fill = bar:GetStatusBarTexture()
    if fill then
        bar.Pip:ClearAllPoints()
        bar.Pip:SetPoint("CENTER", fill, "RIGHT", 0, 0)
    end
    if f.blizzFX then
        f.blizzFX:SetFrameStrata(f:GetFrameStrata())
        f.blizzFX:SetFrameLevel(level + 8)
        f.blizzFX:SetShown(blizz == "blizzard")
    end
    local r, g, b = 1, 1, 1
    if cdm then r, g, b = cdm.CountdownColor(info.countdown) end
    bar.Duration:SetTextColor(r, g, b, 1)
    bar.Duration:SetText(tostring(info.countdown))
end

local function UpdateBarPreview(preview)
    local peff = preview:GetEffectiveScale()
    local r = ItemEff("BuffBarCooldownViewer") / peff
    local width = 220
    local live = FirstItem(_G.BuffBarCooldownViewer)
    if live then
        local ok, w = pcall(live.GetWidth, live)
        if ok and type(w) == "number" and not (issecretvalue and issecretvalue(w)) and w > 0 then width = w end
    end
    local rowH = 30
    local rows = #preview.items
    -- Room on the right for the captions.
    local fit = math.min(1, (WIDTH - EDGE * 2 - 64) / (width * r), (preview.stageHeight - 12) / ((rowH * rows + 12 * (rows - 1)) * r))
    r = r * fit
    local totalH = (rowH * rows + 12 * (rows - 1)) * r
    local y = totalH / 2
    for _, f in ipairs(preview.items) do
        f:SetWidth(width)
        f:SetScale(r)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", preview.stage, "LEFT", EDGE / r, y / r)
        pcall(UpdateBarItem, f)
        f.cap:ClearAllPoints()
        f.cap:SetPoint("LEFT", preview.stage, "LEFT", EDGE + width * r + 8, y - rowH * r / 2)
        y = y - (rowH + 12) * r
    end
    preview.fitNote:SetShown(fit < 0.999)
end

---------------------------------------------------------------------------
-- Nameplate health bar
---------------------------------------------------------------------------

-- Blizzard_NamePlates.xml's health bar: barTexture, bgTexture (sized and
-- anchored in Lua: -2/+3 .. +6/-6 around the bar), selection art. On
-- Forever, the level badge (Camelot's NameplateLevelFrame: 5 to the right of
-- the bar, which Blizzard shortens to make room) -- core/nameplates.lua turns
-- it into the square level box in square mode.
local LEVEL_GAP = 5

local function NewHealthBar(parent)
    local f = CreateFrame("Frame", nil, parent)
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("BOTTOMLEFT")
    bar:SetStatusBarTexture(BAR_ATLAS)
    bar.barTexture = bar:GetStatusBarTexture()
    if bar.barTexture then bar.barTexture:SetAtlas(BAR_ATLAS) end
    bar:SetMinMaxValues(0, 1)
    bar.bgTexture = bar:CreateTexture(nil, "BACKGROUND")
    bar.bgTexture:SetAtlas(BAR_BG_ATLAS)
    bar.bgTexture:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 3)
    bar.bgTexture:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 6, -6)
    bar.selectedBorder = bar:CreateTexture(nil, "OVERLAY")
    bar.selectedBorder:SetAtlas("UI-HUD-Nameplates-Selected")
    bar.selectedBorder:SetPoint("TOPLEFT", bar.bgTexture, "TOPLEFT", -1, 1)
    bar.selectedBorder:SetPoint("BOTTOMRIGHT", bar.bgTexture, "BOTTOMRIGHT", -3, 3)
    bar.selectedBorder:Hide()
    -- An untargeted plate with nothing targeted: no selection border or dim.
    bar.IsTarget = function() return false end
    bar.IsFocus = function() return false end
    bar.ShouldUseSelectedBorder = function() return false end
    f.name = f:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlate")
    f.healthBar = bar

    if UberUI.util.IsForeverClient() then
        local badge = CreateFrame("Frame", nil, f)
        badge:SetPoint("LEFT", bar, "RIGHT", LEVEL_GAP, 0)
        badge:SetSize(18, 10) -- sized from Blizzard's setup options on update
        badge.playerLevelDiffIcon = badge:CreateTexture(nil, "BACKGROUND")
        badge.playerLevelDiffIcon:SetAtlas("ui-hud-nameplates-levelindicator")
        badge.playerLevelDiffIcon:SetAllPoints()
        badge.playerLevelDiffText = badge:CreateFontString(nil, "OVERLAY",
            _G.SystemFont_NamePlateLevel and "SystemFont_NamePlateLevel" or "GameFontWhiteTiny2")
        badge.playerLevelDiffText:SetPoint("CENTER", badge.playerLevelDiffIcon, "CENTER", 0, 0)
        badge.selectedBorder = badge:CreateTexture(nil, "OVERLAY")
        badge.selectedBorder:SetAtlas("ui-hud-nameplates-levelindicator-rectangle-selected")
        badge.selectedBorder:SetPoint("TOPLEFT", badge, "TOPLEFT", -3, 4)
        badge.selectedBorder:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", 3, -4)
        badge.selectedBorder:Hide()
        badge.highLevelTexture = badge:CreateTexture(nil, "OVERLAY")
        badge.highLevelTexture:SetAtlas("ui-hud-nameplates-levelindicator-skull")
        badge.highLevelTexture:SetPoint("CENTER", badge.playerLevelDiffIcon, "CENTER", 0, 0)
        badge.highLevelTexture:Hide()
        f.PlayerLevelDiffFrame = badge
    end
    return f
end

local function UpdateHealthBarPreview(preview)
    local peff = preview:GetEffectiveScale()
    local f = preview.plate
    local badge = f.PlayerLevelDiffFrame
    local setup = _G.NamePlateSetupOptions
    local levelW = tonumber(setup and setup.playerLevelDiffWidth)
    if not levelW or levelW < 4 then levelW = 18 end
    local levelH = tonumber(setup and setup.playerLevelDiffHeight)
    if levelH and levelH < 4 then levelH = nil end

    -- Live plate: its health bar's size and scale (per-plate scale removed).
    -- A bar measured without its level badge showing is shortened here the
    -- way Blizzard does when the badge shows.
    local w, h, measuredWithBadge = 110, 10, false
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local uf = not plate:IsForbidden() and plate.UnitFrame
        local hb = uf and uf.healthBar
        if hb and not hb:IsForbidden() then
            local ok, bw, bh = pcall(hb.GetSize, hb)
            if ok and type(bw) == "number" and type(bh) == "number" and bw > 0 and bh > 0
                and not (issecretvalue and (issecretvalue(bw) or issecretvalue(bh))) then
                w, h = bw, bh
                local lb = uf.PlayerLevelDiffFrame
                measuredWithBadge = lb and not lb:IsForbidden() and lb:IsShown() or false
                break
            end
        end
    end
    if badge and not measuredWithBadge then w = math.max(20, w - levelW - LEVEL_GAP) end
    local totalW = w + (badge and (LEVEL_GAP + levelW) or 0)

    local eff = opt.NameplateBaseScale("healthbar", function(uf) return uf.healthBar end) or 1
    local r = eff / peff
    local fit = math.min(1, (WIDTH - EDGE * 2) / (totalW * r), (preview.stageHeight - 24) / (h * r))
    r = r * fit
    f:SetScale(r)
    f:SetSize(totalW, h)
    f:ClearAllPoints()
    f:SetPoint("CENTER", preview.stage, "CENTER", 0, -4 / r)

    local bar = f.healthBar
    bar:SetWidth(w)
    bar:SetValue(0.6)
    bar:SetStatusBarColor(1, 0.1, 0.1)
    -- Blizzard centers the name over bar + badge.
    f.name:ClearAllPoints()
    f.name:SetPoint("BOTTOM", f, "TOP", 0, 3)
    f.name:SetText("Enemy")
    f.name:SetTextColor(1, 0.1, 0.1)

    if badge then
        badge:SetSize(levelW, levelH or h)
        local level = UnitLevel("player") or 1
        badge.playerLevelDiffText:SetText(tostring(level))
        local ok, color = pcall(GetQuestDifficultyColor, level)
        if ok and type(color) == "table" and color.r then
            badge.playerLevelDiffText:SetTextColor(color.r, color.g, color.b)
        else
            badge.playerLevelDiffText:SetTextColor(1, 0.82, 0)
        end
        if setup and setup.levelFontHeight then
            pcall(badge.playerLevelDiffText.SetTextHeight, badge.playerLevelDiffText, setup.levelFontHeight)
        end
        badge:Show()
    end
    if UberUI.nameplates and UberUI.nameplates.PreviewHealthBar then
        pcall(UberUI.nameplates.PreviewHealthBar, bar, f)
    end
    preview.fitNote:SetShown(fit < 0.999)
end

---------------------------------------------------------------------------
-- Preview rows
---------------------------------------------------------------------------

local function NewPreviewFrame(parent, stageHeight)
    local preview = CreateFrame("Frame", nil, parent)
    preview:SetSize(WIDTH, stageHeight + CAPTION_HEIGHT)
    preview.stageHeight = stageHeight
    local stage = CreateFrame("Frame", nil, preview)
    stage:SetPoint("TOPLEFT")
    stage:SetPoint("TOPRIGHT")
    stage:SetHeight(stageHeight)
    preview.stage = stage
    preview.fitNote = stage:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    preview.fitNote:SetPoint("TOPRIGHT", stage, "TOPRIGHT", -4, -2)
    preview.fitNote:SetText("scaled to fit")
    preview.fitNote:Hide()
    return preview
end

local function Caption(preview, text)
    local cap = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cap:SetJustifyH("CENTER")
    cap:SetText(text)
    return cap
end

-- Cooldown Manager icons: borders, shape, pandemic highlight, countdown.
function opt.AddCDMIconPreview(page)
    local STAGE = 76
    opt.AddPreview(page, {
        name = "Preview",
        tooltip = "Sample Cooldown Manager icons drawn with the settings on this page, at the size they appear on screen: an Essential cooldown, an Essential icon showing your debuff in its pandemic window (expiring countdown color), a tracked buff with a stack count, and a Utility cooldown.",
        height = STAGE + CAPTION_HEIGHT + 12,
        create = function(parent)
            if not (UberUI.cdManager and UberUI.cdManager.preview) then return nil end
            local preview = NewPreviewFrame(parent, STAGE)
            preview.items = {}
            for i, info in ipairs(ICON_SAMPLES) do
                local f = NewIconItem(preview.stage, info)
                f.cap = Caption(preview, info.caption)
                preview.items[i] = f
            end
            preview.Update = UpdateIconPreview
            preview:SetScript("OnShow", UpdateIconPreview)
            return preview
        end,
    })
end

-- Tracked Bars: texture, shape, darkening, pandemic highlight, countdown.
function opt.AddCDMBarPreview(page)
    local STAGE = 84
    opt.AddPreview(page, {
        name = "Preview",
        tooltip = "Sample Tracked Bars drawn with the settings on this page, at the size they appear on screen: a normal bar, and one in its pandemic window with a stack count.",
        height = STAGE + 12,
        create = function(parent)
            if not (UberUI.cdManager and UberUI.cdManager.preview) then return nil end
            local preview = NewPreviewFrame(parent, STAGE)
            preview:SetHeight(STAGE)
            preview.items = {}
            for i, info in ipairs(BAR_SAMPLES) do
                local f = NewBarItem(preview.stage, info)
                f.cap = Caption(preview, info.caption)
                f.cap:SetJustifyH("LEFT")
                preview.items[i] = f
            end
            preview.Update = UpdateBarPreview
            preview:SetScript("OnShow", UpdateBarPreview)
            return preview
        end,
    })
end

-- Nameplate health bar: texture, border shape and thickness, darkness.
function opt.AddNameplateBarPreview(page)
    local STAGE = 44
    opt.AddPreview(page, {
        name = "Preview",
        tooltip = "A sample enemy nameplate health bar drawn with the settings below, at the size nameplates appear on screen (with its level box on WoW Forever).",
        height = STAGE + 12,
        create = function(parent)
            if not (UberUI.nameplates and UberUI.nameplates.PreviewHealthBar) then return nil end
            local preview = NewPreviewFrame(parent, STAGE)
            preview:SetHeight(STAGE)
            preview.plate = NewHealthBar(preview.stage)
            preview.Update = UpdateHealthBarPreview
            preview:SetScript("OnShow", UpdateHealthBarPreview)
            return preview
        end,
    })
end
