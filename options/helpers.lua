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

-- Registers a setting (RegisterAddOnSetting with GetValue/SetValue/Commit
-- overridden). o: variable, name, db (uuidb sub-table), field, default,
-- onChange(value); optional get()/set(value), regKey/regTable. Variable names
-- and saved fields must never change: saved settings are keyed on them.
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
        opt.RefreshPreviews();
        -- Replacing SetValue skips its value-changed event, which dependent
        -- rows re-check their greyed-out state on, so fire it ourselves.
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

-- Color swatch; stored as an "AARRGGBB" hex string.
function opt.AddColorSwatch(page, o)
    local setting = RegisterSetting(page, o, Settings.VarType.String);
    local initializer = Settings.CreateColorSwatchInitializer(setting, nil, o.tooltip);
    page.layout:AddInitializer(initializer);
    return initializer, setting;
end

-- Greys out (and indents) a dependent setting while its parent checkbox is off.
function opt.DependsOn(childInitializer, parentInitializer, isEnabled)
    if childInitializer and parentInitializer and childInitializer.SetParentInitializer then
        childInitializer:SetParentInitializer(parentInitializer, isEnabled);
    end
end

-- Preview row ----------------------------------------------------------------

-- Every preview frame made so far; redrawn after any setting changes (a
-- preview can depend on settings from other sections or pages).
opt.previews = {};
function opt.RefreshPreviews()
    for _, p in ipairs(opt.previews) do
        if p:IsVisible() and p.Update then opt.RunPreview(p) end
    end
end

-- Redraws a preview; a failure goes to the error popup (once per message)
-- rather than leaving a half-drawn preview with no explanation.
function opt.RunPreview(p)
    local ok, err = pcall(p.Update, p)
    if not ok then UberUI:ReportError("Settings preview", err) end
end

-- A list row with a label and a custom preview frame in the control column.
-- o: name, tooltip, height, create(parent) -> frame (made once, reused; it
-- should redraw itself OnShow). The settings list pools its rows, so the
-- frame moves to whichever row is showing this entry and is hidden when that
-- row is recycled.
function opt.AddPreview(page, o)
    local initializer = Settings.CreateElementInitializer("SettingsListElementTemplate",
        { name = o.name, tooltip = o.tooltip });
    local preview
    initializer.GetExtent = function() return o.height or 45 end
    -- The bare template never runs SettingsListElementMixin's OnLoad (only
    -- its subclasses call it), so its Init/Release can't be used; the label
    -- and tooltip are set up here instead.
    initializer.InitFrame = function(self, frame)
        frame.Text:SetFontObject("GameFontNormal");
        frame.Text:SetText(o.name);
        frame.Text:ClearAllPoints();
        frame.Text:SetPoint("LEFT", 37, 0);
        frame.Text:SetPoint("RIGHT", frame, "CENTER", -85, 0);
        frame.Text:Show();
        if frame.NewFeature then frame.NewFeature:Hide() end
        if frame.Tooltip and DefaultTooltipMixin then
            DefaultTooltipMixin.SetTooltipFunc(frame.Tooltip, function()
                Settings.InitTooltip(o.name, o.tooltip);
            end);
        end
        if not preview then
            preview = o.create(frame);
            if not preview then return end
            opt.previews[#opt.previews + 1] = preview;
        end
        preview:SetParent(frame);
        preview:ClearAllPoints();
        preview:SetPoint("LEFT", frame, "CENTER", -80, 0);
        preview:Show();
        if preview.Update then opt.RunPreview(preview) end
    end
    initializer.Resetter = function(self, frame)
        if preview and preview:GetParent() == frame then preview:Hide() end
    end
    page.layout:AddInitializer(initializer);
    return initializer;
end

-- Generic dropdown -----------------------------------------------------------

-- o: variable, name, tooltip, default, values = { {value, label}, ... },
-- get() / set(value), onChange(value).
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

-- Ours plus every LibSharedMedia statusbar texture, with previews; rebuilt
-- on open so late-registered textures show up.
local function GetBarTextureOptionsWithTextures()
    local container = Settings.CreateControlTextContainer();
    local choices = UberUI:GetBarTextureChoices();
    for _, choice in ipairs(choices) do
        container:Add(choice.name, choice.name);
    end
    local options = container:GetData();
    for i, option in ipairs(options) do
        local path = choices[i] and choices[i].path
        if path then
            option.label = CreateTextureMarkup(path, 64, 16, 60, 12, 0, 1, 0, 1) .. " " .. option.label
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

    local cbdefaultValue = false;
    local function cbgetValue()
        if (dbTable) then return dbTable[cbfield]
        else return cbdefaultValue end
    end
    local function cbsetValue(self, value)
        dbTable[cbfield] = value;
        cbOnChange();
        opt.RefreshPreviews();
    end
    local cbsetting = Settings.RegisterAddOnSetting(page.category, opts.cbVariable, cbfield, dbTable,
        Settings.VarType.Boolean, opts.cbName, cbdefaultValue)
    cbsetting.GetValue, cbsetting.SetValue, cbsetting.Commit = cbgetValue, cbsetValue, commitValue;

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
        opt.RefreshPreviews();
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

-- A location's look is stored as aurastyle_<loc>buffs / debuffs ("both" |
-- "border" | "zoom" | "none"): the four combinations of Zoom on/off x Dark
-- border on/off, which the controls below read and write. "none" hands the
-- location's auras back to Blizzard's display.
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

-- o: loc, label, suffix (variable-name suffix), buffKey/debuffKey,
-- refresh(), buffName/debuffName, buffNative/debuffNative (label of the
-- Blizzard choice), buffTooltip/debuffTooltip, zoomTooltip, shapeTooltip,
-- positionDetail, squareVarSuffix ("" for Player's original name).
function opt.AddAuraOptions(page, o)
    local SBkeys = UberUI.squareborders.Keys(o.loc);
    local refresh = o.refresh;
    local BUFF_DEFAULT, DEBUFF_DEFAULT = "both", "zoom";

    if opt.AddAuraPreview then opt.AddAuraPreview(page, o) end

    local handBackNote = "\n\nWith Zoom off and the Blizzard border choice, Uber UI leaves these auras entirely to Blizzard.";

    opt.AddCheckbox(page, {
        variable = "auraZoom" .. o.suffix, name = "Zoom Icons",
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
        variable = "auraBuffBorder" .. o.suffix, name = o.buffName or "Buff Border",
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
        variable = "auraDebuffBorder" .. o.suffix, name = o.debuffName or "Debuff Border",
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
        variable = "auraBorderShape" .. o.suffix, name = "Border Shape",
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
        name = "Border Thickness",
        tooltip = "Thickness of the square " .. o.label .. " aura border, in screen pixels.",
        db = "general", field = SBkeys[2], default = 1,
        min = 1, max = 8, step = 1,
        onChange = refresh,
    }), shapeInit, IsSquare);

    opt.DependsOn(opt.AddDropdown(page, {
        variable = "auraBorderPosition" .. o.suffix, name = "Border Position",
        tooltip = "Inside Icon draws the square border over the icon's outer edge, so icons keep their size. Outside Icon draws it around the icon instead." .. (o.positionDetail or ""),
        default = "inside",
        values = { { "inside", "Inside Icon" }, { "outside", "Outside Icon" } },
        get = function()
            return (uuidb.general and uuidb.general[SBkeys[3]] == false) and "outside" or "inside";
        end,
        set = function(value) uuidb.general[SBkeys[3]] = (value ~= "outside") end,
        onChange = refresh,
    }), shapeInit, IsSquare);

    opt.AddAuraTextOptions(page, o);
end

-- Per-location aura text rows -------------------------------------------------

-- Which aura text each location can style (auratext_<loc>_*, read by
-- aurakit.TextSettings). Arena's trackers have no stack or duration text.
local TEXT_CAPS = {
    player = { duration = true, center = true },
    target = { duration = true },
    focus = { duration = true },
    boss = {},
    party = {},
    compact = { duration = true },
    nameplate = { duration = true },
};

local STACK_ANCHOR_VALUES = {
    { "TOPLEFT", "Top Left" }, { "TOP", "Top" }, { "TOPRIGHT", "Top Right" },
    { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" },
    { "BOTTOMLEFT", "Bottom Left" }, { "BOTTOM", "Bottom" }, { "BOTTOMRIGHT", "Bottom Right" },
};

local function Percent(value) return string.format("%d%%", value) end

-- o: the AddAuraOptions table; o.textParent / o.textParentOn grey the rows
-- out while the location's auras aren't Uber UI's (nameplates).
function opt.AddAuraTextOptions(page, o)
    local caps = TEXT_CAPS[o.loc];
    if not caps then return end
    local k = "auratext_" .. o.loc .. "_";
    local refresh = o.refresh;
    -- Only the initializer: the Add* helpers also return their setting.
    local function Gate(init)
        if o.textParent then
            opt.DependsOn(init, o.textParent, o.textParentOn);
        end
        return init;
    end

    if caps.duration then
        Gate(opt.AddSlider(page, {
            variable = "auraDurationSize" .. o.suffix, name = "Duration Text Size",
            tooltip = "Size of the time-left text on " .. o.label .. " auras, relative to its normal size."
                .. (o.loc == "player" and "\n\nThe text itself stays Blizzard's (e.g. \"1 m\")." or "")
                .. ((o.loc == "target" or o.loc == "focus" or o.loc == "compact") and "\n\nOnly shown while Aura Duration Text is on." or ""),
            db = "general", field = k .. "durationsize", default = 100,
            min = 50, max = 200, step = 5, format = Percent,
            onChange = refresh,
        }));
    end

    local centerInit;
    if caps.center then
        centerInit = Gate(opt.AddCheckbox(page, {
            variable = "auraCenterDuration" .. o.suffix, name = "Duration Inside Icon",
            tooltip = "Show the time left in the middle of each " .. o.label .. " aura icon instead of under it (Blizzard's text, e.g. \"1 m\"), and pack the rows tighter, since the space under the icons isn't needed.\n\nBlizzard's buff frame box in Edit Mode keeps its usual size.",
            db = "general", field = k .. "centerduration", default = false,
            onChange = refresh,
        }));
    end

    if caps.duration then
        local onlyWhenShown = (o.loc == "target" or o.loc == "focus" or o.loc == "compact")
            and "\n\nOnly shown while Aura Duration Text is on." or "";

        -- Player's text is Blizzard's, which already shows every duration.
        if o.loc ~= "player" then
            Gate(opt.AddCheckbox(page, {
                variable = "auraOverMinute" .. o.suffix, name = "Show Durations Over a Minute",
                tooltip = "Keep the time left on " .. o.label .. " auras showing past a minute, as minutes (\"2m\") and hours (\"1h\"). When off, it's whole seconds and only appears in the last minute, like Blizzard's nameplates." .. onlyWhenShown,
                db = "general", field = k .. "overminute", default = o.loc == "compact",
                onChange = refresh,
            }));
        end

        local whiteInit = opt.AddCheckbox(page, {
            variable = "auraWhiteText" .. o.suffix, name = "White Outlined Text",
            tooltip = "Time-left text on " .. o.label .. " auras in white with a black outline, instead of "
                .. (o.loc == "player" and "Blizzard's yellow text (e.g. \"1 m\"). Uses Uber UI's format: whole seconds, then minutes (\"2m\") and hours (\"1h\").\n\nOnly used while Duration Inside Icon is on."
                    or "the nameplate duration colors (normal and expiring).")
                .. onlyWhenShown,
            db = "general", field = k .. "whitetext", default = true,
            onChange = refresh,
        });
        if centerInit then
            opt.DependsOn(whiteInit, centerInit, function()
                return uuidb.general and uuidb.general[k .. "centerduration"] == true
            end);
        else
            Gate(whiteInit);
        end
    end

    Gate(opt.AddSlider(page, {
        variable = "auraStackSize" .. o.suffix, name = "Stack Text Size",
        tooltip = "Size of the stack count on " .. o.label .. " auras, relative to its normal size.",
        db = "general", field = k .. "stacksize", default = 100,
        min = 50, max = 200, step = 5, format = Percent,
        onChange = refresh,
    }));

    Gate(opt.AddDropdown(page, {
        variable = "auraStackAnchor" .. o.suffix, name = "Stack Text Position",
        tooltip = "Where the stack count sits on " .. o.label .. " auras. Bottom Right is Blizzard's spot.",
        default = "BOTTOMRIGHT",
        values = STACK_ANCHOR_VALUES,
        get = function()
            local v = uuidb.general and uuidb.general[k .. "stackanchor"];
            for _, a in ipairs(STACK_ANCHOR_VALUES) do
                if a[1] == v then return v end
            end
            return "BOTTOMRIGHT";
        end,
        set = function(value) uuidb.general[k .. "stackanchor"] = value end,
        onChange = refresh,
    }));

    Gate(opt.AddSlider(page, {
        variable = "auraStackX" .. o.suffix, name = "Stack Text X Offset",
        tooltip = "Moves the stack count left (negative) or right (positive) from its position.",
        db = "general", field = k .. "stackx", default = 0,
        min = -10, max = 10, step = 1,
        onChange = refresh,
    }));

    Gate(opt.AddSlider(page, {
        variable = "auraStackY" .. o.suffix, name = "Stack Text Y Offset",
        tooltip = "Moves the stack count down (negative) or up (positive) from its position.",
        db = "general", field = k .. "stacky", default = 0,
        min = -10, max = 10, step = 1,
        onChange = refresh,
    }));
end

-- All Auras: one-time apply to every location ---------------------------------

-- Every aura location; keep in sync with the per-page AddAuraOptions calls.
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
    { loc = "nameplate", buffKey = "aurastyle_nameplatebuffs", debuffKey = "aurastyle_nameplatedebuffs",
      refresh = function() if UberUI.nameplateauras then UberUI.nameplateauras:RefreshStyle() end end },
};

-- Copies chosen aura parts into every location's settings (a one-time copy,
-- not a live override). parts: zoom ("on"/"off"), buffborder / debuffborder
-- ("dark"/"blizzard"), shape ("rounded"/"square"), thickness ("1".."8"),
-- position ("inside"/"outside"); missing or "keep" is left alone.
function opt.ApplyAuraParts(parts)
    local g = uuidb.general;
    if not g or not parts then return end
    local zoom, buff, debuff = parts.zoom, parts.buffborder, parts.debuffborder;
    local shape, position = parts.shape, parts.position;
    local thickness = tonumber(parts.thickness);

    -- true / false / nil (= unchanged). Not `(v == on and true) or
    -- (v == off and false) or nil`, which turns false into nil.
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
    opt.RefreshPreviews();
    UberUI:Save();
end

-- All Auras: one-shot actions. Picking a value copies that part everywhere
-- and the dropdown snaps back to "Set All..." (never stored).
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
            tooltip = tooltip .. "\n\n|cffff4040Picking a value immediately sets it on every aura location (Player, Target, Focus, Boss, Party, Compact Raid/Party, Arena, Nameplates), overwriting each one's own setting.|r This is a one-time change, not a lock: each location can still be changed on its own page afterwards.",
            get = function() return "none" end,
            set = function(value)
                if value == "none" then return end
                opt.ApplyAuraParts({ [part] = value });
                print("|cff33ff99Uber UI|r: " .. name .. " set to "
                    .. (labels[value] or value) .. " on every aura location.");
                -- Deferred: we're inside the setting's own SetValue.
                C_Timer.After(0, function()
                    if setting then setting:SetValue("none") end
                end);
            end,
        });
        setting = s;
    end

    Action("zoom", "auraAllZoom", "Zoom Icons",
        "Zoom every aura location's icons.",
        { { "on", "On" }, { "off", "Off" } });
    Action("buffborder", "auraAllBuffBorder", "Buff Border",
        "Buff border for every aura location. \"None\" is Blizzard's look (no border on buffs).",
        { { "dark", "Dark" }, { "blizzard", "None" } });
    Action("debuffborder", "auraAllDebuffBorder", "Debuff Border",
        "Debuff border for every aura location. \"Dispel Color\" is Blizzard's look (red on the arena CC tracker).",
        { { "dark", "Dark" }, { "blizzard", "Dispel Color" } });
    Action("shape", "auraAllShape", "Border Shape",
        "Border shape for every aura location.",
        { { "rounded", "Rounded" }, { "square", "Square" } });
    local px = {};
    for i = 1, 8 do px[i] = { tostring(i), i .. " px" } end
    Action("thickness", "auraAllThickness", "Border Thickness",
        "Square border thickness for every aura location.",
        px);
    Action("position", "auraAllPosition", "Border Position",
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
