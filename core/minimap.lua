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
end

UberUI.minimap = minimap
