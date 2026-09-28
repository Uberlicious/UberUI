-- // Uber UI
-- // Uberlicious - 2018

-----------------------------
-- INIT
-----------------------------

--get the addon namespace
local addon, ns = ...
UberUI = {}
uuidb = {}

local _, class = UnitClass("player")
local classcolor = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (GetClassColorObj and GetClassColorObj(class)) or RAID_CLASS_COLORS[class])
-----------------------------
-- DEFAULTS
-----------------------------

--generate a holder for the config data
UberUI = CreateFrame("Frame")
UberUI:RegisterEvent("VARIABLES_LOADED")
UberUI:RegisterEvent("ADDON_LOADED")
UberUI:RegisterEvent("PLAYER_LOGIN")
UberUI:RegisterEvent("PLAYER_LOGOUT")
UberUI:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= addon then
        return
    end
    -- Re-run (not just once-and-lock) on every one of these: mergeDefaults
    -- only fills in keys that are still nil, so repeat calls are harmless,
    -- and this guards against SavedVariables becoming available later than
    -- the first of these events fires (seen on Forever: writes on logout
    -- succeed, but the saved values weren't showing up after a reload --
    -- consistent with the global not being populated yet at ADDON_LOADED
    -- time on this client, with the old single-fire Init() never
    -- re-syncing once PLAYER_LOGIN/VARIABLES_LOADED actually had the data).
    if event == "ADDON_LOADED" or event == "VARIABLES_LOADED" or event == "PLAYER_LOGIN" then
        self:Init()
    elseif event == "PLAYER_LOGOUT" then
        self:Save()
    end
end)

local defaults = {
    statusbars = {
        Blizzard      = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\nameplate",
        Blizzard_Flat = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\nameplate",
        Blizzard_Old  = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\blizzard",
        Minimalist    = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\Minimalist",
        Ace           = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\Ace",
        Aluminum      = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\Aluminum",
        Banto         = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\banto",
        Charcoal      = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\Charcoal",
        Glaze         = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\glaze",
        Litestep      = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\LiteStep",
        Otravi        = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\otravi",
        Perl          = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\perl",
        Smooth        = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\smooth",
        Striped       = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\striped",
        Swag          = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\swag",
        Flat          = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\flat",
    },
    masks = {
        cdm_mask = "Interface\\AddOns\\Uber UI\\textures\\statusbars\\cdm_bar_mask.tga",
    },
    general = {
        classcolorhealth             = true,
        darkencolor                  = { r = .4, g = .4, b = .4, a = 1 },
        texture                      = "Blizzard",
        secondarybartexture          = "Blizzard",
        raidbartexture               = "Blizzard",
        playerbartexture             = "Blizzard",
        targetbartexture             = "Blizzard",
        partybartexture              = "Blizzard",
        focusbartexture              = "Blizzard",
        bossbartexture               = "Blizzard",
        nameplatebartexture          = "Blizzard",
        personalresourcebartexture   = "Blizzard",
        swingtimerbartexture         = "Blizzard",
        swingtimerbartextures        = false,
        darkenswingtimers            = true,
        swingtimerlabelshadow        = true,
        swingtimersquareborder       = false,
        swingtimersquareborder_thickness = 1,
        swingtimermainhandcolor      = "ffffc21a",
        swingtimeroffhandcolor       = "ff3d9eff",
        swingtimerrangedcolor        = "ff5cd65c",
        damagemetertexture           = "Blizzard",
        arenanumbers                 = true,
        hidearenaframes              = false,
        border                       = "Interface\\AddOns\\Uber UI\\textures\\border",
        hidehotkeys                  = false,
        hidemacros                   = false,
        hiderepcolor                 = true,
        hostilitycolor               = true,
        darkenpersonalresourceborder = true,
        allbartextures               = true,
        secondarybartextures         = false,
        raidbartextures              = false,
        playerbartextures            = false,
        targetbartextures            = false,
        partybartextures             = false,
        focusbartextures             = false,
        bossbartextures              = false,
        nameplatebartextures         = false,
        personalresourcebartextures  = false,
        damagemeterbartextures       = false,
        zoomiconbuffs                = false,
        zoomicontarget               = false,
        zoomiconcompact              = false,
        aurastyle_playerbuffs        = "both",
        aurastyle_playerdebuffs      = "zoom",
        squareauraborders_player     = false,
        squareauraborders_thickness  = 2,
        squareauraborders_inset      = true,
        playertempenchantcolor       = true,
        -- Other aura locations: squareauraborders_<loc>[_thickness|_inset]
        -- (see core/squareborders.lua; Player keeps the original keys above).
        squareauraborders_target           = false,
        squareauraborders_target_thickness = 2,
        squareauraborders_target_inset     = true,
        squareauraborders_focus            = false,
        squareauraborders_focus_thickness  = 2,
        squareauraborders_focus_inset      = true,
        squareauraborders_boss             = false,
        squareauraborders_boss_thickness   = 2,
        squareauraborders_boss_inset       = true,
        squareauraborders_party            = false,
        squareauraborders_party_thickness  = 2,
        squareauraborders_party_inset      = true,
        squareauraborders_compact          = false,
        squareauraborders_compact_thickness = 2,
        squareauraborders_compact_inset    = true,
        squareauraborders_arena            = false,
        squareauraborders_arena_thickness  = 2,
        squareauraborders_arena_inset      = true,
        squareauraborders_nameplate            = false,
        squareauraborders_nameplate_thickness  = 2,
        squareauraborders_nameplate_inset      = true,
        squareauraborders_cdm              = false,
        squareauraborders_cdm_thickness    = 1,
        squareauraborders_cdm_inset        = true,
        aurastyle_targetbuffs        = "both",
        aurastyle_targetdebuffs      = "zoom",
        targetbuffs_showdispel       = true,
        aurastyle_focusbuffs         = "both",
        aurastyle_focusdebuffs       = "zoom",
        focusbuffs_showdispel        = true,
        aurastyle_bossbuffs          = "both",
        aurastyle_bossdebuffs        = "zoom",
        bossbuffs_showdispel         = true,
        aurastyle_partybuffs         = "both",
        aurastyle_partydebuffs       = "zoom",
        aurastyle_compactbuffs       = "both",
        aurastyle_compactdebuffs     = "zoom",
        compactbigdefensive          = true,
        aurastyle_arenabuffs         = "both",
        aurastyle_arenadebuffs       = "zoom",
        nameplateauras               = false,
        targetcastbariconborder      = true,
        focuscastbariconborder       = true,
        aurastyle_nameplatebuffs     = "both",
        aurastyle_nameplatedebuffs   = "zoom",
        nameplatebuffs_showdispel    = true,
        nameplatepandemic            = true,
        nameplatepandemicstyle       = "border",
        nameplatepandemiccolor       = "ffff2626",
        nameplatedurationcolor          = "ffffffff",
        nameplatedurationexpiringcolor  = "ffff3333",
        nameplatedurationthreshold      = 5,
        buffauraborders              = true,
        nameplateraidtargetscale     = 1,
        nameplateraidtargettopanchor = false,
        smallfriendlynameplate       = false,
        nameplatesquareborder        = false,
        nameplatesquareborder_thickness = 1,
        darkenaddonminimapbuttons    = true,
    },
    damagemeters = {
        background = false,
        alpha = .5,
        hideoverlay = false,
        hidebarbackground = false,
    },
    cooldown = {
        bartexture            = "Blizzard",
        bartextures           = false,
        borders               = true,
        pandemicstyle         = "blizzard",
        debuffborder          = "dispel",
        pandemiccolor         = "ffff2626",
        durationcolor         = "ffffffff",
        durationexpiringcolor = "ffff3333",
        durationthreshold     = 5,
        essential_collapse    = false,
        essential_centered    = false,
        utility_collapse      = false,
        utility_centered      = false,
        bufficon_collapse     = true,
        bufficon_centered     = false,
        buffbar_collapse      = true,
        buffbar_centered      = false,
    },
    playerframes = {
        classcolor = true,
    },
    targetframes = {
        classcolorenemy = true,
        classcolorfriendly = true,
        totplacement = "narrow",
    },
    focusframes = {
        classcolorenemy = true,
        classcolorfriendly = true,
        totplacement = "narrow",
    },
    bossframes = {
        classcolorenemy = true,
        classcolorfriendly = true,
    },
    partyframes = {
        classcolor = true,
    },
    cuf = {
        hideRaidTitle = false,
        sortMeOnTop = false,
    },
}

function UberUI:GetDefaults()
    return defaults;
end

function UberUI:Init()
    if type(UberuiDB) ~= "table" then
        UberuiDB = {}
    end

    local function mergeDefaults(def, saved)
        for k, v in pairs(def) do
            if type(v) == "table" then
                if type(saved[k]) ~= "table" then
                    saved[k] = {}
                end
                mergeDefaults(v, saved[k])
            else
                if saved[k] == nil then
                    saved[k] = v
                end
            end
        end
    end

    mergeDefaults(defaults, UberuiDB)
    uuidb = UberuiDB
    self:AttachSharedMediaTextures()
end

-----------------------------
-- SHARED MEDIA (LibSharedMedia-3.0)
-----------------------------

-- Every texture lookup in the addon is uuidb.statusbars[name]. Our own
-- textures live in that saved table; any other name falls through to
-- LibSharedMedia's "statusbar" list (textures other addons register), so
-- all of those work everywhere with no per-frame changes and nothing from
-- another addon is ever saved. Names are stored with spaces as underscores
-- (the dropdowns' convention), so both spellings are tried.
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

local function FetchSharedTexture(_, name)
    if not LSM or type(name) ~= "string" then return nil end
    return LSM:Fetch("statusbar", name, true) or LSM:Fetch("statusbar", (name:gsub("_", " ")), true)
end

function UberUI:AttachSharedMediaTextures()
    if type(uuidb.statusbars) == "table" and getmetatable(uuidb.statusbars) == nil then
        setmetatable(uuidb.statusbars, { __index = FetchSharedTexture })
    end
end

-- Our textures for other addons' pickers (names with spaces). A name another
-- addon already registered keeps its texture there.
if LSM then
    for name, path in pairs(defaults.statusbars) do
        if name ~= "Blizzard" then
            LSM:Register("statusbar", "Uber UI " .. name:gsub("_", " "), path)
        end
    end
end

-- A texture another addon registers after our frames were textured (their
-- load order is theirs) left a chosen shared texture unapplied until the next
-- refresh. When one of the textures picked in our settings shows up, re-apply
-- bar textures once (coalesced; next frame, outside the registering call).
if LSM then
    local pending = false
    local watcher = {}
    LSM.RegisterCallback(watcher, "LibSharedMedia_Registered", function(_, mediatype, key)
        if mediatype ~= "statusbar" or pending or type(key) ~= "string" then return end
        local g = uuidb and uuidb.general
        if type(g) ~= "table" then return end
        local stored = key:gsub(" ", "_")
        local used = false
        for field, value in pairs(g) do
            if type(value) == "string" and field:find("texture$") and (value == key or value == stored) then
                used = true
                break
            end
        end
        if not used then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if UberUI.misc then pcall(UberUI.misc.AllFramesHealthManaTexture, UberUI.misc) end
        end)
    end)
end

-- The bar texture dropdowns: ours, then every LibSharedMedia texture that
-- isn't already one of ours, as display names (spaces). "Blizzard" first.
function UberUI:GetBarTextureChoices()
    local seen, list = {}, {}
    local function add(display, path)
        local key = display:lower()
        if seen[key] then return end
        seen[key] = true
        list[#list + 1] = { name = display, path = path }
    end
    for name, path in pairs(defaults.statusbars) do
        add((name:gsub("_", " ")), path)
    end
    if LSM then
        for name, path in pairs(LSM:HashTable("statusbar")) do
            if type(name) == "string" and not name:find("^Uber UI ") then add(name, path) end
        end
    end
    table.sort(list, function(a, b)
        if a.name == "Blizzard" then return b.name ~= "Blizzard" end
        if b.name == "Blizzard" then return false end
        return a.name:lower() < b.name:lower()
    end)
    return list
end

function UberUI:Save()
    _G["UberuiDB"] = uuidb
end
