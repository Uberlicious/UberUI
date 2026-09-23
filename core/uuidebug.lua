local addon, ns = ...

local function BuildReport()
    local lines = {}
    local function add(s) table.insert(lines, s) end

    add("InCombatLockdown = " .. tostring(InCombatLockdown and InCombatLockdown()))
    add("UberUI global = " .. tostring(UberUI))
    local tf = UberUI and UberUI.targetframes
    add("UberUI.targetframes = " .. tostring(tf))
    local c = tf and tf.customAuras
    add("customAuras = " .. tostring(c))

    -- Blizzard'''s OWN native target frame aura container
    add("---- native blizzAuras ----")
    local blizzAuras = TargetFrame and TargetFrame.TargetFrameContent and TargetFrame.TargetFrameContent.TargetFrameContentContextual and TargetFrame.TargetFrameContent.TargetFrameContentContextual.Auras
    add("blizzAuras = " .. tostring(blizzAuras))
    if blizzAuras then
        local okForbid, isForbid = pcall(function() return blizzAuras:IsForbidden() end)
        add("blizzAuras forbidden = " .. (okForbid and tostring(isForbid) or ("ERROR:" .. tostring(isForbid))))
        local okType, objType = pcall(function() return blizzAuras:GetObjectType() end)
        add("blizzAuras objectType = " .. (okType and tostring(objType) or ("ERROR:" .. tostring(objType))))
        add("blizzAuras.buffAuraGroup = " .. tostring(blizzAuras.buffAuraGroup))
        add("blizzAuras.debuffAuraGroup = " .. tostring(blizzAuras.debuffAuraGroup))
        add("blizzAuras.auraGroups = " .. tostring(blizzAuras.auraGroups))
        add("blizzAuras.AddAuraGroup = " .. tostring(blizzAuras.AddAuraGroup))
        add("blizzAuras.buffsOnTop(field) = " .. tostring(blizzAuras.buffsOnTop))
        add("TargetFrame.buffsOnTop = " .. tostring(TargetFrame and TargetFrame.buffsOnTop))
        local okKids, kids = pcall(function() return { blizzAuras:GetChildren() } end)
        if okKids and kids then
            add("blizzAuras GetChildren count = " .. #kids)
            for i, child in ipairs(kids) do
                if i <= 6 then
                    local okCF, cForbid = pcall(function() return child:IsForbidden() end)
                    add("  child " .. i .. " forbidden=" .. (okCF and tostring(cForbid) or ("ERROR:" .. tostring(cForbid))))
                end
            end
        else
            add("blizzAuras GetChildren ERROR: " .. tostring(kids))
        end
        if blizzAuras.buffAuraGroup and blizzAuras.buffAuraGroup.GetFramesByIndex then
            local okF, frames = pcall(function() return blizzAuras.buffAuraGroup:GetFramesByIndex() end)
            if okF and frames then
                add("buffAuraGroup frame count = " .. #frames)
                for i, btn in ipairs(frames) do
                    if i <= 4 then
                        local okBF, bForbid = pcall(function() return btn:IsForbidden() end)
                        add("  buff btn " .. i .. " forbidden=" .. (okBF and tostring(bForbid) or ("ERROR:" .. tostring(bForbid))) .. " DebuffBorder=" .. tostring(btn.DebuffBorder) .. " Border=" .. tostring(btn.Border))
                    end
                end
            else
                add("buffAuraGroup:GetFramesByIndex ERROR: " .. tostring(frames))
            end
        end
        if blizzAuras.debuffAuraGroup and blizzAuras.debuffAuraGroup.GetFramesByIndex then
            local okF2, frames2 = pcall(function() return blizzAuras.debuffAuraGroup:GetFramesByIndex() end)
            if okF2 and frames2 then
                add("debuffAuraGroup frame count = " .. #frames2)
                for i, btn in ipairs(frames2) do
                    if i <= 4 then
                        local okBF2, bForbid2 = pcall(function() return btn:IsForbidden() end)
                        add("  debuff btn " .. i .. " forbidden=" .. (okBF2 and tostring(bForbid2) or ("ERROR:" .. tostring(bForbid2))) .. " DebuffBorder=" .. tostring(btn.DebuffBorder) .. " Border=" .. tostring(btn.Border) .. " AddDispelTypeTexture=" .. tostring(btn.AddDispelTypeTexture))
                    end
                end
            else
                add("debuffAuraGroup:GetFramesByIndex ERROR: " .. tostring(frames2))
            end
        end
    end
    add("---- end native blizzAuras ----")

    if c then
        local n = 0
        for b in pairs(c.allButtons or {}) do
            n = n + 1
            local okForbid, isForbid = pcall(function() return b:IsForbidden() end)
            local forbidStr = okForbid and tostring(isForbid) or ("ERROR:" .. tostring(isForbid))
            local okLine, line = pcall(function()
                return string.format(
                    "#%d forbidden=%s group=%s isBuff=%s | DebuffBorder=%s DispelBorder=%s Border=%s border=%s IconBorder=%s AuraBorder=%s BorderOverlay=%s Overlay=%s | AddDispelTypeTexture=%s",
                    n,
                    forbidStr,
                    tostring(b.groupKey),
                    tostring(b.isBuff),
                    tostring(b.DebuffBorder),
                    tostring(b.DispelBorder),
                    tostring(b.Border),
                    tostring(b.border),
                    tostring(b.IconBorder),
                    tostring(b.AuraBorder),
                    tostring(b.BorderOverlay),
                    tostring(b.Overlay),
                    tostring(b.AddDispelTypeTexture)
                )
            end)
            if okLine then
                add(line)
            else
                add("button #" .. n .. " ERROR: " .. tostring(line))
            end
        end
        add("total buttons tracked=" .. n)
    end

    if Enum and Enum.CustomAuraButtonDispelTypeTextureStyle then
        add("Enum.CustomAuraButtonDispelTypeTextureStyle:")
        for k, v in pairs(Enum.CustomAuraButtonDispelTypeTextureStyle) do
            add("  " .. tostring(k) .. " = " .. tostring(v))
        end
    else
        add("Enum.CustomAuraButtonDispelTypeTextureStyle = NIL")
    end

    return table.concat(lines, "\n")
end

local debugFrame

local function ShowReport(text)
    if not debugFrame then
        debugFrame = CreateFrame("Frame", "UberUIDebugFrame", UIParent, "BackdropTemplate")
        debugFrame:SetSize(760, 520)
        debugFrame:SetPoint("CENTER")
        debugFrame:SetFrameStrata("DIALOG")
        debugFrame:SetMovable(true)
        debugFrame:EnableMouse(true)
        debugFrame:RegisterForDrag("LeftButton")
        debugFrame:SetScript("OnDragStart", debugFrame.StartMoving)
        debugFrame:SetScript("OnDragStop", debugFrame.StopMovingOrSizing)
        if debugFrame.SetBackdrop then
            debugFrame:SetBackdrop({
                bgFile = "Interface/DialogFrame/UI-DialogBox-Background",
                edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
        end

        local scrollFrame = CreateFrame("ScrollFrame", "UberUIDebugScrollFrame", debugFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 20, -20)
        scrollFrame:SetPoint("BOTTOMRIGHT", -36, 48)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(670)
        editBox:SetAutoFocus(false)
        editBox:SetScript("OnEscapePressed", function() debugFrame:Hide() end)
        scrollFrame:SetScrollChild(editBox)
        debugFrame.editBox = editBox

        local closeButton = CreateFrame("Button", nil, debugFrame, "UIPanelCloseButton")
        closeButton:SetPoint("TOPRIGHT", -5, -5)

        local hint = debugFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("BOTTOM", 0, 16)
        hint:SetText("Click inside the box, Ctrl+A to select all, Ctrl+C to copy")
    end

    debugFrame.editBox:SetText(text)
    debugFrame.editBox:HighlightText()
    debugFrame.editBox:SetFocus()
    debugFrame:Show()
end

SLASH_UBERUIDEBUG1 = "/uuidebug"
SlashCmdList["UBERUIDEBUG"] = function()
    local ok, report = pcall(BuildReport)
    if not ok then
        report = "ERROR building report: " .. tostring(report)
    end
    print("|cff33ff99UberUI debug|r report ready -- see the popup window (Ctrl+A, Ctrl+C to copy).")
    ShowReport(report)
end

-- Dumps C_Texture.GetAtlasInfo() for one or more atlas names into the same
-- copyable popup as /uuidebug, instead of chat (which can't be selected
-- cleanly for multi-line output). Usage: /uuidebugatlas <name> [name2] ...
-- With no args, dumps the atlases this session currently cares about
-- (XP bar fill, reputation fill, nameplate bar/bg).
local DEFAULT_ATLASES = {
    "UI-HUD-ExperienceBar-Fill-Experience",
    "UI-HUD-ExperienceBar-Fill-Rested",
    "UI-HUD-ExperienceBar-Fill-Reputation-Faction-Green",
    "UI-HUD-CoolDownManager-Bar",
    "UI-HUD-CoolDownManager-Bar-BG",
}

local function BuildAtlasReport(names)
    local lines = {}
    local function add(s) table.insert(lines, s) end

    for _, name in ipairs(names) do
        add("==== " .. name .. " ====")
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        if not ok then
            add("  ERROR: " .. tostring(info))
        elseif not info then
            add("  GetAtlasInfo returned nil (atlas name not found)")
        else
            for k, v in pairs(info) do
                add("  " .. tostring(k) .. " = " .. tostring(v))
            end
        end
        add("")
    end

    return table.concat(lines, "\n")
end

SLASH_UBERUIDEBUGATLAS1 = "/uuidebugatlas"
SlashCmdList["UBERUIDEBUGATLAS"] = function(msg)
    local names = {}
    if msg and msg:trim() ~= "" then
        for name in msg:gmatch("%S+") do
            table.insert(names, name)
        end
    else
        names = DEFAULT_ATLASES
    end

    local ok, report = pcall(BuildAtlasReport, names)
    if not ok then
        report = "ERROR building report: " .. tostring(report)
    end
    print("|cff33ff99UberUI debug|r atlas report ready -- see the popup window (Ctrl+A, Ctrl+C to copy).")
    ShowReport(report)
end
