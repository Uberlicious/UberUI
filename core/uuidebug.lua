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

-- Checks which bag/keyring/reagent-bag globals actually exist at runtime,
-- and if BagSlotCluster exists, lists its real children (name, whether it
-- has a NormalTexture/atlas, GetBagID if any). Forever's "camelot" game
-- type excludes the XML file that defines BagSlotClusterTemplate on other
-- game types, so the individual bag-slot button names it produces (if any)
-- aren't verifiable from source -- this checks what's really there.
local function BuildBagReport()
    local lines = {}
    local function add(s) table.insert(lines, s) end

    local function describe(name)
        local obj = _G[name]
        add(name .. " = " .. tostring(obj))
        if obj then
            local okBagID, bagID = pcall(obj.GetBagID, obj)
            if okBagID then add("  GetBagID() = " .. tostring(bagID)) end
            local okNT, nt = pcall(obj.GetNormalTexture, obj)
            add("  GetNormalTexture() = " .. (okNT and tostring(nt) or ("ERROR:" .. tostring(nt))))
            if okNT and nt then
                local okAtlas, atlas = pcall(nt.GetAtlas, nt)
                add("    atlas = " .. (okAtlas and tostring(atlas) or "n/a"))
            end
        end
    end

    for _, name in ipairs({
        "MainMenuBarBackpackButton",
        "KeyRingButton",
        "CharacterReagentBag0Slot",
        "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot",
        "BagSlotCluster", "BagsBar",
    }) do
        describe(name)
    end

    add("")
    add("---- BagSlotCluster:GetChildren() ----")
    local cluster = BagSlotCluster
    if cluster and cluster.GetChildren then
        local ok, kids = pcall(function() return { cluster:GetChildren() } end)
        if ok then
            for i, child in ipairs(kids) do
                local okName, cname = pcall(child.GetName, child)
                local okBagID, bagID = pcall(child.GetBagID, child)
                add(string.format("  #%d name=%s bagID=%s", i,
                    okName and tostring(cname) or "?",
                    okBagID and tostring(bagID) or "n/a"))
            end
        else
            add("  ERROR: " .. tostring(kids))
        end
    else
        add("  BagSlotCluster missing or has no GetChildren")
    end

    add("")
    add("---- BagsBar:GetChildren() ----")
    if BagsBar and BagsBar.GetChildren then
        local ok, kids = pcall(function() return { BagsBar:GetChildren() } end)
        if ok then
            for i, child in ipairs(kids) do
                local okName, cname = pcall(child.GetName, child)
                add(string.format("  #%d name=%s", i, okName and tostring(cname) or "?"))
            end
        else
            add("  ERROR: " .. tostring(kids))
        end
    else
        add("  BagsBar missing or has no GetChildren")
    end

    return table.concat(lines, "\n")
end

SLASH_UBERUIDEBUGBAGS1 = "/uuidebugbags"
SlashCmdList["UBERUIDEBUGBAGS"] = function()
    local ok, report = pcall(BuildBagReport)
    if not ok then
        report = "ERROR building report: " .. tostring(report)
    end
    print("|cff33ff99UberUI debug|r bag report ready -- see the popup window (Ctrl+A, Ctrl+C to copy).")
    ShowReport(report)
end

-- Dumps raw aura data for one unit's HELPFUL and HARMFUL auras: name,
-- source, isCastByPlayer/isFromPlayerOrPlayerPet (whichever API answers),
-- and what UnitIsUnit/UnitIsOwnerOrControllerOfUnit against player/pet/
-- vehicle actually say. Two different native "is this mine" mechanisms
-- have now behaved unexpectedly on this beta client (candidateFilters.
-- isFromPlayerOrPlayerPet marking everything as mine; C_UnitAuras.
-- GetAuraSlots erroring out outright) -- this tries both the modern
-- C_UnitAuras path and the older index-based UnitAura API (which directly
-- returns isCastByPlayer) so we see real values instead of guessing a
-- third approach blind. Usage: /uuidebugauras [unit] (default target)
local function DescribeSource(src)
    local okUP, isPlayer = pcall(UnitIsUnit, src, "player")
    local okUV, isVehicle = pcall(UnitIsUnit, src, "vehicle")
    local okUPet, isPet = pcall(UnitIsUnit, src, "pet")
    local okOwner, isOwnerControlled = pcall(UnitIsOwnerOrControllerOfUnit, "player", src or "")
    return string.format(
        "UnitIsUnit(src,player)=%s vehicle=%s pet=%s | UnitIsOwnerOrControllerOfUnit(player,src)=%s",
        okUP and tostring(isPlayer) or "ERR",
        okUV and tostring(isVehicle) or "ERR",
        okUPet and tostring(isPet) or "ERR",
        okOwner and tostring(isOwnerControlled) or "ERR"
    )
end

local function IsSecretLocal(v)
    return issecretvalue and issecretvalue(v)
end

-- GetAuraSlots/UnitAura/button:GetAuraInstance() are all dead ends on this
-- client (see prior /uuidebugauras runs). But core/buffsandauras.lua -- a
-- different, older module in this same addon -- has been successfully
-- calling C_UnitAuras.GetAuraDataByAuraInstanceID(unit, button.auraInstanceID)
-- all along to read isHarmful/isHelpful off native aura buttons. Checking
-- whether our own aurakit-created buttons expose that same .auraInstanceID
-- field, and whether sourceUnit/isFromPlayerOrPlayerPet come through
-- readable via THIS specific function (unlike the others).
local function DumpContainerAuras(add, container, label, unitToken)
    add("---- " .. label .. " ----")
    if not container or not container.allButtons then
        add("  (no container / no allButtons)")
        return
    end
    for btn in pairs(container.allButtons) do
        local okShown, isShown = pcall(btn.IsShown, btn)
        local instID = btn.auraInstanceID
        local instIsSecret = IsSecretLocal(instID)
        add(string.format("  shown=%s groupKey=%s isBuff=%s | auraInstanceID=%s secret=%s",
            okShown and tostring(isShown) or "ERR", tostring(btn.groupKey), tostring(btn.isBuff),
            instIsSecret and "<secret>" or tostring(instID), tostring(instIsSecret)))

        if instID and not instIsSecret and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
            local okAura, aura
            local okCall = pcall(function()
                okAura, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unitToken, instID)
            end)
            if okCall and okAura and aura and not IsSecretLocal(aura) then
                add(string.format("    via GetAuraDataByAuraInstanceID: name=%s sourceUnit=%s(secret=%s) isFromPlayerOrPlayerPet=%s(secret=%s) isHarmful=%s isHelpful=%s",
                    tostring(aura.name),
                    IsSecretLocal(aura.sourceUnit) and "<secret>" or tostring(aura.sourceUnit), tostring(IsSecretLocal(aura.sourceUnit)),
                    IsSecretLocal(aura.isFromPlayerOrPlayerPet) and "<secret>" or tostring(aura.isFromPlayerOrPlayerPet), tostring(IsSecretLocal(aura.isFromPlayerOrPlayerPet)),
                    tostring(aura.isHarmful), tostring(aura.isHelpful)))
                if aura.sourceUnit and not IsSecretLocal(aura.sourceUnit) then
                    add("    " .. DescribeSource(aura.sourceUnit))
                end
            else
                add("    GetAuraDataByAuraInstanceID failed/nil/secret: okCall=" .. tostring(okCall) .. " okAura=" .. tostring(okAura))
            end
        end

        local okInst, gaiUnit, auraData = pcall(btn.GetAuraInstance, btn)
        add("    GetAuraInstance(): ok=" .. tostring(okInst) .. " result=" .. tostring(gaiUnit))
    end
end

local function BuildAuraSourceReport(frameLabel)
    local lines = {}
    local function add(s) table.insert(lines, s) end

    local frameObj = (frameLabel == "focus") and (UberUI and UberUI.focusframes) or (UberUI and UberUI.targetframes)
    add("frameObj (" .. tostring(frameLabel or "target") .. ") = " .. tostring(frameObj))
    if not frameObj then
        add("  UberUI.targetframes/focusframes not found")
        return table.concat(lines, "\n")
    end

    local unitToken = (frameLabel == "focus") and "focus" or "target"
    DumpContainerAuras(add, frameObj.customBuffs, "customBuffs", unitToken)
    add("")
    DumpContainerAuras(add, frameObj.customDebuffs, "customDebuffs", unitToken)

    return table.concat(lines, "\n")
end

SLASH_UBERUIDEBUGAURAS1 = "/uuidebugauras"
SlashCmdList["UBERUIDEBUGAURAS"] = function(msg)
    local frameLabel = (msg and msg:trim() ~= "") and msg:trim() or "target"
    local ok, report = pcall(BuildAuraSourceReport, frameLabel)
    if not ok then
        report = "ERROR building report: " .. tostring(report)
    end
    print("|cff33ff99UberUI debug|r aura-source report ready -- see the popup window (Ctrl+A, Ctrl+C to copy).")
    ShowReport(report)
end
