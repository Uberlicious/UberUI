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
    if event == "ADDON_LOADED" and arg1 == addon then
        if not self.initialized then
            self:Init()
            self.initialized = true
        end
    elseif event == "VARIABLES_LOADED" then
        if not self.initialized then
            self:Init()
            self.initialized = true
        end
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
        nameplatebartextures         = false,
        personalresourcebartextures  = false,
        damagemeterbartextures       = false,
        zoomiconbuffs                = false,
        zoomicontarget               = false,
        zoomiconparty                = false,
        zoomiconcompact              = false,
        aurastyle_playerbuffs        = "both",
        aurastyle_playerdebuffs      = "zoom",
        aurastyle_targetbuffs        = "both",
        aurastyle_targetdebuffs      = "zoom",
        targetbuffs_showdispel       = true,
        aurastyle_focusbuffs         = "both",
        aurastyle_focusdebuffs       = "zoom",
        focusbuffs_showdispel        = true,
        aurastyle_partybuffs         = "both",
        aurastyle_partydebuffs       = "zoom",
        aurastyle_compactbuffs       = "both",
        aurastyle_compactdebuffs     = "zoom",
        aurastyle_nameplatebuffs     = "both",
        aurastyle_nameplatedebuffs   = "zoom",
        aurastyle_arenabuffs         = "both",
        aurastyle_arenadebuffs       = "zoom",
        buffauraborders              = true,
        showExtendedBarTextures      = false,
        nameplateraidtargetscale     = 1,
        nameplateraidtargettopanchor = false,
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
    arenaframes = {
        classcolor = true,
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
