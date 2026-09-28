local addon, ns = ...
local minimap = UberUI:CreateFrame("frame")
minimap:RegisterEvent("PLAYER_LOGIN")
minimap:RegisterEvent("PLAYER_ENTERING_WORLD")
local lateRescanDone = false
minimap:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self.RegisterLibDBIconCallback()
        return
    end
    self:Color()
    -- Catch buttons some addons create late without LibDBIcon.
    if not lateRescanDone then
        lateRescanDone = true
        C_Timer.After(5, function() self.DarkenAddonButtons() end)
    end
end)
function minimap.Color()
    local dc = uuidb.general.darkencolor
    if MinimapCompassTexture then
        MinimapCompassTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end
    if MinimapBorder then
        MinimapBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end
    
    local function ColorBorderRegion(frame)
        if not frame then return end
        if frame.Border and type(frame.Border.SetVertexColor) == "function" then
            frame.Border:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            return
        end
        for _, region in pairs({frame:GetRegions()}) do
            if region:IsObjectType("Texture") then
                local isBorder = false
                local atlas = region.GetAtlas and region:GetAtlas()
                local tex = region.GetTexture and region:GetTexture()
                
                if atlas and string.find(string.lower(atlas), "border") then
                    isBorder = true
                elseif type(tex) == "string" and string.find(string.lower(tex), "border") then
                    isBorder = true
                elseif region:GetDrawLayer() == "BORDER" or region:GetDrawLayer() == "OVERLAY" then
                    isBorder = true
                end

                if isBorder then
                    region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                end
            end
        end
    end

    if MinimapCluster then
        ColorBorderRegion(MinimapCluster.IndicatorFrame)
        ColorBorderRegion(MinimapCluster.DielFrame)
    end

    minimap.DarkenAddonButtons()
end

-- Tint tracking border ring on third-party minimap buttons.
local RING_FILE_IDS = {
    [136430] = true, -- Interface\Minimap\MiniMap-TrackingBorder
}
local RING_PATH = "interface\\minimap\\minimap%-trackingborder"

local function IsButtonRing(region)
    local ok, isRing = pcall(function()
        if not (region.IsObjectType and region:IsObjectType("Texture")) then return false end
        local id = region.GetTextureFileID and region:GetTextureFileID()
        if id and RING_FILE_IDS[id] then return true end
        local tex = region:GetTexture()
        if type(tex) == "number" then return RING_FILE_IDS[tex] == true end
        return type(tex) == "string" and tex:lower():find(RING_PATH) ~= nil
    end)
    return ok and isRing
end

-- Rings we've tinted, so turning the option off resets exactly those.
local tintedRings = setmetatable({}, { __mode = "k" })

local function Enabled()
    return uuidb and uuidb.general and uuidb.general.darkenaddonminimapbuttons ~= false
end

local function DarkenButtonRing(button, dc)
    if not button or not button.GetRegions then return end
    if button.IsForbidden and button:IsForbidden() then return end
    for _, region in ipairs({ button:GetRegions() }) do
        if IsButtonRing(region) then
            region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            tintedRings[region] = true
        end
    end
end

local function GetLibDBIcon()
    return LibStub and LibStub("LibDBIcon-1.0", true)
end

local RegisterLibDBIconCallback

function minimap.DarkenAddonButtons()
    if not (uuidb and uuidb.general and uuidb.general.darkencolor) then return end
    if not Enabled() then
        -- Option off: put the rings we tinted back to their default white.
        for region in pairs(tintedRings) do
            region:SetVertexColor(1, 1, 1, 1)
            tintedRings[region] = nil
        end
        return
    end
    RegisterLibDBIconCallback()
    local dc = uuidb.general.darkencolor

    -- Buttons on the minimap (LibDBIcon parents to Minimap; older addons
    -- use MinimapBackdrop).
    for _, parent in ipairs({ Minimap, MinimapBackdrop }) do
        if parent and parent.GetChildren then
            for _, child in ipairs({ parent:GetChildren() }) do
                DarkenButtonRing(child, dc)
            end
        end
    end

    -- LibDBIcon's registry also covers buttons moved off the minimap.
    local ldbi = GetLibDBIcon()
    if ldbi and type(ldbi.objects) == "table" then
        for _, button in pairs(ldbi.objects) do
            DarkenButtonRing(button, dc)
        end
    end
end

-- Darken buttons created dynamically by LibDBIcon after login.
local libDBIconRegistered = false
RegisterLibDBIconCallback = function()
    if libDBIconRegistered or not Enabled() then return end
    local ldbi = GetLibDBIcon()
    if not (ldbi and ldbi.RegisterCallback) then return end
    libDBIconRegistered = true
    ldbi.RegisterCallback(minimap, "LibDBIcon_IconCreated", function(_, button)
        if Enabled() and uuidb.general.darkencolor then
            DarkenButtonRing(button, uuidb.general.darkencolor)
        end
    end)
end
minimap.RegisterLibDBIconCallback = RegisterLibDBIconCallback

UberUI.minimap = minimap
