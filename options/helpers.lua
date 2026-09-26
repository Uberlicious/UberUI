--[[--------------------------------------------------------------------
	Uber UI options -- shared helpers
	Used by the per-page files in options\ (general, unitframes, ...);
	options\register.lua builds the pages in order.
----------------------------------------------------------------------]]

local addon, ns = ...
local opt = {}
ns.options = opt

local function commitValue()
    UberUI:Save();
end
opt.commitValue = commitValue

-- A page is { category, layout }. Pages are created in register.lua.
function opt.Header(page, text)
    page.layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text));
end

-- Registers a setting the same way this addon always has (RegisterAddOnSetting
-- with GetValue/SetValue/Commit overridden). o: variable, name, db (uuidb
-- sub-table name), field, default, onChange(value); optional get()/set(value)
-- for values stored in a different shape; regKey/regTable override what's
-- passed to RegisterAddOnSetting (defaults: field, uuidb[db]). Variable names
-- and saved fields must never change -- they're what players' saved settings
-- are keyed on.
local function RegisterSetting(page, o, varType)
    local function getValue()
        if o.get then return o.get() end
        local t = uuidb[o.db];
        if t and t[o.field] ~= nil then
            return t[o.field];
        end
        return o.default;
    end

    local function setValue(self, value)
        if o.set then
            o.set(value);
        else
            uuidb[o.db][o.field] = value;
        end
        if o.onChange then o.onChange(value) end
        -- This override replaces SettingMixin:SetValue, which is what fires
        -- the setting's value-changed event. Dependent rows (DependsOn /
        -- SetParentInitializer) only re-check their greyed-out state on that
        -- event, so fire it ourselves.
        if self and self.TriggerValueChanged then
            self:TriggerValueChanged(value);
        end
    end

    local setting = Settings.RegisterAddOnSetting(page.category, o.variable, o.regKey or o.field,
        o.regTable or uuidb[o.db], varType, o.name, o.default);
    setting.GetValue, setting.SetValue, setting.Commit = getValue, setValue, commitValue;
    return setting;
end

function opt.AddCheckbox(page, o)
    local setting = RegisterSetting(page, o, Settings.VarType.Boolean);
    return Settings.CreateCheckbox(page.category, setting, o.tooltip), setting;
end

-- o additionally: min, max, step, format(value) -> label text
function opt.AddSlider(page, o)
    local setting = RegisterSetting(page, o, Settings.VarType.Number);
    local options = Settings.CreateSliderOptions(o.min, o.max, o.step);
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, o.format);
    return Settings.CreateSlider(page.category, setting, options, o.tooltip), setting;
end

-- Greys out (and indents) a dependent setting while its parent checkbox is off.
function opt.DependsOn(childInitializer, parentInitializer, isEnabled)
    if childInitializer and parentInitializer and childInitializer.SetParentInitializer then
        childInitializer:SetParentInitializer(parentInitializer, isEnabled);
    end
end

-- Generic dropdown -----------------------------------------------------------

-- o: variable, name, tooltip, default, values = { {value, label}, ... },
-- get() / set(value), onChange(value). Values are stored however get/set
-- decide -- the dropdown's own registration only uses a throwaway proxy.
function opt.AddDropdown(page, o)
    o.regKey = o.regKey or o.variable;
    o.regTable = o.regTable or { [o.variable] = o.get and o.get() or o.default };
    local setting = RegisterSetting(page, o, Settings.VarType.String);
    local function GetOptions()
        local container = Settings.CreateControlTextContainer();
        for _, v in ipairs(o.values) do
            container:Add(v[1], v[2]);
        end
        return container:GetData();
    end
    local initializer = Settings.CreateDropdownInitializer(setting, GetOptions, o.tooltip);
    page.layout:AddInitializer(initializer);
    return initializer, setting;
end

-- Bar texture checkbox + dropdown pairs --------------------------------------

local function GetBarTextureOptionsWithTextures()
    local container = Settings.CreateControlTextContainer();
    for bar in pairs(UberUI:GetDefaults().statusbars) do
        bar = gsub(bar, "_", " ");
        container:Add(bar, bar);
    end
    local options = container:GetData();
    local statusbars = UberUI:GetDefaults().statusbars
    if statusbars then
        for _, option in ipairs(options) do
            local textureName = gsub(option.value, " ", "_")
            local texturePath = statusbars[textureName]
            if texturePath then
                local iconString = CreateTextureMarkup(texturePath, 64, 16, 60, 12, 0, 1, 0, 1)
                option.label = iconString .. " " .. option.label
            end
        end
    end
    return options
end

-- opts: dbTable, cbVariable/cbName/cbTooltip/cbField, ddVariable/ddName/ddTooltip/ddField,
-- cbOnChange()/ddOnChange(value) refresh callbacks
function opt.AddBarTextureSetting(page, opts)
    local dbTable = opts.dbTable;
    local cbfield, ddfield = opts.cbField, opts.ddField;
    local cbOnChange = opts.cbOnChange or function() end;
    local ddOnChange = opts.ddOnChange or function() end;

    -- checkbox
    local cbdefaultValue = false;
    local function cbgetValue()
        if (dbTable) then return dbTable[cbfield]
        else return cbdefaultValue end
    end
    local function cbsetValue(self, value)
        dbTable[cbfield] = value;
        cbOnChange();
    end
    local cbsetting = Settings.RegisterAddOnSetting(page.category, opts.cbVariable, cbfield, dbTable,
        Settings.VarType.Boolean, opts.cbName, cbdefaultValue)
    cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

    -- drop down
    local dddefaultValue = "Blizzard";
    local function ddgetValue()
        if (dbTable) then
            local val = dbTable[ddfield];
            return val and gsub(val, "_", " ") or dddefaultValue;
        else
            return dddefaultValue;
        end
    end
    local function ddsetValue(self, value)
        value = gsub(value, " ", "_");
        dbTable[ddfield] = value;
        ddOnChange(value);
    end
    local proxy = { [ddfield] = ddgetValue() }
    local ddsetting = Settings.RegisterAddOnSetting(page.category, opts.ddVariable, ddfield, proxy,
        Settings.VarType.String, opts.ddName, dddefaultValue)
    ddsetting.GetValue, ddsetting.SetValue, ddsetting.Commit = ddgetValue, ddsetValue, commitValue;

    local cbdd = CreateSettingsCheckboxDropdownInitializer(cbsetting, opts.cbName, opts.cbTooltip, ddsetting,
        GetBarTextureOptionsWithTextures, opts.ddName, opts.ddTooltip);
    page.layout:AddInitializer(cbdd);
    return cbsetting, ddsetting;
end

-- Per-location aura rows -------------------------------------------------------

-- Each location's look is still stored as the two original style strings,
-- aurastyle_<loc>buffs / aurastyle_<loc>debuffs ("both" | "border" | "zoom" |
-- "none"), which are exactly the four combinations of two independent
-- choices -- Zoom on/off x Dark border on/off -- so the controls below just
-- read and write those halves. "none" (zoom off + Blizzard border) is also
-- where a location hands its auras back to Blizzard's own display, same as
-- before. Nothing is migrated; existing saved looks show up unchanged.
local function StyleParts(key, default)
    local s = (uuidb.general and uuidb.general[key]) or default;
    return (s == "both" or s == "zoom"), (s == "both" or s == "border");
end

local function ComposeStyle(zoom, dark)
    if zoom and dark then return "both" end
    if dark then return "border" end
    if zoom then return "zoom" end
    return "none";
end

local function SetStylePart(key, default, zoom, dark)
    local curZoom, curDark = StyleParts(key, default);
    if zoom == nil then zoom = curZoom end
    if dark == nil then dark = curDark end
    uuidb.general[key] = ComposeStyle(zoom, dark);
end

-- o: loc ("player", "target", ...), label ("Target"), suffix (variable-name
-- suffix, e.g. "Target"), buffKey/debuffKey (aurastyle_* fields), refresh(),
-- buffName/debuffName (default "<label> Buff Border" / "... Debuff Border"),
-- buffNative/debuffNative (label of the Blizzard choice: "None" /
-- "Dispel Color"), buffTooltip/debuffTooltip, zoomTooltip, shapeTooltip,
-- positionDetail, squareVarSuffix (thickness variable suffix; "" for
-- Player's original name).
function opt.AddAuraOptions(page, o)
    local SBkeys = UberUI.squareborders.Keys(o.loc);
    local refresh = o.refresh;
    local BUFF_DEFAULT, DEBUFF_DEFAULT = "both", "zoom";

    local handBackNote = "\n\nWith Zoom off and the Blizzard border choice, Uber UI leaves these auras entirely to Blizzard.";

    opt.AddCheckbox(page, {
        variable = "auraZoom" .. o.suffix, name = o.label .. " Zoom Icons",
        tooltip = o.zoomTooltip or ("Zoom " .. o.label .. " aura icons slightly to crop off Blizzard's built-in icon edge." .. handBackNote),
        default = true,
        regKey = "auraZoom" .. o.suffix, regTable = {},
        get = function()
            local bz = StyleParts(o.buffKey, BUFF_DEFAULT);
            local dz = StyleParts(o.debuffKey, DEBUFF_DEFAULT);
            return bz or dz;
        end,
        set = function(value)
            SetStylePart(o.buffKey, BUFF_DEFAULT, value, nil);
            SetStylePart(o.debuffKey, DEBUFF_DEFAULT, value, nil);
        end,
        onChange = refresh,
    });

    opt.AddDropdown(page, {
        variable = "auraBuffBorder" .. o.suffix, name = o.buffName or (o.label .. " Buff Border"),
        tooltip = o.buffTooltip or ("Border on " .. o.label .. " buffs. Blizzard doesn't draw one on buffs, so \"" .. (o.buffNative or "None") .. "\" is its default look." .. handBackNote),
        default = "dark",
        values = { { "dark", "Dark" }, { "blizzard", o.buffNative or "None" } },
        get = function()
            local _, dark = StyleParts(o.buffKey, BUFF_DEFAULT);
            return dark and "dark" or "blizzard";
        end,
        set = function(value) SetStylePart(o.buffKey, BUFF_DEFAULT, nil, value == "dark") end,
        onChange = refresh,
    });

    opt.AddDropdown(page, {
        variable = "auraDebuffBorder" .. o.suffix, name = o.debuffName or (o.label .. " Debuff Border"),
        tooltip = o.debuffTooltip or ("Border on " .. o.label .. " debuffs: Blizzard's dispel-type color (Magic, Curse, Disease, Poison, Bleed; red when there's no type), or the darkness color." .. handBackNote),
        default = "blizzard",
        values = { { "dark", "Dark" }, { "blizzard", o.debuffNative or "Dispel Color" } },
        get = function()
            local _, dark = StyleParts(o.debuffKey, DEBUFF_DEFAULT);
            return dark and "dark" or "blizzard";
        end,
        set = function(value) SetStylePart(o.debuffKey, DEBUFF_DEFAULT, nil, value == "dark") end,
        onChange = refresh,
    });

    local shapeInit = opt.AddDropdown(page, {
        variable = "auraBorderShape" .. o.suffix, name = o.label .. " Border Shape",
        tooltip = o.shapeTooltip or ("Rounded uses Blizzard's border art. Square draws a flat border of exact pixel thickness in the same colors.\n\nHas no effect on auras Uber UI has handed back to Blizzard (Zoom off + Blizzard border)."),
        default = "rounded",
        values = { { "rounded", "Rounded" }, { "square", "Square" } },
        get = function()
            return (uuidb.general and uuidb.general[SBkeys[1]]) and "square" or "rounded";
        end,
        set = function(value) uuidb.general[SBkeys[1]] = (value == "square") end,
        onChange = refresh,
    });
    local function IsSquare() return uuidb.general and uuidb.general[SBkeys[1]] end

    opt.DependsOn(opt.AddSlider(page, {
        variable = "squareAuraBorderThickness" .. (o.squareVarSuffix or o.suffix),
        name = o.label .. " Border Thickness",
        tooltip = "Thickness of the square " .. o.label .. " aura border, in screen pixels.",
        db = "general", field = SBkeys[2], default = 2,
        min = 1, max = 8, step = 1,
        onChange = refresh,
    }), shapeInit, IsSquare);

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "auraBorderPosition" .. o.suffix, name = o.label .. " Border Position",
        tooltip = "Inside Icon draws the square border over the icon's outer edge, so icons keep their size. Outside Icon draws it around the icon instead." .. (o.positionDetail or ""),
        default = "inside",
        values = { { "inside", "Inside Icon" }, { "outside", "Outside Icon" } },
        get = function()
            return (uuidb.general and uuidb.general[SBkeys[3]] == false) and "outside" or "inside";
        end,
        set = function(value) uuidb.general[SBkeys[3]] = (value ~= "outside") end,
        onChange = refresh,
    }), shapeInit, IsSquare);
end

-- All Auras: one-time apply to every location ---------------------------------

-- Every aura location, with its style keys and live-refresh call. Keep in
-- sync with the per-page AddAuraOptions calls.
local AURA_LOCATIONS = {
    { loc = "player",  buffKey = "aurastyle_playerbuffs",  debuffKey = "aurastyle_playerdebuffs",
      refresh = function() if UberUI.buffsandauras then UberUI.buffsandauras:Refresh() end end },
    { loc = "target",  buffKey = "aurastyle_targetbuffs",  debuffKey = "aurastyle_targetdebuffs",
      refresh = function() if UberUI.targetframes then UberUI.targetframes:UpdateAuras() end end },
    { loc = "focus",   buffKey = "aurastyle_focusbuffs",   debuffKey = "aurastyle_focusdebuffs",
      refresh = function() if UberUI.focusframes and UberUI.focusframes.UpdateAuras then UberUI.focusframes:UpdateAuras() end end },
    { loc = "boss",    buffKey = "aurastyle_bossbuffs",    debuffKey = "aurastyle_bossdebuffs",
      refresh = function() if UberUI.bossframes then UberUI.bossframes:UpdateAllAuras() end end },
    { loc = "party",   buffKey = "aurastyle_partybuffs",   debuffKey = "aurastyle_partydebuffs",
      refresh = function() if UberUI.partyframes and UberUI.partyframes.RefreshAuraStyle then UberUI.partyframes:RefreshAuraStyle() end end },
    { loc = "compact", buffKey = "aurastyle_compactbuffs", debuffKey = "aurastyle_compactdebuffs",
      refresh = function() if UberUI.compactauras and UberUI.compactauras.Refresh then UberUI.compactauras:Refresh() end end },
    { loc = "arena",   buffKey = "aurastyle_arenabuffs",   debuffKey = "aurastyle_arenadebuffs",
      refresh = function() if UberUI.arenaframes then UberUI.arenaframes:RefreshAuraStyle() end end },
};

-- Copies chosen aura parts into every location's own settings. parts: any of
-- zoom ("on"/"off"), buffborder / debuffborder ("dark"/"blizzard"), shape
-- ("rounded"/"square"), thickness ("1".."8"), position ("inside"/"outside");
-- anything missing or "keep" is left alone. A copy, not a live override:
-- afterwards each location can still be changed on its own.
function opt.ApplyAuraParts(parts)
    local g = uuidb.general;
    if not g or not parts then return end
    local zoom, buff, debuff = parts.zoom, parts.buffborder, parts.debuffborder;
    local shape, position = parts.shape, parts.position;
    local thickness = tonumber(parts.thickness);

    -- true / false / nil (= leave unchanged). Not written as
    -- `(v == on and true) or (v == off and false) or nil`: in Lua that turns
    -- the false case into nil, which silently dropped every "off" choice.
    local function Choice(v, onValue, offValue)
        if v == onValue then return true end
        if v == offValue then return false end
        return nil;
    end
    local zoomValue = Choice(zoom, "on", "off");
    local buffDark = Choice(buff, "dark", "blizzard");
    local debuffDark = Choice(debuff, "dark", "blizzard");
    for _, L in ipairs(AURA_LOCATIONS) do
        local keys = UberUI.squareborders.Keys(L.loc);
        if zoomValue ~= nil or buffDark ~= nil then
            SetStylePart(L.buffKey, "both", zoomValue, buffDark);
        end
        if zoomValue ~= nil or debuffDark ~= nil then
            SetStylePart(L.debuffKey, "zoom", zoomValue, debuffDark);
        end
        if shape == "square" or shape == "rounded" then g[keys[1]] = (shape == "square") end
        if thickness then g[keys[2]] = math.max(1, math.min(8, math.floor(thickness))) end
        if position == "inside" or position == "outside" then g[keys[3]] = (position == "inside") end
    end

    for _, L in ipairs(AURA_LOCATIONS) do
        pcall(L.refresh);
    end
    UberUI:Save();
end

-- All Auras section: one-shot actions, not settings. Picking a value
-- immediately copies just that part into every location (opt.ApplyAuraParts)
-- and the dropdown snaps back to "Set All..." -- the choice is never stored
-- and nothing ever reads it again.
function opt.AddAllAurasOptions(page)
    local NONE = { "none", "Set All..." };

    local function Action(part, variable, name, tooltip, values)
        local list = { NONE };
        local labels = {};
        for _, v in ipairs(values) do
            list[#list + 1] = v;
            labels[v[1]] = v[2];
        end
        local setting;
        local _, s = opt.AddDropdown(page, {
            variable = variable, name = name, default = "none", values = list,
            tooltip = tooltip .. "\n\n|cffff4040Picking a value immediately sets it on every aura location (Player, Target, Focus, Boss, Party, Compact Raid/Party, Arena), overwriting each one's own setting.|r This is a one-time change, not a lock: each location can still be changed on its own page afterwards.",
            get = function() return "none" end,
            set = function(value)
                if value == "none" then return end
                opt.ApplyAuraParts({ [part] = value });
                print("|cff33ff99Uber UI|r: " .. name:gsub("^All Auras: ", "") .. " set to "
                    .. (labels[value] or value) .. " on every aura location.");
                -- Snap the dropdown back to "Set All..." (deferred: we're
                -- inside the setting's own SetValue right now).
                C_Timer.After(0, function()
                    if setting then setting:SetValue("none") end
                end);
            end,
        });
        setting = s;
    end

    Action("zoom", "auraAllZoom", "All Auras: Zoom Icons",
        "Zoom every aura location's icons.",
        { { "on", "On" }, { "off", "Off" } });
    Action("buffborder", "auraAllBuffBorder", "All Auras: Buff Border",
        "Buff border for every aura location. \"None\" is Blizzard's look (no border on buffs).",
        { { "dark", "Dark" }, { "blizzard", "None" } });
    Action("debuffborder", "auraAllDebuffBorder", "All Auras: Debuff Border",
        "Debuff border for every aura location. \"Dispel Color\" is Blizzard's look (red on the arena CC tracker).",
        { { "dark", "Dark" }, { "blizzard", "Dispel Color" } });
    Action("shape", "auraAllShape", "All Auras: Border Shape",
        "Border shape for every aura location.",
        { { "rounded", "Rounded" }, { "square", "Square" } });
    local px = {};
    for i = 1, 8 do px[i] = { tostring(i), i .. " px" } end
    Action("thickness", "auraAllThickness", "All Auras: Border Thickness",
        "Square border thickness for every aura location.",
        px);
    Action("position", "auraAllPosition", "All Auras: Border Position",
        "Square border position for every aura location.",
        { { "inside", "Inside Icon" }, { "outside", "Outside Icon" } });
end

-- Shared text / refresh callbacks ---------------------------------------------

opt.RELOAD_NOTE = "\n\n|cffff0000Requires reload to properly attach \n\nBlizzard option is not accurate until reload";

function opt.DispelTooltip(frameLabel)
    return "Show a white border on enemy " .. frameLabel .. " buffs your class can Purge, Dispel or Spellsteal, on top of whichever "
        .. frameLabel .. " Buff Border is chosen above (square when Border Shape is Square). Matches stock Blizzard behavior: only shown if your class actually has a way to remove it.";
end

function opt.RefreshPlayerAuras()
    if UberUI.buffsandauras then
        UberUI.buffsandauras:Refresh();
    end
end
