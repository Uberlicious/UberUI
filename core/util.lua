-- Small helpers shared across modules.
local util = {}

function util.IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

-- false for nil or secret values.
function util.SafeBool(v)
    if v == nil or util.IsSecret(v) then return false end
    return v == true
end

-- IsShown, false when the call fails or the result is secret.
function util.SafeShown(region)
    local ok, shown = pcall(region.IsShown, region)
    if not ok or util.IsSecret(shown) then return false end
    return shown and true or false
end

-- WoW Forever runs as a "camelot" game type on the mainline project, so the
-- project ID can't tell it apart from retail. Its client API can: only
-- Forever has C_GameRules.GetForeverExperiencePreset -- no version numbers
-- involved, so patches on either client don't affect it.
local isForever
function util.IsForeverClient()
    if isForever == nil then
        isForever = (C_GameRules and C_GameRules.GetForeverExperiencePreset ~= nil)
            or WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
    end
    return isForever
end

function util.ClassColor(class)
    return class and ((C_ClassColor and C_ClassColor.GetClassColor(class))
        or (GetClassColorObj and GetClassColorObj(class)) or RAID_CLASS_COLORS[class])
end

-- "AARRGGBB" -> color object, or nil when malformed.
function util.HexColor(hex)
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x%x%x$") then return nil end
    local ok, c = pcall(CreateColorFromHexString, hex)
    return ok and c or nil
end

UberUI.util = util
