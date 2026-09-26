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
        buffauraborders              = true,
        nameplateraidtargetscale     = 1,
        nameplateraidtargettopanchor = false,
        smallfriendlynameplate       = false,
    },
    damagemeters = {
        background = false,
        alpha = .5,
        hideoverlay = false,
        hidebarbackground = false,
    },
    cooldown = {
        bartexture  = "Blizzard",
        bartextures = false,
        borders     = true,
    },
    playerframes = {
        classcolor = true,
    },
    targetframes = {
        classcolorenemy = true,
        classcolorfriendly = true,
    },
    focusframes = {
        classcolorenemy = true,
        classcolorfriendly = true,
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
end

function UberUI:Save()
    _G["UberuiDB"] = uuidb
end
