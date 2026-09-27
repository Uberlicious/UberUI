local addon, ns = ...

-- Player debuffs in our own aurakit container, used ONLY while Player auras
-- use square borders (and Player debuffs aren't handed back to Blizzard).
-- Buffs and weapon enchants stay on Blizzard's BuffFrame as before.
--
-- Why: Blizzard's DebuffFrame buttons are styled from outside, and in combat
-- every route to a player debuff's dispel type is closed to addon code, so
-- square Player debuff borders fell back to the "None" red in combat. Inside
-- a CustomAuraContainer the ENGINE colors the square strips (aurakit's
-- PreserveAsset registration), so they're right in combat too -- same as
-- Target/Focus. See docs/square-borders.md.
--
-- Mirrors Blizzard's DebuffFrame (Blizzard_BuffFrame/BuffFrame.lua, same on
-- retail 12.1 and Forever 1.60.1):
--   * every HARMFUL aura on PlayerFrame.unit (vehicle-aware), no filtering,
--     in application order (AuraInstanceIDOnly ~= Blizzard's slot order), up
--     to DEBUFF_MAX_DISPLAY plus the 6 private aura slots -- private (boss)
--     auras come through the container itself, so Blizzard's private aura
--     anchors are hidden along with its buttons;
--   * Edit Mode settings, read from DebuffFrame.AuraContainer after every
--     UpdateGridLayout: orientation, icon wrap/direction, icon limit (per
--     row), icon size (container scale), icon padding. Visibility and
--     opacity apply to DebuffFrame itself, which is our parent, so they
--     carry over on their own; so does the frame's Edit Mode position;
--   * 30x30 icons in Blizzard's 30x40 (horizontal) / 60x30 (vertical) cells,
--     duration text in the gap beside the icon with Blizzard's white-under-
--     BUFF_DURATION_WARNING_TIME / yellow coloring and the "buffDurations"
--     CVar, stack count bottom-right in NumberFontNormal, no cooldown swipe.
-- Not mirrored: the low-time flash (BUFF_WARNING_TIME), Edit Mode's "Show
-- Dispel Type" symbol (square borders have no slot for it -- colors are the
-- same either way), and Forever's gamepad navigation of DebuffFrame buttons.
-- The deadly-debuff center alert is a separate frame and keeps working.
--
-- While Edit Mode is open, Blizzard's own container is shown instead so its
-- preview icons work.
--
-- Hooks on Blizzard frames are installed only once the feature is actually
-- in use (CLAUDE.md), and every write they trigger is deferred a frame to
-- stay out of Blizzard's update chain.

local aurakit = UberUI.aurakit
local SB = UberUI.squareborders
local playerdebuffs = {}

local SQUARE_LOC = "player"
local GROUP_KEY = "debuffs"
local ICON_SIZE = 30
local CELL_EXTRA_HORIZONTAL = 40 - ICON_SIZE -- 30x40 cell: text below/above
local CELL_EXTRA_VERTICAL = 60 - ICON_SIZE   -- 60x30 cell: text beside
local PRIVATE_AURA_SLOTS = 6

local container
local hooksInstalled = false
local blizzardHidden = false
local pendingBuild = false
local syncQueued = false
local layout = { horizontal = true, top = false, right = false }
local layoutKey

local function DebuffStyle()
    return (uuidb and uuidb.general and uuidb.general.aurastyle_playerdebuffs) or "zoom"
end

local function WantActive()
    if not (uuidb and uuidb.general) then return false end
    if not (DebuffFrame and DebuffFrame.AuraContainer) then return false end
    return SB.IsEnabled(SQUARE_LOC) and DebuffStyle() ~= "none"
end

local function IsEditing()
    return DebuffFrame and DebuffFrame.IsEditing and DebuffFrame:IsEditing() and true or false
end

local function PlayerUnit()
    return (PlayerFrame and PlayerFrame.unit) or "player"
end

local function ShowDurations()
    return C_CVar.GetCVarBool("buffDurations") ~= false
end

-------------------------------------------------------------------------------
-- Buttons
-------------------------------------------------------------------------------

-- Blizzard's AuraButtonMixin:UpdateDuration colors: white under
-- BUFF_DURATION_WARNING_TIME, yellow otherwise. A step curve on remaining
-- time lets the engine apply it, since the duration itself is secret.
local durationColorCurve
local function GetDurationColorCurve()
    if durationColorCurve ~= nil then return durationColorCurve or nil end
    durationColorCurve = false
    pcall(function()
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, HIGHLIGHT_FONT_COLOR)
        curve:AddPoint(BUFF_DURATION_WARNING_TIME or 90, NORMAL_FONT_COLOR)
        durationColorCurve = curve
    end)
    return durationColorCurve or nil
end

-- Duration text sits in the cell's gap past the icon, on the side Blizzard
-- puts it (AuraContainerMixin:UpdateGridLayout), pushed out by an outset
-- square border's thickness like buffsandauras.lua does for Blizzard's own.
local function LayoutDuration(button)
    local text = button.uuDuration
    if not text or not button.icon then return end
    local push = 0
    if not SB.IsInset(SQUARE_LOC) then
        -- Dispel Color borders are 1px thicker than Dark ones.
        local style = DebuffStyle()
        local px = (style == "both" or style == "border") and SB.Thickness(SQUARE_LOC)
            or SB.DispelThickness(SQUARE_LOC)
        push = SB.PixelsToUIUnits(button, px)
    end
    local point, relPoint, dx, dy
    if layout.horizontal then
        point = layout.top and "BOTTOM" or "TOP"
        relPoint = layout.top and "TOP" or "BOTTOM"
        dx, dy = 0, layout.top and push or -push
    else
        point = layout.right and "LEFT" or "RIGHT"
        relPoint = layout.right and "RIGHT" or "LEFT"
        dx, dy = layout.right and push or -push, 0
    end
    text:ClearAllPoints()
    text:SetPoint(point, button.icon, relPoint, dx, dy)
    button.uuDurationHolder:SetShown(ShowDurations())
end

function playerdebuffs:StyleButton(button)
    if not button then return end
    -- With square borders on, aurakit lets the icon fill the 30x30 button,
    -- same as Blizzard's player debuff icon.
    aurakit.ApplyAuraButtonStyle(button, { style = DebuffStyle(), squareLoc = SQUARE_LOC })
    LayoutDuration(button)
end

local function StyleFn(button)
    playerdebuffs:StyleButton(button)
end

local function InitButton(button)
    aurakit.InitAuraButton(container, button, GROUP_KEY, false, ICON_SIZE, false, nil)

    -- Blizzard's player debuffs show the time as text only, no swipe.
    if button.ClearDurationCooldown then pcall(button.ClearDurationCooldown, button) end
    if button.cooldown then button.cooldown:Hide() end

    -- Stack count: Blizzard's font and offset.
    if button.count then
        button.count:SetFontObject(NumberFontNormal)
        button.count:ClearAllPoints()
        button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    end

    -- Duration text in its own holder so the buffDurations CVar can hide it
    -- (the engine owns the fontstring's alpha).
    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints(button)
    holder:SetFrameLevel(button.textHolder and button.textHolder:GetFrameLevel() or (button:GetFrameLevel() + 5))
    holder:EnableMouse(false)
    local text = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.uuDurationHolder = holder
    button.uuDuration = text
    if button.SetDurationText then
        local options
        local curve = GetDurationColorCurve()
        if curve and Enum.DurationTextBindingProperty then
            options = { textColor = { curve = curve, property = Enum.DurationTextBindingProperty.RemainingDuration } }
        end
        if not pcall(button.SetDurationText, button, text, options) then
            pcall(button.SetDurationText, button, text)
        end
    end

    playerdebuffs:StyleButton(button)
end

local function RestyleAll()
    if container and container.allButtons then
        for button in pairs(container.allButtons) do
            pcall(StyleFn, button)
        end
    end
end

-------------------------------------------------------------------------------
-- Layout (Edit Mode settings from DebuffFrame.AuraContainer)
-------------------------------------------------------------------------------

local function ApplyLayout()
    local ac = DebuffFrame.AuraContainer
    local horizontal = ac.isHorizontal ~= false
    local right = ac.addIconsToRight and true or false
    local top = ac.addIconsToTop and true or false
    local stride = tonumber(ac.iconStride) or 8
    if stride < 1 then stride = 1 end
    local padding = tonumber(ac.iconPadding) or 0
    local scale = tonumber(ac.iconScale) or 1
    if scale <= 0 then scale = 1 end

    local key = table.concat({ tostring(horizontal), tostring(right), tostring(top), stride, padding, scale }, "|")
    if key == layoutKey then return end
    layoutKey = key
    layout.horizontal, layout.right, layout.top = horizontal, right, top

    -- Same corner Blizzard anchors its own container to (BaseAuraFrameMixin:
    -- UpdateAuraContainerAnchor) and grows from.
    local point
    if top then
        point = right and "BOTTOMLEFT" or "BOTTOMRIGHT"
    else
        point = right and "TOPLEFT" or "TOPRIGHT"
    end

    container:SetScale(scale)
    container:ClearAllPoints()
    container:SetPoint(point, DebuffFrame, point, 0, 0)

    local axis = AnchorUtil.FlowLayoutAxis
    pcall(container.SetFlowLayoutAxis, container, horizontal and axis.Horizontal or axis.Vertical)
    pcall(container.SetFlowLayoutAnchorPoint, container, point)
    pcall(container.SetFlowLayoutGrowthDirection, container, right and 1 or -1, top and 1 or -1)
    pcall(container.SetFlowLayoutMaximumLineSize, container, stride * ICON_SIZE + (stride - 1) * padding + 0.5)

    local lineGap = padding + (horizontal and CELL_EXTRA_HORIZONTAL or CELL_EXTRA_VERTICAL)
    pcall(container.SetAuraGroupLayout, container, GROUP_KEY, {
        elementWidth = ICON_SIZE,
        elementHeight = ICON_SIZE,
        elementSpacing = padding,
        lineSpacing = lineGap,
        groupSpacing = 0,
        groupLineSpacing = lineGap,
        forceNewLine = false,
        layoutIndex = 1,
    })

    RestyleAll()
end

-------------------------------------------------------------------------------
-- Container
-------------------------------------------------------------------------------

local function Build()
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        if C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        end
    end
    if not (C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") and AuraContainerSortMethod) then return end

    local ok, c = pcall(CreateFrame, "AuraContainer", "UberUI_PlayerDebuffs", DebuffFrame, "CustomAuraContainerTemplate")
    if not ok or not c then return end
    container = c
    container:SetSize(1, 1)
    container:SetFrameLevel(DebuffFrame:GetFrameLevel() + 2)
    container:SetFlowLayoutPadding(0, 0, 0, 0)

    local okG = pcall(container.AddAuraGroup, container, GROUP_KEY, "HARMFUL", {
        maxFrameCount = (DEBUFF_MAX_DISPLAY or 16) + PRIVATE_AURA_SLOTS,
        sortMethod = AuraContainerSortMethod.AuraInstanceIDOnly,
        sortDirection = AuraContainerSortDirection.Normal,
        initializeFrame = InitButton,
        layout = {
            elementWidth = ICON_SIZE,
            elementHeight = ICON_SIZE,
            elementSpacing = 0,
            lineSpacing = CELL_EXTRA_HORIZONTAL,
            groupSpacing = 0,
            groupLineSpacing = CELL_EXTRA_HORIZONTAL,
            forceNewLine = false,
            layoutIndex = 1,
        },
    })
    if not okG then
        container:Hide()
        container = nil
        return
    end

    -- Our own frame, so these hooks are always safe.
    local function refresh()
        aurakit.RefreshGroupButtons(container, { GROUP_KEY }, StyleFn)
    end
    if container.ApplyLayout then hooksecurefunc(container, "ApplyLayout", refresh) end
    if container.UpdateAllAuras then hooksecurefunc(container, "UpdateAllAuras", refresh) end
    if container.UpdateAuraGroup then hooksecurefunc(container, "UpdateAuraGroup", refresh) end

    layoutKey = nil
end

-- Hides Blizzard's own debuff buttons and private aura anchors while ours are
-- showing, and puts them back when we stop. Only ever touches them once
-- we've actually taken over.
local function SetBlizzardShown(shown)
    local ac = DebuffFrame.AuraContainer
    if shown then
        if not blizzardHidden then return end
        blizzardHidden = false
        ac:Show()
        if not IsEditing() then -- Blizzard hides these itself while editing
            for _, anchor in ipairs(DebuffFrame.PrivateAuraAnchors or {}) do
                anchor:Show()
            end
        end
    else
        blizzardHidden = true
        ac:Hide()
        for _, anchor in ipairs(DebuffFrame.PrivateAuraAnchors or {}) do
            anchor:Hide()
        end
    end
end

local QueueSync

local function EnsureHooks()
    if hooksInstalled then return end
    hooksInstalled = true
    -- Runs after every Blizzard debuff update and every Edit Mode setting
    -- change; also where Blizzard re-shows its private aura anchors after
    -- Edit Mode, and where a PlayerFrame.unit (vehicle) change shows up.
    hooksecurefunc(DebuffFrame.AuraContainer, "UpdateGridLayout", function() QueueSync() end)
    if DebuffFrame.SetIsEditing then
        hooksecurefunc(DebuffFrame, "SetIsEditing", function() QueueSync() end)
    end
end

function playerdebuffs:Sync()
    local want = WantActive()
    if want then EnsureHooks() end
    local active = want and not IsEditing()

    if active and not container then
        if InCombatLockdown() then
            -- Container creation stays out of combat; Blizzard's debuffs keep
            -- showing until then.
            pendingBuild = true
            return
        end
        Build()
        if not container then return end
    end

    if not container then return end

    if active then
        ApplyLayout()
        local unit = PlayerUnit()
        if container:GetUnit() ~= unit then
            pcall(container.SetUnit, container, unit)
        end
        container:Show()
        SetBlizzardShown(false)
    else
        container:Hide()
        SetBlizzardShown(true)
    end
end

QueueSync = function()
    if syncQueued then return end
    syncQueued = true
    C_Timer.After(0, function()
        syncQueued = false
        playerdebuffs:Sync()
    end)
end

-- Called from buffsandauras:Refresh() on every Player aura / darkness
-- setting change: re-evaluate on/off and restyle.
function playerdebuffs:Update()
    self:Sync()
    RestyleAll()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        if not pendingBuild then return end
        pendingBuild = false
        playerdebuffs:Sync()
    elseif event == "CVAR_UPDATE" then
        if arg1 == "buffDurations" and container then RestyleAll() end
    else
        playerdebuffs:Sync()
    end
end)

UberUI.playerdebuffs = playerdebuffs
