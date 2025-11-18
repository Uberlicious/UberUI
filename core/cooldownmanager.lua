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

    local texture
    if uuidb.cooldown.bartextures then
        if uuidb.cooldown.bartexture ~= "Blizzard" then
            texture = uuidb.statusbars[uuidb.cooldown.bartexture]
        end
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        texture = uuidb.statusbars[uuidb.general.texture]
    end

    if not texture then return end

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
        DestroyBorders(BuffBarCooldownViewer)
        DestroyBorders(BuffIconCooldownViewer)
        DestroyBorders(UtilityCooldownViewer)
        DestroyBorders(EssentialCooldownViewer)
        return
    end

    local dc = uuidb.general.darkencolor
    local tx = MultiBarBottomRightButton1NormalTexture:GetAtlas()

    local function CreateBorder(parent, anchor, tl, br)
        local holder
        if anchor:IsObjectType("Frame") then
            holder = anchor
        else -- is a region
            holder = anchor:GetParent()
        end

        local borderTexture = holder:CreateTexture(nil, "OVERLAY", nil, -8)
        borderTexture:SetPoint("TOPLEFT", anchor, "TOPLEFT", tl, -tl)
        borderTexture:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", br, -br)
        borderTexture:SetAtlas(tx)
        borderTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
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
                    f.uberBorder = CreateBorder(f, iconFrame, 0, 4)
                    f.styled = true
                end
            end
        end
    end

    local function ApplyBordersToIconViewer(viewer, tl, br)
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
                            f.uberBorder = CreateBorder(f, iconFrame, tl, br)
                            f.styled = true
                        end
                    elseif icon:IsObjectType("Texture") then
                        -- Handle case where f.Icon is a texture
                        local iconTexture = icon
                        f.uberBorder = CreateBorder(f, iconTexture, tl, br)
                        f.styled = true
                    end
                end
            end
        end
    end

    ApplyBordersToIconViewer(BuffIconCooldownViewer, .5, 5)
    ApplyBordersToIconViewer(UtilityCooldownViewer, .5, 5)
    ApplyBordersToIconViewer(EssentialCooldownViewer, .5, 5)
end

-- Register the specific callback we need
local function RegisterCooldownCallbacks()
    if cdManager._callbackRegistered then return end

    -- This is the specific callback that fires when hovering items in settings
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnEnterItem", function(cooldownItem)
        C_Timer.After(0, function()
            cdManager:Texture()
            cdManager:Color()
        end)
    end, cdManager)

    -- Also register for data changes (when items added/removed)
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
        C_Timer.After(0, function()
            cdManager:Texture()
            cdManager:Color()
        end)
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
        end

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
        end)
    end
end)

-- Public function for manual refresh
function cdManager:Refresh()
    self:Texture()
    self:Color()
end

UberUI.cdManager = cdManager
