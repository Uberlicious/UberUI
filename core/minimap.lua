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
    
    -- WoW Forever 1.6 / Retail
    if MinimapCluster and MinimapCluster.IndicatorFrame then
        if MinimapCluster.IndicatorFrame:GetRegions() then
            for _, region in pairs({MinimapCluster.IndicatorFrame:GetRegions()}) do
                if region:IsObjectType("Texture") then
                    region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                end
            end
        end
    end
    -- Also try to catch DielFrame if it exists
    if MinimapCluster and MinimapCluster.DielFrame then
        for _, region in pairs({MinimapCluster.DielFrame:GetRegions()}) do
            if region:IsObjectType("Texture") then
                region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
        end
    end
    -- Classic GameTimeFrame
    if GameTimeFrame then
        for _, region in pairs({GameTimeFrame:GetRegions()}) do
            if region:IsObjectType("Texture") then
                region:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
        end
    end
end

UberUI.minimap = minimap
