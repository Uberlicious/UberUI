local addon, ns = ...
local minimap = {}

minimap = UberUI:CreateFrame("frame")
-- minimap:RegisterEvent("ADDON_LOADED")
-- minimap:RegisterEvent("PLAYER_LOGIN")
minimap:RegisterEvent("PLAYER_ENTERING_WORLD")
minimap:SetScript("OnEvent", function(self, event)
    self:Color()
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
                    -- If no name matches, assume the border/overlay layer contains the ring
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
end

UberUI.minimap = minimap
