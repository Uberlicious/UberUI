
-- // Uber UI
-- // Uberlicious - 2018

-----------------------------
-- INIT
-----------------------------

--get the addon namespace
local addon, ns = ...

-----------------------------
-- DEFAULTS
-----------------------------

--generate a holder for the config data
local cfg = CreateFrame("Frame")
cfg:SetScript("OnEvent", function(self, event, ...) return self[event] and self[event](self, ...) end)
cfg:RegisterEvent("PLAYER_LOGIN")

local defaults = {
    Gryphon = true,
    Hotkey   = true,
    Macroname = false, 
    LargeHealth = true,
    ClassColorHealth = true,
    ClassColorFrames = false,
    BigFrames = true,
    MBBB = true,
    pvpicons = false,
}

function cfg:PLAYER_LOGIN()
  --print("LOGIN")
  local function initDB(def, tbl)
    if type(def) ~= "table" then return {} end
    if type(tbl) ~= "table" then tbl = {} end
    for k, v in pairs(def) do
      if type(v) == "table" then
        tbl[k] = initDB(v, tbl[k])
      elseif type(tbl[k]) ~= type(v) then
        tbl[k] = v
      end
    end
    return tbl
  end
  UberuiDB = initDB(defaults, UberuiDB)
  self:UnregisterEvent("PLAYER_LOGIN")
end

  -----------------------------
  -- CONFIG
  -----------------------------

-- action bars settings
  cfg.textures = {
    normal            = "Interface\\AddOns\\Uber UI\\textures\\gloss",
    light             = "Interface\\AddOns\\Uber UI\\textures\\glosslight",
    flash             = "Interface\\AddOns\\Uber UI\\textures\\flash",
    hover             = "Interface\\AddOns\\Uber UI\\textures\\hover",
    pushed            = "Interface\\AddOns\\Uber UI\\textures\\pushed",
    checked           = "Interface\\AddOns\\Uber UI\\textures\\checked",
    equipped          = "Interface\\AddOns\\Uber UI\\textures\\gloss_grey",
    buttonback        = "Interface\\AddOns\\Uber UI\\textures\\button_backgroundlight",
    buttonbackflat    = "Interface\\AddOns\\Uber UI\\textures\\button_background_flat",
    outer_shadow      = "Interface\\AddOns\\Uber UI\\textures\\outer_shadow",
  }

  cfg.targetframebig  = {
    targetingframe    = "Interface\\AddOns\\Uber UI\\textures\\target\\targetingframebig",
    elite             = "Interface\\Addons\\Uber UI\\textures\\target\\elitebig",
    rareelite         = "Interface\\Addons\\Uber UI\\textures\\target\\rare-elitebig",
    rare              = "Interface\\AddOns\\Uber UI\\textures\\target\\rarebig",
}

  cfg.targetframe = {
    targetingframe    = "Interface\\AddOns\\Uber UI\\textures\\target\\targetingframe",
    elite             = "Interface\\Addons\\Uber UI\\textures\\target\\elite",
    rareelite         = "Interface\\Addons\\Uber UI\\textures\\target\\rare-elite",
    rare              = "Interface\\AddOns\\Uber UI\\textures\\target\\rare",
}

  cfg.background = {
    showbg            = true,  --show an background image?
    showshadow        = true,   --show an outer shadow?
    useflatbackground = false,  --true uses plain flat color instead
    backgroundcolor   = { r = 0.2, g = 0.2, b = 0.2, a = 0.3},
    shadowcolor       = { r = 0, g = 0, b = 0, a = 0.9},
    classcolored      = true,
    inset             = 5,
  }

  cfg.color = {
    normal            = { r = 0.37, g = 0.3, b = 0.3, },
    equipped          = { r = 0.1, g = 0.5, b = 0.1, },
    classcolored      = true,
  }

  cfg.hotkeys = {
    show            = true,
    fontsize        = 12,
    pos1             = { a1 = "TOPRIGHT", x = 0, y = 0 },
    pos2             = { a1 = "TOPLEFT", x = 0, y = 0 }, --important! two points are needed to make the hotkeyname be inside of the button
  }

  cfg.macroname = {
    show            = false,
    fontsize        = 12,
    pos1             = { a1 = "BOTTOMLEFT", x = 0, y = 0 },
    pos2             = { a1 = "BOTTOMRIGHT", x = 0, y = 0 }, --important! two points are needed to make the macroname be inside of the button
  }

  cfg.itemcount = {
    show            = true,
    fontsize        = 12,
    pos1             = { a1 = "BOTTOMRIGHT", x = 0, y = 0 },
  }

  cfg.cooldown = {
    spacing         = 0,
  }

  cfg.font = STANDARD_TEXT_FONT

  --adjust the oneletter abbrev?
  cfg.adjustOneletterAbbrev = true
  
  --scale of the consolidated tooltip
  cfg.consolidatedTooltipScale = 1.2
  
  --combine buff and debuff frame - should buffs and debuffs be displayed in one single frame?
  --if you disable this it is intended that you unlock the buff and debuffs and move them apart!
  cfg.combineBuffsAndDebuffs = false

-- buff frame settings

  cfg.buffFrame = {
    pos             = { a1 = "TOPRIGHT", af = "Minimap", a2 = "TOPLEFT", x = -35, y = 0 },
    gap             = 30, --gap between buff and debuff rows
    userplaced      = true, --want to place the bar somewhere else?
    rowSpacing      = 10,
    colSpacing      = 7,
    buttonsPerRow   = 10,
    button = {
      size              = 28,
    },
    icon = {
      padding           = -2,
    },
    border = {
      texture           = "Interface\\AddOns\\Uber UI\\textures\\gloss",
      color             = { r = 0.4, g = 0.35, b = 0.35, },
      classcolored      = false,
    },
    background = {
      show              = true,   --show backdrop
      edgeFile          = "Interface\\AddOns\\Uber UI\\textures\\outer_shadow",
      color             = { r = 0, g = 0, b = 0, a = 0.9},
      classcolored      = true,
      inset             = 6,
      padding           = 4,
    },
    duration = {
      font              = STANDARD_TEXT_FONT,
      size              = 11,
      pos               = { a1 = "BOTTOM", x = 0, y = 0 },
    },
    count = {
      font              = STANDARD_TEXT_FONT,
      size              = 11,
      pos               = { a1 = "TOPRIGHT", x = 0, y = 0 },
    },
  }
  
-- debuff frame settings

  cfg.debuffFrame = {    pos             = { a1 = "TOPRIGHT", af = "Minimap", a2 = "TOPLEFT", x = -35, y = -85 },
    gap             = 10, --gap between buff and debuff rows
    userplaced      = true, --want to place the bar somewhere else?
    rowSpacing      = 10,
    colSpacing      = 7,
    buttonsPerRow   = 10,
    button = {
      size              = 28,
    },
    icon = {
      padding           = -2,
    },
    border = {
      texture           = "Interface\\AddOns\\Uber UI\\textures\\gloss",
      color             = { r = 0.4, g = 0.35, b = 0.35, },
      classcolored      = false,
    },
    background = {
      show              = true,   --show backdrop
      edgeFile          = "Interface\\AddOns\\Uber UI\\textures\\outer_shadow",
      color             = { r = 0, g = 0, b = 0, a = 0.9},
      classcolored      = true,
      inset             = 6,
      padding           = 4,
    },
    duration = {
      font              = STANDARD_TEXT_FONT,
      size              = 11,
      pos               = { a1 = "BOTTOM", x = 0, y = 0 },
    },
    count = {
      font              = STANDARD_TEXT_FONT,
      size              = 11,
      pos               = { a1 = "TOPRIGHT", x = 0, y = 0 },
    },
  }

  -----------------------------
  -- SLASH COMMAND
  -----------------------------

SlashCmdList.UBERUI = function(msg)
    msg = msg:lower()
    if msg == "options" then
      ns.ShowOptions()
    else
      InterfaceOptionsFrame_OpenToCategory(addon)
      InterfaceOptionsFrame_OpenToCategory(addon)
    end
end
SLASH_UBERUI1 = "/uui"

  -----------------------------
  -- HANDOVER
  -----------------------------

  --hand the config to the namespace for usage in other lua files (remember: those lua files must be called after the cfg.lua)
  ns.cfg = cfg
