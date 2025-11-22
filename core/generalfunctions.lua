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
end

function general:SetHealthColor(healthBar, unit, db)
    if healthBar == nil then return end

    local canUseClassColor = UnitIsPlayer(unit)
    local isFriendly = UnitIsFriend("player", unit)

    if canUseClassColor then
        local _, class = UnitClass(unit)
        local classColor = RAID_CLASS_COLORS[class]
        if classColor then
            if (db.classcolorenemy and not isFriendly) or (db.classcolorfriendly and isFriendly) then
                healthBar:SetStatusBarDesaturated(true)
                healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
                return -- Class color applied, so we are done.
            end
        end
    end

    local useHostilityColor = uuidb.general and uuidb.general.hostilitycolor
    if useHostilityColor then
        local reaction = UnitReaction(unit, "player")
        healthBar:SetStatusBarDesaturated(true)
        if reaction and reaction >= 5 then
            healthBar:SetStatusBarColor(0, 1, 0) -- Friendly
        elseif reaction == 4 then
            healthBar:SetStatusBarColor(1, 1, 0) -- Neutral
        else
            healthBar:SetStatusBarColor(1, 0, 0) -- Hostile
        end
        return                                   -- Hostility color applied, so we are done.
    end

    -- Default to friendly color if no other condition is met
    healthBar:SetStatusBarDesaturated(true)
    healthBar:SetStatusBarColor(0, 1, 0)
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
