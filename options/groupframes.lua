--[[--------------------------------------------------------------------
	Uber UI options -- Raid & Group Frames page (compact raid/party frames)
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

function opt.BuildGroupFrames(page)
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        opt.Header(page, "Auras");

        -- "None" hands that aura type back to Blizzard's native display
        -- (restores the raid frame option we turned off), so each of these
        -- doubles as the on/off switch for testing.
        local function RefreshCompactAuras()
            if UberUI.compactauras and UberUI.compactauras.Refresh then
                UberUI.compactauras:Refresh();
            end
        end

        -- Zoom off + the Blizzard border choice hands that aura type back to
        -- Blizzard's native display (restores the raid frame option we turned
        -- off), so it doubles as the on/off switch for testing.
        opt.AddAuraOptions(page, {
            loc = "compact", label = "Compact Raid/Party", suffix = "Compact",
            buffKey = "aurastyle_compactbuffs", debuffKey = "aurastyle_compactdebuffs",
            refresh = RefreshCompactAuras,
            debuffTooltip = "Border on compact raid and party debuffs, including private boss debuffs: Blizzard's dispel-type color (Magic, Curse, Disease, Poison, Bleed; red when there's no type), or the darkness color.\n\nWith Zoom off and the Blizzard border choice, Uber UI leaves these auras entirely to Blizzard.",
        });

        opt.AddCheckbox(page, {
            variable = "compactBigDefensive", name = "Compact Raid/Party Big Defensive",
            tooltip = "Replace the large defensive cooldown icon in the center of compact raid and party frames with Uber UI's, styled like Compact Raid/Party buffs (same zoom, border and shape). Size follows Blizzard's Edit Mode Big Defensive size.\n\nWhen off, Blizzard's own icon is restored.",
            db = "general", field = "compactbigdefensive", default = true,
            onChange = RefreshCompactAuras,
        });
    end

    opt.Header(page, "Frames");

    opt.AddCheckbox(page, {
        variable = "HideRaidFrameTitles", name = "Hide Raid Frame Titles",
        tooltip = "Hide the title text on raid frames e.g. 'Group 1'",
        db = "cuf", field = "hideRaidTitle", default = false,
        onChange = function() UberUI.cuf:HideRaidFrameTitles() end,
    });

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "RaidBarTextures", cbName = "Raid Bar Textures", cbField = "raidbartextures",
        cbTooltip = "Retexture Raid & Raid Party Frames Separately from All Bars texture",
        ddVariable = "RaidTexture", ddName = "Raid Bar Texture", ddField = "raidbartexture",
        ddTooltip = "Set your desired status bar texture for Raid & Raid Party frames" .. opt.RELOAD_NOTE,
        cbOnChange = function() UberUI.misc:AllFramesHealthManaTexture() end,
        ddOnChange = function() UberUI.misc:AllFramesHealthManaTexture() end,
    });
end
