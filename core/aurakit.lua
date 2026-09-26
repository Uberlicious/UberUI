-- Shared building blocks for the "target-style" custom aura containers used
-- by targetframe.lua and focusframe.lua (and any future frame that wants
-- the same two-permanent-container/dispel-border/stealable-overlay design).
-- Nothing in here is target- or focus-specific; every per-frame detail
-- (which global frame, which unit token, which uuidb keys, pixel constants)
-- is passed in by the caller.

local addon, ns = ...

local aurakit = {}

local function IsSecret(v)
    return (issecretvalue and issecretvalue(v))
end

local function SafeBool(v)
    if v == nil or IsSecret(v) then return false end
    return (v == true)
end

local function SafeIsForbidden(frame)
    if not frame or IsSecret(frame) then return true end
    local ok, isForbid = pcall(frame.IsForbidden, frame)
    if not ok then return true end
    return SafeBool(isForbid)
end

aurakit.IsSecret = IsSecret
aurakit.SafeBool = SafeBool
aurakit.SafeIsForbidden = SafeIsForbidden

-- Detects the "sourceUnit resolution failed" engine state that causes an
-- aura to satisfy both "<base>|PLAYER" and "<base>|!PLAYER" simultaneously
-- -- confirmed (via /uuidebugoverlapwatch) to be triggered specifically by
-- the unit being in a different zone than the local player, on BOTH WoW
-- Forever and retail. auraData.sourceUnit goes nil for the affected aura
-- when this happens; the two filter-string queries then both admit it
-- instead of exactly one.
--
-- Queries C_UnitAuras.GetUnitAuraInstanceIDs DIRECTLY -- no container/
-- button involved -- so this can be checked cheaply before deciding
-- whether it's safe to show the "mine" group at all. When ambiguous,
-- hiding "mine" (see aurakit.GetSafeMineMaxFrameCount below) leaves the
-- aura visible via the correctly-populated "other" group instead of
-- either duplicating it or -- like Blizzard's own default UI does under
-- the same condition -- losing it entirely.
function aurakit.HasAmbiguousMineMatch(unit, isHarmful)
    if not unit or not UnitExists(unit) then return false end
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs) then return false end

    local base = isHarmful and "HARMFUL" or "HELPFUL"
    local okMine, mineIDs = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, base .. "|PLAYER")
    local okOther, otherIDs = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, base .. "|!PLAYER")
    if not okMine or not okOther or not mineIDs or not otherIDs then return false end
    if IsSecret(mineIDs) or IsSecret(otherIDs) then return false end

    local mineSet = {}
    for _, id in ipairs(mineIDs) do
        if not IsSecret(id) then mineSet[id] = true end
    end
    for _, id in ipairs(otherIDs) do
        if id and not IsSecret(id) and mineSet[id] then
            return true
        end
    end
    return false
end

-- Caller passes its normal (style-driven) max count for the "mine" group;
-- this returns 0 instead whenever HasAmbiguousMineMatch is true for that
-- unit, and the normal count otherwise. Callers apply this identically to
-- how they already apply the "none" style's max-count override.
function aurakit.GetSafeMineMaxFrameCount(unit, isHarmful, normalMaxCount)
    if aurakit.HasAmbiguousMineMatch(unit, isHarmful) then
        return 0
    end
    return normalMaxCount
end

function aurakit.MakeGroupLayout(elementSize, spacingX, spacingY, forceNewLine, layoutIndex)
    spacingX = spacingX or 1
    spacingY = spacingY or 1
    return {
        elementWidth = elementSize,
        elementHeight = elementSize,
        elementSpacing = spacingX,
        lineSpacing = spacingY + 2,
        groupSpacing = -1,
        groupLineSpacing = spacingY + 2,
        forceNewLine = forceNewLine or false,
        layoutIndex = layoutIndex,
    }
end

function aurakit.GetLeaderIcon(frame)
    if not frame then return nil end
    local contextual = frame.TargetFrameContent and frame.TargetFrameContent.TargetFrameContentContextual
    if contextual then
        local leader = contextual.LeaderIcon
        if leader and leader:IsShown() then return leader end
        local guide = contextual.GuideIcon
        if guide and guide:IsShown() then return guide end
    end
    if frame.LeaderIcon and frame.LeaderIcon:IsShown() then return frame.LeaderIcon end
    if frame.leaderIcon and frame.leaderIcon:IsShown() then return frame.leaderIcon end
    local globalLeader = frame.GetName and _G[frame:GetName() .. "LeaderIcon"]
    if globalLeader and globalLeader:IsShown() then return globalLeader end
    return nil
end

-- Restyle every aura button currently active in one of a container's two
-- permanent groups ("mine"/"other"), using the container's own authoritative
-- group membership (GetAuraGroupFrameCount/GetAuraGroupFrame) rather than
-- any addon-cached per-button state. A group's harmful/helpful identity and
-- its container never change, so buttons are never reclassified between
-- buff and debuff roles -- each button's role is fixed for its entire
-- lifetime by which group it was created in.
function aurakit.ForEachActiveAuraButton(container, keyMine, keyOther, callback)
    if not container or type(container.GetAuraGroupFrameCount) ~= "function"
        or type(container.GetAuraGroupFrame) ~= "function" then
        return
    end

    local function visitGroup(groupKey)
        if not groupKey then return end
        local okCount, count = pcall(container.GetAuraGroupFrameCount, container, groupKey)
        if not okCount or type(count) ~= "number" then return end
        for i = 1, count do
            local okFrame, btn = pcall(container.GetAuraGroupFrame, container, groupKey, i)
            if okFrame and btn and not IsSecret(btn) then
                callback(btn)
            end
        end
    end

    visitGroup(keyMine)
    visitGroup(keyOther)
end

function aurakit.RefreshContainerButtons(container, keyMine, keyOther, updateStyleFn)
    if not container or not updateStyleFn then return end
    aurakit.ForEachActiveAuraButton(container, keyMine, keyOther, function(btn)
        pcall(updateStyleFn, btn)
    end)
end

-- Same as RefreshContainerButtons, for containers built with
-- BuildGroupedAuraContainer (any number of groups, not a fixed mine/other
-- pair).
function aurakit.RefreshGroupButtons(container, groupKeys, updateStyleFn)
    if not container or not updateStyleFn or not groupKeys then return end
    for _, key in ipairs(groupKeys) do
        aurakit.ForEachActiveAuraButton(container, key, nil, function(btn)
            pcall(updateStyleFn, btn)
        end)
    end
end

-- Offensive dispel capability and the stealable-border asset map live in
-- UberUI.general (generalfunctions.lua) -- shared by every frame type.
--
-- AddDispelTypeTexture is denied outright while aura data is "secret"
-- (loading screens/zone transitions) -- a single attempt at button-creation
-- time can silently and permanently fail, so we retry every style pass
-- until it succeeds. A button's buff/debuff role is fixed for life (see
-- InitAuraButton/BuildAuraContainer), so only one registration is ever
-- needed per button.
--
-- Buffs: Blizzard's own StealableBorder texture (same one stock target/
-- focus frames use, see TargetFrameAuraButton.xml), gated by stealableFilter
-- so the ENGINE decides show/hide from the real, otherwise-secret
-- isStealable flag. Style = CustomAsset, not PreserveAsset: PreserveAsset is
-- the only style that computes the REAL per-dispel-type color (AuraUtil.
-- SetAuraBorderColor) -- every other style, including CustomAsset, forces
-- SetVertexColor(1,1,1,1), which is what we want here.
function aurakit.TryRegisterDispelBorder(button)
    if type(button.AddDispelTypeTexture) ~= "function" then return end
    if not (Enum and Enum.CustomAuraButtonDispelTypeTextureStyle) then return end

    -- Square-border strips (core/squareborders.lua), registered alongside the
    -- round border so toggling square borders on later needs no aura update
    -- to get real colors: debuffs get engine dispel-colored strips (slot 1),
    -- buffs get engine stealable-gated white strips (slot 2; slot 1 is the
    -- plain dark border). They live in hidden frames until square borders are
    -- on for this button's location. Same retry-until-it-sticks contract.
    -- Tinted rounded ring for "Dispel Color" (see InitAuraButton).
    if not button.isBuff and button.roundDispelTexPending and not button.roundDispelTex then
        local preserve = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
        if preserve then
            local okAdd = pcall(button.AddDispelTypeTexture, button, button.roundDispelTexPending, {
                style = preserve,
                showWhenHarmful = true,
                showWhenHelpful = false,
                showWithoutDispelType = true,
            })
            if okAdd then
                button.roundDispelTex = button.roundDispelTexPending
                button.roundDispelTexPending = nil
            end
        end
    end

    local SB = UberUI.squareborders
    if SB then
        if button.isBuff then
            local o = SB.StealableEngineOptions()
            if o then SB.RegisterEngineStrips(button, SB.Get(button, 2), o) end
        else
            local o = SB.DebuffEngineOptions()
            if o then SB.RegisterEngineStrips(button, SB.Get(button, 1), o) end
        end
    end

    if button.isBuff then
        if button.stealableRegistered or not button.stealable then return end
        local customAsset = Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset
        if not customAsset then return end
        local options = {
            style = customAsset,
            showWhenHarmful = false,
            showWhenHelpful = true,
            showWithoutDispelType = true,
            stealableFilter = Enum.CustomAuraButtonDispelTypeStealableFilter and
            Enum.CustomAuraButtonDispelTypeStealableFilter.Stealable,
            customDispelAssetMap = UberUI.general:GetStealableDispelAssetMap(),
        }
        local okAdd, addErr = pcall(button.AddDispelTypeTexture, button, button.stealable, options)
        if okAdd then
            button.stealableRegistered = true
        end
        button.dispelRegOk = okAdd
        button.dispelRegErr = (not okAdd) and tostring(addErr) or nil
    else
        if button.dispelBorderTex or not button.dispelBorderTexPending then return end
        -- Border: hands the engine both atlas + color together, the same
        -- mechanism Blizzard's own native aura frames use for debuffs.
        local borderStyle = Enum.CustomAuraButtonDispelTypeTextureStyle.Border
        if not borderStyle then return end
        local options = {
            style = borderStyle,
            showWhenHarmful = true,
            showWhenHelpful = false,
            showWithoutDispelType = true,
        }
        local okAdd, addErr = pcall(button.AddDispelTypeTexture, button, button.dispelBorderTexPending, options)
        if okAdd then
            button.dispelBorderTex = button.dispelBorderTexPending
            button.dispelBorderTexPending = nil
        end
        button.dispelRegOk = okAdd
        button.dispelRegErr = (not okAdd) and tostring(addErr) or nil
    end
end

-- button.isBuff is fixed permanently at button creation (see InitAuraButton)
-- based on which permanent aura group the button belongs to.
--
-- opts: { style = "both"|"zoom"|"border"|"none", showDispel = bool }
-- style is the CALLER's already-resolved aurastyle_<frame><buffs/debuffs>
-- setting for this button's buff/debuff role; showDispel is the caller's
-- already-resolved "Show Dispels for <Frame> Buffs" setting.
function aurakit.ApplyAuraButtonStyle(button, opts)
    if not button or IsSecret(button) then return end
    -- Not bailing out on SafeIsForbidden(button): a forbidden AuraButton
    -- rejects some calls (SetSize) but not others (border show/hide still
    -- works mid-combat) -- every widget call below is already individually
    -- pcall-wrapped, so there's nothing to gain from bailing out entirely.
    aurakit.TryRegisterDispelBorder(button)

    local isBuff = button.isBuff
    local style = (opts and opts.style) or "both"
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    if button.icon then
        pcall(function()
            button.icon:ClearAllPoints()
            if darkBorderEnabled or zoomEnabled then
                button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
                button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            else
                button.icon:SetAllPoints(button)
            end
            if zoomEnabled then
                button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                button.icon:SetTexCoord(0, 1, 0, 1)
            end
        end)
        -- Cooldown tracks the icon's own bounds, not the full button -- the
        -- icon is inset 1px from the button edges above, and a Cooldown
        -- anchored to the (larger) button instead would render its swipe a
        -- pixel or two past the icon on every side, most visible on the
        -- small aura icons where that overhang is a bigger fraction of the
        -- total size.
        if button.cooldown then
            pcall(function()
                button.cooldown:ClearAllPoints()
                button.cooldown:SetAllPoints(button.icon)
            end)
        end
    end

    if button.elementSize then
        pcall(button.SetSize, button, button.elementSize, button.elementSize)
    end

    if button.cooldown then
        pcall(button.cooldown.SetDrawSwipe, button.cooldown, true)
        pcall(button.cooldown.SetDrawEdge, button.cooldown, true)
    end

    if button.borderHost then
        pcall(function()
            local pad = (button.elementSize and button.elementSize >= 20) and 3 or 2
            button.borderHost:ClearAllPoints()
            button.borderHost:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
            button.borderHost:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)

            if button.borderTex then
                button.borderTex:ClearAllPoints()
                button.borderTex:SetAllPoints(button.borderHost)
            end

            -- This widget type has no native border texture of its own, so
            -- "stock" means reproducing Blizzard's target/focus frame
            -- ourselves: no border on buffs, real dispel-type color on
            -- debuffs. We can't compute that color ourselves --
            -- auraData.dispelName reads back as a secret value to addon
            -- code -- so debuffs register button.dispelBorderTex via
            -- AddDispelTypeTexture (once, see InitAuraButton) and from here
            -- on we only show/hide the frame that hosts it; Blizzard colors
            -- it.
            local function ApplyDarkBorder()
                button.borderHost:Show()
                if button.dispelBorderHost then button.dispelBorderHost:Hide() end
                if button.roundDispelHost then button.roundDispelHost:Hide() end
                if button.borderTex then
                    button.borderTex:Show()
                    button.borderTex:SetAtlas("ui-debuff-border-default-noicon")
                    button.borderTex:SetDesaturated(true)
                    local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or
                    { r = 0.4, g = 0.4, b = 0.4, a = 1 }
                    button.borderTex:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                end
            end

            local function ApplyNoBorder()
                -- Blizzard's stock target/focus frame never draws a border
                -- on buffs.
                button.borderHost:Hide()
                if button.borderTex then button.borderTex:Hide() end
                if button.dispelBorderHost then button.dispelBorderHost:Hide() end
                if button.roundDispelHost then button.roundDispelHost:Hide() end
            end

            -- Debuffs only -- buffs use the separate button.stealable
            -- mechanism below instead, shown/hidden independently of style.
            local function ApplyDispelColoredBorder()
                button.borderHost:Show()
                if button.borderTex then button.borderTex:Hide() end
                if button.roundDispelTex then
                    -- Our ring, engine-tinted with the dispel color.
                    button.roundDispelHost:Show()
                    if button.dispelBorderHost then button.dispelBorderHost:Hide() end
                elseif button.dispelBorderHost then
                    -- Fallback until the ring registers: Blizzard's per-type
                    -- art, engine-managed.
                    if button.roundDispelHost then button.roundDispelHost:Hide() end
                    button.dispelBorderHost:Show()
                elseif button.borderTex then
                    -- Fallback if AddDispelTypeTexture is unavailable.
                    button.borderTex:Show()
                    button.borderTex:SetAtlas("ui-debuff-border-default-noicon")
                    button.borderTex:SetDesaturated(false)
                    button.borderTex:SetVertexColor(1, 1, 1, 1)
                end
            end

            if isBuff then
                if darkBorderEnabled then
                    ApplyDarkBorder()
                else
                    ApplyNoBorder()
                end
            elseif darkBorderEnabled then
                ApplyDarkBorder()
            else
                ApplyDispelColoredBorder()
            end

            -- Stealable overlay: button.stealable is engine-registered
            -- (stealableFilter decides if it renders at all), but
            -- stealableHost is OUR frame -- never registered -- so it's what
            -- the caller's showDispel + PlayerCanOffensiveDispel actually
            -- gate, independent of the base border above.
            if button.stealableHost then
                local showStealable = isBuff and UberUI.general:PlayerCanOffensiveDispel() and
                (opts and opts.showDispel)
                if showStealable then
                    button.stealableHost:Show()
                else
                    button.stealableHost:Hide()
                end
            end
        end)
    end

    aurakit.ApplySquareBorder(button, opts, style, darkBorderEnabled)
end

-- Square borders (core/squareborders.lua) for opts.squareLoc ("target",
-- "focus", "boss", "compact"). Replaces the atlas border above, following
-- the same Buff/Debuff Border choices: dark when the style includes a dark
-- border, otherwise Blizzard's look -- dispel color on debuffs (engine-
-- applied, so it's right even while aura data is secret), no border on
-- buffs. The "Highlight Purgeable Buffs" stealable border becomes a square
-- white one. Slots: 1 = buff dark border / debuff engine dispel strips,
-- 2 = buff engine stealable strips, 3 = debuff dark border (plain strips --
-- the engine re-tints slot 1 on every aura update, so it can't be darkened).
-- Until the engine strips are registered (denied while aura data is secret),
-- the round border above stays as the fallback.
function aurakit.ApplySquareBorder(button, opts, style, darkBorderEnabled)
    local SB = UberUI.squareborders
    if not SB or not button.icon then return end
    pcall(function()
        local loc = opts and opts.squareLoc
        local useSquare = loc and style ~= "none" and SB.IsEnabled(loc)
        local isBuff = button.isBuff
        local main, steal, dark = SB.Find(button, 1), SB.Find(button, 2), SB.Find(button, 3)
        local showMain, showSteal, showDark = false, false, false

        if useSquare then
            if isBuff then
                local showStealable = UberUI.general:PlayerCanOffensiveDispel() and opts.showDispel
                if showStealable and not (steal and steal.engineRegistered) then
                    useSquare = false -- keep the round stealable border until registered
                else
                    showSteal = showStealable and true or false
                    showMain = darkBorderEnabled
                end
            elseif darkBorderEnabled then
                showDark = true
            elseif main and main.engineRegistered then
                showMain = true
            else
                useSquare = false
            end
        end

        if not useSquare then
            if main then main:Hide() end
            if steal then steal:Hide() end
            if dark then dark:Hide() end
            return
        end

        if button.borderHost then button.borderHost:Hide() end
        local level = button.borderHost and button.borderHost:GetFrameLevel()

        if showMain then
            main = main or SB.Get(button, 1)
            SB.LayoutFor(main, button.icon, loc)
            if level then main:SetFrameLevel(level) end
            if isBuff then SB.SetDarkColor(main) end -- debuff strips are engine-colored
            main:Show()
        elseif main then
            main:Hide()
        end

        if showDark then
            dark = dark or SB.Get(button, 3)
            SB.LayoutFor(dark, button.icon, loc)
            if level then dark:SetFrameLevel(level) end
            SB.SetDarkColor(dark)
            dark:Show()
        elseif dark then
            dark:Hide()
        end

        if showSteal then
            SB.LayoutFor(steal, button.icon, loc)
            if level then steal:SetFrameLevel(level + 1) end
            steal:Show()
        elseif steal then
            steal:Hide()
        end
    end)
end

-- Generic per-button widget setup: icon/cooldown/text/border/stealable
-- overlay. Identical for every frame type that uses this container design --
-- only size/group membership differ, both passed in. updateStyleFn(button)
-- is called once at the end to apply the caller's current style.
function aurakit.InitAuraButton(container, button, groupKey, isBuff, size, isMine, updateStyleFn)
    if container then
        if not container.allButtons then container.allButtons = {} end
        container.allButtons[button] = true
        button.container = container
    end
    button:SetSize(size, size)
    button.groupKey = groupKey
    button.isBuff = isBuff
    button.elementSize = size
    button.isMine = isMine

    local icon = button.icon or button:CreateTexture(nil, "ARTWORK")
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    -- Independent pixel-grid snapping between the icon and border textures
    -- is what causes a hairline gap between them at non-1x UI scale (each
    -- texture rounds to the nearest physical pixel on its own) -- same fix
    -- Blizzard's own TargetFrame.lua uses on its scaled status bar textures.
    icon:SetTexelSnappingBias(0)
    icon:SetSnapToPixelGrid(false)
    button.icon = icon
    if button.SetIcon then
        pcall(button.SetIcon, button, icon)
    end

    local cd = button.cooldown or CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cd:ClearAllPoints()
    cd:SetAllPoints(icon)
    cd:SetReverse(true)
    cd:SetDrawEdge(false)
    cd:SetDrawSwipe(false)
    cd:SetHideCountdownNumbers(true)
    -- The swipe's default texture sweeps its dark shade all the way into the
    -- button's actual square corners, showing a hard, sharp-edged wedge
    -- there. Swap in a texture that's transparent in the four corners
    -- instead: the swipe still sweeps normally, it just never darkens those
    -- corner pixels. Confirmed working for the fill/background -- the only
    -- remaining artifact was the bright edge-highlight line still tracing a
    -- full circle, which is a separate flag from the swipe texture content:
    -- force it off explicitly (SetDrawEdge(false) alone wasn't enough to
    -- keep that line's own shape square).
    pcall(cd.SetSwipeTexture, cd, "Interface\\AddOns\\Uber UI\\textures\\auracornermask", 0, 0, 0, 0.8)
    pcall(cd.SetUseCircularEdge, cd, false)
    button.cooldown = cd
    if button.SetDurationCooldown then
        pcall(button.SetDurationCooldown, button, cd)
    end

    local textHolder = button.textHolder or CreateFrame("Frame", nil, button)
    textHolder:ClearAllPoints()
    textHolder:SetAllPoints(button)
    textHolder:SetFrameLevel(cd:GetFrameLevel() + 5)
    textHolder:EnableMouse(false)
    button.textHolder = textHolder

    local count = button.count or textHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:ClearAllPoints()
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.count = count
    if button.SetApplicationCount then
        pcall(button.SetApplicationCount, button, count, {})
    end

    local pad = (size >= 20) and 3 or 2
    local borderHost = button.borderHost or CreateFrame("Frame", nil, button)
    borderHost:ClearAllPoints()
    borderHost:SetPoint("TOPLEFT", button, "TOPLEFT", -pad, pad)
    borderHost:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", pad, -pad)
    borderHost:SetFrameLevel(cd:GetFrameLevel() + 2)
    borderHost:EnableMouse(false)

    local borderTex = button.borderTex or borderHost:CreateTexture(nil, "OVERLAY")
    borderTex:ClearAllPoints()
    borderTex:SetAllPoints(borderHost)
    borderTex:SetAtlas("ui-debuff-border-default-noicon")
    borderTex:SetTexelSnappingBias(0)
    borderTex:SetSnapToPixelGrid(false)

    button.borderHost = borderHost
    button.borderTex = borderTex

    -- Dedicated engine-colored border for stock-style debuffs (see
    -- ApplyAuraButtonStyle and TryRegisterDispelBorder). Debuffs only --
    -- buffs use the separate button.stealable mechanism below.
    if not isBuff and not button.dispelBorderHost then
        local dispelBorderHost = CreateFrame("Frame", nil, borderHost)
        dispelBorderHost:SetAllPoints(borderHost)
        dispelBorderHost:EnableMouse(false)
        dispelBorderHost:Hide()

        local dispelBorderTex = dispelBorderHost:CreateTexture(nil, "OVERLAY")
        dispelBorderTex:SetAllPoints(dispelBorderHost)
        dispelBorderTex:SetAtlas("ui-debuff-border-default-noicon")
        dispelBorderTex:SetTexelSnappingBias(0)
        dispelBorderTex:SetSnapToPixelGrid(false)

        button.dispelBorderHost = dispelBorderHost
        button.dispelBorderTexPending = dispelBorderTex
    end

    -- Our own rounded ring (same art as the Dark border), tinted by the
    -- ENGINE with the real dispel color (PreserveAsset keeps the art and only
    -- applies AuraUtil.SetAuraBorderColor, so it's right even while aura data
    -- is secret). This is what "Dispel Color" shows, so Dark and Dispel Color
    -- are the same ring with only the color changing; dispelBorderHost above
    -- (Blizzard's per-type art) is the fallback until this registers.
    if not isBuff and not button.roundDispelHost then
        local roundDispelHost = CreateFrame("Frame", nil, borderHost)
        roundDispelHost:SetAllPoints(borderHost)
        roundDispelHost:EnableMouse(false)
        roundDispelHost:Hide()

        local roundDispelTex = roundDispelHost:CreateTexture(nil, "OVERLAY")
        roundDispelTex:SetAllPoints(roundDispelHost)
        roundDispelTex:SetAtlas("ui-debuff-border-default-noicon")
        roundDispelTex:SetDesaturated(true)
        roundDispelTex:SetTexelSnappingBias(0)
        roundDispelTex:SetSnapToPixelGrid(false)

        button.roundDispelHost = roundDispelHost
        button.roundDispelTexPending = roundDispelTex
    end

    -- Buffs only: Blizzard's own StealableBorder texture, layered over (not
    -- replacing) the normal border. stealableHost is OUR frame, never
    -- registered, so the "Show Dispels" option can reliably show/hide it
    -- regardless of the (also-registered) button.stealable.
    if isBuff and not button.stealableHost then
        local stealableHost = CreateFrame("Frame", nil, borderHost)
        stealableHost:SetAllPoints(borderHost)
        stealableHost:EnableMouse(false)
        stealableHost:Hide()

        local stealable = stealableHost:CreateTexture(nil, "OVERLAY")
        stealable:SetAllPoints(stealableHost)
        stealable:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
        stealable:SetBlendMode("ADD")
        stealable:SetTexelSnappingBias(0)
        stealable:SetSnapToPixelGrid(false)

        button.stealableHost = stealableHost
        button.stealable = stealable
    end

    if updateStyleFn then
        updateStyleFn(button)
    end
end

-- Two permanent, structurally-identical containers -- debuffs and buffs --
-- each with a fixed "mine"(large)/"other"(small) group pair, never
-- reconfigured after creation. Which one anchors under the health bar is
-- decided entirely by the caller's UpdatePairedPositions call, not touched
-- again here.
--
-- opts: {
--   namePrefix, parentFrame, unitToken,
--   mineKey, otherKey, mineFilter, otherFilter,
--   frameLevelBonus, largeSize, smallSize, spacing,
--   updateStyleFn(button),      -- applies current style to one button
--   isUpdating(),               -- returns true while caller's own UpdateAuras is running
--   onApplyLayout(),            -- optional, called after a Blizzard-driven ApplyLayout refresh
--   clearUpdating(),            -- optional, called after onApplyLayout
-- }
function aurakit.BuildAuraContainer(opts)
    local okC, container = pcall(function()
        return CreateFrame("AuraContainer", opts.namePrefix, opts.parentFrame, "CustomAuraContainerTemplate")
    end)
    if not okC or not container then return nil end

    container:SetSize(1, 1)
    if opts.parentFrame and opts.parentFrame.GetFrameLevel then
        container:SetFrameLevel(opts.parentFrame:GetFrameLevel() + opts.frameLevelBonus)
    end
    container:SetFlowLayoutMaximumLineSize(122)
    container:SetFlowLayoutPadding(0, 0, 0, 0)
    if container.SetFlowLayoutSpacing then
        pcall(container.SetFlowLayoutSpacing, container, opts.spacing, opts.spacing + 2)
    end

    local mineKey, otherKey = opts.mineKey, opts.otherKey

    container:AddAuraGroup(mineKey, opts.mineFilter, {
        maxFrameCount = 16,
        initializeFrame = function(btn)
            aurakit.InitAuraButton(container, btn, mineKey, opts.mineFilter:find("HELPFUL") ~= nil, opts.largeSize, true, opts.updateStyleFn)
        end,
        layout = aurakit.MakeGroupLayout(opts.largeSize, opts.spacing, opts.spacing, false, 1),
    })

    container:AddAuraGroup(otherKey, opts.otherFilter, {
        maxFrameCount = 16,
        initializeFrame = function(btn)
            aurakit.InitAuraButton(container, btn, otherKey, opts.otherFilter:find("HELPFUL") ~= nil, opts.smallSize, false, opts.updateStyleFn)
        end,
        layout = aurakit.MakeGroupLayout(opts.smallSize, opts.spacing, opts.spacing, false, 2),
    })

    if container.ApplyLayout then
        hooksecurefunc(container, "ApplyLayout", function()
            if opts.isUpdating and opts.isUpdating() then return end
            aurakit.RefreshContainerButtons(container, mineKey, otherKey, opts.updateStyleFn)
            if opts.onApplyLayout then opts.onApplyLayout() end
            if opts.clearUpdating then opts.clearUpdating() end
        end)
    end

    if container.UpdateAllAuras then
        hooksecurefunc(container, "UpdateAllAuras", function()
            if opts.isUpdating and opts.isUpdating() then return end
            aurakit.RefreshContainerButtons(container, mineKey, otherKey, opts.updateStyleFn)
        end)
    end

    if container.UpdateAuraGroup then
        hooksecurefunc(container, "UpdateAuraGroup", function()
            if opts.isUpdating and opts.isUpdating() then return end
            aurakit.RefreshContainerButtons(container, mineKey, otherKey, opts.updateStyleFn)
        end)
    end

    container:SetUnit(opts.unitToken)
    container:UpdateAllAuras()
    return container
end

-- Generic container with any number of groups, for frames that don't use
-- the target/focus mine/other pair (compact party/raid frames). Each group
-- description:
--   { key, filter, isBuff, size, maxFrameCount, layoutIndex,
--     sortMethod, candidateFilters }
-- isBuff is explicit (not derived from the filter) because Blizzard's
-- ProcessAura classification can put a HELPFUL aura (boss buffs) in a
-- debuff-styled group.
--
-- opts: {
--   name, parentFrame, frameLevelBonus, spacing, maxLineSize,
--   processAura,       -- optional SetAuraProcessingPolicy(ProcessAura) options
--   groups,            -- array of group descriptions (above)
--   updateStyleFn(button),
-- }
--
-- Unit starts as "none" (the engine's null binding). Callers point it at a
-- real unit with container:SetUnit() -- never "player" as a placeholder, or
-- an unassigned container shows the player's own auras.
function aurakit.BuildGroupedAuraContainer(opts)
    local okC, container = pcall(function()
        return CreateFrame("AuraContainer", opts.name, opts.parentFrame, "CustomAuraContainerTemplate")
    end)
    if not okC or not container then return nil end

    container:SetSize(1, 1)
    if opts.parentFrame and opts.parentFrame.GetFrameLevel then
        container:SetFrameLevel(opts.parentFrame:GetFrameLevel() + (opts.frameLevelBonus or 0))
    end
    container:SetFlowLayoutMaximumLineSize(opts.maxLineSize)
    container:SetFlowLayoutPadding(0, 0, 0, 0)
    if container.SetFlowLayoutSpacing then
        pcall(container.SetFlowLayoutSpacing, container, opts.spacing, opts.spacing)
    end

    -- Must be set before any group exists: AddAuraGroup parses immediately,
    -- and processedAuraType candidate filters hide everything without it.
    if opts.processAura and container.SetAuraProcessingPolicy and CustomAuraContainerAuraProcessingPolicy then
        pcall(container.SetAuraProcessingPolicy, container,
            CustomAuraContainerAuraProcessingPolicy.ProcessAura, opts.processAura)
    end

    container.uuGroups = {}
    container.uuGroupKeys = {}
    container.uuSpacing = opts.spacing

    for index, group in ipairs(opts.groups) do
        local def = {
            key = group.key,
            isBuff = group.isBuff,
            size = group.size,
            layoutIndex = group.layoutIndex or index,
        }
        container.uuGroups[group.key] = def
        container.uuGroupKeys[#container.uuGroupKeys + 1] = group.key

        local groupOptions = {
            maxFrameCount = group.maxFrameCount or 0,
            -- Reads def.size at init time, not a captured copy, so buttons
            -- created after a SetGroupedContainerSizes call get the new size.
            initializeFrame = function(btn)
                aurakit.InitAuraButton(container, btn, def.key, def.isBuff, def.size, false, opts.updateStyleFn)
            end,
            layout = aurakit.MakeGroupLayout(def.size, opts.spacing, opts.spacing, false, def.layoutIndex),
        }
        if group.sortMethod ~= nil and AuraContainerSortDirection then
            groupOptions.sortMethod = group.sortMethod
            groupOptions.sortDirection = AuraContainerSortDirection.Normal
        end
        if group.candidateFilters then
            groupOptions.candidateFilters = group.candidateFilters
        end

        local okG, errG = pcall(container.AddAuraGroup, container, group.key, group.filter, groupOptions)
        if not okG then
            container.uuGroupErrors = container.uuGroupErrors or {}
            container.uuGroupErrors[group.key] = tostring(errG)
        end
    end

    local function refresh()
        aurakit.RefreshGroupButtons(container, container.uuGroupKeys, opts.updateStyleFn)
    end
    if container.ApplyLayout then hooksecurefunc(container, "ApplyLayout", refresh) end
    if container.UpdateAllAuras then hooksecurefunc(container, "UpdateAllAuras", refresh) end
    if container.UpdateAuraGroup then hooksecurefunc(container, "UpdateAuraGroup", refresh) end

    return container
end

-- Resize groups of a BuildGroupedAuraContainer container in place (Edit Mode
-- icon size % changed). sizes = { [groupKey] = size }. Updates the group's
-- flow layout and every button already created for it; buttons created
-- later pick the new size up from the group def.
function aurakit.SetGroupedContainerSizes(container, sizes, updateStyleFn)
    if not container or not container.uuGroups then return end
    for key, size in pairs(sizes) do
        local def = container.uuGroups[key]
        if def and def.size ~= size then
            def.size = size
            if container.SetAuraGroupLayout then
                pcall(container.SetAuraGroupLayout, container, key,
                    aurakit.MakeGroupLayout(size, container.uuSpacing, container.uuSpacing, false, def.layoutIndex))
            end
            if container.allButtons then
                for btn in pairs(container.allButtons) do
                    if btn.groupKey == key then
                        btn.elementSize = size
                        pcall(btn.SetSize, btn, size, size)
                        if updateStyleFn then pcall(updateStyleFn, btn) end
                    end
                end
            end
        end
    end
end

-- Shared show/hide for both permanent containers together. frameObj is
-- whatever module table owns .customDebuffs/.customBuffs (e.g. targetframes,
-- focusframes).
function aurakit.ShowAuraContainers(frameObj, shown)
    if not frameObj then return end
    if frameObj.customDebuffs then
        if shown then frameObj.customDebuffs:Show() else frameObj.customDebuffs:Hide() end
    end
    if frameObj.customBuffs then
        if shown then frameObj.customBuffs:Show() else frameObj.customBuffs:Hide() end
    end
end

function aurakit.GetAuraContainers(frameObj)
    return { frameObj.customDebuffs, frameObj.customBuffs }
end

-- Whether a container is showing any aura: true (at least one shown), false
-- (every button positively reports hidden), or nil (can't tell). In combat
-- the engine makes aura buttons' state secret or refuses the read outright,
-- and the old geometry-based check (GetContainerAuraExtent, removed) treated that
-- the same as "nothing shown" --
-- which made an enemy WITH debuffs look empty, pinning its buff row onto the
-- debuff row (regression from 031b8ef's gap fix). Callers should only act on
-- a positive false.
function aurakit.ContainerHasShownAuras(container)
    if not container or not container.allButtons then return false end
    local unknown = false
    for button in pairs(container.allButtons) do
        if not button or IsSecret(button) then
            unknown = true
        else
            local ok, shown = pcall(button.IsShown, button)
            if not ok or IsSecret(shown) then
                unknown = true
            elseif shown then
                return true
            end
        end
    end
    if unknown then return nil end
    return false
end

-- Which container sits directly under the health/mana bar ("primary") vs
-- trails behind it ("secondary") swaps with hostility: debuffs primary on
-- an enemy, buffs primary on a friendly (including self). This is a plain
-- SetPoint on a container-level frame, not a per-AuraButton call, so it
-- isn't subject to the forbidden/combat-secrecy restriction. The secondary
-- container anchors to the primary's own edge (not a fixed refFrame
-- offset), so it auto-restacks when the primary's size changes, including
-- collapsing to ~0 when empty -- "no buffs -> debuffs sit where buffs
-- would've been" for free, no row-counting needed.
-- opts: { frameObj, refFrame, isEnemyFn(), buffsOnTop, topX, topY, topOnTopX, containerGap }
function aurakit.UpdatePairedPositions(opts)
    local frameObj, refFrame = opts.frameObj, opts.refFrame
    if not frameObj.customDebuffs or not frameObj.customBuffs or not refFrame then return end

    local isEnemy = opts.isEnemyFn()
    local primary, secondary
    if isEnemy then
        primary, secondary = frameObj.customDebuffs, frameObj.customBuffs
    else
        primary, secondary = frameObj.customBuffs, frameObj.customDebuffs
    end

    primary:ClearAllPoints()
    secondary:ClearAllPoints()

    -- The ask was narrow: on an enemy with no debuff, nudge its (secondary)
    -- buff row up closer to the frame instead of leaving it hanging off
    -- where the empty debuff row would have been. Everything else --
    -- including the friendly side, where buffs are primary and debuffs
    -- trail -- keeps the original unconditional chain (secondary anchored
    -- straight off primary's own edge, live-updating with zero extra calls
    -- as primary's row count changes). Scoping the bypass to isEnemy only
    -- avoids the friendly-side regression where an over-eager "is primary
    -- empty" check picked the wrong anchor and stacked debuffs on top of
    -- buffs instead of below them.
    -- Only a POSITIVE "nothing shown" bypasses the chain; if the debuff
    -- buttons can't be read (combat), keep the chain so buffs still follow
    -- below real debuffs.
    local primaryIsEmpty = false
    if isEnemy then
        primaryIsEmpty = (aurakit.ContainerHasShownAuras(primary) == false)
    end

    if opts.buffsOnTop then
        local ref = (refFrame.TargetFrameContainer and refFrame.TargetFrameContainer.FrameTexture) or refFrame
        local offsetX = (ref == refFrame) and opts.topX or opts.topOnTopX
        local startY = -6
        local extraY = 0
        if refFrame.threatNumericIndicator and refFrame.threatNumericIndicator:IsShown() then
            local th = refFrame.threatNumericIndicator:GetHeight()
            if th and th > 0 then
                extraY = math.max(extraY, th)
            end
        end
        local leader = aurakit.GetLeaderIcon(refFrame)
        if leader then
            local lh = (leader.GetHeight and leader:GetHeight()) or 0
            if not lh or lh <= 0 then lh = 18 end
            extraY = math.max(extraY, lh)
        end
        startY = startY + extraY
        primary:SetPoint("BOTTOMLEFT", ref, "TOPLEFT", offsetX, startY)
        if primaryIsEmpty then
            secondary:SetPoint("BOTTOMLEFT", ref, "TOPLEFT", offsetX, startY + opts.containerGap)
        else
            secondary:SetPoint("BOTTOMLEFT", primary, "TOPLEFT", 0, opts.containerGap)
        end
        for _, c in ipairs({ primary, secondary }) do
            if c.SetFlowLayoutAnchorPoint then
                pcall(c.SetFlowLayoutAnchorPoint, c, "BOTTOMLEFT")
            end
            if c.SetFlowLayoutGrowthDirection then
                pcall(c.SetFlowLayoutGrowthDirection, c, 1, 1)
            end
        end
    else
        primary:SetPoint("TOPLEFT", refFrame, "BOTTOMLEFT", opts.topX, opts.topY)
        if primaryIsEmpty then
            secondary:SetPoint("TOPLEFT", refFrame, "BOTTOMLEFT", opts.topX, opts.topY - opts.containerGap)
        else
            secondary:SetPoint("TOPLEFT", primary, "BOTTOMLEFT", 0, -opts.containerGap)
        end
        for _, c in ipairs({ primary, secondary }) do
            if c.SetFlowLayoutAnchorPoint then
                pcall(c.SetFlowLayoutAnchorPoint, c, "TOPLEFT")
            end
            if c.SetFlowLayoutGrowthDirection then
                pcall(c.SetFlowLayoutGrowthDirection, c, 1, -1)
            end
        end
    end
end

-- Spellbar auto-repositioning below whichever container's buttons sit
-- lowest. isAdjustingSpellbar is a single shared reentrancy latch: it only
-- guards against a spellbar's own AdjustPosition hook recursively
-- retriggering itself, so sharing it across every frame type that uses this
-- kit is correct, not a cross-frame data leak.
local isAdjustingSpellbar = false

function aurakit.TriggerSpellbarAdjust(spellbar)
    if isAdjustingSpellbar or not spellbar.AdjustPosition then return end
    isAdjustingSpellbar = true
    pcall(spellbar.AdjustPosition, spellbar)
    isAdjustingSpellbar = false
end

function aurakit.UpdateSpellbar(frameObj, containers)
    if InCombatLockdown() then return end
    if not frameObj then return end
    local spellbar = frameObj.spellbar or (frameObj.GetName and _G[frameObj:GetName() .. "SpellBar"])
    if not spellbar then return end

    if frameObj.buffsOnTop then
        frameObj.auraRows = 0
        frameObj.spellbarAnchor = nil
        aurakit.TriggerSpellbarAdjust(spellbar)
        return
    end

    local visibleButtons = {}
    if containers then
        for _, container in ipairs(containers) do
            if container and container.allButtons and container:IsShown() then
                for button in pairs(container.allButtons) do
                    if button and not IsSecret(button) and not SafeIsForbidden(button) then
                        local okS, isShown = pcall(button.IsShown, button)
                        if okS and SafeBool(isShown) then
                            local okB, bottom = pcall(button.GetBottom, button)
                            local okL, left = pcall(button.GetLeft, button)
                            if okB and okL and bottom and left and not IsSecret(bottom) and not IsSecret(left) then
                                table.insert(visibleButtons, { btn = button, bottom = bottom, left = left })
                            end
                        end
                    end
                end
            end
        end
    end

    if #visibleButtons == 0 then
        frameObj.auraRows = 0
        frameObj.spellbarAnchor = nil
        aurakit.TriggerSpellbarAdjust(spellbar)
        return
    end

    table.sort(visibleButtons, function(a, b)
        return a.bottom < b.bottom
    end)

    local rows = 1
    local currentBottom = visibleButtons[1].bottom
    for i = 2, #visibleButtons do
        if math.abs(visibleButtons[i].bottom - currentBottom) > 4 then
            rows = rows + 1
            currentBottom = visibleButtons[i].bottom
        end
    end

    local minBottom = visibleButtons[1].bottom
    local lowestLeftBtn = visibleButtons[1].btn
    local minLeft = visibleButtons[1].left
    for _, item in ipairs(visibleButtons) do
        if math.abs(item.bottom - minBottom) <= 4 then
            if item.left < minLeft then
                minLeft = item.left
                lowestLeftBtn = item.btn
            end
        end
    end

    frameObj.auraRows = rows
    frameObj.spellbarAnchor = lowestLeftBtn

    aurakit.TriggerSpellbarAdjust(spellbar)
end

function aurakit.HookSpellbarAdjustPosition(spellbar, frameObj, getContainer)
    if not spellbar or not spellbar.AdjustPosition or spellbar._uberUIHooked then return end
    spellbar._uberUIHooked = true
    hooksecurefunc(spellbar, "AdjustPosition", function(self)
        if isAdjustingSpellbar or InCombatLockdown() then return end
        local parent = self:GetParent()
        if parent ~= frameObj then return end
        local containers = getContainer and getContainer()
        if containers then
            aurakit.UpdateSpellbar(frameObj, containers)
        end
    end)
end

UberUI.aurakit = aurakit
