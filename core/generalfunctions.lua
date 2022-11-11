local addon, ns = ...
local general = {}

function general:SetHealthColor(healthBar, target, variableParent)
    assert(healthBar:GetObjectType() == "StatusBar", "healthBar must be of type StatusBar");
    assert(type(target) == "string", "Target must be of type string");
    assert(type(variableParent) == "table" and variableParent.classcolorenemy ~= nil and
        variableParent.classcolorfriendly ~= nil,
        "variableParent must contain both classcolorenemy and classcolorfriendly")
    -- assert(v )
    local classColor = RAID_CLASS_COLORS[select(2, UnitClass(target))];
    local playerCheck = UnitIsPlayer(target);
    local friend = UnitIsFriend("player", target);
    local enemy = UnitIsEnemy("player", target);
    if ((variableParent.classcolorenemy and enemy) and playerCheck) then
        healthBar:SetStatusBarDesaturated(true);
        healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, classColor.a);
    elseif (variableParent.classcolorfriendly and friend and playerCheck) then
        healthBar:SetStatusBarDesaturated(true);
        healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, classColor.a);
    elseif (uuidb.general.hostilitycolor) then
        healthBar:SetStatusBarDesaturated(true);
        if (not variableParent.classcolorenemy and enemy and playerCheck) then
            healthBar:SetStatusBarColor(1, 0, 0, 1);

        elseif (not variableParent.classcolorfriend and friend and playerCheck) then
            healthBar:SetStatusBarDesaturated(false);
            healthBar:SetStatusBarColor(0, 1, 0, 1);
        else
            healthBar:SetStatusBarColor(UnitSelectionColor(target, true));
        end
    else
        healthBar:SetStatusBarDesaturated(false);
        healthBar:SetStatusBarColor(0, 1, 0, 1);
    end
end

function general:PvPIcon(frameParent)
    assert(type(frameParent) == "table", "Must be a table containing the pvp icons");
    -- frames have differnet names for pvpicon
    local pvpIcon;
    for i, v in pairs(frameParent) do
        if (strlower(i) == "pvpicon") then pvpIcon = v end
    end
    -- local pvpIcon = frameParent.PvpIcon;
    local prestigePortrait = frameParent.PrestigePortrait;
    local prestigeBadge = frameParent.PrestigeBadge;
    local dc = uuidb.general.darkencolor;
    if (uuidb.general.hidehonor) then
        prestigePortrait:SetAlpha(0);
        prestigeBadge:SetAlpha(0);
        pvpIcon:SetAlpha(0);
    else
        prestigePortrait:SetAlpha(1);
        prestigeBadge:SetAlpha(1);
        pvpIcon:SetAlpha(1);
        prestigePortrait:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
    end
end

UberUI.general = general
