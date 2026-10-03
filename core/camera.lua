local addon, ns = ...

-- Max camera distance past Blizzard's own slider (WoW Forever only: its
-- Controls slider for cameraDistanceMaxZoomFactor stops at 2.0). Measured on
-- Forever 1.60.1 with GetCameraZoom fully zoomed out: 15 yards per 1.0 of
-- the factor (2.0 = 30, 2.6 = 39) up to an engine limit of 50 yards (3.9
-- still gave 50), so 3.4 is the first step that reaches the limit. The CVar
-- is the game's own and persists by itself; the original value is saved
-- when the option is turned on and restored when it's off.

local camera = {}

local CVAR = "cameraDistanceMaxZoomFactor"
local MIN_FACTOR, MAX_FACTOR, DEFAULT_FACTOR = 1.0, 3.4, 3.4
local YARDS_PER_FACTOR, MAX_YARDS = 15, 50

local applying = false

local function DB()
    return uuidb and uuidb.general
end

local function Enabled()
    local g = DB()
    return UberUI.util.IsForeverClient() and g and g.cameramaxzoom == true
end

local function Factor()
    local g = DB()
    local n = tonumber(g and g.cameramaxzoomfactor) or DEFAULT_FACTOR
    return Clamp(n, MIN_FACTOR, MAX_FACTOR)
end

local function SetFactor(value)
    applying = true
    C_CVar.SetCVar(CVAR, tostring(value))
    applying = false
end

function camera:Apply()
    local g = DB()
    if not g or not UberUI.util.IsForeverClient() then return end
    if Enabled() then
        if g.cameramaxzoomoriginal == nil then
            g.cameramaxzoomoriginal = C_CVar.GetCVar(CVAR)
        end
        local want = Factor()
        if tonumber(C_CVar.GetCVar(CVAR)) ~= want then SetFactor(want) end
    elseif g.cameramaxzoomoriginal ~= nil then
        SetFactor(g.cameramaxzoomoriginal)
        g.cameramaxzoomoriginal = nil
    end
end

-- Camera distance in yards for a factor, as the client applies it.
function camera.FactorToYards(factor)
    return math.min(factor * YARDS_PER_FACTOR, MAX_YARDS)
end

local f = UberUI:CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("CVAR_UPDATE")
f:SetScript("OnEvent", function(self, event, cvar, value)
    if event == "PLAYER_LOGIN" then
        camera:Apply()
    elseif event == "CVAR_UPDATE" then
        -- Blizzard's own slider moved while ours is on: follow it rather than
        -- fight it on the next login.
        if applying or not Enabled() then return end
        if type(cvar) ~= "string" or cvar:lower() ~= CVAR:lower() then return end
        local n = tonumber(value)
        if n then DB().cameramaxzoomfactor = Clamp(n, MIN_FACTOR, MAX_FACTOR) end
    end
end)

UberUI.camera = camera
