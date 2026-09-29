--[[--------------------------------------------------------------------
	Uber UI options -- Arena page (not built on Classic; see register.lua)
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = ns.options

function opt.BuildArena(page)
    opt.Header(page, "Arena Frames");

    opt.AddCheckbox(page, {
        variable = "HideArenaFrames", name = "Hide Arena Frames",
        tooltip = "Force hide default blizzard arena frames.",
        db = "general", field = "hidearenaframes", default = false,
        onChange = function() UberUI.arenaframes:SetVisibility() end,
    });

    local function RefreshArenaAuraStyle()
        if UberUI.arenaframes then
            UberUI.arenaframes:RefreshAuraStyle();
        end
    end

    -- Arena frames never show general buffs (Blizzard hardcodes
    -- ignore-buffs=true for PvP-classified frames), so the "buffs" style slot
    -- (aurastyle_arenabuffs) styles the Diminishing Returns tracker, and the
    -- native debuff display is the forbidden private-aura renderer, so the
    -- "debuffs" slot (aurastyle_arenadebuffs) styles the addon-visible Crowd
    -- Control (Loss of Control) tracker instead.
    opt.AddAuraOptions(page, {
        loc = "arena", label = "Arena", suffix = "Arena",
        buffKey = "aurastyle_arenabuffs", debuffKey = "aurastyle_arenadebuffs",
        refresh = RefreshArenaAuraStyle,
        zoomTooltip = "Zoom the arena DR and CC tracker icons slightly to crop off Blizzard's built-in icon edge.",
        buffName = "Arena DR Tracker Border",
        buffTooltip = "Border on the Diminishing Returns tracker icons. \"None\" is Blizzard's look (no border).",
        debuffName = "Arena CC Tracker Border",
        debuffNative = "Red",
        debuffTooltip = "Border on the Crowd Control tracker icon. \"Red\" is Blizzard's look.",
        shapeTooltip = "Rounded uses Blizzard's border art. Square draws a flat border of exact pixel thickness in the same colors.",
    });

    opt.Header(page, "Nameplates");

    opt.AddCheckbox(page, {
        variable = "ArenaNameplateNumbers", name = "Arena Nameplate Numbers",
        tooltip = "Change name on arena nameplate frames to target number",
        db = "general", field = "arenanumbers", default = true,
        onChange = function() UberUI.arenaframes:NameplateNumbers() end,
    });
end
