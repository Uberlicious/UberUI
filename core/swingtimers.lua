-- Swing timers (WoW Forever).
local swingtimers = {}
local retextured = setmetatable({}, { __mode = "k" })
local tinted = setmetatable({}, { __mode = "k" }) -- Blizzard atlas fills we desaturated + tinted

local FRAMES = {
    { name = "SwingTimerMainHandFrame", colorField = "swingtimermainhandcolor", default = "ffffc21a" },
    { name = "SwingTimerOffHandFrame",  colorField = "swingtimeroffhandcolor",  default = "ff3d9eff" },
    { name = "SwingTimerRangedFrame",   colorField = "swingtimerrangedcolor",   default = "ff5cd65c" },
}
swingtimers.FRAMES = FRAMES

local function HexColor(hex, fallbackHex)
    return UberUI.util.HexColor(hex) or UberUI.util.HexColor(fallbackHex)
end

-- Fill tint for one bar per the Swing Timer Bar Color dropdown, or nil for
-- "none" (no tint).
local function BarColor(g, def)
    local mode = g.swingtimerbarcolor
    if mode == "class" then
        local c = UberUI.util.ClassColor(select(2, UnitClass("player")))
        if c then return c end
        mode = "custom"
    end
    if mode == "custom" then
        return HexColor(g[def.colorField], def.default)
    end
    return nil
end

local function GetSwingTexture()
    local g = uuidb and uuidb.general
    if not (g and uuidb.statusbars) then return nil end
    if not (g.swingtimerbartextures and g.swingtimerbartexture ~= "Blizzard") then return nil end
    local tex = uuidb.statusbars[g.swingtimerbartexture]
    return type(tex) == "string" and tex or nil
end

-- Square border around swing timer bars, in a base color matching
-- Blizzard's frame art (silver; copper kept for testing), multiplied by the
-- darkness color when Darken Swing Timers is on.
local BORDER_BASE_COPPER = { r = 0.60, g = 0.45, b = 0.35 }
local BORDER_BASE_SILVER = { r = 0.50, g = 0.50, b = 0.50 }
local SQUARE_BORDER_BASE = BORDER_BASE_SILVER
local ART_ATLAS = { Border = "ui-swingtimerbar-frame", Background = "ui-swingtimerbar-background" }
local artCleared = setmetatable({}, { __mode = "k" }) -- texture -> true
local SQUARE_BG_ALPHA = 0.6
local squareParts = setmetatable({}, { __mode = "k" }) -- statusBar -> { bg, top, bottom, left, right }

local function NewPart(owner, layer, sublevel)
    local t = owner:CreateTexture(nil, layer, nil, sublevel)
    t:SetColorTexture(1, 1, 1, 1)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    return t
end

-- Blizzard insets the bar inside the Edit Mode frame to leave room for the
-- rounded art (Blizzard_SwingTimer.xml). Square mode instead has the bar fill
-- the frame minus the border, so the Edit Mode box matches what's drawn and
-- snapped bars sit flush.
local BLIZZ_INSET_X, BLIZZ_INSET_Y = 5, 4
local barReanchored = setmetatable({}, { __mode = "k" }) -- statusBar -> true

local function AnchorBar(frame, bar, insetX, insetY)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", insetX, -insetY)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -insetX, insetY)
end

local function UpdateBarInset(frame, bar, square, w)
    if square then
        AnchorBar(frame, bar, w, w)
        barReanchored[bar] = true
    elseif barReanchored[bar] then
        barReanchored[bar] = nil
        AnchorBar(frame, bar, BLIZZ_INSET_X, BLIZZ_INSET_Y)
    end
end

local function UpdateSquareBorder(frame, square, darken, dc)
    local bar = frame.StatusBar
    if not bar then return end
    local parts = squareParts[bar]
    if not square then
        UpdateBarInset(frame, bar, false)
        if parts then
            for _, t in pairs(parts) do t:Hide() end
        end
        for key, atlas in pairs(ART_ATLAS) do
            local t = frame[key]
            if t and artCleared[t] then
                artCleared[t] = nil
                t:SetAtlas(atlas)
                t:SetAlpha(1)
                t:Show()
            end
        end
        return false
    end
    if not parts then
        parts = {
            bg = NewPart(bar, "BACKGROUND", -8),
            top = NewPart(bar, "ARTWORK", 7), bottom = NewPart(bar, "ARTWORK", 7),
            left = NewPart(bar, "ARTWORK", 7), right = NewPart(bar, "ARTWORK", 7),
        }
        squareParts[bar] = parts
    end
    for key in pairs(ART_ATLAS) do
        local t = frame[key]
        if t and not artCleared[t] then
            artCleared[t] = true
            t:SetTexture(nil)
            t:SetAlpha(0)
            t:Hide()
        end
    end
    local px = tonumber(uuidb.general.swingtimersquareborder_thickness) or 1
    local SB = UberUI.squareborders
    local w = SB and SB.PixelsToUIUnits(bar, px) or px
    UpdateBarInset(frame, bar, true, w)
    parts.bg:ClearAllPoints()
    parts.bg:SetAllPoints(bar)
    parts.top:ClearAllPoints()
    parts.top:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", -w, 0)
    parts.top:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", w, 0)
    parts.top:SetHeight(w)
    parts.bottom:ClearAllPoints()
    parts.bottom:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", -w, 0)
    parts.bottom:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", w, 0)
    parts.bottom:SetHeight(w)
    parts.left:ClearAllPoints()
    parts.left:SetPoint("TOPRIGHT", bar, "TOPLEFT", 0, 0)
    parts.left:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 0, 0)
    parts.left:SetWidth(w)
    parts.right:ClearAllPoints()
    parts.right:SetPoint("TOPLEFT", bar, "TOPRIGHT", 0, 0)
    parts.right:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 0, 0)
    parts.right:SetWidth(w)
    local cr, cg, cb = SQUARE_BORDER_BASE.r, SQUARE_BORDER_BASE.g, SQUARE_BORDER_BASE.b
    if darken and dc then
        cr = cr * dc.r
        cg = cg * dc.g
        cb = cb * dc.b
    end
    for _, key in ipairs({ "top", "bottom", "left", "right" }) do
        parts[key]:SetVertexColor(cr, cg, cb, 1)
    end
    parts.bg:SetVertexColor(0, 0, 0, SQUARE_BG_ALPHA)
    for _, t in pairs(parts) do t:Show() end
    return true
end

local hookedFrames = setmetatable({}, { __mode = "k" })
local function HookFrame(frame)
    if not frame or hookedFrames[frame] then return end
    hookedFrames[frame] = true
    if frame.HookScript then
        frame:HookScript("OnShow", function()
            swingtimers:Apply()
        end)
    end
end

local mixinHooked = false
local function HookMixin()
    if mixinHooked then return end
    if SwingTimerMixin then
        mixinHooked = true
        if SwingTimerMixin.InitializeBarPresentation then
            hooksecurefunc(SwingTimerMixin, "InitializeBarPresentation", function()
                swingtimers:Apply()
            end)
        end
        if SwingTimerMixin.ApplyRangePresentation then
            hooksecurefunc(SwingTimerMixin, "ApplyRangePresentation", function(self)
                local g = uuidb and uuidb.general
                if not g then return end
                if g.swingtimersquareborder then
                    local border = self.Border or (self.GetBorder and self:GetBorder())
                    if border then
                        border:SetTexture(nil)
                        border:SetAlpha(0)
                        border:Hide()
                    end
                    local bg = self.Background or (self.GetBackground and self:GetBackground())
                    if bg then
                        bg:SetTexture(nil)
                        bg:SetAlpha(0)
                        bg:Hide()
                    end
                else
                    local dc = g.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
                    local darken = g.darkenswingtimers ~= false
                    local cr, cg, cb = 1, 1, 1
                    if darken and dc then cr, cg, cb = dc.r, dc.g, dc.b end

                    local border = self.Border or (self.GetBorder and self:GetBorder())
                    if border and border.SetVertexColor then
                        border:SetVertexColor(cr, cg, cb, 1)
                    end
                    local bg = self.Background or (self.GetBackground and self:GetBackground())
                    if bg and bg.SetVertexColor then
                        bg:SetVertexColor(cr, cg, cb, 1)
                    end
                end
            end)
        end
    end
end

function swingtimers:Apply()
    local g = uuidb and uuidb.general
    if not g then return end
    local dc = g.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    local darken = g.darkenswingtimers ~= false
    local tex = GetSwingTexture()

    HookMixin()

    for _, def in ipairs(FRAMES) do
        local frame = _G[def.name]
        if frame and not frame:IsForbidden() then
            -- Per frame, so one bar failing can't leave the others unstyled.
            local ok, err = pcall(function()
                HookFrame(frame)

                UpdateSquareBorder(frame, g.swingtimersquareborder == true, darken, dc)

                if not g.swingtimersquareborder then
                    local border = frame.Border or (frame.GetBorder and frame:GetBorder())
                    if not border and frame.GetRegions then
                        for _, region in ipairs({ frame:GetRegions() }) do
                            if region:IsObjectType("Texture") and region:GetAtlas() == "ui-swingtimerbar-frame" then
                                border = region
                                break
                            end
                        end
                    end
                    local cr, cg, cb = 1, 1, 1
                    if darken and dc then cr, cg, cb = dc.r, dc.g, dc.b end

                    if border and border.SetVertexColor then
                        border:SetVertexColor(cr, cg, cb, 1)
                    end

                    local bg = frame.Background or (frame.GetBackground and frame:GetBackground())
                    if not bg and frame.GetRegions then
                        for _, region in ipairs({ frame:GetRegions() }) do
                            if region:IsObjectType("Texture") and region:GetAtlas() == "ui-swingtimerbar-background" then
                                bg = region
                                break
                            end
                        end
                    end
                    if bg and bg.SetVertexColor then
                        bg:SetVertexColor(cr, cg, cb, 1)
                    end
                end

                local bar = frame.StatusBar
                -- Label shadow behind MAIN HAND / OFF HAND / RANGED; Blizzard
                -- never touches it after load.
                local shadow = bar and bar.TypeLabelShadow
                if shadow then shadow:SetShown(g.swingtimerlabelshadow ~= false) end

                local fill = bar and bar:GetStatusBarTexture()
                local c = fill and BarColor(g, def)
                if fill then
                    if tex then
                        if tinted[fill] then
                            tinted[fill] = nil
                            fill:SetDesaturated(false)
                        end
                        fill:SetTexture(tex)
                        if c then
                            fill:SetVertexColor(c.r, c.g, c.b, 1)
                        else
                            fill:SetVertexColor(1, 1, 1, 1)
                        end
                        retextured[fill] = true
                    elseif c then
                        -- Keep Blizzard's per-hand atlas (its shading/gloss), but
                        -- desaturate it so the vertex color tints it cleanly to
                        -- any hue instead of multiplying against the built-in one.
                        retextured[fill] = nil
                        if frame.barTexture then fill:SetAtlas(frame.barTexture) end
                        fill:SetDesaturated(true)
                        fill:SetVertexColor(c.r, c.g, c.b, 1)
                        tinted[fill] = true
                    elseif retextured[fill] or tinted[fill] then
                        -- Back to Blizzard's own per-hand atlas.
                        retextured[fill] = nil
                        tinted[fill] = nil
                        if frame.barTexture then fill:SetAtlas(frame.barTexture) end
                        fill:SetDesaturated(false)
                        fill:SetVertexColor(1, 1, 1, 1)
                    end
                end
            end)
            if not ok then UberUI:ReportError("swing timer styling (" .. def.name .. ")", err) end
        end
    end
end

-- Temporary: /uuidebugswing reports each swing timer's layout state.
SLASH_UUIDEBUGSWING1 = "/uuidebugswing"
SlashCmdList.UUIDEBUGSWING = function()
    local function pts(region)
        local out = {}
        for i = 1, region:GetNumPoints() do
            local p, rel, rp, x, y = region:GetPoint(i)
            out[#out + 1] = ("%s->%s:%s (%.2f, %.2f)"):format(p, rel and (rel:GetName() or tostring(rel)) or "nil", rp, x or 0, y or 0)
        end
        return table.concat(out, "; ")
    end
    local g = uuidb and uuidb.general or {}
    local lines = { ("squareborder=%s thickness=%s"):format(tostring(g.swingtimersquareborder), tostring(g.swingtimersquareborder_thickness)) }
    for _, def in ipairs(FRAMES) do
        local f = _G[def.name]
        lines[#lines + 1] = ""
        if not f then
            lines[#lines + 1] = def.name .. ": missing"
        else
            local bar = f.StatusBar
            local ok, inDefault = pcall(function() return f.IsInDefaultPosition and f:IsInDefaultPosition() end)
            lines[#lines + 1] = ("%s: shown=%s forbidden=%s managed=%s inDefault=%s scale=%.3f size=%.1fx%.1f"):format(
                def.name, tostring(f:IsShown()), tostring(f:IsForbidden()), tostring(f.isManagedFrame),
                ok and tostring(inDefault) or ("ERR " .. tostring(inDefault)), f:GetScale(), f:GetWidth(), f:GetHeight())
            lines[#lines + 1] = "  frame points: " .. pts(f)
            if bar then
                lines[#lines + 1] = ("  bar size=%.1fx%.1f reanchored=%s squareParts=%s"):format(
                    bar:GetWidth(), bar:GetHeight(), tostring(barReanchored[bar]), tostring(squareParts[bar] ~= nil))
                lines[#lines + 1] = "  bar points: " .. pts(bar)
            else
                lines[#lines + 1] = "  no StatusBar"
            end
        end
    end
    UberUI.ShowDebugReport(table.concat(lines, "\n"))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_SwingTimer" and name ~= addon then return end
    HookMixin()
    if not (uuidb and uuidb.general) then return end
    swingtimers:Apply()
    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.5, function()
            HookMixin()
            swingtimers:Apply()
        end)
        C_Timer.After(2, function()
            HookMixin()
            swingtimers:Apply()
        end)
    end
end)

UberUI.swingtimers = swingtimers
