-- // Uber UI
-- // Uberlicious - 2018

-----------------------------
-- INIT
-----------------------------

local addon, ns = ...
UberUI = {}
uuidb = {}

local _, class = UnitClass("player")
local classcolor = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (GetClassColorObj and GetClassColorObj(class)) or RAID_CLASS_COLORS[class])
-----------------------------
-- DEFAULTS
-----------------------------

UberUI = CreateFrame("Frame")
UberUI:RegisterEvent("VARIABLES_LOADED")
UberUI:RegisterEvent("ADDON_LOADED")
UberUI:RegisterEvent("PLAYER_LOGIN")
UberUI:RegisterEvent("PLAYER_LOGOUT")
UberUI:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= addon then
        return
    end
    -- Re-run on each event so late-loading SavedVariables are merged properly.
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
        swingtimerbarcolor           = "none",
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
        squareauraborders_thickness  = 1,
        squareauraborders_inset      = true,
        playertempenchantcolor       = true,
        -- Other aura locations: squareauraborders_<loc>[_thickness|_inset]
        -- (squareborders.lua).
        squareauraborders_target           = false,
        squareauraborders_target_thickness = 1,
        squareauraborders_target_inset     = true,
        squareauraborders_focus            = false,
        squareauraborders_focus_thickness  = 1,
        squareauraborders_focus_inset      = true,
        squareauraborders_boss             = false,
        squareauraborders_boss_thickness   = 1,
        squareauraborders_boss_inset       = true,
        squareauraborders_party            = false,
        squareauraborders_party_thickness  = 1,
        squareauraborders_party_inset      = true,
        squareauraborders_compact          = false,
        squareauraborders_compact_thickness = 1,
        squareauraborders_compact_inset    = true,
        squareauraborders_arena            = false,
        squareauraborders_arena_thickness  = 1,
        squareauraborders_arena_inset      = true,
        squareauraborders_nameplate            = false,
        squareauraborders_nameplate_thickness  = 1,
        squareauraborders_nameplate_inset      = true,
        squareauraborders_cdm              = false,
        squareauraborders_cdm_thickness    = 1,
        squareauraborders_cdm_inset        = true,
        squaredispelborderthicker    = true,
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
        nameplatebuffbudget          = 1,
        nameplatebuffsimportant      = true,
        nameplatebuffspurgeable      = "group",
        nameplatepandemic            = true,
        nameplatepandemicstyle       = "border",
        nameplatepandemiccolor       = "ffff3030",
        nameplatepandemicclasscolor  = false,
        nameplatedurationcolor          = "ffffffff",
        nameplatedurationexpiringcolor  = "ffff3333",
        nameplatedurationthreshold      = 5,
        targetauraduration              = false,
        focusauraduration               = false,
        compactauraduration             = false,
        buffauraborders              = true,
        nameplateraidtargetscale     = 1,
        nameplateraidtargettopanchor = false,
        smallfriendlynameplate       = false,
        nameplatesquareborder        = false,
        nameplatesquareborder_thickness = 1,
        namehealthstyle              = "off",
        namehealthhidefull           = true,
        namehealthunderlinethickness = 1,
        namehealthunderlineside      = "BELOW",
        namehealthunderlineoffset    = 0,
        namehealthdotsize            = 8,
        namehealthdotside            = "LEFT",
        namehealthdotoffset          = 0,
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
        squarebars            = false,
        barpandemic           = "bar",
        barpandemicstyle      = "blizzard",
        barpandemiccolor      = "ffff3030",
        barpandemicclasscolor = false,
        darkenbars            = true,
        baricontobar          = false,
        borders               = true,
        pandemicstyle         = "blizzard",
        pandemiccolor         = "ffff3030",
        pandemicclasscolor    = false,
        durationcolors        = false,
        durationcolor         = "ffffffff",
        durationexpiringcolor = "ffff3333",
        durationthreshold     = 5,
        -- "blizzard" (Blizzard's own layout), "pack" or "center"
        essential_align       = "blizzard",
        utility_align         = "blizzard",
        bufficon_align        = "blizzard",
        buffbar_align         = "blizzard",
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
    },
}

-- Copyable error popup.
local reportedErrors, errorLog = {}, {}
local errorFrame

local function ShowErrors(text)
    if not errorFrame then
        errorFrame = CreateFrame("Frame", "UberUIErrorFrame", UIParent, "BackdropTemplate")
        errorFrame:SetSize(640, 360)
        errorFrame:SetPoint("CENTER")
        errorFrame:SetFrameStrata("DIALOG")
        errorFrame:SetMovable(true)
        errorFrame:EnableMouse(true)
        errorFrame:RegisterForDrag("LeftButton")
        errorFrame:SetScript("OnDragStart", errorFrame.StartMoving)
        errorFrame:SetScript("OnDragStop", errorFrame.StopMovingOrSizing)
        errorFrame:SetBackdrop({
            bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
            edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })

        local scroll = CreateFrame("ScrollFrame", nil, errorFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -20)
        scroll:SetPoint("BOTTOMRIGHT", -36, 40)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(570)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(edit)
        errorFrame.edit = edit

        CreateFrame("Button", nil, errorFrame, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -5, -5)
        local hint = errorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("BOTTOM", 0, 16)
        hint:SetText("Click inside the box, Ctrl+A to select all, Ctrl+C to copy")
    end
    errorFrame.edit:SetText(text)
    errorFrame:Show()
end

-- Copyable popup for /uuidebug* reports (never chat).
function UberUI.ShowDebugReport(text)
    ShowErrors(text)
end

function UberUI:ReportError(where, err)
    local msg = tostring(where) .. ": " .. tostring(err)
    if reportedErrors[msg] then return end
    reportedErrors[msg] = true
    errorLog[#errorLog + 1] = date("%H:%M:%S") .. "  " .. msg
    print("|cff33ff99Uber UI|r: " .. tostring(where) .. " failed -- details in the popup.")
    ShowErrors("Uber UI errors -- please copy and report these:\n\n" .. table.concat(errorLog, "\n\n"))
end

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

    -- Migrate Cooldown Manager collapse/centered settings to align choice.
    local cd = UberuiDB.cooldown
    if type(cd) == "table" then
        for _, p in ipairs({ "essential", "utility", "bufficon", "buffbar" }) do
            local collapse, centered = cd[p .. "_collapse"], cd[p .. "_centered"]
            if cd[p .. "_align"] == nil and (collapse ~= nil or centered ~= nil) then
                cd[p .. "_align"] = (centered and "center") or (collapse and "pack") or "blizzard"
            end
            cd[p .. "_collapse"], cd[p .. "_centered"] = nil, nil
        end
        cd.debuffborder = nil
        -- Tracked Bars got their own pandemic style: start from the shared one.
        if cd.barpandemicstyle == nil and cd.pandemicstyle ~= nil then
            cd.barpandemicstyle = cd.pandemicstyle
        end
        -- Pandemic colors default to Blizzard's pandemic red (255, 48, 48);
        -- the new bar color/class color start from their defaults.
        if (cd._pandemic_version or 0) < 1 then
            if cd.pandemiccolor == "ffff2626" then cd.pandemiccolor = nil end
            cd.barpandemiccolor, cd.barpandemicclasscolor = nil, nil
            cd._pandemic_version = 1
        end
        -- Countdown coloring became opt-in: on for anyone who'd changed a color.
        if cd.durationcolors == nil then
            local normal = type(cd.durationcolor) == "string" and cd.durationcolor:lower()
            local expiring = type(cd.durationexpiringcolor) == "string" and cd.durationexpiringcolor:lower()
            if (normal and normal ~= "ffffffff") or (expiring and expiring ~= "ffff3333" and expiring ~= "ffffffff") then
                cd.durationcolors = true
            end
        end
        if cd._defaults_version == nil or cd._defaults_version < 2 then
            if cd.bufficon_align == "pack" then cd.bufficon_align = "blizzard" end
            if cd.buffbar_align == "pack" then cd.buffbar_align = "blizzard" end
            cd._defaults_version = 2
        end
    end

    local g = UberuiDB.general
    if type(g) == "table" and g.nameplatepandemiccolor == "ffff2626" then
        g.nameplatepandemiccolor = nil
    end
    if type(g) == "table" then
        if g._defaults_version == nil or g._defaults_version < 2 then
            g.swingtimersquareborder = false
            g.nameplatesquareborder = false
            g.squareauraborders_nameplate = false
            g.SwingTimerBorderShape = nil
            g.NameplateHealthBorderShape = nil
            g._defaults_version = 2
        end
        -- Swing timer bar color became one dropdown. Custom textures always
        -- used the per-hand colors, so keep them colored.
        if g.swingtimerbarcolor == nil then
            if g.swingtimerclasscolor then
                g.swingtimerbarcolor = "class"
            elseif g.swingtimerbartint or g.swingtimerbartextures then
                g.swingtimerbarcolor = "custom"
            end
        end
        g.swingtimerbartint, g.swingtimerclasscolor = nil, nil
        -- Friendly name health dot went from plate-scaled units to screen
        -- pixels; the old default of 5 becomes the new default of 8.
        if (g._namehealth_version or 0) < 1 then
            if g.namehealthdotsize == 5 then g.namehealthdotsize = nil end
            g._namehealth_version = 1
        end
    end

    mergeDefaults(defaults, UberuiDB)
    uuidb = UberuiDB
    self:AttachSharedMediaTextures()
end

-----------------------------
-- SHARED MEDIA (LibSharedMedia-3.0)
-----------------------------

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

-- Register our textures with LibSharedMedia.
if LSM then
    for name, path in pairs(defaults.statusbars) do
        if name ~= "Blizzard" then
            LSM:Register("statusbar", "Uber UI " .. name:gsub("_", " "), path)
        end
    end
end

-- Re-apply bar textures if a selected LibSharedMedia texture is registered late.
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

-- Bar texture choices: built-in textures followed by external LibSharedMedia textures.
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
