local addon, ns = ...
local bartender4 = C_AddOns.IsAddOnLoaded("Bartender4")

local actionbars = UberUI:CreateFrame("frame")
actionbars:RegisterEvent("ADDON_LOADED")
actionbars:RegisterEvent("PLAYER_ENTERING_WORLD")
actionbars:SetScript("OnEvent", function(self, event)
    self:Color();
end)

function actionbars:Color()
    local dc = uuidb.general.darkencolor;

    -- Bartender4
    if bartender4 then
        for i = 1, 120 do
            if (_G["BT4Button" .. i]) then
                _G["BT4Button" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
            end
            if (_G["BT4PetButton" .. i]) then
                _G["BT4PetButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
            end

            if (_G["BT4StanceButton" .. i]) then
                _G["BT4StanceButton" .. i .. "NormalTexture"]:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
            end
        end
    end

    if MainActionBar and MainActionBar.BorderArt then
        MainActionBar.BorderArt:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        UberUI.general:HookDividers(MainActionBar);
    else
        for i = 0, 3 do
            local tex = _G["MainMenuBarTexture"..i]
            if tex then tex:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end
        end
    end

    local function modButton(button, secondaryBar)
        if not button then return end
        local action = button.action;
        local texture = nil;
        if (action) then
            texture = GetActionTexture(action);
        end

        if button.NormalTexture then
            button.NormalTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        end
        if button.HotKey then
            if (uuidb.general.hidehotkeys) then
                button.HotKey:Hide();
            elseif (texture or secondaryBar) then
                button.HotKey:Show();
            end
        end

        if button.Name then
            if (uuidb.general.hidemacros) then
                button.Name:Hide();
            else
                button.Name:Show();
            end
        end
    end

    for i = 1, 12 do
        modButton(_G["ActionButton" .. i]);
        modButton(_G["MultiBarBottomLeftButton" .. i]);
        modButton(_G["MultiBarBottomRightButton" .. i]);
        modButton(_G["MultiBarRightButton" .. i]);
        modButton(_G["MultiBarLeftButton" .. i]);
        modButton(_G["MultiBar5Button" .. i]);
        modButton(_G["MultiBar6Button" .. i]);
        modButton(_G["MultiBar7Button" .. i]);
        if (i < 11) then
            modButton(_G["StanceButton" .. i]);
            modButton(_G["PetActionButton" .. i]);
        end
    end

    self:ColorExtraAbilities();
    self:ColorGamepad();
end

-- Extra action button (boss/encounter button) and zone ability buttons:
-- their decorative art (style / Style; Blizzard swaps the encounter art on
-- the same texture, which keeps our tint) and button borders.
local function DarkenTexture(tex, dc)
    if tex and tex.SetVertexColor then tex:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end
end

function actionbars:ColorExtraAbilities()
    local dc = uuidb.general.darkencolor;
    local extra = ExtraActionButton1;
    if extra then
        DarkenTexture(extra.style, dc);
        DarkenTexture(extra.NormalTexture or (extra.GetNormalTexture and extra:GetNormalTexture()), dc);
    end
    local zone = ZoneAbilityFrame;
    if zone then
        DarkenTexture(zone.Style, dc);
        local container = zone.SpellButtonContainer;
        if container and container.EnumerateActive then
            for button in container:EnumerateActive() do
                DarkenTexture(button.NormalTexture or (button.GetNormalTexture and button:GetNormalTexture()), dc);
            end
        end
    end
end

-- Zone ability buttons come from a pool as abilities appear; darken after
-- Blizzard's update (deferred out of its update chain). Always-on darkening,
-- so the hook needs no setting gate.
local zoneHooked = false;
local function HookZoneAbilities()
    if zoneHooked or not (ZoneAbilityFrame and ZoneAbilityFrame.UpdateDisplayedZoneAbilities) then return end
    zoneHooked = true;
    hooksecurefunc(ZoneAbilityFrame, "UpdateDisplayedZoneAbilities", function()
        C_Timer.After(0, function() actionbars:ColorExtraAbilities() end)
    end);
end

-- WoW Forever's gamepad action bars (Blizzard_GamepadActionBars): each
-- button's frame ring is its NormalTexture (circle/square slot border atlas,
-- swapped by SetShapeToCircle/SetShapeToSquare), plus the page unit's
-- shoulder-button backgrounds. Buttons are walked from the bar roots, so
-- every bar (top/bottom/left/right, stance, possess, targeting, shortcuts,
-- class actions) and the edit-mode copy are covered.
local GAMEPAD_ROOTS = { "GamepadMainActionBarFrame", "GamepadActionBarEditFrame" };
local GAMEPAD_KEYED_ART = { "LeftShoulderBackground", "RightShoulderBackground" };
-- Controller-button glyphs (InputIconTextureFrameTemplate): one texture per
-- state, swapped by atlas only, so a tint sticks.
local INPUT_ICON_STATES = { "NormalTexture", "HoverTexture", "PressedTexture", "ActiveTexture", "DisabledTexture" };

-- A page unit's modifier prompts (pageUnit.ModifierIcons: LeftIcon,
-- RightIcon, and CenteredIcons -- two glyphs and a "+" divider).
local function DarkenInputIcon(icon, dc)
    if type(icon) ~= "table" then return end
    for _, key in ipairs(INPUT_ICON_STATES) do
        DarkenTexture(icon[key], dc);
    end
    for _, list in ipairs({ icon.InputIcons, icon.IconDividers }) do
        if type(list) == "table" then
            for _, sub in ipairs(list) do DarkenInputIcon(sub, dc) end
        end
    end
end
local gamepadHooked = setmetatable({}, { __mode = "k" });
local gamepadQueued = false;

local function QueueGamepadColor()
    if gamepadQueued then return end
    gamepadQueued = true;
    C_Timer.After(0, function()
        gamepadQueued = false;
        actionbars:ColorGamepad();
    end);
end

function actionbars:ColorGamepad()
    local dc = uuidb.general.darkencolor;
    local function walk(frame)
        for _, key in ipairs(GAMEPAD_KEYED_ART) do
            DarkenTexture(frame[key], dc);
        end
        if type(frame.ModifierIcons) == "table" then
            for _, icon in ipairs(frame.ModifierIcons) do DarkenInputIcon(icon, dc) end
        end
        if frame:IsObjectType("CheckButton") and frame.GetNormalTexture then
            DarkenTexture(frame:GetNormalTexture(), dc);
            -- The shape setters swap the border atlas; re-tint after them.
            -- Always-on darkening, so no setting gate.
            if not gamepadHooked[frame] then
                gamepadHooked[frame] = true;
                for _, method in ipairs({ "SetShapeToCircle", "SetShapeToSquare" }) do
                    if type(frame[method]) == "function" then
                        hooksecurefunc(frame, method, QueueGamepadColor);
                    end
                end
            end
        end
        for _, child in ipairs({ frame:GetChildren() }) do
            walk(child);
        end
    end
    for _, name in ipairs(GAMEPAD_ROOTS) do
        local root = _G[name];
        if root then
            local ok, err = pcall(walk, root);
            if not ok then UberUI:ReportError("gamepad action bar darkening", err) end
        end
    end
end

local extraEvents = CreateFrame("Frame");
extraEvents:RegisterEvent("PLAYER_LOGIN");
extraEvents:RegisterEvent("ADDON_LOADED");
extraEvents:RegisterEvent("PLAYER_ENTERING_WORLD");
if C_InputInterfaceStyle then
    -- Forever only; pcall in case the event name differs on a client.
    pcall(extraEvents.RegisterEvent, extraEvents, "INPUT_DEVICE_INTERFACE_TRANSITION");
end
extraEvents:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or event == "ADDON_LOADED" then
        HookZoneAbilities();
    end
    if event ~= "ADDON_LOADED" or name == "Blizzard_GamepadActionBars" then
        if GamepadMainActionBarFrame then QueueGamepadColor() end
    end
end);

UberUI.actionbars = actionbars
