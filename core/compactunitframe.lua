local addon, ns = ...
local cuf = {}

cuf = CreateFrame("Frame");
cuf:RegisterEvent("PLAYER_ENTERING_WORLD")
cuf:RegisterEvent("GROUP_ROSTER_UPDATE")
cuf:RegisterEvent("UNIT_PET");
cuf:SetScript("OnEvent", function(self)
    self:set_hook();
end)

local default_hook = false

cuf.updateFrameCB = function(self)
    if (self ~= nil) then return end
    local useRaidTexture = uuidb.general.raidbartextures and uuidb.general.raidbartexture ~= "Blizzard"
    local useGeneralTexture = uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard"
    local texture = useRaidTexture and uuidb.statusbars[uuidb.general.raidbartexture] or
        (useGeneralTexture and uuidb.statusbars[uuidb.general.texture] or uuidb.statusbars["Blizzard"])

    if (useRaidTexture or useGeneralTexture) then
        self.roleIcon:SetDrawLayer("ARTWORK", 4)
        self.healthBar:SetStatusBarTexture(texture);
    end
    if (uuidb.general.secondarybartextures and uuidb.general.secondarybartexture == "Blizzard") then return end
    if (uuidb.general.secondarybartextures or useRaidTexture or useGeneralTexture) then
        local texture = uuidb.general.secondarybartextures and
            uuidb.statusbars[uuidb.general.secondarybartexture] or
            useRaidTexture and
            uuidb.statusbars[uuidb.general.raidbartexture] or
            (useGeneralTexture and uuidb.statusbars[uuidb.general.texture] or uuidb.statusbars["Blizzard"]);
        self.myHealPrediction:SetTexture(texture);
        self.otherHealPrediction:SetTexture(texture);
        self.totalAbsorb:SetTexture(texture);
        self.totalAbsorb:SetVertexColor(.6, .9, .9, 1);
    end
end

cuf.default = function(self)
    if (self == nil) then return end
    local useRaidTexture = uuidb.general.raidbartextures and uuidb.general.raidbartexture ~= "Blizzard"
    local useGeneralTexture = uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard"
    local texture = useRaidTexture and uuidb.statusbars[uuidb.general.raidbartexture] or
        (useGeneralTexture and uuidb.statusbars[uuidb.general.texture] or uuidb.statusbars["Blizzard"])

    if (useRaidTexture or useGeneralTexture) then
        if (self.roleIcon) then
            self.roleIcon:SetDrawLayer("ARTWORK", 4)
        end
        self.healthBar:SetStatusBarTexture(texture);
    end

    if (uuidb.general.secondarybartextures and uuidb.general.secondarybartexture == "Blizzard") then return end
    if (uuidb.general.secondarybartextures or useRaidTexture or useGeneralTexture) then
        local texture = uuidb.general.secondarybartextures and
            uuidb.statusbars[uuidb.general.secondarybartexture] or
            useRaidTexture and
            uuidb.statusbars[uuidb.general.raidbartexture] or
            (useGeneralTexture and uuidb.statusbars[uuidb.general.texture] or uuidb.statusbars["Blizzard"]);
        self.myHealPrediction:SetTexture(texture);
        self.otherHealPrediction:SetTexture(texture);
        self.totalAbsorb:SetTexture(texture);
        self.totalAbsorb:SetVertexColor(.6, .9, .9, 1);
    end
end

function cuf:set_hook()
    if (default_hook ~= true) then
        hooksecurefunc("DefaultCompactUnitFrameSetup", UberUI.cuf.default)
        default_hook = true
    end
end

UberUI.cuf = cuf
