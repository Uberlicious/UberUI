local addon, ns = ...
local minimap = {}

minimap = CreateFrame("frame")
-- minimap:RegisterEvent("ADDON_LOADED")
-- minimap:RegisterEvent("PLAYER_LOGIN")
minimap:RegisterEvent("PLAYER_ENTERING_WORLD")
minimap:SetScript("OnEvent", function(self, event)
    self:Color()
end)
function minimap.Color()
    local dc = uuidb.general.darkencolor
    MinimapCompassTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
end

UberUI.minimap = minimap
