--[[--------------------------------------------------------------------
	Uber UI options -- Nameplates page (+ Personal Resource Display)
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

function opt.BuildNameplates(page)
    opt.Header(page, "Nameplates");

    opt.AddCheckbox(page, {
        variable = "HideNPSelctionGlow", name = "Hide Nameplate Selection Glow",
        tooltip = "Hide the inner glow on selected nameplate",
        db = "general", field = "hidenameplateglow", default = false,
        onChange = function()
            if UberUI.nameplates then UberUI.nameplates:ForceNameplateTexture() end
        end,
    });

    opt.AddCheckbox(page, {
        variable = "SmallFriendlyNampelates", name = "Small Friendly Nameplates",
        tooltip = "Make friendly nameplates half the size",
        db = "general", field = "smallfriendlynameplate", default = false,
        onChange = function()
            if UberUI.nameplates then UberUI.nameplates:UpdateNameplateSize() end
        end,
    });

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "NameplateBarTextures", cbName = "Nameplate Bar Textures", cbField = "nameplatebartextures",
        cbTooltip = "Retexture Nameplate Frames Separately from All Bars texture",
        ddVariable = "NameplateTexture", ddName = "Nameplate Bar Texture", ddField = "nameplatebartexture",
        ddTooltip = "Set your desired status bar texture for Nameplate frames",
        cbOnChange = function() UberUI.nameplates:ForceNameplateTexture() end,
        ddOnChange = function(value) UberUI.nameplates:ForceNameplateTexture(value) end,
    });

    opt.Header(page, "Friendly Raid Target Icons");

    opt.AddSlider(page, {
        variable = "FriendlyNameplateRaidTargetScale", name = "Friendly Nameplate Raid Target Scale",
        tooltip = "Scale of the raid target icon on friendly nameplates",
        db = "general", field = "nameplateraidtargetscale", default = 1,
        min = 0.5, max = 10, step = 0.1,
        format = function(value) return string.format("%.1f", value) end,
        onChange = function() UberUI.nameplates:UpdateAllNameplateRaidTargetScale() end,
    });

    opt.AddCheckbox(page, {
        variable = "AnchorFriendlyRaidIconTop", name = "Anchor Friendly Raid Icon Top",
        tooltip = "Anchor the raid icon to the top center of the nameplate",
        db = "general", field = "nameplateraidtargettopanchor", default = false,
        onChange = function() UberUI.nameplates:UpdateAllNameplateRaidTargetScale() end,
    });

    if PersonalResourceDisplayMixin then
        opt.Header(page, "Personal Resource Display");

        local function RefreshPersonalResource()
            if UberUI.personalresource then UberUI.personalresource:ForceTexture() end
        end

        opt.AddCheckbox(page, {
            variable = "darkenpersonalresourceborder", name = "Darken Personal Resource Border",
            tooltip = "Darkens the border texture of the Personal Resource Display",
            db = "general", field = "darkenpersonalresourceborder", default = true,
            onChange = RefreshPersonalResource,
        });

        opt.AddBarTextureSetting(page, {
            dbTable = uuidb.general,
            cbVariable = "PersonalResourceBarTextures", cbName = "Personal Resource Bar Textures", cbField = "personalresourcebartextures",
            cbTooltip = "Retexture Personal Resource Display Separately from All Bars texture",
            ddVariable = "PersonalResourceTexture", ddName = "Personal Resource Bar Texture", ddField = "personalresourcebartexture",
            ddTooltip = "Set your desired status bar texture for Personal Resource Display",
            cbOnChange = RefreshPersonalResource,
            ddOnChange = RefreshPersonalResource,
        });
    end
end
