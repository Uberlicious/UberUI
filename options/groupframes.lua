--[[--------------------------------------------------------------------
	Uber UI options -- Raid & Group Frames page (compact raid/party frames)

	Same order as the Unit Frames sections: Frame, Auras, Aura Text.
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

function opt.BuildGroupFrames(page)
    opt.Header(page, "Frame");

    opt.AddRaidFramePreview(page);

    opt.AddCheckbox(page, {
        variable = "HideRaidFrameTitles", name = "Hide Raid Frame Titles",
        tooltip = "Hide the title text on raid frames e.g. 'Group 1'",
        db = "cuf", field = "hideRaidTitle", default = false,
        onChange = function() UberUI.cuf:HideRaidFrameTitles() end,
    });

    opt.AddBarTextureSetting(page, {
        dbTable = uuidb.general,
        cbVariable = "RaidBarTextures", cbName = "Bar Textures", cbField = "raidbartextures",
        cbTooltip = "Retexture Raid & Raid Party Frames Separately from All Bars texture",
        ddVariable = "RaidTexture", ddName = "Bar Texture", ddField = "raidbartexture",
        ddTooltip = "Set your desired status bar texture for Raid & Raid Party frames" .. opt.RELOAD_NOTE,
        cbOnChange = function() UberUI.misc:AllFramesHealthManaTexture() end,
        ddOnChange = function() UberUI.misc:AllFramesHealthManaTexture() end,
    });

    local function RefreshThreat()
        if UberUI.compactthreat then UberUI.compactthreat:Refresh() end
    end
    local function ThreatStyle()
        return (uuidb.general and uuidb.general.cufthreatstyle) or "blizzard"
    end

    local threatInit = opt.AddDropdown(page, {
        variable = "CUFThreatStyle", name = "Threat Highlight",
        tooltip = "How a party or raid member's threat shows (yellow when gaining threat, red when tanking). The white target selection stays visible on top of every style.\n\nBlizzard: Blizzard's thick colored frame.\n\nThin Border: a thin line just inside the frame edge.\n\nInner Glow: a soft glow fading in from the edges.\n\nCorner Marks: small triangles in the corners.\n\nTop Stripe: a line along the top edge.\n\nHidden: no threat highlight.\n\nShown only while Blizzard's \"Display Aggro Highlight\" raid frame option is on.",
        default = "blizzard",
        values = { { "blizzard", "Blizzard" }, { "border", "Thin Border" }, { "glow", "Inner Glow" },
                   { "corners", "Corner Marks" }, { "stripe", "Top Stripe" }, { "hidden", "Hidden" } },
        get = ThreatStyle,
        set = function(value) uuidb.general.cufthreatstyle = value end,
        onChange = RefreshThreat,
        repair = true,
    });
    local function ThreatLines()
        local s = ThreatStyle()
        return s == "border" or s == "stripe"
    end
    local threatThicknessInit = opt.AddSlider(page, {
        variable = "CUFThreatThickness", name = "Threat Line Thickness",
        tooltip = "Thickness of the Thin Border or Top Stripe threat highlight, in screen pixels.",
        db = "general", field = "cufthreatthickness", default = 2,
        min = 1, max = 6, step = 1,
        onChange = RefreshThreat,
    });
    opt.DependsOn(threatThicknessInit, threatInit, ThreatLines);
    opt.ShowWhen(threatThicknessInit, ThreatLines);

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
        styleHeader = "Auras", textHeader = "Aura Text",
        debuffTooltip = "Border on compact raid and party debuffs, including private boss debuffs: Blizzard's dispel-type color (Magic, Curse, Disease, Poison, Bleed; red when there's no type), or the darkness color.\n\nWith Zoom off and the Blizzard border choice, Uber UI leaves these auras entirely to Blizzard.",
        afterStyle = function()
            opt.AddSlider(page, {
                variable = "compactMaxDebuffs", name = "Max Debuffs",
                tooltip = "How many debuffs each compact raid and party frame shows, three per row: 3 is Blizzard's default, 6 is two full rows.\n\nBoss debuffs, dispellable debuffs and other debuffs are each limited to this many, so a frame carrying several kinds at once can show more.",
                db = "general", field = "compactmaxdebuffs", default = 3,
                min = 3, max = 6, step = 1,
                onChange = RefreshCompactAuras,
            });

            opt.AddCheckbox(page, {
                variable = "compactBigDefensive", name = "Big Defensive",
                tooltip = "Replace the large defensive cooldown icon in the center of compact raid and party frames with Uber UI's, styled like Compact Raid/Party buffs (same zoom, border and shape). Size follows Blizzard's Edit Mode Big Defensive size.\n\nWhen off, Blizzard's own icon is restored.",
                db = "general", field = "compactbigdefensive", default = true,
                onChange = RefreshCompactAuras,
            });
        end,
        durationToggle = {
            variable = "compactAuraDuration", field = "compactauraduration", onChange = RefreshCompactAuras,
            tooltip = "Show the time left on compact raid and party auras as a number in the middle of the icon, sized to the icon. The settings under it set how it looks.",
        },
    });
end
