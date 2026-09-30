-- Shared building blocks for the custom aura containers (target, focus,
-- boss, compact frames). Per-frame details are passed in by the caller.

local addon, ns = ...

local aurakit = {}

local IsSecret, SafeBool = UberUI.util.IsSecret, UberUI.util.SafeBool

local function SafeIsForbidden(frame)
    if not frame or IsSecret(frame) then return true end
    local ok, isForbid = pcall(frame.IsForbidden, frame)
    if not ok then return true end
    return SafeBool(isForbid)
end

aurakit.IsSecret = IsSecret
aurakit.SafeBool = SafeBool
aurakit.SafeIsForbidden = SafeIsForbidden

-- Blizzard's nameplate aura size. The duration text scales against it
-- everywhere (its font is the nameplate countdown font); it's also the
-- default stack count reference.
local TEXT_REF_SIZE = NamePlateConstants and NamePlateConstants.AURA_ITEM_HEIGHT or 25

-- Per-location aura text settings (auratext_<loc>_*): duration and stack
-- text size as multipliers, the stack count's anchor and offset, and
-- Player's centered duration. Shared by every aura location, including the
-- Blizzard-drawn ones (Player, Party).
local STACK_ANCHORS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}
function aurakit.TextSettings(loc)
    local g = uuidb and uuidb.general or {}
    local k = "auratext_" .. tostring(loc) .. "_"
    local function Scale(v)
        v = tonumber(v) or 100
        return math.max(0.25, math.min(3, v / 100))
    end
    local anchor = g[k .. "stackanchor"]
    return {
        duration = Scale(g[k .. "durationsize"]),
        stack = Scale(g[k .. "stacksize"]),
        anchor = STACK_ANCHORS[anchor] and anchor or "BOTTOMRIGHT",
        x = tonumber(g[k .. "stackx"]) or 0,
        y = tonumber(g[k .. "stacky"]) or 0,
        center = g[k .. "centerduration"] == true,
    }
end

-- Places a stack count at the chosen anchor plus offset. The location's own
-- stock offset (nativeX/Y) only applies in its stock bottom-right corner.
function aurakit.PlaceCount(count, owner, t, nativeX, nativeY)
    local bx, by = 0, 0
    if t.anchor == "BOTTOMRIGHT" then bx, by = nativeX or 0, nativeY or 0 end
    count:ClearAllPoints()
    count:SetPoint(t.anchor, owner, t.anchor, bx + t.x, by + t.y)
    local justify = (t.anchor:find("LEFT") and "LEFT") or (t.anchor:find("RIGHT") and "RIGHT") or "CENTER"
    count:SetJustifyH(justify)
end

-- Sizes the stack count to the button's icon size, against the container's
-- _uberCountRefSize: the location's stock icon size, where Blizzard draws
-- the count font unscaled; times the location's Stack Text Size. Sized from
-- the font object, not the current font, so repeated calls don't compound;
-- only re-applied when something it depends on changes.
local function UpdateCountSize(button)
    local count = button.count
    if not count or not NumberFontNormalSmall then return end
    local iconSize = button.elementSize or TEXT_REF_SIZE
    local t = aurakit.TextSettings(button._uberTextLoc)
    local key = table.concat({ iconSize, t.stack, t.anchor, t.x, t.y }, "|")
    if button.uuCountSize == key then return end
    local container = button.container
    local fontObject = container and container._uberCountFont or NumberFontNormalSmall
    local font, fsize, flags = fontObject:GetFont()
    if not font then return end
    local refSize = container and container._uberCountRefSize or TEXT_REF_SIZE
    count:SetFont(font, math.max(4, math.floor(fsize * iconSize / refSize * t.stack + 0.5)), flags)
    -- Blizzard's own count offsets differ per location (see InitAuraButton);
    -- containers override via _uberCountOffset, default the target frame's.
    local off = container and container._uberCountOffset
    aurakit.PlaceCount(count, button, t, off and off[1] or 1, off and off[2] or 0)
    button.uuCountSize = key
end

-- When a unit is in another zone the engine can fail to resolve an aura's
-- source, and the aura then matches both "|PLAYER" and "|!PLAYER". Detected
-- so the "mine" group can be hidden and the aura shows once, in "other".
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

-- 0 instead of normalMaxCount while the unit has ambiguous "mine" matches.
function aurakit.GetSafeMineMaxFrameCount(unit, isHarmful, normalMaxCount)
    if aurakit.HasAmbiguousMineMatch(unit, isHarmful) then
        return 0
    end
    return normalMaxCount
end

-- Blizzard's real Target/Focus/Boss frames (TargetFrameAuraContainerPrivateMixin,
-- Interface/AddOns/Blizzard_UnitFrame/Shared/TargetFrameAuraContainer.lua) hide
-- other players'/pets' debuffs by default, governed by the "noBuffDebuffFilterOnTarget"
-- CVar. Our custom "debuffs_other" group has no such rule built in (it's a plain
-- HARMFUL|!PLAYER filter), so callers gate that group's max frame count on this.
function aurakit.ShowAllTargetDebuffs()
    return CVarCallbackRegistry:GetCVarValueBool("noBuffDebuffFilterOnTarget") and true or false
end

-- exactLineSpacing: rows exactly spacingY apart (Blizzard's target frame);
-- otherwise spacingY + 2.
function aurakit.MakeGroupLayout(elementSize, spacingX, spacingY, forceNewLine, layoutIndex, exactLineSpacing)
    spacingX = spacingX or 1
    spacingY = spacingY or 1
    local lineSpacing = exactLineSpacing and spacingY or (spacingY + 2)
    return {
        elementWidth = elementSize,
        elementHeight = elementSize,
        elementSpacing = spacingX,
        lineSpacing = lineSpacing,
        groupSpacing = -1,
        groupLineSpacing = lineSpacing,
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

-- Every active button in a container's two groups, from the container's own
-- group membership. A button's buff/debuff role is fixed by its group.
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

-- RefreshContainerButtons for BuildGroupedAuraContainer (any number of groups).
function aurakit.RefreshGroupButtons(container, groupKeys, updateStyleFn)
    if not container or not updateStyleFn or not groupKeys then return end
    for _, key in ipairs(groupKeys) do
        aurakit.ForEachActiveAuraButton(container, key, nil, function(btn)
            pcall(updateStyleFn, btn)
        end)
    end
end

-- AddDispelTypeTexture is refused while aura data is secret (loading
-- screens), so registration is retried every style pass until it sticks.
-- Buffs: Blizzard's StealableBorder texture, gated by stealableFilter so the
-- engine decides show/hide from the secret isStealable flag. CustomAsset
-- (not PreserveAsset) keeps it white.
function aurakit.TryRegisterDispelBorder(button)
    if type(button.AddDispelTypeTexture) ~= "function" then return end
    if not (Enum and Enum.CustomAuraButtonDispelTypeTextureStyle) then return end

    -- Square strips are registered up front too (debuffs: dispel-colored,
    -- slot 1; buffs: stealable-gated, slot 2) so switching to square needs no
    -- aura update to get real colors.
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

-- Rounded white "purgeable" border (opts.stealableRing): a white texture
-- masked by the rounded border art (which is red, so it can't be tinted),
-- engine-registered so it only shows on stealable buffs. Lives on the button,
-- not borderHost, which "None" and square borders hide.
local RING_ATLAS = "ui-debuff-border-default-noicon"
local ringHosts = setmetatable({}, { __mode = "k" }) -- button -> host frame

local function GetStealableRing(button)
    local host = ringHosts[button]
    if not host then
        if not button.borderHost then return nil end
        host = CreateFrame("Frame", nil, button)
        host:ClearAllPoints()
        host:SetAllPoints(button.borderHost)
        host:EnableMouse(false)
        host:Hide()
        local tex = host:CreateTexture(nil, "OVERLAY", nil, 2)
        tex:ClearAllPoints()
        tex:SetAllPoints(host)
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetTexelSnappingBias(0)
        tex:SetSnapToPixelGrid(false)
        local mask = host:CreateMaskTexture()
        mask:ClearAllPoints()
        mask:SetAtlas(RING_ATLAS)
        mask:SetAllPoints(host)
        mask:SetTexelSnappingBias(0)
        mask:SetSnapToPixelGrid(false)
        tex:AddMaskTexture(mask)
        host.tex = tex
        ringHosts[button] = host
    end
    host:SetFrameLevel(button.borderHost:GetFrameLevel() + 2)
    if not host.registered then
        local SB = UberUI.squareborders
        local o = SB and SB.StealableEngineOptions()
        if o and button.AddDispelTypeTexture and pcall(button.AddDispelTypeTexture, button, host.tex, o) then
            host.registered = true
        end
    end
    return host
end

-- opts: { style = "both"|"zoom"|"border"|"none", showDispel = bool,
--         squareLoc, stealableRing }, already resolved by the caller for
-- this button's buff/debuff role.
function aurakit.ApplyAuraButtonStyle(button, opts)
    if not button or IsSecret(button) then return end
    -- No SafeIsForbidden bail-out: a forbidden button still accepts border
    -- show/hide, and every widget call below is pcall-wrapped.
    aurakit.TryRegisterDispelBorder(button)

    -- The location's text settings (stack count here, duration text in
    -- UpdateDurationText) follow its square-border location key.
    if opts and opts.squareLoc then button._uberTextLoc = opts.squareLoc end
    UpdateCountSize(button)

    -- Layers, relative to the button on every style pass: icon (the button),
    -- cooldown swipe, borders, text. Levels set once at creation don't follow
    -- when the container re-levels its pooled buttons, which left the borders
    -- under the icon.
    pcall(function()
        local level = button:GetFrameLevel()
        if button.cooldown then button.cooldown:SetFrameLevel(level + 1) end
        if button.borderHost then button.borderHost:SetFrameLevel(level + 3) end
        if button.textHolder then button.textHolder:SetFrameLevel(level + 8) end
    end)

    local isBuff = button.isBuff
    local style = (opts and opts.style) or "both"
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    -- Square borders sit on or outside the icon edge, so the icon fills the
    -- button instead of keeping the round border's 1px inset.
    local SBk = UberUI.squareborders
    local squareOn = opts and opts.squareLoc and style ~= "none" and SBk and SBk.IsEnabled(opts.squareLoc)
    if button.icon then
        pcall(function()
            button.icon:ClearAllPoints()
            if (darkBorderEnabled or zoomEnabled) and not squareOn then
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
        -- Cooldown follows the icon's bounds so the swipe never overhangs it.
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

            local hostLevel = button.borderHost:GetFrameLevel()
            if button.roundDispelHost then
                button.roundDispelHost:ClearAllPoints()
                button.roundDispelHost:SetAllPoints(button.borderHost)
                button.roundDispelHost:SetFrameLevel(hostLevel + 2)
            end
            if button.dispelBorderHost then
                button.dispelBorderHost:ClearAllPoints()
                button.dispelBorderHost:SetAllPoints(button.borderHost)
                button.dispelBorderHost:SetFrameLevel(hostLevel + 1)
            end
            if button.stealableHost then
                button.stealableHost:ClearAllPoints()
                button.stealableHost:SetAllPoints(button.borderHost)
                button.stealableHost:SetFrameLevel(hostLevel + 2)
            end

            -- Debuff dispel colors can't be computed (dispelName is secret),
            -- so the engine colors the registered textures and we only
            -- show/hide their hosts.
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
                button.borderHost:Hide()
                if button.borderTex then button.borderTex:Hide() end
                if button.dispelBorderHost then button.dispelBorderHost:Hide() end
                if button.roundDispelHost then button.roundDispelHost:Hide() end
            end

            -- Debuffs only; buffs use button.stealable below.
            local function ApplyDispelColoredBorder()
                button.borderHost:Show()
                -- Prefer the pandemic-style masked ColorTexture (roundDispelHost)
                -- which renders at hostLevel + 2, on top of any dark border.
                if button.roundDispelHost then
                    button.roundDispelHost:Show()
                    if button.dispelBorderHost then button.dispelBorderHost:Hide() end
                    if button.borderTex then button.borderTex:Hide() end
                elseif button.dispelBorderTex or (button.dispelBorderHost and not button.roundDispelTex) then
                    button.dispelBorderHost:Show()
                    if button.borderTex then button.borderTex:Hide() end
                elseif button.borderTex then
                    button.borderTex:Show()
                    button.borderTex:SetAtlas("ui-debuff-border-default-noicon")
                    button.borderTex:SetDesaturated(false)
                    button.borderTex:SetVertexColor(1, 1, 1, 1)
                end
            end

            if button._uberInPandemic then
                ApplyNoBorder()
            elseif isBuff then
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

            -- stealableHost is our own (unregistered) frame, so showDispel
            -- gates it independently of the engine-registered texture.
            if button.stealableHost then
                local showStealable = isBuff and UberUI.general:PlayerCanOffensiveDispel() and
                (opts and opts.showDispel)
                if opts and opts.stealableRing then
                    button.stealableHost:Hide() -- the white ring below replaces it
                elseif showStealable then
                    button.stealableHost:Show()
                else
                    button.stealableHost:Hide()
                end
            end
        end)
    end

    aurakit.ApplySquareBorder(button, opts, style, darkBorderEnabled)

    if opts and opts.stealableRing and isBuff then
        pcall(function()
            local ring = GetStealableRing(button)
            if not ring then return end
            local showStealable = UberUI.general:PlayerCanOffensiveDispel() and opts.showDispel
            -- Square borders never show the rounded ring (their own white
            -- strips once registered). Decided from settings: the strips'
            -- IsShown is secret here.
            ring:SetShown((showStealable and ring.registered and not squareOn) and true or false)
        end)
    end
end

-- Square mode hides every rounded border host (separate frames on the
-- button). Blizzard's aura code only Show()s the textures inside them, never
-- the hosts, so hidden hosts stay hidden.
local ROUND_HOSTS = { "borderHost", "dispelBorderHost", "roundDispelHost", "stealableHost" }
local function HideRoundHosts(button)
    for _, key in ipairs(ROUND_HOSTS) do
        local host = button[key]
        if host then pcall(host.Hide, host) end
    end
end

-- Square borders for opts.squareLoc, following the same Buff/Debuff Border
-- choices. Slots: 1 = buff dark border / debuff engine dispel strips,
-- 2 = buff engine stealable strips, 3 = debuff dark border (the engine
-- re-tints slot 1, so it can't be darkened). Until the engine strips are
-- registered, debuffs get the dark border (never the rounded art).
function aurakit.ApplySquareBorder(button, opts, style, darkBorderEnabled)
    local SB = UberUI.squareborders
    if not SB or not button.icon then return end
    pcall(function()
        local loc = opts and opts.squareLoc
        local useSquare = loc and style ~= "none" and SB.IsEnabled(loc)
        if useSquare then HideRoundHosts(button) end
        local isBuff = button.isBuff
        local main, steal, dark = SB.Find(button, 1), SB.Find(button, 2), SB.Find(button, 3)
        local showMain, showSteal, showDark = false, false, false

        if button._uberInPandemic then
            useSquare = false
        elseif useSquare then
            if isBuff then
                local showStealable = UberUI.general:PlayerCanOffensiveDispel() and opts.showDispel
                showSteal = (showStealable and steal and steal.engineRegistered) and true or false
                showMain = darkBorderEnabled
            elseif darkBorderEnabled or not (main and main.engineRegistered) then
                -- Dark until the engine dispel strips register: square mode
                -- never falls back to the rounded dispel art.
                showDark = true
            else
                showMain = true
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
            if isBuff then
                SB.LayoutFor(main, button.icon, loc)
                if level then main:SetFrameLevel(level) end
                SB.SetDarkColor(main)
            else
                SB.LayoutDispelFor(main, button.icon, loc)
                if level then main:SetFrameLevel(level + 1) end
            end
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
            SB.LayoutDispelFor(steal, button.icon, loc)
            if level then steal:SetFrameLevel(level + 2) end
            steal:Show()
        elseif steal then
            steal:Hide()
        end
    end)
end

-- Per-button widget setup; updateStyleFn(button) applies the caller's style.
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
    -- Unsnapped so icon and border textures don't round to pixels apart
    -- (hairline gaps at non-1x UI scale).
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
    -- A swipe texture transparent in the corners keeps the dark sweep off the
    -- square corners; the circular edge line is turned off separately.
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

    -- Blizzard's own count offsets, which differ per location and are the same
    -- on retail and Forever: target/focus/boss aura buttons use BOTTOMRIGHT
    -- x=1 (TargetFrameAuraButton.xml), nameplates x=3 y=-2
    -- (Blizzard_NamePlateAuras.xml). Both overhang rather than inset -- the
    -- inset we used before pushed the count into the centred duration text.
    -- Containers override via _uberCountOffset; the default is the target
    -- frame's, which is what most callers are.
    local count = button.count or textHolder:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.count = count
    UpdateCountSize(button)
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

    -- Engine-colored border for debuffs (see TryRegisterDispelBorder).
    if not isBuff and not button.dispelBorderHost then
        local dispelBorderHost = CreateFrame("Frame", nil, button)
        dispelBorderHost:ClearAllPoints()
        dispelBorderHost:SetAllPoints(borderHost)
        dispelBorderHost:SetFrameLevel(borderHost:GetFrameLevel() + 1)
        dispelBorderHost:EnableMouse(false)
        dispelBorderHost:Hide()

        local dispelBorderTex = dispelBorderHost:CreateTexture(nil, "OVERLAY", nil, 1)
        dispelBorderTex:ClearAllPoints()
        dispelBorderTex:SetAllPoints(dispelBorderHost)
        dispelBorderTex:SetAtlas("ui-debuff-border-default-noicon")
        dispelBorderTex:SetTexelSnappingBias(0)
        dispelBorderTex:SetSnapToPixelGrid(false)

        button.dispelBorderHost = dispelBorderHost
        button.dispelBorderTexPending = dispelBorderTex
    end

    -- Rounded dispel ring: a white ColorTexture masked by the rounded border
    -- art, tinted by the engine (PreserveAsset), drawn above borderHost.
    if not isBuff and not button.roundDispelHost then
        local roundDispelHost = CreateFrame("Frame", nil, button)
        roundDispelHost:ClearAllPoints()
        roundDispelHost:SetAllPoints(borderHost)
        roundDispelHost:SetFrameLevel(borderHost:GetFrameLevel() + 2)
        roundDispelHost:EnableMouse(false)
        roundDispelHost:Hide()

        local roundDispelTex = roundDispelHost:CreateTexture(nil, "OVERLAY", nil, 2)
        roundDispelTex:ClearAllPoints()
        roundDispelTex:SetAllPoints(roundDispelHost)
        roundDispelTex:SetColorTexture(1, 1, 1, 1)
        roundDispelTex:SetTexelSnappingBias(0)
        roundDispelTex:SetSnapToPixelGrid(false)

        local mask = roundDispelHost:CreateMaskTexture()
        mask:ClearAllPoints()
        mask:SetAtlas("ui-debuff-border-default-noicon")
        mask:SetAllPoints(roundDispelHost)
        mask:SetTexelSnappingBias(0)
        mask:SetSnapToPixelGrid(false)
        roundDispelTex:AddMaskTexture(mask)

        button.roundDispelHost = roundDispelHost
        button.roundDispelTexPending = roundDispelTex
        roundDispelHost.mask = mask
    end

    -- Buffs: Blizzard's StealableBorder texture over the normal border, in our
    -- own host so "Show Dispels" can show/hide it.
    if isBuff and not button.stealableHost then
        local stealableHost = CreateFrame("Frame", nil, button)
        stealableHost:ClearAllPoints()
        stealableHost:SetAllPoints(borderHost)
        stealableHost:SetFrameLevel(borderHost:GetFrameLevel() + 2)
        stealableHost:EnableMouse(false)
        stealableHost:Hide()

        local stealable = stealableHost:CreateTexture(nil, "OVERLAY", nil, 2)
        stealable:ClearAllPoints()
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

-- Duration text in Blizzard's nameplate look, shared by every location that
-- shows it. The duration is secret, so the engine formats it (whole seconds,
-- rounded up) and colors it from a step curve on the remaining time: expiring
-- color up to the threshold, normal up to 60 s, transparent above (Blizzard
-- shows no number over a minute). The curve is copied at registration, so
-- settings changes re-register. Colors and threshold are the nameplate ones.
local function DurationSettings()
    local g = uuidb and uuidb.general or {}
    local threshold = tonumber(g.nameplatedurationthreshold) or 5
    if threshold < 0 then threshold = 0 end
    return g.nameplatedurationcolor or "ffffffff", g.nameplatedurationexpiringcolor or "ffff3333", threshold
end

local durationFormatter
local durationOptions, durationOptionsKey
local function GetDurationTextOptions()
    local normal, expiring, threshold = DurationSettings()
    local key = normal .. "|" .. expiring .. "|" .. threshold
    if durationOptionsKey == key then return durationOptions, key end
    durationOptionsKey = key
    durationOptions = nil
    pcall(function()
        local opts = {}
        if durationFormatter == nil then
            durationFormatter = false
            if C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum.NumericRuleFormatRounding then
                local formatter = C_StringUtil.CreateNumericRuleFormatter()
                formatter:AddBreakpoint({ threshold = 0, step = 1, rounding = Enum.NumericRuleFormatRounding.Up, format = "%d" })
                durationFormatter = formatter
            end
        end
        if durationFormatter then opts.textFormatter = durationFormatter end
        if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum.DurationTextBindingProperty then
            local n = UberUI.util.HexColor(normal) or CreateColor(1, 1, 1, 1)
            local e = UberUI.util.HexColor(expiring) or CreateColor(1, 0.2, 0.2, 1)
            local curve = C_CurveUtil.CreateColorCurve()
            curve:SetType(Enum.LuaCurveType.Step)
            curve:AddPoint(0, CreateColor(e.r, e.g, e.b, 1))
            if threshold > 0 and threshold < 60 then
                curve:AddPoint(threshold, CreateColor(n.r, n.g, n.b, 1))
            end
            curve:AddPoint(60.001, CreateColor(n.r, n.g, n.b, 0))
            opts.textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration }
        end
        durationOptions = opts
    end)
    return durationOptions, key
end

-- Creates, sizes, registers and shows (or hides) a button's duration text.
-- Call from the location's style function; it's cheap when nothing changed.
-- The font is the cooldown countdown font scaled by icon size against
-- Blizzard's 25px nameplate aura, re-sized when the icon size changes.
function aurakit.UpdateDurationText(button, enabled)
    if not button or not button.SetDurationText then return end
    local text = button.uuDuration
    if not enabled then
        if text then text:Hide() end
        return
    end
    if not text then
        text = (button.textHolder or button):CreateFontString(nil, "OVERLAY")
        text:SetPoint("CENTER", button.icon or button, "CENTER", 0, 0)
        local cdText = button.cooldown and button.cooldown.GetCountdownFontString and button.cooldown:GetCountdownFontString()
        local font, size, flags
        if cdText then font, size, flags = cdText:GetFont() end
        if not font and NumberFontNormal then font, size, flags = NumberFontNormal:GetFont() end
        button.uuDurationFont = font and { font, size, flags } or false
        button.uuDuration = text
    end

    local iconSize = button.elementSize or TEXT_REF_SIZE
    local scale = aurakit.TextSettings(button._uberTextLoc).duration
    local sizeKey = iconSize .. "|" .. scale
    if button.uuDurationSize ~= sizeKey then
        local f = button.uuDurationFont
        if f then
            text:SetFont(f[1], math.max(4, math.floor(f[2] * iconSize / TEXT_REF_SIZE * scale + 0.5)), f[3])
        else
            text:SetFontObject(NumberFontNormal)
        end
        button.uuDurationSize = sizeKey
    end

    local opts, key = GetDurationTextOptions()
    if button.uuDurationKey ~= key then
        if opts and pcall(button.SetDurationText, button, text, opts) then
            button.uuDurationKey = key
        elseif not button.uuDurationKey then
            pcall(button.SetDurationText, button, text) -- engine default, retried next style pass
        end
    end
    text:Show()
end

-- Two permanent containers (debuffs, buffs), each with a "mine" (large) and
-- "other" (small) group. The caller positions them (UpdatePairedPositions).
-- opts: {
--   namePrefix, parentFrame, unitToken,
--   mineKey, otherKey, mineFilter, otherFilter,
--   frameLevelBonus, largeSize, smallSize, spacing, exactLineSpacing,
--   updateStyleFn(button), isUpdating(), onApplyLayout(), clearUpdating(),
-- }
function aurakit.BuildAuraContainer(opts)
    local okC, container = pcall(function()
        return CreateFrame("AuraContainer", opts.namePrefix, opts.parentFrame, "CustomAuraContainerTemplate")
    end)
    if not okC or not container then return nil end

    container:SetSize(1, 1)
    -- Blizzard draws the count unscaled on the large ("mine") icons.
    container._uberCountRefSize = opts.largeSize
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
        layout = aurakit.MakeGroupLayout(opts.largeSize, opts.spacing, opts.spacing, false, 1, opts.exactLineSpacing),
    })

    container:AddAuraGroup(otherKey, opts.otherFilter, {
        maxFrameCount = 16,
        initializeFrame = function(btn)
            aurakit.InitAuraButton(container, btn, otherKey, opts.otherFilter:find("HELPFUL") ~= nil, opts.smallSize, false, opts.updateStyleFn)
        end,
        layout = aurakit.MakeGroupLayout(opts.smallSize, opts.spacing, opts.spacing, false, 2, opts.exactLineSpacing),
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

-- Container with any number of groups (compact party/raid frames). Group:
--   { key, filter, isBuff, size, maxFrameCount, layoutIndex,
--     sortMethod, candidateFilters }
-- isBuff is explicit: Blizzard's ProcessAura can put a HELPFUL aura (boss
-- buffs) in a debuff-styled group.
-- opts: { name, parentFrame, frameLevelBonus, spacing, maxLineSize,
--         processAura, groups, countRefSize, updateStyleFn(button) }
-- countRefSize: the location's stock icon size (see UpdateCountSize).
-- The unit starts unset; callers SetUnit() a real unit (never a "player"
-- placeholder, or an unassigned container shows the player's auras).
function aurakit.BuildGroupedAuraContainer(opts)
    local okC, container = pcall(function()
        return CreateFrame("AuraContainer", opts.name, opts.parentFrame, "CustomAuraContainerTemplate")
    end)
    if not okC or not container then return nil end

    container:SetSize(1, 1)
    container._uberCountRefSize = opts.countRefSize
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
            -- Reads def.size at init so later buttons pick up resizes.
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

-- Resize groups in place (Edit Mode icon size). sizes = { [groupKey] = size }.
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
                        UpdateCountSize(btn)
                        if updateStyleFn then pcall(updateStyleFn, btn) end
                    end
                end
            end
        end
    end
end

-- frameObj: the module table owning .customDebuffs/.customBuffs.
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

-- true (an aura shown), false (every button reports hidden), or nil (can't
-- tell: button state is secret in combat). Act only on a positive false.
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

-- The primary container sits under the frame (debuffs on enemies, buffs on
-- friendlies); the secondary anchors to the primary's edge, so it restacks
-- as the primary grows or empties.
-- opts: { frameObj, refFrame, isEnemyFn(), buffsOnTop, topX, topY, topOnTopX, containerGap }
--
-- While the ToT frame is shown Blizzard narrows the first two aura rows to
-- TOT_AURA_ROW_WIDTH so they clear the ToT portrait. Our containers take one
-- width for every row, so the whole container narrows instead.
local FULL_AURA_ROW_WIDTH = 122 -- TargetFrameAuraContainerDefaults.FlowLayoutLineSize

-- Frames whose ToT we've moved aside; those keep full-width rows.
local totAside = setmetatable({}, { __mode = "k" })

function aurakit.ApplyToTRowWidth(frameObj, refFrame)
    local width = FULL_AURA_ROW_WIDTH
    local tot = refFrame and refFrame.totFrame
    if tot and tot.IsShown and tot:IsShown() and not totAside[refFrame] then
        width = tonumber(refFrame.TOT_AURA_ROW_WIDTH) or 101
    end
    for _, c in ipairs({ frameObj.customDebuffs, frameObj.customBuffs }) do
        if c and c.uuRowWidth ~= width then
            c.uuRowWidth = width
            pcall(c.SetFlowLayoutMaximumLineSize, c, width)
        end
    end
end

-- "Move ToT Aside": shift the target-of-target frame 24px right so aura rows
-- keep full width. The ToT is a protected frame: only moved out of combat
-- (in-combat changes apply on PLAYER_REGEN_ENABLED). The shift is relative to
-- Blizzard's own anchor, re-captured when Blizzard re-anchors it
-- (RecaptureToTAnchor), so it never compounds.
local TOT_ASIDE_X = 24
local totBase = setmetatable({}, { __mode = "k" })    -- tot frame -> Blizzard's anchor
local totWanted = setmetatable({}, { __mode = "k" })  -- refFrame -> desired aside state
local totRegen

local function ReadAnchor(tot)
    if not tot.GetNumPoints or tot:GetNumPoints() ~= 1 then return nil end
    local point, rel, relPoint, x, y = tot:GetPoint(1)
    if not point then return nil end
    return { point, rel, relPoint, x or 0, y or 0 }
end

local function ApplyToTPlacementNow(refFrame)
    local tot = refFrame and refFrame.totFrame
    if not tot then return end
    local aside = totWanted[refFrame] and true or false
    if aside == (totAside[refFrame] and true or false) then return end
    if aside then
        totBase[tot] = totBase[tot] or ReadAnchor(tot)
        local b = totBase[tot]
        if not b then return end
        tot:ClearAllPoints()
        tot:SetPoint(b[1], b[2], b[3], b[4] + TOT_ASIDE_X, b[5])
        totAside[refFrame] = true
    else
        local b = totBase[tot]
        if b then
            tot:ClearAllPoints()
            tot:SetPoint(b[1], b[2], b[3], b[4], b[5])
        end
        totAside[refFrame] = nil
    end
end

function aurakit.SetToTPlacement(refFrame, aside)
    if not (refFrame and refFrame.totFrame) then return end
    totWanted[refFrame] = aside and true or nil
    if InCombatLockdown() then
        if not totRegen then
            totRegen = CreateFrame("Frame")
            totRegen:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                for frame in pairs(totWanted) do pcall(ApplyToTPlacementNow, frame) end
                -- Frames switched back in combat aren't in totWanted; restore them too.
                for frame in pairs(totAside) do pcall(ApplyToTPlacementNow, frame) end
            end)
        end
        totRegen:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    pcall(ApplyToTPlacementNow, refFrame)
end

-- Blizzard re-anchored this ToT (FocusFrame:SetSmallSize): new base anchor.
function aurakit.RecaptureToTAnchor(refFrame)
    local tot = refFrame and refFrame.totFrame
    if not tot or InCombatLockdown() then return end
    totBase[tot] = ReadAnchor(tot)
    totAside[refFrame] = nil -- Blizzard's SetPoint undid our shift
    pcall(ApplyToTPlacementNow, refFrame)
end

function aurakit.UpdatePairedPositions(opts)
    local frameObj, refFrame = opts.frameObj, opts.refFrame
    if not frameObj.customDebuffs or not frameObj.customBuffs or not refFrame then return end

    aurakit.ApplyToTRowWidth(frameObj, refFrame)

    local isEnemy = opts.isEnemyFn()
    local primary, secondary
    if isEnemy then
        primary, secondary = frameObj.customDebuffs, frameObj.customBuffs
    else
        primary, secondary = frameObj.customBuffs, frameObj.customDebuffs
    end

    primary:ClearAllPoints()
    secondary:ClearAllPoints()

    -- On an enemy with no debuffs shown, buffs take the empty debuff row's
    -- spot. Only a positive "nothing shown" does this; unreadable (combat)
    -- keeps the chain so buffs still follow real debuffs.
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
        -- Empty primary: take its exact spot (Blizzard's flow layout drops
        -- an empty group, so no gap).
        if primaryIsEmpty then
            secondary:SetPoint("BOTTOMLEFT", ref, "TOPLEFT", offsetX, startY)
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
        if primaryIsEmpty then -- same as above: no gap in the empty primary's spot
            secondary:SetPoint("TOPLEFT", refFrame, "BOTTOMLEFT", opts.topX, opts.topY)
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

-- Spellbar placement below the lowest aura row: we record auraRows and
-- spellbarAnchor, and Blizzard's own AdjustPosition reads them.
--
-- We must never call AdjustPosition ourselves. It opens with
-- TargetFrame:ShouldAnchorSpellBarToAuraContainer(), which compares
-- GetNumVisibleFlowLayoutLines() -- a secret aura-row count -- so a call
-- originating here taints that comparison and the game blocks it. taintLog
-- caught it as our largest source by far: 411 blocked comparisons in one
-- retail session, 17 on Forever. Setting the fields is fine; triggering the
-- placement is not, so we wait for Blizzard to run it.

function aurakit.UpdateSpellbar(frameObj, containers)
    if InCombatLockdown() then return end
    if not frameObj then return end
    local spellbar = frameObj.spellbar or (frameObj.GetName and _G[frameObj:GetName() .. "SpellBar"])
    if not spellbar then return end

    if frameObj.buffsOnTop then
        frameObj.auraRows = 0
        frameObj.spellbarAnchor = nil
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
end

function aurakit.HookSpellbarAdjustPosition(spellbar, frameObj, getContainer)
    if not spellbar or not spellbar.AdjustPosition or spellbar._uberUIHooked then return end
    spellbar._uberUIHooked = true
    hooksecurefunc(spellbar, "AdjustPosition", function(self)
        if InCombatLockdown() then return end
        local parent = self:GetParent()
        if parent ~= frameObj then return end
        local containers = getContainer and getContainer()
        if containers then
            aurakit.UpdateSpellbar(frameObj, containers)
        end
    end)
end

-- Border on a Target/Focus cast bar's spell icon in the frame's aura border
-- look (rounded or square, darkness color), icon zoomed. Our frame is born
-- with DisableUntrustedLayoutScriptsTemplate: in 12.1 the spell bar can take
-- the aura container's layout aspects, and a plain frame anchored to its icon
-- would refuse to lay out.
local castIconBorders = setmetatable({}, { __mode = "k" }) -- spellbar -> host

function aurakit.StyleCastBarIcon(spellbar, loc, enabled)
    local icon = spellbar and spellbar.Icon
    if not icon or SafeIsForbidden(spellbar) then return end
    local host = castIconBorders[spellbar]

    if not enabled then
        if host then
            host:Hide()
            pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
        end
        return
    end

    if not host then
        local ok, f = pcall(CreateFrame, "Frame", nil, spellbar, "DisableUntrustedLayoutScriptsTemplate")
        if not ok or not f then return end
        f:EnableMouse(false)
        local ring = f:CreateTexture(nil, "OVERLAY")
        ring:SetAtlas("ui-debuff-border-default-noicon")
        ring:SetDesaturated(true)
        ring:SetTexelSnappingBias(0)
        ring:SetSnapToPixelGrid(false)
        f.ring = ring
        host = f
        castIconBorders[spellbar] = host
    end

    local okL = pcall(function()
        host:ClearAllPoints()
        host:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 3)
        host:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
        host.ring:ClearAllPoints()
        host.ring:SetAllPoints(host)
    end)
    if not okL then return end
    host:SetFrameLevel(spellbar:GetFrameLevel() + 5)
    pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)

    local SB = UberUI.squareborders
    local square = SB and SB.IsEnabled(loc)
    local dc = (uuidb and uuidb.general and uuidb.general.darkencolor) or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    if square then
        host.ring:Hide()
        host.square = host.square or SB.CreateBorder(host)
        SB.LayoutFor(host.square, icon, loc)
        SB.SetDarkColor(host.square)
        host.square:Show()
    else
        if host.square then host.square:Hide() end
        host.ring:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        host.ring:Show()
    end
    host:Show()
end

-- Highlight visuals (nameplate aura and Cooldown Manager pandemic). Styles
-- host's children only; the caller decides when host is shown.
-- opts: { kind = "border"|"glow"|"ants"|"pixel", r, g, b,
--         square, loc, icon (square strips), ringFrom, ringTo, ringX (ring),
--         center, size, sizeH (height, default size), glowScale (glows) }
local HIGHLIGHT_GLOWS = {
    -- FlipBook sheets (6x5, 30 frames); pad = art padding past the icon.
    glow = { atlas = "UI-HUD-ActionBar-Proc-Loop-Flipbook", pad = 1.4 },
    ants = { atlas = "RotationHelper_Ants_Flipbook", pad = 1.6 },
}
local HIGHLIGHT_RING_ATLAS = "ui-debuff-border-default-noicon"

-- Pixel Glow ("pixel"; what LibCustomGlow and EllesmereUI call it): thin
-- dashes marching clockwise around the icon or bar, a whole number of pixels
-- thick, just outside its edge. Dashes run on around the corners instead of
-- being cut off. Also what bars get for "ants": Blizzard's ants art is a
-- square ring for icons and stretches out of shape on a bar.
local PIXEL_THICKNESS = 2   -- screen pixels
local PIXEL_GAP = 1         -- screen pixels between the edge and the dashes
local PIXEL_DASH = 8        -- UI units per dash (and per gap), about
local PIXEL_SPEED = 30      -- UI units per second, whatever the size

-- A point `pos` along the perimeter (clockwise from the top left corner):
-- which edge (1 top, 2 right, 3 bottom, 4 left) and how far along it.
local function PerimeterEdge(pos, w, h)
    if pos < w then return 1, pos, w end
    pos = pos - w
    if pos < h then return 2, pos, h end
    pos = pos - h
    if pos < w then return 3, pos, w end
    return 4, pos - w, h
end

-- One straight piece of a dash on edge `edge`, from `from` for `len`.
local function PlacePiece(tex, frame, edge, from, len, t)
    tex:ClearAllPoints()
    if edge == 1 then
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", from, 0)
        tex:SetSize(len, t)
    elseif edge == 2 then
        tex:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -from)
        tex:SetSize(t, len)
    elseif edge == 3 then
        tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -from, 0)
        tex:SetSize(len, t)
    else
        tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, from)
        tex:SetSize(t, len)
    end
    tex:Show()
end

local function PlacePixelDashes(st)
    local w, h, t = st.w, st.h, st.thick
    local per = 2 * (w + h)
    for i = 1, st.count do
        local a, b = st.pieces[2 * i - 1], st.pieces[2 * i]
        local pos = ((i - 1) / st.count + st.progress) % 1 * per
        local edge, along, edgeLen = PerimeterEdge(pos, w, h)
        local first = math.min(st.len, edgeLen - along)
        PlacePiece(a, st.frame, edge, along, first, t)
        -- The rest runs on around the corner, onto the next edge.
        local rest = st.len - first
        if rest > 0.01 then
            PlacePiece(b, st.frame, edge % 4 + 1, 0, rest, t)
        else
            b:Hide()
        end
    end
end

-- opts: center, size, sizeH (default size), pixelInside, pixelGap; the size
-- comes from the caller because a bar's own size can read back secret.
local function StylePixelGlow(host, show, opts, r, g, b)
    local st = host.uuPixel
    if not show then
        if st then st.frame:Hide() end
        return
    end
    if not st then
        -- Anchored into nameplates too, which needs this template in 12.x.
        local ok, f = pcall(CreateFrame, "Frame", nil, host, "DisableUntrustedLayoutScriptsTemplate")
        if not ok or not f then f = CreateFrame("Frame", nil, host) end
        st = { frame = f, pieces = {}, progress = 0, count = 0 }
        f:EnableMouse(false)
        f:SetScript("OnUpdate", function(_, elapsed)
            local per = 2 * ((st.w or 1) + (st.h or 1))
            st.progress = (st.progress + elapsed * PIXEL_SPEED / per) % 1
            PlacePixelDashes(st)
        end)
        host.uuPixel = st
    end
    local SB = UberUI.squareborders
    local function Px(n) return SB and SB.PixelsToUIUnits(st.frame, n) or n end
    st.thick = Px(PIXEL_THICKNESS)
    -- Outside (default): just past the edge. Inside: over the edge, like a
    -- square border drawn inside the icon.
    local out = opts.pixelInside and 0 or (Px(opts.pixelGap or PIXEL_GAP) + st.thick)
    st.w = (opts.size or 24) + 2 * out
    st.h = (opts.sizeH or opts.size or 24) + 2 * out
    st.frame:ClearAllPoints()
    st.frame:SetPoint("CENTER", opts.center or host, "CENTER")
    st.frame:SetSize(st.w, st.h)
    -- Dash and gap the same length, a whole number of them per lap.
    local per = 2 * (st.w + st.h)
    st.count = math.max(4, math.floor(per / (2 * PIXEL_DASH) + 0.5))
    st.len = per / (2 * st.count)
    for i = 1, 2 * st.count do
        local tex = st.pieces[i]
        if not tex then
            tex = st.frame:CreateTexture(nil, "OVERLAY", nil, 7)
            tex:SetColorTexture(1, 1, 1, 1)
            st.pieces[i] = tex
        end
        tex:SetVertexColor(r, g, b, 1)
    end
    for i = 2 * st.count + 1, #st.pieces do st.pieces[i]:Hide() end
    PlacePixelDashes(st)
    st.frame:Show()
end

function aurakit.StyleHighlight(host, opts)
    local SB = UberUI.squareborders
    local kind = opts.kind
    local r, g, b = opts.r or 1, opts.g or 0.15, opts.b or 0.15

    -- Rounded: the border art as a mask over a solid color (the art is red,
    -- so it can't be tinted).
    local wantRing = kind == "border" and not opts.square
    if wantRing and not host.uuRing and opts.ringFrom then
        local ring = host:CreateTexture(nil, "OVERLAY", nil, 3)
        ring:SetColorTexture(1, 1, 1, 1)
        ring:SetTexelSnappingBias(0)
        ring:SetSnapToPixelGrid(false)
        local mask = host:CreateMaskTexture()
        mask:SetAtlas(HIGHLIGHT_RING_ATLAS)
        mask:SetAllPoints(ring)
        mask:SetTexelSnappingBias(0)
        mask:SetSnapToPixelGrid(false)
        ring:AddMaskTexture(mask)
        host.uuRing = ring
    end
    if host.uuRing then
        if wantRing then
            host.uuRing:ClearAllPoints()
            host.uuRing:SetPoint("TOPLEFT", opts.ringFrom, "TOPLEFT", opts.ringX or 0, -(opts.ringX or 0))
            host.uuRing:SetPoint("BOTTOMRIGHT", opts.ringTo or opts.ringFrom, "BOTTOMRIGHT", -(opts.ringX or 0), opts.ringX or 0)
        end
        host.uuRing:SetVertexColor(r, g, b, 1)
        host.uuRing:SetShown(wantRing)
    end

    local wantSquare = kind == "border" and opts.square and SB and opts.icon
    if wantSquare and not host.uuSquare then
        host.uuSquare = SB.CreateBorder(host)
        host.uuSquare:SetFrameLevel(host:GetFrameLevel() + 2)
    end
    if host.uuSquare then
        if wantSquare then
            SB.LayoutDispelFor(host.uuSquare, opts.icon, opts.loc)
            SB.SetColor(host.uuSquare, r, g, b, 1)
            host.uuSquare:Show()
        else
            host.uuSquare:Hide()
        end
    end

    -- Occluder: a solid border inside the host, under the highlight art.
    -- The engine marks a pandemic region's Shown aspect secret
    -- (CustomAuraButtonSharedMixin:AddPandemicRegion), so insecure code can
    -- never learn when the window opens -- no OnShow fires and IsShown reads
    -- secret. Hiding the debuff's own dispel-colored border on entry is
    -- therefore impossible; covering it from inside the host isn't, because
    -- the engine shows the host for us. opts.occlude = { r, g, b }.
    local occ = opts.occlude
    if occ and opts.square and SB and opts.icon then
        if not host.uuCover then
            host.uuCover = SB.CreateBorder(host)
        end
        -- Same frame level as the host, with the strips dropped to ARTWORK:
        -- a child frame at host+1 would outrank the glow and ants, which are
        -- OVERLAY textures on the host itself (frame level beats draw
        -- layer), and swallow the animation. At equal level the draw layer
        -- decides, so the fx stay on top while the cover still hides the
        -- debuff border, which sits below on borderHost.
        host.uuCover:SetFrameLevel(host:GetFrameLevel())
        for i = 1, 4 do
            local e = host.uuCover.edges and host.uuCover.edges[i]
            if e then e:SetDrawLayer("ARTWORK", 0) end
        end
        SB.LayoutDispelFor(host.uuCover, opts.icon, opts.loc)
        SB.SetColor(host.uuCover, occ.r, occ.g, occ.b, 1)
        host.uuCover:Show()
    elseif occ and not opts.square and opts.ringFrom then
        if not host.uuCoverRing then
            local ring = host:CreateTexture(nil, "OVERLAY", nil, 2)
            ring:SetColorTexture(1, 1, 1, 1)
            ring:SetTexelSnappingBias(0)
            ring:SetSnapToPixelGrid(false)
            local mask = host:CreateMaskTexture()
            mask:SetAtlas(HIGHLIGHT_RING_ATLAS)
            mask:SetAllPoints(ring)
            mask:SetTexelSnappingBias(0)
            mask:SetSnapToPixelGrid(false)
            ring:AddMaskTexture(mask)
            host.uuCoverRing = ring
        end
        host.uuCoverRing:ClearAllPoints()
        host.uuCoverRing:SetAllPoints(opts.ringFrom)
        host.uuCoverRing:SetVertexColor(occ.r, occ.g, occ.b, 1)
        host.uuCoverRing:Show()
    else
        if host.uuCover then host.uuCover:Hide() end
        if host.uuCoverRing then host.uuCoverRing:Hide() end
    end

    -- Pixel Glow, and bars' ants (a bar has its own height).
    local pixel = kind == "pixel" or (kind == "ants" and opts.sizeH ~= nil)
    StylePixelGlow(host, pixel, opts, r, g, b)

    local glowDef = not pixel and HIGHLIGHT_GLOWS[kind] or nil
    if glowDef and not host.uuGlow then
        local tex = host:CreateTexture(nil, "OVERLAY", nil, 7)
        local ag = tex:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local anim = ag:CreateAnimation("FlipBook")
        anim:SetFlipBookRows(6)
        anim:SetFlipBookColumns(5)
        anim:SetFlipBookFrames(30)
        anim:SetFlipBookFrameWidth(0)
        anim:SetFlipBookFrameHeight(0)
        anim:SetDuration(1.0)
        host.uuGlow, host.uuGlowAg = tex, ag
    end
    if host.uuGlow then
        if glowDef then
            local scale = glowDef.pad * (opts.glowScale or 1)
            local size = (opts.size or 24) * scale
            local sizeH = opts.sizeH and (opts.sizeH * scale) or size
            host.uuGlow:ClearAllPoints()
            host.uuGlow:SetPoint("CENTER", opts.center or host, "CENTER")
            if host.uuGlowAtlas ~= glowDef.atlas then
                host.uuGlow:SetAtlas(glowDef.atlas)
                host.uuGlowAtlas = glowDef.atlas
            end
            host.uuGlow:SetSize(size, sizeH)
            host.uuGlow:SetDesaturated(true)
            host.uuGlow:SetVertexColor(r, g, b, 1)
            host.uuGlow:Show()
            if not host.uuGlowAg:IsPlaying() then host.uuGlowAg:Play() end
        else
            host.uuGlow:Hide()
            host.uuGlowAg:Stop()
        end
    end
end

UberUI.aurakit = aurakit
