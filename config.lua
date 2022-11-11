-- // Uber UI
-- // Uberlicious - 2018

-----------------------------
-- INIT
-----------------------------

--get the addon namespace
local addon, ns = ...
UberUI = {}
uuidb = {}

local classcolor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
-----------------------------
-- DEFAULTS
-----------------------------

--generate a holder for the config data
UberUI = CreateFrame("Frame")
UberUI:RegisterEvent("VARIABLES_LOADED")
UberUI:RegisterEvent("ADDON_LOADED")
UberUI:RegisterEvent("PLAYER_LOGIN")
UberUI:RegisterEvent("PLAYER_LOGOUT")
UberUI:SetScript("OnEvent", function(self, event)
    if (event == "ADDON_LOADED" or event == "VARIABLES_LOADED") then
        self:Init();
    end

    if (event == "PLAYER_LOGOUT") then
        self:Save();
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
    general = {
        classcolorhealth     = true;
        darkencolor          = { r = .4, g = .4, b = .4, a = 1 };
        texture              = "Blizzard";
        secondarybartexture  = "Blizzard";
        raidbartexture       = "Blizzard";
        arenanumbers         = true;
        hidearenaframes      = false;
        border               = "Interface\\AddOns\\Uber UI\\textures\\border";
        hidehotkeys          = false;
        hidemacros           = false;
        hidehonor            = false;
        hiderepcolor         = true;
        hostilitycolor       = true;
        ccpersonalresource   = true;
        hidenameplateglow    = false;
        secondarybartextures = false;
        raidbartextures      = false;
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
        hideframes = false,
        classcolor = true,
    },
    partyframes = {
        classcolor = true,
    },
}

function UberUI:GetDefaults()
    return defaults;
end

function UberUI:Init()
    local function initDB(def, tbl, saved)
        if type(def) ~= "table" then return {} end
        if type(tbl) ~= "table" then tbl = {} end
        if type(saved) ~= "table" then saved = {} end
        for k, v in pairs(def) do
            if type(v) == "table" then
                tbl[k] = initDB(v, tbl[k], saved[k])
            elseif type(tbl[k]) ~= "table" and saved[k] ~= nil then -- If saved value exists use it
                tbl[k] = saved[k]
            elseif type(tbl[k]) ~= "table" and saved[k] == nil then -- If saved value does not exist use default
                tbl[k] = v
            end
        end
        return tbl
    end

    uuidb = initDB(defaults, uuidb, UberuiDB)
end

function UberUI:Save()
    local function updateSave(def, tbl, saved)
        if type(def) ~= "table" then return {} end
        if type(tbl) ~= "table" then tbl = {} end
        if type(saved) ~= "table" then saved = {} end
        for k, v in pairs(tbl) do
            if type(v) == "table" then
                saved[k] = updateSave(def[k], v, saved[k])
            elseif type(saved[k]) ~= "table" and v ~= def[k] then -- If temp value does not equal the default, save it
                saved[k] = v
            elseif type(saved[k]) ~= "table" and v == def[k] and saved[k] ~= def[k] then -- Unset saved value if temp == default and saved value exists
                saved[k] = nil
            elseif type(saved[k]) ~= "table" and saved[k] == def[k] then -- Cleanup if save value happens to == default
                saved[k] = nil
            end
        end
        return saved
    end

    UberuiDB = updateSave(defaults, uuidb, UberuiDB)

    local function cleanupSave(saved)
        for k, v in pairs(saved) do
            if type(v) == "table" and next(v) then
                cleanupSave(v)
            elseif type(v) == "table" and not next(v) then
                saved[k] = nil
            end
        end
        return saved
    end

    UberuiDB = cleanupSave(UberuiDB)
end
