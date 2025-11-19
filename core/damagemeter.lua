local addon, ns = ...
local damageMeter = UberUI:CreateFrame("frame")

function damageMeter:HookDamageMeter(damageMeterWindow)
    -- Color the header immediately
    local header = damageMeterWindow:GetHeader()
    if header then
        local dc = uuidb.general.darkencolor
        header:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end

    -- We are hooking the SetupEntry function of the damage meter window frame.
    -- This function is called for each row in the damage meter when it's created or updated.
    hooksecurefunc(damageMeterWindow, "SetupEntry", function(self, frame)
        -- "self" in this context is the DamageMeterSessionWindow frame.
        -- "frame" is the DamageMeterEntryTemplate frame.

        -- Texture the status bar
        local statusBar = frame:GetStatusBar()
        if statusBar then
            local textureToUse
            if uuidb.general.damagemeterbartextures then
                textureToUse = uuidb.general.damagemetertexture
            else
                textureToUse = uuidb.general.texture
            end
            statusBar:SetStatusBarTexture(uuidb.statusbars[textureToUse])
        end
    end)
end

function damageMeter:HookAllDamageMeters()
    -- Loop through all possible damage meter windows and hook them.
    for i = 1, 10 do
        local windowName = "DamageMeterSessionWindow" .. i
        local damageMeterWindow = _G[windowName]
        if damageMeterWindow then
            self:HookDamageMeter(damageMeterWindow)
        end
    end
end

function damageMeter:ForceTexture()
    -- Loop through all possible damage meter windows
    for i = 1, 10 do
        local windowName = "DamageMeterSessionWindow" .. i
        local damageMeterWindow = _G[windowName]
        if damageMeterWindow then
            -- Loop through all the entries in the scrollbox
            for _, frame in damageMeterWindow:EnumerateEntryFrames() do
                local statusBar = frame:GetStatusBar()
                if statusBar then
                    local textureToUse
                    if uuidb.general.damagemeterbartextures then
                        textureToUse = uuidb.general.damagemetertexture
                    else
                        textureToUse = uuidb.general.texture
                    end
                    statusBar:SetStatusBarTexture(uuidb.statusbars[textureToUse])
                end
            end
        end
    end
end

-- We'll wait until the player has entered the world to make sure all the default UI is loaded.
damageMeter:RegisterEvent("PLAYER_ENTERING_WORLD")
damageMeter:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        self:HookAllDamageMeters()
        -- We can stop listening for this event now
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    end
end)

UberUI.damageMeter = damageMeter
