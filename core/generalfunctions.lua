-- Centralized functions for UberUI

function UberUI:CreateFrame(frameType, frameName, parent, template)
    -- This function wraps the global CreateFrame.
    -- It allows for centralized control and can be expanded later
    -- to add debugging or frame management.
    local frame = CreateFrame(frameType, frameName, parent, template)
    return frame
end

local general = {}

function general:PvPIcon(frame)
    if (frame and frame.HonorIcon) then
        if (uuidb and uuidb.general and uuidb.general.hidehonor) then
            frame.PrestigeBadge:SetAlpha(0)
            frame.PrestigePortrait:SetAlpha(0)
            frame.HonorIcon:Hide()
        else
            frame.PrestigeBadge:SetAlpha(1)
            frame.PrestigePortrait:SetAlpha(1)
            frame.HonorIcon:Show()
        end
    end
    if frame then
        local dc = uuidb and uuidb.general and uuidb.general.darkencolor
        if dc then
            if frame.PvpBackgroundCircle and frame.PvpBackgroundCircle.SetVertexColor then
                frame.PvpBackgroundCircle:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
            if frame.PvPBackgroundCircle and frame.PvPBackgroundCircle.SetVertexColor then
                frame.PvPBackgroundCircle:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
            end
        end
    end
end

local function IsSecret(val)
    return issecretvalue and issecretvalue(val)
end

local function SafeBool(val)
    if val == nil or IsSecret(val) then return false end
    return val and true or false
end

function general:SetHealthColor(healthBar, unit, db)
    if healthBar == nil or not db then return end

    local isFriendly = false
    local isEnemy = false
    local isPlayer = false

    local okU, isSelf = pcall(UnitIsUnit, "player", unit)
    if okU and SafeBool(isSelf) then
        isFriendly = true
        isPlayer = true
    else
        local okP, isP = pcall(UnitIsPlayer, unit)
        if okP and not IsSecret(isP) then
            isPlayer = isP and true or false
        end

        local okF, isF = pcall(UnitIsFriend, "player", unit)
        if okF and not IsSecret(isF) then
            isFriendly = isF and true or false
            isEnemy = not isFriendly
        else
            local okE, isE = pcall(UnitCanAttack, "player", unit)
            if okE and not IsSecret(isE) then
                isEnemy = isE and true or false
                isFriendly = not isEnemy
            end
        end
    end

    if isPlayer then
        local _, class = UnitClass(unit)
        local classColor = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (GetClassColorObj and GetClassColorObj(class)) or RAID_CLASS_COLORS[class])
        if classColor then
            if (db.classcolorfriendly and db.classcolorenemy) or
               (db.classcolorenemy and isEnemy) or
               (db.classcolorfriendly and isFriendly) then
                healthBar:SetStatusBarDesaturated(true)
                healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
                return
            end
        end
    end

    local useHostilityColor = uuidb and uuidb.general and uuidb.general.hostilitycolor
    if useHostilityColor then
        local reaction
        local okR, r = pcall(UnitReaction, unit, "player")
        if okR and not IsSecret(r) and type(r) == "number" then
            reaction = r
        end

        healthBar:SetStatusBarDesaturated(true)
        if reaction and reaction >= 5 then
            healthBar:SetStatusBarColor(0, 1, 0) -- Friendly
        elseif reaction == 4 then
            healthBar:SetStatusBarColor(1, 1, 0) -- Neutral
        elseif isFriendly then
            healthBar:SetStatusBarColor(0, 1, 0) -- Friendly fallback
        else
            healthBar:SetStatusBarColor(1, 0, 0) -- Hostile
        end
        return
    end

    -- Default to friendly color if no other condition is met
    healthBar:SetStatusBarDesaturated(true)
    if isEnemy then
        healthBar:SetStatusBarColor(1, 0, 0)
    else
        healthBar:SetStatusBarColor(0, 1, 0)
    end
end

-- Safer ApplyIconZoom in Uber UI/core/generalfunctions.lua
function general:ApplyIconZoom(textureObject, enable)
    -- Check if the object is actually a texture before attempting the call
    if textureObject and textureObject:IsObjectType("Texture") then
        if enable then
            local inset = 0.07
            textureObject:SetTexCoord(inset, 1 - inset, inset, 1 - inset)
        else
            textureObject:SetTexCoord(0, 1, 0, 1)
        end
    else
        -- This will help you track down which object is being passed incorrectly
        print("ApplyIconZoom received non-Texture object: " .. tostring(textureObject))
    end
end

UberUI.general = general
