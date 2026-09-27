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

-- Every field pulled off real aura data must be individually secret-checked
-- before it ever touches tostring/string.format/concat -- a secret value is
-- contagious through all of those (even tostring() of a secret value stays
-- secret), so one unguarded field silently poisons a whole formatted string
-- and table.concat() throws for the entire report. This is the single choke
-- point every field print below goes through.
local function SecretSafeEnum(v)
    if v == nil then return "nil" end
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    local ok, s = pcall(tostring, v)
    if not ok or (issecretvalue and issecretvalue(s)) then return "<secret>" end
    return s
end

-- New angle, not tried yet: every previous test read aura data THROUGH a
-- button (ours or Blizzard's) or through the AuraContainer group/filter
-- system. AuraUtil.ForEachAura (Blizzard_FrameXMLUtil/AuraUtil.lua) is a
-- completely different, always-loaded, non-secure API that enumerates a
-- unit's auras directly -- it's what AuraUtil.DefaultAuraCompare itself
-- uses to read auraData.sourceUnit for sorting, which only works at all if
-- sourceUnit is NOT unconditionally secret through this path. Testing
-- whether that holds for a party member's own buffs specifically (the
-- exact case that showed the double-listing bug).
--
-- Usage: /uuidebugauraenum [target|focus]
local function BuildAuraEnumReport(frameLabel)
    local lines = {}
    local function add(s) table.insert(lines, s) end

    local unitToken = (frameLabel == "focus") and "focus" or "target"
    add("==== direct unit aura enumeration (AuraUtil.ForEachAura) -- " .. unitToken .. " ====")
    add("Reads aura data directly off the unit, with no button or container")
    add("involved at all, to check whether sourceUnit/isFromPlayerOrPlayerPet")
    add("are readable through THIS path even though every button-based path")
    add("has failed so far.")
    add("")

    if not UnitExists(unitToken) then
        add("UnitExists(" .. unitToken .. ") = false -- target/focus something with buffs first")
        return table.concat(lines, "\n")
    end

    if not (AuraUtil and AuraUtil.ForEachAura) then
        add("AuraUtil.ForEachAura not available")
        return table.concat(lines, "\n")
    end

    local n = 0
    local okRun, errRun = pcall(function()
        -- usePackedAura=true (5th arg) is required to get a real auraData
        -- TABLE with named fields in the callback -- without it, ForEachAura
        -- unpacks into a loose tuple of raw values instead, and indexing
        -- the first one with .name/.auraInstanceID silently returns nil
        -- rather than erroring (that's what the first run actually hit).
        AuraUtil.ForEachAura(unitToken, "HELPFUL", nil, function(auraData)
            n = n + 1
            if not auraData or (issecretvalue and issecretvalue(auraData)) then
                add(string.format("  #%d auraData itself is nil/secret", n))
                return false
            end

            local instID = auraData.auraInstanceID
            local src = auraData.sourceUnit
            local isMineFlag = auraData.isFromPlayerOrPlayerPet

            add(string.format(
                "  #%d name=%s auraInstanceID=%s sourceUnit=%s isFromPlayerOrPlayerPet=%s isHarmful=%s isHelpful=%s",
                n,
                SecretSafeEnum(auraData.name),
                SecretSafeEnum(instID),
                SecretSafeEnum(src),
                SecretSafeEnum(isMineFlag),
                SecretSafeEnum(auraData.isHarmful),
                SecretSafeEnum(auraData.isHelpful)
            ))

            if src and not (issecretvalue and issecretvalue(src)) then
                local okCmp, isPlayerSrc = pcall(UnitIsUnit, "player", src)
                add("    UnitIsUnit(player, sourceUnit) = " .. (okCmp and SecretSafeEnum(isPlayerSrc) or "ERROR"))
            end

            return false -- keep iterating, don't stop early
        end, true) -- usePackedAura=true
    end)

    if not okRun then
        add("")
        add("AuraUtil.ForEachAura ERROR: " .. SecretSafeEnum(errRun))
    end

    add("")
    add("total helpful auras enumerated=" .. n)

    return table.concat(lines, "\n")
end

SLASH_UBERUIDEBUGAURAENUM1 = "/uuidebugauraenum"
SlashCmdList["UBERUIDEBUGAURAENUM"] = function(msg)
    local frameLabel = (msg and msg:trim():lower() == "focus") and "focus" or "target"
    local ok, report = pcall(BuildAuraEnumReport, frameLabel)
    if not ok then
        report = "ERROR building report: " .. tostring(report)
    end
    print("|cff33ff99UberUI debug|r direct aura-enumeration report ready -- see the popup window (Ctrl+A, Ctrl+C to copy).")
    ShowReport(report)
end

-- Two cheap checks in one pass, both aimed at the same question: can we
-- correlate a real, sourceUnit-verified aura (from AuraUtil.ForEachAura,
-- proven readable/accurate in prior /uuidebugauraenum runs) to a specific
-- button in a single-group AddAuraGroup container, for sizing?
--
-- 1) Key dump: pairs() over a real button from a single "HELPFUL" group, to
--    check for any identity field (auraData/auraInfo/layoutIndex/etc) we
--    might have missed by only probing .auraInstanceID and :GetAuraInstance()
--    directly before.
-- 2) Count-parity: AuraContainerSortMethod.AuraInstanceIDOnly (=8, strict
--    ascending auraInstanceID order -- Blizzard_AuraContainerShared.lua)
--    sorts the group's buttons by the exact same key we can independently
--    compute from AuraUtil.ForEachAura's own auraInstanceID field. If both
--    sides report the same count for the same filter on the same unit at
--    the same moment, positional index correlation between them becomes a
--    real, checkable hypothesis instead of a guess -- not proof by itself,
--    but a necessary condition for it to work at all.
--
-- Usage: /uuidebugcorrelate [target|focus]
-- Async: AddAuraGroup pre-allocates a batch of frames immediately at
-- registration time (Blizzard_CustomAuraContainer.lua:301-304,
-- "Allocate a batch of frames up-front..."), before any real aura data
-- exists -- actual frame ASSIGNMENT happens on a deferred update cycle.
-- Reading GetAuraGroupFrameCount in the same tick as UpdateAllAuras() can
-- catch the pre-allocated batch size instead of the real assigned count
-- (this is also why production UpdateAuras() re-runs itself after a
-- C_Timer.After(0.05, ...) delay -- see targetframe.lua). So this report
-- is built after a short delay instead of synchronously.
local correlateTestContainer

local function BuildCorrelateReport(frameLabel, callback)
    local lines = {}
    local function add(s) table.insert(lines, s) end

    local unitToken = (frameLabel == "focus") and "focus" or "target"
    add("==== button/enumeration correlation check (" .. unitToken .. ") ====")
    add("")

    if not UnitExists(unitToken) then
        add("UnitExists(" .. unitToken .. ") = false -- target/focus something with buffs first")
        callback(table.concat(lines, "\n"))
        return
    end

    if not correlateTestContainer then
        local okC, container = pcall(function()
            return CreateFrame("AuraContainer", "UberUI_CorrelateTest", UIParent, "CustomAuraContainerTemplate")
        end)
        if not okC or not container then
            add("CreateFrame failed: " .. tostring(container))
            callback(table.concat(lines, "\n"))
            return
        end
        container:Hide()

        local okAdd = pcall(container.AddAuraGroup, container, "buffs", "HELPFUL", {
            maxFrameCount = 40,
            initializeFrame = function(btn) pcall(btn.Hide, btn) end,
            sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.AuraInstanceIDOnly,
            sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal,
        })
        add("AddAuraGroup(sortMethod=AuraInstanceIDOnly) ok=" .. tostring(okAdd))
        correlateTestContainer = container
    end

    local container = correlateTestContainer
    local okSet = pcall(container.SetUnit, container, unitToken)
    add("SetUnit(" .. unitToken .. ") ok=" .. tostring(okSet))
    pcall(container.UpdateAllAuras, container)

    C_Timer.After(0.15, function()
        -- 1) Direct identity-getter probe on every button: GetCasterName/
        --    GetSpellName/GetApplicationCount, found via the earlier key
        --    dump -- if GetCasterName() returns a real player name here,
        --    that's a much simpler mine/other signal than any index
        --    correlation, with no separate enumeration needed at all.
        add("")
        add("-- per-button identity getters --")
        local okCount1, groupCount = pcall(container.GetAuraGroupFrameCount, container, "buffs")
        groupCount = (okCount1 and type(groupCount) == "number") and groupCount or 0
        local playerName = UnitName("player")
        for i = 1, groupCount do
            local okBtn, btn = pcall(container.GetAuraGroupFrame, container, "buffs", i)
            if okBtn and btn and not (issecretvalue and issecretvalue(btn)) then
                local okCaster, caster = pcall(btn.GetCasterName, btn)
                local okSpell, spell = pcall(btn.GetSpellName, btn)
                local okShown, isShown = pcall(btn.IsShown, btn)
                local okIcon, icon = pcall(btn.GetIcon, btn)
                local casterStr = okCaster and SecretSafeEnum(caster) or "ERROR"
                add(string.format("  #%d shown=%s icon=%s caster=%s spell=%s matchesPlayerName=%s",
                    i, okShown and SecretSafeEnum(isShown) or "ERROR",
                    okIcon and SecretSafeEnum(icon) or "ERROR",
                    casterStr, okSpell and SecretSafeEnum(spell) or "ERROR",
                    tostring(okCaster and caster == playerName)))
            else
                add("  #" .. i .. " no button (ok=" .. tostring(okBtn) .. ")")
            end
        end

        -- 2) Count parity between the sorted group and independent
        --    enumeration, now given time to settle.
        add("")
        add("-- count parity (after 0.15s settle) --")
        add("group button count = " .. tostring(groupCount))

        local enumCount = 0
        if AuraUtil and AuraUtil.ForEachAura then
            pcall(function()
                AuraUtil.ForEachAura(unitToken, "HELPFUL", nil, function(auraData)
                    if auraData and not (issecretvalue and issecretvalue(auraData)) then
                        enumCount = enumCount + 1
                    end
                    return false
                end, true)
            end)
        end
        add("AuraUtil.ForEachAura count = " .. tostring(enumCount))

        if groupCount == enumCount then
            add("COUNTS MATCH -- index correlation is at least plausible.")
        else
            add("COUNT MISMATCH -- index correlation between these two sources is not safe to rely on.")
        end

        callback(table.concat(lines, "\n"))
    end)
end

SLASH_UBERUIDEBUGCORRELATE1 = "/uuidebugcorrelate"
SlashCmdList["UBERUIDEBUGCORRELATE"] = function(msg)
    local frameLabel = (msg and msg:trim():lower() == "focus") and "focus" or "target"
    local ok, err = pcall(BuildCorrelateReport, frameLabel, function(report)
        print("|cff33ff99UberUI debug|r button/enumeration correlation report ready -- see the popup window (Ctrl+A, Ctrl+C to copy).")
        ShowReport(report)
    end)
    if not ok then
        print("|cff33ff99UberUI debug|r ERROR: " .. tostring(err))
    end
end

-- Live VISUAL grouping test -- no styling, no borders, no zoom, just plain
-- engine-rendered icons in three big, clearly labeled, always-on-top rows,
-- so double-listing (or its absence) can be seen directly instead of
-- inferred from GetAuraGroupFrameCount (which we've now proven reports
-- pool capacity, not real match count -- see FrameCreationBatchSize=10 in
-- BuildCorrelateReport above). Three independent single-group containers:
--   row 1: "HELPFUL|PLAYER"   (the "mine" half of the original split)
--   row 2: "HELPFUL|!PLAYER"  (the "other" half of the original split)
--   row 3: "HELPFUL"          (plain baseline, no caster filter at all)
-- If a specific non-player-cast buff on the targeted ally shows an icon in
-- BOTH row 1 and row 2, that's the double-listing bug, visually confirmed.
-- If it only ever shows in row 2, the PLAYER token is trustworthy alone
-- (just not paired with a competing !PLAYER group) and row 3 confirms the
-- same aura is present overall either way.
--
-- Usage: /uuidebugvisualtest [target|focus] -- re-run any time to re-point
-- at the current target/focus; toggle again with /uuidebugvisualtest hide.
local visualTestRows

local function BuildVisualTestRow(labelText, filterString, yOffset)
    local row = CreateFrame("Frame", nil, UIParent)
    row:SetSize(700, 60)
    row:SetPoint("TOP", UIParent, "TOP", 0, yOffset)
    row:SetFrameStrata("TOOLTIP")

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 2)
    label:SetText(labelText)
    label:SetTextColor(1, 1, 0)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(row)
    bg:SetColorTexture(0, 0, 0, 0.6)

    local container = CreateFrame("AuraContainer", nil, row, "CustomAuraContainerTemplate")
    container:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)
    container:SetFrameLevel(row:GetFrameLevel() + 1)
    pcall(container.SetFlowLayoutMaximumLineSize, container, 690)
    if container.SetFlowLayoutSpacing then
        pcall(container.SetFlowLayoutSpacing, container, 4, 4)
    end

    pcall(container.AddAuraGroup, container, "g", filterString, {
        maxFrameCount = 20,
        initializeFrame = function(btn)
            pcall(btn.SetSize, btn, 40, 40)
            -- The generic AuraButton widget has no built-in icon layer -- the
            -- engine only draws the aura's icon into a texture object we
            -- create and hand it ourselves via SetIcon. Without this, the
            -- button exists (and is correctly counted/positioned) but
            -- nothing ever appears on screen -- exactly what happened on
            -- the first run of this test.
            local okIcon, icon = pcall(btn.CreateTexture, btn, nil, "ARTWORK")
            if okIcon and icon then
                icon:SetAllPoints(btn)
                pcall(btn.SetIcon, btn, icon)
            end
            pcall(btn.Show, btn)
        end,
        layout = { elementWidth = 40, elementHeight = 40, elementSpacing = 4, lineSpacing = 4 },
    })

    row.container = container
    row.label = label
    return row
end

local function EnsureVisualTestRows()
    if visualTestRows then return visualTestRows end
    visualTestRows = {
        BuildVisualTestRow("Row 1: HELPFUL|PLAYER", "HELPFUL|PLAYER", -160),
        BuildVisualTestRow("Row 2: HELPFUL|!PLAYER", "HELPFUL|!PLAYER", -240),
        BuildVisualTestRow("Row 3: HELPFUL (baseline, no caster filter)", "HELPFUL", -320),
        -- Debuffs: most targets won't have any, but worth having on hand --
        -- same three-way split, same reasoning, just HARMFUL instead of
        -- HELPFUL. A hostile target with a DoT from someone else in the
        -- group (or a boss debuff) is the case that actually exercises this.
        BuildVisualTestRow("Row 4: HARMFUL|PLAYER", "HARMFUL|PLAYER", -420),
        BuildVisualTestRow("Row 5: HARMFUL|!PLAYER", "HARMFUL|!PLAYER", -500),
        BuildVisualTestRow("Row 6: HARMFUL (baseline, no caster filter)", "HARMFUL", -580),
    }
    return visualTestRows
end

SLASH_UBERUIDEBUGVISUALTEST1 = "/uuidebugvisualtest"
SlashCmdList["UBERUIDEBUGVISUALTEST"] = function(msg)
    local arg = (msg and msg:trim():lower()) or ""

    if arg == "hide" then
        if visualTestRows then
            for _, row in ipairs(visualTestRows) do
                row:Hide()
            end
        end
        print("|cff33ff99UberUI debug|r visual grouping test hidden.")
        return
    end

    local unitToken = (arg == "focus") and "focus" or "target"
    if not UnitExists(unitToken) then
        print("|cff33ff99UberUI debug|r UnitExists(" .. unitToken .. ") = false -- target/focus something with buffs first.")
        return
    end

    local rows = EnsureVisualTestRows()
    for _, row in ipairs(rows) do
        row:Show()
        pcall(row.container.SetUnit, row.container, unitToken)
        pcall(row.container.UpdateAllAuras, row.container)
    end

    print("|cff33ff99UberUI debug|r visual grouping test shown, pointed at '" .. unitToken ..
        "'. Compare the three rows by eye. Run '/uuidebugvisualtest hide' to hide them again.")
end

-- Passive background watcher for the intermittent PLAYER/!PLAYER overlap
-- bug. Since it hasn't reproduced on demand, this checks in the background
-- so an occurrence gets caught (with context) whenever it next happens,
-- instead of relying on noticing it live and reacting in time.
--
-- Uses C_UnitAuras.GetUnitAuraInstanceIDs(unit, filterString) DIRECTLY --
-- no AddAuraGroup/container/button involved at all, so there's no pool-size
-- ambiguity (see BuildCorrelateReport's FrameCreationBatchSize finding).
-- An aura's instanceID showing up in BOTH the "HELPFUL|PLAYER" list and the
-- "HELPFUL|!PLAYER" list for the same unit at the same moment is a hard,
-- unambiguous overlap -- not an inference from counts or a visual read.
--
-- Usage:
--   /uuidebugoverlapwatch          -- start watching (checks every 1s)
--   /uuidebugoverlapwatch stop     -- stop watching
--   /uuidebugoverlapwatch clear    -- clear the log
--   /uuidebugoverlaylog            -- show everything caught so far
local DEFAULT_WATCHED_OVERLAP_UNITS = {
    "target", "focus",
    "party1", "party2", "party3", "party4",
    "raid1", "raid2", "raid3", "raid4", "raid5",
    "raid6", "raid7", "raid8", "raid9", "raid10",
}
-- Mutable, swapped out by /uuidebugoverlapwatch <unit> to scope the watcher
-- to just one unit (e.g. "target") -- useful for isolating a demonstration
-- to the target frame specifically, since the bug isn't raid/party-frame
-- specific and it's worth being able to show that cleanly.
local activeWatchedUnits = DEFAULT_WATCHED_OVERLAP_UNITS

local overlapLog = {}
local overlapTicker
local overlapZoneFrame
local overlapLoginTime = GetTime()
-- Per (unit .. ":" .. auraInstanceID) STATE (true while overlapping, false/
-- nil otherwise) -- unlike a one-way latch, this lets a clear-on-zone-
-- return be logged as its own event instead of just never firing again.
local overlapState = {}
local lastKnownZone

-- UnitIsVisible/UnitInRange are the closest addon-facing proxies for "is
-- this unit actually nearby right now". sameZoneMap answers a more direct
-- question -- "is this unit positioned on the SAME zone map I'm currently
-- on" -- via C_Map.GetPlayerMapPosition, the same mechanism that places
-- party/raid member dots on the world map; it returns nil when the unit
-- isn't on the queried map at all, which is as close as addon code gets to
-- "what zone is this other player in" (there's no direct UnitZone API).
-- Recorded on every log entry (overlap or zone change) to test the zone
-- hypothesis directly: does the overlap coincide with sameZoneMap=false?
local function DescribeUnitProximity(unit)
    if not UnitExists(unit) then return "n/a" end
    local okVis, isVisible = pcall(UnitIsVisible, unit)
    local okRange, inRange = pcall(UnitInRange, unit)

    local sameZoneMap = "ERR"
    local okMapID, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    if okMapID and mapID then
        local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, unit)
        sameZoneMap = SecretSafeEnum(okPos and (pos ~= nil))
    end

    return string.format("visible=%s inRange=%s sameZoneMap=%s",
        okVis and SecretSafeEnum(isVisible) or "ERR",
        okRange and SecretSafeEnum(inRange) or "ERR",
        sameZoneMap)
end

-- started=true logs an "OVERLAP STARTED" entry (with aura name/source
-- context); started=false logs an "OVERLAP CLEARED" entry for the same
-- unit/instanceID -- this is what actually answers "does it clear when
-- zoning back" instead of just latching the first sighting forever.
local function LogOverlapEvent(unit, id, started)
    local entry = {
        type = started and "overlap_start" or "overlap_clear",
        time = date("%H:%M:%S"),
        sinceLogin = math.floor(GetTime() - overlapLoginTime),
        unit = unit,
        auraInstanceID = SecretSafeEnum(id),
        zone = SecretSafeEnum((GetRealZoneText and GetRealZoneText()) or "?"),
        proximity = DescribeUnitProximity(unit),
        inCombat = SecretSafeEnum(InCombatLockdown and InCombatLockdown()),
        playerClass = SecretSafeEnum(select(2, UnitClass("player"))),
    }
    if started then
        pcall(function()
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
            if aura and not (issecretvalue and issecretvalue(aura)) then
                entry.name = SecretSafeEnum(aura.name)
                entry.sourceUnit = SecretSafeEnum(aura.sourceUnit)
            end
        end)
    end
    table.insert(overlapLog, entry)

    local tag = started and "OVERLAP STARTED" or "OVERLAP CLEARED"
    local color = started and "|cffff3333" or "|cff33ff33"
    print(string.format("%sUberUI debug|r %s on %s (aura #%s%s) -- %s -- see /uuidebugoverlaylog",
        color, tag, unit, entry.auraInstanceID,
        entry.name and (", name=" .. entry.name) or "",
        entry.proximity))
end

local function CheckUnitForOverlap(unit)
    if not UnitExists(unit) then return end

    local okMine, mineIDs = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, "HELPFUL|PLAYER")
    local okOther, otherIDs = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, "HELPFUL|!PLAYER")
    if not okMine or not okOther or not mineIDs or not otherIDs then return end
    if issecretvalue and (issecretvalue(mineIDs) or issecretvalue(otherIDs)) then return end

    local mineSet = {}
    for _, id in ipairs(mineIDs) do
        if not (issecretvalue and issecretvalue(id)) then
            mineSet[id] = true
        end
    end

    local currentlyOverlapping = {}
    for _, id in ipairs(otherIDs) do
        if id and not (issecretvalue and issecretvalue(id)) and mineSet[id] then
            currentlyOverlapping[id] = true
            local key = unit .. ":" .. tostring(id)
            if not overlapState[key] then
                overlapState[key] = true
                LogOverlapEvent(unit, id, true)
            end
        end
    end

    -- Anything previously overlapping on THIS unit that isn't in the
    -- current overlap set anymore has cleared -- log the transition.
    local prefix = unit .. ":"
    for key, isOverlapping in pairs(overlapState) do
        if isOverlapping and key:sub(1, #prefix) == prefix then
            local idNum = tonumber(key:sub(#prefix + 1))
            if idNum and not currentlyOverlapping[idNum] then
                overlapState[key] = false
                LogOverlapEvent(unit, idNum, false)
            end
        end
    end
end

-- Zone-change events log their own timeline entry alongside overlap
-- entries, with a proximity snapshot for every currently-existing watched
-- unit at that moment -- lets /uuidebugoverlaylog show "zone changed here,
-- then an overlap appeared N seconds later" instead of two disconnected
-- facts you have to line up by hand.
local function LogZoneChange()
    local newZone = (GetRealZoneText and GetRealZoneText()) or "?"
    if newZone == lastKnownZone then return end
    lastKnownZone = newZone

    local entry = {
        type = "zonechange",
        time = date("%H:%M:%S"),
        sinceLogin = math.floor(GetTime() - overlapLoginTime),
        zone = SecretSafeEnum(newZone),
    }
    local proximities = {}
    for _, unit in ipairs(activeWatchedUnits) do
        if UnitExists(unit) then
            table.insert(proximities, unit .. "=[" .. DescribeUnitProximity(unit) .. "]")
        end
    end
    entry.proximity = table.concat(proximities, " ")
    table.insert(overlapLog, entry)
    print("|cff33ff99UberUI debug|r zone change -> " .. entry.zone .. " -- logged, see /uuidebugoverlaylog")
end

-- units: optional explicit list of unit tokens to watch (e.g. {"target"}
-- to isolate the demonstration to the target frame only); defaults to
-- DEFAULT_WATCHED_OVERLAP_UNITS (target/focus/party/raid) when omitted.
local function StartOverlapWatcher(units)
    if overlapTicker then
        print("|cff33ff99UberUI debug|r overlap watcher already running -- run /uuidebugoverlapwatch stop first to change scope.")
        return
    end
    activeWatchedUnits = units or DEFAULT_WATCHED_OVERLAP_UNITS
    lastKnownZone = (GetRealZoneText and GetRealZoneText()) or "?"

    overlapTicker = C_Timer.NewTicker(1, function()
        for _, unit in ipairs(activeWatchedUnits) do
            pcall(CheckUnitForOverlap, unit)
        end
    end)

    if not overlapZoneFrame then
        overlapZoneFrame = CreateFrame("Frame")
    end
    overlapZoneFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    overlapZoneFrame:RegisterEvent("ZONE_CHANGED")
    overlapZoneFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    overlapZoneFrame:SetScript("OnEvent", function() pcall(LogZoneChange) end)

    print("|cff33ff99UberUI debug|r overlap watcher started -- watching [" ..
        table.concat(activeWatchedUnits, ", ") ..
        "] every 1s and logging zone changes in the background. Keep playing normally; run /uuidebugoverlaylog any time to see what's been caught.")
end

local function StopOverlapWatcher()
    if overlapTicker then
        overlapTicker:Cancel()
        overlapTicker = nil
        if overlapZoneFrame then
            overlapZoneFrame:UnregisterAllEvents()
        end
        print("|cff33ff99UberUI debug|r overlap watcher stopped.")
    else
        print("|cff33ff99UberUI debug|r overlap watcher wasn't running.")
    end
end

-- Usage recap (see comment above the watcher functions for the full
-- rationale): "/uuidebugoverlapwatch" watches target/focus/party/raid;
-- "/uuidebugoverlapwatch target" (or any single unit token, e.g. "focus",
-- "party1") scopes it to just that one unit -- useful for demonstrating
-- the bug isn't raid/party-frame specific, since it reproduces identically
-- on the target frame alone.
SLASH_UBERUIDEBUGOVERLAPWATCH1 = "/uuidebugoverlapwatch"
SlashCmdList["UBERUIDEBUGOVERLAPWATCH"] = function(msg)
    local arg = (msg and msg:trim():lower()) or ""
    if arg == "stop" then
        StopOverlapWatcher()
    elseif arg == "clear" then
        overlapLog = {}
        overlapState = {}
        print("|cff33ff99UberUI debug|r overlap log cleared.")
    elseif arg == "" or arg == "all" then
        StartOverlapWatcher()
    else
        -- Treat anything else as an explicit single unit token to scope to.
        StartOverlapWatcher({ arg })
    end
end

SLASH_UBERUIDEBUGOVERLAPLOG1 = "/uuidebugoverlaylog"
SlashCmdList["UBERUIDEBUGOVERLAPLOG"] = function()
    if #overlapLog == 0 then
        print("|cff33ff99UberUI debug|r overlap log is empty -- nothing caught yet" ..
            (overlapTicker and " (watcher is running)." or " -- run /uuidebugoverlapwatch to start watching."))
        return
    end

    local lines = { "==== overlap watcher log (" .. #overlapLog .. " entries) ====" }
    for i, e in ipairs(overlapLog) do
        if e.type == "zonechange" then
            table.insert(lines, string.format(
                "#%d [ZONE CHANGE] time=%s sinceLogin=%ds -> zone=%s | %s",
                i, e.time, e.sinceLogin, e.zone, e.proximity))
        elseif e.type == "overlap_clear" then
            table.insert(lines, string.format(
                "#%d [OVERLAP CLEARED] time=%s sinceLogin=%ds unit=%s auraInstanceID=%s zone=%s %s inCombat=%s class=%s",
                i, e.time, e.sinceLogin, e.unit, e.auraInstanceID,
                e.zone, e.proximity, e.inCombat, e.playerClass))
        else
            table.insert(lines, string.format(
                "#%d [OVERLAP STARTED] time=%s sinceLogin=%ds unit=%s auraInstanceID=%s name=%s sourceUnit=%s zone=%s %s inCombat=%s class=%s",
                i, e.time, e.sinceLogin, e.unit, e.auraInstanceID, tostring(e.name), tostring(e.sourceUnit),
                e.zone, e.proximity, e.inCombat, e.playerClass))
        end
    end
    ShowReport(table.concat(lines, "\n"))
end

-- Taint scanner for the nameplate "attempt to compare a secret number value
-- (execution tainted by 'Uber UI')" errors. Those errors mean some value
-- Blizzard's nameplate SetUnit chain reads (a frame field, an options
-- table entry, a global) was last written by Uber UI code -- deferring our
-- own calls doesn't help if a stored value is already tainted. This asks
-- the client directly (issecurevariable) which keys are tainted, so the
-- actual source shows up instead of being guessed at.
-- Usage: /uuidebugtaint   (have a few nameplates on screen first)
local function ScanTable(add, label, t, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    if t.IsForbidden and t:IsForbidden() then
        add("  " .. label .. ": FORBIDDEN, skipped")
        return
    end
    local hits = 0
    for k in pairs(t) do
        if type(k) == "string" or type(k) == "number" then
            local secure, taintedBy = issecurevariable(t, k)
            if not secure then
                hits = hits + 1
                add(string.format("  %s.%s  tainted by %s", label, tostring(k), tostring(taintedBy)))
            end
        end
    end
    if hits == 0 then add("  " .. label .. ": clean") end
end

local function BuildTaintReport()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    local seen = {}

    add("==== globals tainted by an addon (Blizzard-looking names only) ====")
    for k in pairs(_G) do
        if type(k) == "string" and (k:find("NamePlate") or k:find("CompactUnitFrame") or k:find("TextStatusBar")
            or k:find("PixelUtil") or k:find("UnitFrame")) then
            local secure, taintedBy = issecurevariable(k)
            if not secure then add("  _G." .. k .. "  tainted by " .. tostring(taintedBy)) end
        end
    end

    add("")
    add("==== shared option tables / mixins ====")
    for _, name in ipairs({ "NamePlateSetupOptions", "NamePlateFriendlyFrameOptions", "NamePlateEnemyFrameOptions",
        "NamePlateUnitFrameMixin", "NamePlateBaseMixin", "NamePlateDriverMixin", "TextStatusBarMixin",
        "NamePlateDriverFrame", "PixelUtil" }) do
        if _G[name] then ScanTable(add, name, _G[name], seen) else add("  " .. name .. ": (nil)") end
    end

    add("")
    add("==== live nameplates ====")
    for i, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local plabel = (plate.GetName and plate:GetName()) or ("plate" .. i)
        add(plabel .. " unit=" .. tostring(plate.unitToken))
        ScanTable(add, plabel, plate, seen)
        local uf = plate.UnitFrame
        if uf then
            ScanTable(add, plabel .. ".UnitFrame", uf, seen)
            ScanTable(add, plabel .. ".UnitFrame.optionTable", uf.optionTable, seen)
            ScanTable(add, plabel .. ".UnitFrame.customOptions", uf.customOptions, seen)
            ScanTable(add, plabel .. ".UnitFrame.healthBar", uf.healthBar, seen)
            ScanTable(add, plabel .. ".UnitFrame.HealthBarsContainer", uf.HealthBarsContainer, seen)
            ScanTable(add, plabel .. ".UnitFrame.RaidTargetFrame", uf.RaidTargetFrame, seen)
            ScanTable(add, plabel .. ".UnitFrame.CastBarsContainer", uf.CastBarsContainer, seen)
            local cb = uf.castBar or (uf.CastBarsContainer and uf.CastBarsContainer.castBar)
            ScanTable(add, plabel .. ".UnitFrame.castBar", cb, seen)
            ScanTable(add, plabel .. ".UnitFrame.AurasFrame", uf.AurasFrame, seen)
        end
    end
    return table.concat(lines, "\n")
end

SLASH_UBERUIDEBUGTAINT1 = "/uuidebugtaint"
SlashCmdList["UBERUIDEBUGTAINT"] = function()
    local ok, report = pcall(BuildTaintReport)
    if not ok then
        report = "ERROR building taint report: " .. tostring(report)
    end
    print("|cff33ff99UberUI debug|r taint report ready -- see the popup window (Ctrl+A, Ctrl+C to copy).")
    ShowReport(report)
end

-- Compact party/raid aura containers (core/compactauras.lua): which frames
-- got containers, what unit each points at, how many aura buttons are
-- active per group, any AddAuraGroup errors, and the native raid frame
-- CVars we've saved/overridden.
-- Usage: /uuidebugcompact
local function BuildCompactReport()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    local ca = UberUI.compactauras
    if not ca or not ca.GetDebugInfo then return "compactauras module not loaded" end
    local info = ca:GetDebugInfo()

    add("==== compact auras ====")
    add("supported=" .. tostring(info.supported) .. " pendingCVars=" .. tostring(info.pendingCVars))
    local g = uuidb and uuidb.general or {}
    add(string.format("settings: buffs=%s debuffs=%s bigdefensive=%s",
        tostring(g.aurastyle_compactbuffs), tostring(g.aurastyle_compactdebuffs),
        tostring(g.compactbigdefensive)))

    add("")
    add("==== native CVars (current / saved original) ====")
    local saved = (uuidb and uuidb.cuf and uuidb.cuf.nativecvars) or {}
    for _, cvar in ipairs({ "raidFramesDisplayBuffs", "raidFramesDisplayDebuffs", "raidFramesCenterBigDefensive",
        "raidFramesDisplayOnlyDispellableDebuffs" }) do
        add(string.format("  %s = %s  (saved: %s)", cvar, tostring(C_CVar.GetCVar(cvar)), tostring(saved[cvar])))
    end

    add("")
    add("==== frames with containers (" .. #info.frames .. ") ====")
    table.sort(info.frames, function(a, b) return (a.frame:GetName() or "") < (b.frame:GetName() or "") end)
    for _, entry in ipairs(info.frames) do
        local frame, state = entry.frame, entry.state
        add(string.format("%s unit=%s displayedUnit=%s shown=%s", frame:GetName() or "?",
            tostring(frame.unit), tostring(frame.displayedUnit), tostring(frame:IsShown())))
        for _, key in ipairs({ "debuffs", "buffs", "bigDefensive" }) do
            local c = state[key]
            if c then
                local parts = {}
                for _, groupKey in ipairs(c.uuGroupKeys or {}) do
                    local ok, count = pcall(c.GetAuraGroupFrameCount, c, groupKey)
                    local def = c.uuGroups and c.uuGroups[groupKey]
                    parts[#parts + 1] = string.format("%s=%s@%.1fpx", groupKey, ok and tostring(count) or "err",
                        def and def.size or 0)
                end
                local okU, unit = pcall(c.GetUnit, c)
                add(string.format("  %s: unit=%s shown=%s %s", key, okU and tostring(unit) or "err",
                    tostring(c:IsShown()), table.concat(parts, " ")))
                if c.uuGroupErrors then
                    for groupKey, err in pairs(c.uuGroupErrors) do
                        add("    GROUP ERROR " .. groupKey .. ": " .. err)
                    end
                end
            end
        end
    end

    if #info.pending > 0 then
        add("")
        add("==== waiting for combat to end (" .. #info.pending .. ") ====")
        for _, frame in ipairs(info.pending) do add("  " .. (frame:GetName() or "?")) end
    end
    return table.concat(lines, "\n")
end

SLASH_UBERUIDEBUGCOMPACT1 = "/uuidebugcompact"
SlashCmdList["UBERUIDEBUGCOMPACT"] = function()
    local ok, report = pcall(BuildCompactReport)
    if not ok then
        report = "ERROR building compact report: " .. tostring(report)
    end
    print("|cff33ff99UberUI debug|r compact aura report ready -- see the popup window (Ctrl+A, Ctrl+C to copy).")
    ShowReport(report)
end

-- Opens Edit Mode so you can check its "Show Arena Frames" account setting
-- yourself -- see arenaframes:ShowFakeFrames in core/arenaframes.lua for why
-- this can't be done directly from addon code (a real click is required to
-- avoid tainting a secret-value range check on the arena-classified frame).
SLASH_UBERUIDEBUGARENA1 = "/uuidebugarena"
SlashCmdList["UBERUIDEBUGARENA"] = function()
    if not (UberUI and UberUI.arenaframes) then
        print("|cff33ff99UberUI debug|r arenaframes module not loaded.")
        return
    end
    UberUI.arenaframes:ShowFakeFrames()
end

-- /uuidebugplayerdebuffs: why is a player debuff border the wrong color?
-- For each shown DebuffFrame button: its buttonInfo.index, the aura
-- instance ID we pair it with (GetUnitAuraInstanceIDs[index], see
-- buffsandauras.lua GetPlayerDebuffInstanceID), that aura's real name and
-- dispel type (readable out of combat), and the color our dispel curve
-- returns for it. Also dumps the curve itself next to Blizzard's own
-- AuraUtil colors so a wrong dispel-type ID mapping is visible directly.
-- Run it out of combat with a couple of different-type debuffs on you.
local function SafeStr(v)
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    return tostring(v)
end

local function ColorStr(r, g, b)
    if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then return "<secret color>" end
    if type(r) ~= "number" then return tostring(r) end
    return string.format("%.2f, %.2f, %.2f", r, g, b)
end

local function BuildPlayerDebuffReport()
    local lines = {}
    local function add(s) table.insert(lines, s) end
    local SB = UberUI.squareborders
    local unit = (PlayerFrame and PlayerFrame.unit) or "player"
    add("unit = " .. tostring(unit) .. "   inCombat = " .. tostring(InCombatLockdown()))

    local ids
    if C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs then
        local ok, res = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, "HARMFUL")
        if ok then ids = res else add("GetUnitAuraInstanceIDs ERROR: " .. tostring(res)) end
    else
        add("GetUnitAuraInstanceIDs: not available")
    end
    if type(ids) == "table" then
        local parts = {}
        for i, id in ipairs(ids) do parts[#parts + 1] = i .. "=" .. SafeStr(id) end
        add("GetUnitAuraInstanceIDs(HARMFUL): " .. table.concat(parts, "  "))
    end

    add("")
    add("==== DebuffFrame buttons ====")
    local buttons = DebuffFrame and DebuffFrame.auraFrames or {}
    for n, btn in ipairs(buttons) do
        local okS, shown = pcall(btn.IsShown, btn)
        if okS and shown == true then
            local info = btn.buttonInfo
            local index = info and info.index
            local infoID = info and info.auraInstanceID
            add(string.format("button #%d  auraType=%s  buttonInfo.index=%s  buttonInfo.auraInstanceID=%s  buttonInfo.debuffType=%s",
                n, SafeStr(info and info.auraType), SafeStr(index), SafeStr(infoID), SafeStr(info and info.debuffType)))
            local id = infoID
            if (id == nil) and type(ids) == "table" and type(index) == "number" then id = ids[index] end
            add("   paired instanceID = " .. SafeStr(id))
            if id and not (issecretvalue and issecretvalue(id)) then
                local okA, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, id)
                if okA and aura and not (issecretvalue and issecretvalue(aura)) then
                    add("   that aura: " .. SafeStr(aura.name) .. "  dispelName=" .. SafeStr(aura.dispelName))
                else
                    add("   that aura: unreadable (" .. tostring(aura) .. ")")
                end
                if SB then
                    local okC, r, g, b = pcall(SB.GetDispelColor, nil, unit, id)
                    add("   curve color = " .. (okC and ColorStr(r, g, b) or ("ERROR " .. tostring(r))))
                end
            end
            -- What the button itself says it is, by index, for cross-checking order.
            if type(index) == "number" and C_UnitAuras.GetAuraDataByIndex then
                local okI, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HARMFUL")
                if okI and aura and not (issecretvalue and issecretvalue(aura)) then
                    add("   GetAuraDataByIndex(" .. index .. "): " .. SafeStr(aura.name) .. "  id=" .. SafeStr(aura.auraInstanceID)
                        .. "  dispelName=" .. SafeStr(aura.dispelName))
                end
            end
        end
    end

    add("")
    add("==== dispel curve vs Blizzard colors ====")
    local curve = SB and SB.GetDispelColorCurve and SB.GetDispelColorCurve()
    add("curve = " .. tostring(curve))
    for x = 0, 12 do
        local s = "x=" .. x
        if curve and curve.EvaluateUnpacked then
            local okE, r, g, b = pcall(curve.EvaluateUnpacked, curve, x)
            s = s .. "  curve: " .. (okE and ColorStr(r, g, b) or ("ERROR " .. tostring(r)))
        end
        add(s)
    end
    for _, key in ipairs({ "None", "Magic", "Curse", "Disease", "Poison", "Bleed" }) do
        local okC, color = pcall(AuraUtil.GetAuraBorderColor, key)
        add("AuraUtil " .. key .. ": " .. ((okC and color) and ColorStr(color:GetRGB()) or "n/a"))
    end
    return table.concat(lines, "\n")
end

SLASH_UBERUIDEBUGPLAYERDEBUFFS1 = "/uuidebugplayerdebuffs"
SlashCmdList["UBERUIDEBUGPLAYERDEBUFFS"] = function()
    local ok, report = pcall(BuildPlayerDebuffReport)
    if not ok then report = "ERROR building report: " .. tostring(report) end
    print("|cff33ff99UberUI debug|r player debuff report ready -- see the popup window (Ctrl+A, Ctrl+C to copy).")
    ShowReport(report)
end

-------------------------------------------------------------------------------
-- Nameplate aura pool load-time test (/uuidebugnppool). Measures what
-- building our own nameplate aura containers would cost, before committing
-- to the feature (docs/nameplate-auras.md). Test-only: never touches the
-- nameplate CVars or writes to Blizzard's nameplates, and does nothing
-- unless run.
--
-- One "bundle" per nameplate = 4 CustomAuraContainers using Blizzard's
-- nameplate rules (Blizzard_NamePlateAuras.lua, 12.1):
--   debuffs  1 group  HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL|PLAYER,
--                     nameplateShowPersonal (unless the show-all-personal
--                     CVar), max 12
--   buffs    2 groups IMPORTANT, and !IMPORTANT + isStealable (Blizzard:
--                     enemy buffs only if stealable or important), max 2
--   cc       2 groups CROWD_CONTROL, and !CROWD_CONTROL + nameplateShowAll
--                     (Blizzard's IsAuraCrowdControl), max 2
--   bigdebuff 1 slot  HARMFUL|CROWD_CONTROL (stand-in for the single
--                     loss-of-control icon; Blizzard reads C_LossOfControl)
-- Every AddAuraGroup pre-creates a 10-button batch: ~51 buttons per bundle.
--
-- Button setup variants (compare build cost):
--   lean    icon + stack count only -- the minimum that can display an aura
--   full    aurakit.InitAuraButton (cooldown, text holder, border frames)
--   styled  full + aurakit.ApplyAuraButtonStyle with your Target aura
--           settings, re-run on aura updates like the real containers (default)
--   lazy    full at build; styled on the bundle's first aura update (its first
--           attach), then only restyled when the style settings change. The
--           engine creates buttons in batches of 10 and hides which ones are in
--           use, so "style a button when it first shows an aura" isn't
--           possible -- this is the closest: styling moves off the loading
--           screen, and unchanged buttons are never restyled.
--
-- Usage:
--   /uuidebugnppool build <n> [variant]    build n bundles now, in one frame
--   /uuidebugnppool trickle <n> [variant]  build n bundles, one per frame
--   /uuidebugnppool login <n> [variant]    build n inside PLAYER_LOGIN on the
--                                          next /reload (loading screen); 0 = off
--   /uuidebugnppool attach                 bind bundles to visible nameplates,
--                                          time it, count shown auras, release
--   /uuidebugnppool attach show            same, but leave them visible above
--                                          each nameplate until detach
--   /uuidebugnppool live on|off            attach/release automatically as
--                                          nameplates appear/disappear (shown)
--   /uuidebugnppool detach                 release shown bundles
--   /uuidebugnppool report                 show results
-- Built bundles can't be destroyed -- /reload to clear them.
-------------------------------------------------------------------------------

local NPPool = { bundles = {}, results = {}, attached = {} }
local NP_ICON_SIZE = 20
local NP_SPACING = 2
local NP_CONTAINER_KEYS = { "debuffs", "buffs", "cc", "bigdebuff" }
local NP_VARIANTS = { lean = true, full = true, styled = true, lazy = true }

local function NPIsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function NPAddResult(line)
    NPPool.results[#NPPool.results + 1] = line
end

local function NPEnsureAuraContainer()
    if not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        if C_AddOns.DoesAddOnExist and C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        end
    end
    return C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") and AuraContainerSortMethod ~= nil
end

-- Forced collection first, so a GC landing mid-test can't skew the reading.
local function NPMemoryKB()
    collectgarbage("collect")
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        pcall(UpdateAddOnMemoryUsage)
        local ok, kb = pcall(GetAddOnMemoryUsage, addon)
        if ok and type(kb) == "number" then return kb end
    end
    return nil
end

local function NPShowAllPersonal()
    return NamePlateConstants and CVarCallbackRegistry
        and CVarCallbackRegistry:GetCVarValueBool(NamePlateConstants.SHOW_ALL_PERSONAL_AURAS_CVAR) or false
end

-- "styled": Target's aura settings stand in for future nameplate settings.
local function NPStyleButton(btn)
    local g = uuidb and uuidb.general or {}
    local style = btn.isBuff and (g.aurastyle_targetbuffs or "both") or (g.aurastyle_targetdebuffs or "zoom")
    UberUI.aurakit.ApplyAuraButtonStyle(btn, { style = style, squareLoc = "target" })
end

-- lazy: everything that changes the look, as one string; a button is only
-- restyled when this differs from what it was last styled with.
local function NPStyleKey(btn)
    local g = uuidb and uuidb.general or {}
    local SB = UberUI.squareborders
    local dc = g.darkencolor or {}
    return table.concat({
        tostring(btn.isBuff),
        tostring(btn.isBuff and g.aurastyle_targetbuffs or g.aurastyle_targetdebuffs),
        tostring(SB and SB.IsEnabled("target")), tostring(SB and SB.Thickness("target")),
        tostring(SB and SB.IsInset("target")), tostring(dc.r),
    }, "|")
end

local npLazyStyled = setmetatable({}, { __mode = "k" }) -- button -> style key
NPPool.lazyStyleCount = 0
local function NPLazyStyle(btn)
    local key = NPStyleKey(btn)
    if npLazyStyled[btn] == key then return end
    npLazyStyled[btn] = key
    NPPool.lazyStyleCount = NPPool.lazyStyleCount + 1
    NPStyleButton(btn)
end

local function NPLeanInit(c, btn, isBuff, size)
    btn:SetSize(size, size)
    btn.isBuff = isBuff
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    if btn.SetIcon then pcall(btn.SetIcon, btn, icon) end
    local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    if btn.SetApplicationCount then pcall(btn.SetApplicationCount, btn, count, {}) end
end

local function NPBuildBundle(variant)
    local aurakit = UberUI.aurakit
    local errors = {}
    -- Born with DisableUntrustedLayoutScriptsTemplate: attach show anchors the
    -- holder to a nameplate, and a frame lacking the UntrustedLayoutScript-
    -- Execution aspect can't anchor to one that has it ("Anchoring disallowed
    -- as dependent object would inherit forbidden aspects"). The aspect can
    -- only be given at creation (docs/nameplate-auras.md, EllesmereUI notes).
    local okH, holder = pcall(CreateFrame, "Frame", nil, UIParent, "DisableUntrustedLayoutScriptsTemplate")
    if not okH or not holder then holder = CreateFrame("Frame", nil, UIParent) end
    holder:SetSize(1, 1)
    holder:SetPoint("CENTER")
    holder:Hide()

    local styleFn = (variant == "styled") and NPStyleButton or nil
    local refreshFn = styleFn or ((variant == "lazy") and NPLazyStyle) or nil

    local function newContainer()
        local c = CreateFrame("AuraContainer", nil, holder, "CustomAuraContainerTemplate")
        c:SetSize(1, 1)
        c.npButtons = {} -- every button this test created, whatever the variant
        pcall(c.SetFlowLayoutAnchorPoint, c, "BOTTOMLEFT")
        pcall(c.SetFlowLayoutGrowthDirection, c, 1, 1)
        pcall(c.SetFlowLayoutMaximumLineSize, c, 6 * (NP_ICON_SIZE + NP_SPACING))
        return c
    end
    local function init(c, key, isBuff, size)
        return function(btn)
            c.npButtons[btn] = true
            if variant == "lean" then
                NPLeanInit(c, btn, isBuff, size)
            else
                aurakit.InitAuraButton(c, btn, key, isBuff, size, false, styleFn)
            end
        end
    end
    local function group(c, key, filter, maxCount, isBuff, candidates, index)
        local ok, err = pcall(c.AddAuraGroup, c, key, filter, {
            maxFrameCount = maxCount,
            candidateFilters = candidates,
            initializeFrame = init(c, key, isBuff, NP_ICON_SIZE),
            layout = aurakit.MakeGroupLayout(NP_ICON_SIZE, NP_SPACING, NP_SPACING, false, index, true),
        })
        if not ok then errors[#errors + 1] = key .. ": " .. tostring(err) end
    end

    local b = { holder = holder, errors = errors, variant = variant }

    b.debuffs = newContainer()
    group(b.debuffs, "debuffs", "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL|PLAYER", 12, false,
        { nameplateShowAll = false, nameplateShowPersonal = (not NPShowAllPersonal()) or nil }, 1)

    b.buffs = newContainer()
    group(b.buffs, "important", "HELPFUL|INCLUDE_NAME_PLATE_ONLY|IMPORTANT", 2, true, nil, 1)
    group(b.buffs, "stealable", "HELPFUL|INCLUDE_NAME_PLATE_ONLY|!IMPORTANT", 2, true, { isStealable = true }, 2)

    b.cc = newContainer()
    group(b.cc, "cc", "HARMFUL|CROWD_CONTROL", 2, false, nil, 1)
    group(b.cc, "showall", "HARMFUL|!CROWD_CONTROL", 2, false, { nameplateShowAll = true }, 2)

    b.bigdebuff = newContainer()
    local okS, errS = pcall(b.bigdebuff.AddAuraSlot, b.bigdebuff, "bigdebuff", "HARMFUL|CROWD_CONTROL", {
        initializeFrame = init(b.bigdebuff, "bigdebuff", false, NP_ICON_SIZE * 2),
    })
    if not okS then errors[#errors + 1] = "bigdebuff: " .. tostring(errS) end

    -- styled/lazy: (re)style on aura updates, the same hooks the real
    -- containers use (our own frames, so always safe).
    if refreshFn then
        for _, key in ipairs(NP_CONTAINER_KEYS) do
            local c = b[key]
            local function refresh()
                for btn in pairs(c.npButtons) do pcall(refreshFn, btn) end
            end
            if c.UpdateAllAuras then hooksecurefunc(c, "UpdateAllAuras", refresh) end
            if c.UpdateAuraGroup then hooksecurefunc(c, "UpdateAuraGroup", refresh) end
        end
    end
    return b
end

-- Buttons created / buttons currently showing an aura / unreadable (secret).
local function NPCountButtons(b)
    local total, shown, unknown = 0, 0, 0
    for _, key in ipairs(NP_CONTAINER_KEYS) do
        local c = b[key]
        for btn in pairs(c and c.npButtons or {}) do
            total = total + 1
            if NPIsSecret(btn) then
                unknown = unknown + 1
            else
                local ok, isShown = pcall(btn.IsShown, btn)
                if not ok or NPIsSecret(isShown) then
                    unknown = unknown + 1
                elseif isShown then
                    shown = shown + 1
                end
            end
        end
    end
    return total, shown, unknown
end

local function NPSummarizeBuild(label, variant, count, total, maxOne, memBefore, extra, builtInCombat)
    local buttons, errs = 0, 0
    local firstErr
    for i = #NPPool.bundles - count + 1, #NPPool.bundles do
        local b = NPPool.bundles[i]
        if b then
            buttons = buttons + (NPCountButtons(b))
            errs = errs + #b.errors
            firstErr = firstErr or b.errors[1]
        end
    end
    local memAfter = NPMemoryKB()
    NPAddResult(string.format("[%s, %s%s] %d bundles: total %.1f ms, avg %.2f ms/bundle, slowest %.2f ms, %d buttons (%.3f ms/button)",
        label, variant, builtInCombat and ", BUILT IN COMBAT" or "", count, total,
        count > 0 and total / count or 0, maxOne, buttons, buttons > 0 and total / buttons or 0))
    if memBefore and memAfter then
        NPAddResult(string.format("    addon memory %+.0f KB after GC (%.2f KB/bundle; now %.0f KB)",
            memAfter - memBefore, count > 0 and (memAfter - memBefore) / count or 0, memAfter))
    end
    if extra then NPAddResult("    " .. extra) end
    if errs > 0 then
        NPAddResult(string.format("    %d group/slot errors, first: %s", errs, tostring(firstErr)))
    end
    NPAddResult(string.format("    pool now holds %d bundles", #NPPool.bundles))
end

local function NPBuildSync(count, variant, label)
    if not NPEnsureAuraContainer() then
        NPAddResult("Blizzard_AuraContainer not available on this client")
        return
    end
    local memBefore = NPMemoryKB()
    local builtInCombat = InCombatLockdown()
    local total, maxOne = 0, 0
    for _ = 1, count do
        local t0 = debugprofilestop()
        NPPool.bundles[#NPPool.bundles + 1] = NPBuildBundle(variant)
        local dt = debugprofilestop() - t0
        total = total + dt
        if dt > maxOne then maxOne = dt end
    end
    NPSummarizeBuild(label or "sync build", variant, count, total, maxOne, memBefore, nil, builtInCombat)
end

local npTrickleFrame
local function NPBuildTrickle(count, variant, onDone)
    if not NPEnsureAuraContainer() then
        NPAddResult("Blizzard_AuraContainer not available on this client")
        if onDone then onDone() end
        return
    end
    npTrickleFrame = npTrickleFrame or CreateFrame("Frame")
    local memBefore = NPMemoryKB()
    local built, total, maxOne = 0, 0, 0
    local startTime = GetTime()
    npTrickleFrame:SetScript("OnUpdate", function(self)
        local t0 = debugprofilestop()
        NPPool.bundles[#NPPool.bundles + 1] = NPBuildBundle(variant)
        local dt = debugprofilestop() - t0
        built, total = built + 1, total + dt
        if dt > maxOne then maxOne = dt end
        if built >= count then
            self:SetScript("OnUpdate", nil)
            NPSummarizeBuild("trickle, 1/frame", variant, count, total, maxOne, memBefore,
                string.format("spread over %.2f s of frames; worst single-frame cost %.2f ms", GetTime() - startTime, maxOne))
            if onDone then onDone() end
        end
    end)
end

local function NPRelease(b)
    for _, key in ipairs(NP_CONTAINER_KEYS) do
        pcall(b[key].SetUnit, b[key], "none")
        if b[key].npOutline then b[key].npOutline:Hide() end
    end
    b.holder:Hide()
    b.holder:ClearAllPoints()
    b.holder:SetPoint("CENTER")
    b.inUse = nil
end

local function NPDetachAll()
    local n = 0
    for _, b in ipairs(NPPool.attached) do
        NPRelease(b)
        n = n + 1
    end
    wipe(NPPool.attached)
    return n
end

-- show mode: rows above the nameplate -- CC and big debuff on the left,
-- debuffs, buffs above them. Only our frames get positioned; anchoring to
-- the plate doesn't write anything to Blizzard's frame.
-- Magenta 1px outline around each of our containers (they resize to their
-- content), so ours can't be mistaken for Blizzard's own icons. Once a
-- container has an aura group, only frames born with
-- DisableUntrustedLayoutScriptsTemplate may anchor to it (Blizzard's
-- AddAuraGroup comment), so the outline gets its own frame from that
-- template, parented to the bundle's holder. Test-only; failure is ignored.
local function NPOutline(c, holder)
    if not c.npOutline then
        local ok, f = pcall(CreateFrame, "Frame", nil, holder, "DisableUntrustedLayoutScriptsTemplate")
        if not ok or not f then return end
        f:SetFrameLevel(c:GetFrameLevel() + 20)
        f:EnableMouse(false)
        local okP = pcall(function()
            f:SetPoint("TOPLEFT", c, "TOPLEFT", -1, 1)
            f:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 1, -1)
        end)
        if not okP then return end
        for _, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                               { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
            local t = f:CreateTexture(nil, "OVERLAY")
            t:SetColorTexture(1, 0, 1, 1)
            t:SetPoint(pts[1], f, pts[1])
            t:SetPoint(pts[2], f, pts[2])
            if pts[3] then t:SetHeight(1) else t:SetWidth(1) end
        end
        c.npOutline = f
    end
    c.npOutline:Show()
end

-- Each anchor step is labelled, so a restriction error names the exact
-- anchor that failed. Returns the first failure (or nil).
local function NPLayoutShown(b, plate)
    local failed
    local function step(label, fn)
        local ok, err = pcall(fn)
        if not ok and not failed then failed = label .. ": " .. tostring(err) end
    end
    -- Well clear of Blizzard's own nameplate auras, which sit just above the
    -- plate.
    step("holder -> nameplate", function()
        b.holder:ClearAllPoints()
        b.holder:SetPoint("BOTTOM", plate, "TOP", 0, 46)
    end)
    step("debuffs -> holder", function()
        b.debuffs:ClearAllPoints()
        b.debuffs:SetPoint("BOTTOMLEFT", b.holder, "BOTTOM", -50, 0)
    end)
    step("buffs -> debuffs", function()
        b.buffs:ClearAllPoints()
        b.buffs:SetPoint("BOTTOMLEFT", b.debuffs, "TOPLEFT", 0, NP_SPACING + NP_ICON_SIZE)
    end)
    step("cc -> holder", function()
        b.cc:ClearAllPoints()
        b.cc:SetPoint("BOTTOMRIGHT", b.holder, "BOTTOM", -54, 0)
    end)
    step("bigdebuff -> cc", function()
        b.bigdebuff:ClearAllPoints()
        b.bigdebuff:SetPoint("BOTTOMRIGHT", b.cc, "BOTTOMLEFT", -2 * (NP_ICON_SIZE + NP_SPACING) - 4, 0)
    end)
    for _, key in ipairs(NP_CONTAINER_KEYS) do
        step("outline -> " .. key, function() NPOutline(b[key], b.holder) end)
    end
    return failed
end

-- Binds bundles to the visible nameplates the way a real version would on
-- NAME_PLATE_UNIT_ADDED: per-plate filters from Blizzard's own settings
-- (friend/enemy, player/NPC, the aura display CVars), then SetUnit, which
-- runs the engine's synchronous aura parse.
-- Binds one bundle to one nameplate unit the way a real version would on
-- NAME_PLATE_UNIT_ADDED: per-plate filters from Blizzard's own settings
-- (friend/enemy, player/NPC, the aura display CVars), then SetUnit, which
-- runs the engine's synchronous aura parse. Returns the time taken and a
-- description of what was turned on.
local function NPBind(b, unit)
    local isFriend = UnitIsFriend("player", unit)
    local isPlayer = UnitIsPlayer(unit)
    local t0 = debugprofilestop()

    -- Blizzard: enemy debuffs must be yours; friendly buffs must be yours.
    pcall(b.debuffs.SetAuraGroupFilterString, b.debuffs, "debuffs",
        isFriend and "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL"
        or "HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL|PLAYER")
    pcall(b.buffs.SetAuraGroupFilterString, b.buffs, "important",
        isFriend and "HELPFUL|INCLUDE_NAME_PLATE_ONLY|PLAYER" or "HELPFUL|INCLUDE_NAME_PLATE_ONLY|IMPORTANT")
    pcall(b.buffs.SetAuraGroupMaxFrameCount, b.buffs, "stealable", isFriend and 0 or 2)

    -- Which categories Blizzard's settings show for this unit type.
    local npBit = CVarCallbackRegistry and NamePlateConstants and function(cvar, index)
        return CVarCallbackRegistry:GetCVarBitfieldIndex(cvar, index)
    end
    local showBuffs, showDebuffs, showCC, showBig = true, true, true, false
    if npBit then
        local E = Enum
        if isFriend then
            showBuffs = isPlayer and npBit(NamePlateConstants.FRIENDLY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateFriendlyPlayerAuraDisplay.Buffs) or false
            showDebuffs = CVarCallbackRegistry:GetCVarValueBool(NamePlateConstants.SHOW_DEBUFFS_ON_FRIENDLY_CVAR)
            showCC = false
            showBig = isPlayer and npBit(NamePlateConstants.FRIENDLY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateFriendlyPlayerAuraDisplay.LossOfControl) or false
        elseif isPlayer then
            showBuffs = npBit(NamePlateConstants.ENEMY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateEnemyPlayerAuraDisplay.Buffs)
            showDebuffs = npBit(NamePlateConstants.ENEMY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateEnemyPlayerAuraDisplay.Debuffs)
            showCC = false
            showBig = npBit(NamePlateConstants.ENEMY_PLAYER_AURA_DISPLAY_CVAR, E.NamePlateEnemyPlayerAuraDisplay.LossOfControl)
        else
            showBuffs = npBit(NamePlateConstants.ENEMY_NPC_AURA_DISPLAY_CVAR, E.NamePlateEnemyNpcAuraDisplay.Buffs)
            showDebuffs = npBit(NamePlateConstants.ENEMY_NPC_AURA_DISPLAY_CVAR, E.NamePlateEnemyNpcAuraDisplay.Debuffs)
            showCC = npBit(NamePlateConstants.ENEMY_NPC_AURA_DISPLAY_CVAR, E.NamePlateEnemyNpcAuraDisplay.CrowdControl)
            showBig = false
        end
    end

    b.holder:Show()
    for key, shown in pairs({ debuffs = showDebuffs, buffs = showBuffs, cc = showCC, bigdebuff = showBig }) do
        local c = b[key]
        c:SetShown(shown and true or false)
        if shown then pcall(c.SetUnit, c, unit) end
    end
    local dt = debugprofilestop() - t0
    local desc = string.format("%s %s -- categories on: %s%s%s%s",
        isFriend and "friendly" or "enemy", isPlayer and "player" or "NPC",
        showDebuffs and "debuffs " or "", showBuffs and "buffs " or "", showCC and "cc " or "",
        showBig and "big" or "")
    return dt, desc
end

local function NPAttachTest(show)
    NPDetachAll()
    for _, b in ipairs(NPPool.bundles) do b.inUse = nil end

    local plates = C_NamePlate and C_NamePlate.GetNamePlates() or {}
    local targets = {}
    for _, plate in ipairs(plates) do
        if not (plate.IsForbidden and plate:IsForbidden()) then
            local unit = plate.unitToken or plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if unit then targets[#targets + 1] = { unit = unit, plate = plate } end
        end
    end
    if #targets == 0 then
        NPAddResult("[attach] no visible nameplates -- stand near some units and run again")
        return
    end

    -- Prefer styled/lazy bundles (closest to real); top up with styled.
    local pick = {}
    local pickedVariants = {}
    for _, b in ipairs(NPPool.bundles) do
        if (b.variant == "styled" or b.variant == "lazy") and #pick < #targets then
            pick[#pick + 1] = b
            pickedVariants[b.variant] = (pickedVariants[b.variant] or 0) + 1
        end
    end
    if #pick < #targets then
        local before = #NPPool.bundles
        pickedVariants.styled = (pickedVariants.styled or 0) + (#targets - #pick)
        NPBuildSync(#targets - #pick, "styled", "attach top-up build")
        for i = before + 1, #NPPool.bundles do pick[#pick + 1] = NPPool.bundles[i] end
    end

    local total, maxOne = 0, 0
    local perUnit = {}
    local lazyBefore = NPPool.lazyStyleCount
    for i, t in ipairs(targets) do
        local b, unit = pick[i], t.unit
        b.inUse = true
        local dt, desc = NPBind(b, unit)

        total = total + dt
        if dt > maxOne then maxOne = dt end

        if show then
            local failed = NPLayoutShown(b, t.plate)
            if failed then perUnit[#perUnit + 1] = "    LAYOUT FAILED on " .. unit .. " -- " .. failed end
        end

        local _, shownAuras, unknown = NPCountButtons(b)
        perUnit[#perUnit + 1] = string.format("    %s: %d auras shown%s -- %s", unit, shownAuras,
            unknown > 0 and (" + " .. unknown .. " unreadable") or "", desc)
        NPPool.attached[#NPPool.attached + 1] = b
    end
    local variants = {}
    for v, n in pairs(pickedVariants) do variants[#variants + 1] = n .. " " .. v end
    NPAddResult(string.format("[attach%s] %d nameplates: total %.2f ms, avg %.3f ms/plate, slowest %.3f ms (bundles: %s)",
        show and " show" or "", #targets, total, total / #targets, maxOne, table.concat(variants, ", ")))
    if NPPool.lazyStyleCount > lazyBefore then
        NPAddResult(string.format("    lazy: %d buttons styled during this attach (first use of those bundles)",
            NPPool.lazyStyleCount - lazyBefore))
    end
    NPAddResult("    (unreadable = the engine hides which buttons are in use; verify with attach show)")
    for _, line in ipairs(perUnit) do NPAddResult(line) end

    if show then
        NPAddResult("    ours are the MAGENTA-outlined rows well above each nameplate (Blizzard's stay in their"
            .. " usual spot) -- /uuidebugnppool detach to release (snapshot: new plates need attach again)")
    else
        local r0 = debugprofilestop()
        local n = NPDetachAll()
        NPAddResult(string.format("    release: %.2f ms for %d plates", debugprofilestop() - r0, n))
    end
end

-- Live mode: attach a bundle as each nameplate appears and release it when
-- the plate goes away, like the real feature would (minus hiding Blizzard's
-- own auras). Attach is deferred a frame -- this file's nameplate taint rule.
-- Plates beyond the pool size get nothing (Blizzard's auras only) and are
-- counted.
local npLive = { on = false, byUnit = {}, seq = {}, attaches = 0, total = 0, maxOne = 0,
                 releases = 0, releaseTotal = 0, exhausted = 0, peak = 0 }
local npLiveFrame = CreateFrame("Frame")

local function NPLiveInUse()
    local n = 0
    for _ in pairs(npLive.byUnit) do n = n + 1 end
    return n
end

local function NPLiveAttach(unit)
    if not npLive.on or npLive.byUnit[unit] then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    local b
    for _, cand in ipairs(NPPool.bundles) do
        if not cand.inUse then b = cand break end
    end
    if not b then
        npLive.exhausted = npLive.exhausted + 1
        return
    end
    b.inUse = true
    npLive.byUnit[unit] = b
    local dt = NPBind(b, unit)
    NPLayoutShown(b, plate)
    npLive.attaches = npLive.attaches + 1
    npLive.total = npLive.total + dt
    if dt > npLive.maxOne then npLive.maxOne = dt end
    local inUse = NPLiveInUse()
    if inUse > npLive.peak then npLive.peak = inUse end
end

local function NPLiveRelease(unit)
    local b = npLive.byUnit[unit]
    if not b then return end
    local t0 = debugprofilestop()
    NPRelease(b)
    npLive.byUnit[unit] = nil
    npLive.releases = npLive.releases + 1
    npLive.releaseTotal = npLive.releaseTotal + (debugprofilestop() - t0)
end

npLiveFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        -- A token can be removed and re-added before the deferred attach
        -- runs; the sequence number makes a stale attach a no-op.
        local seq = (npLive.seq[unit] or 0) + 1
        npLive.seq[unit] = seq
        C_Timer.After(0, function()
            if npLive.seq[unit] == seq then pcall(NPLiveAttach, unit) end
        end)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        npLive.seq[unit] = (npLive.seq[unit] or 0) + 1
        pcall(NPLiveRelease, unit)
    end
end)

local function NPLiveSummary()
    return string.format("[live %s] pool %d, in use %d (peak %d); %d attaches avg %.3f ms, slowest %.3f ms;"
        .. " %d releases avg %.3f ms; %d plates got nothing (pool empty)",
        npLive.on and "on" or "off", #NPPool.bundles, NPLiveInUse(), npLive.peak, npLive.attaches,
        npLive.attaches > 0 and npLive.total / npLive.attaches or 0, npLive.maxOne,
        npLive.releases, npLive.releases > 0 and npLive.releaseTotal / npLive.releases or 0,
        npLive.exhausted)
end

local function NPLiveOn()
    if npLive.on then return end
    NPDetachAll()
    for _, b in ipairs(NPPool.bundles) do b.inUse = nil end
    if #NPPool.bundles == 0 then
        NPBuildSync(25, "styled", "live: no pool yet, built")
    end
    npLive.on = true
    npLive.attaches, npLive.total, npLive.maxOne = 0, 0, 0
    npLive.releases, npLive.releaseTotal, npLive.exhausted, npLive.peak = 0, 0, 0, 0
    npLiveFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    npLiveFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        if not (plate.IsForbidden and plate:IsForbidden()) then
            local unit = plate.unitToken or plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if unit then pcall(NPLiveAttach, unit) end
        end
    end
end

local function NPLiveOff()
    if not npLive.on then return end
    npLive.on = false
    npLiveFrame:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
    npLiveFrame:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
    for unit in pairs(npLive.byUnit) do NPLiveRelease(unit) end
end

local npLiveRestore = CreateFrame("Frame")
npLiveRestore:RegisterEvent("PLAYER_ENTERING_WORLD")
npLiveRestore:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if uuidb and uuidb.general and uuidb.general.debug_nppool_live then
        C_Timer.After(1, function()
            pcall(NPLiveOn)
            print("|cff33ff99UberUI debug|r nameplate live mode restored after reload (/uuidebugnppool live off to stop).")
        end)
    end
end)

local function NPReport()
    local lines = { "==== nameplate aura pool test ====", "client: " .. (select(4, GetBuildInfo()) or "?")
        .. "  in combat: " .. tostring(InCombatLockdown()) }
    local pending = uuidb and uuidb.general and uuidb.general.debug_nppool_login
    lines[#lines + 1] = "login test on next /reload: " .. (pending and pending > 0
        and (pending .. " bundles, " .. (uuidb.general.debug_nppool_variant or "styled")) or "off")
    lines[#lines + 1] = NPLiveSummary()
    lines[#lines + 1] = ""
    if #NPPool.results == 0 then
        lines[#lines + 1] = "(no results yet)"
    else
        for _, l in ipairs(NPPool.results) do lines[#lines + 1] = l end
    end
    return table.concat(lines, "\n")
end

-- Login mode: runs inside PLAYER_LOGIN (still behind the loading screen),
-- report shown once the world is up.
local npLoginFrame = CreateFrame("Frame")
npLoginFrame:RegisterEvent("PLAYER_LOGIN")
npLoginFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        local n = uuidb and uuidb.general and tonumber(uuidb.general.debug_nppool_login)
        if not n or n <= 0 then return end
        local variant = uuidb.general.debug_nppool_variant
        if not NP_VARIANTS[variant] then variant = "styled" end
        NPBuildSync(n, variant, "PLAYER_LOGIN (loading screen)")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        C_Timer.After(2, function()
            print("|cff33ff99UberUI debug|r nameplate pool login test done -- see the popup. (/uuidebugnppool login 0 to turn it off)")
            ShowReport(NPReport())
        end)
    end
end)

-- /uuidebugrings: the white rounded purgeable-buff rings (aurakit
-- stealableRing) -- created / engine-registered / shown, and what a shown one
-- is actually drawing.
-- /uuidebugcdm: Cooldown Manager icons -- debuff border, our square border
-- color, pandemic state.
SLASH_UBERUIDEBUGCDM1 = "/uuidebugcdm"
SlashCmdList["UBERUIDEBUGCDM"] = function()
    if UberUI.cdManager and UberUI.cdManager.DebugReport then
        ShowReport(UberUI.cdManager:DebugReport())
    end
end

SLASH_UBERUIDEBUGRINGS1 = "/uuidebugrings"
SlashCmdList["UBERUIDEBUGRINGS"] = function()
    local summary, lines = UberUI.aurakit.DebugStealableRings()
    print("|cff33ff99UberUI debug|r " .. summary)
    for _, l in ipairs(lines) do print(l) end
end

SLASH_UBERUIDEBUGNPPOOL1 = "/uuidebugnppool"
SlashCmdList["UBERUIDEBUGNPPOOL"] = function(msg)
    local cmd, arg1, arg2 = strsplit(" ", strtrim(msg or ""))
    cmd = (cmd or ""):lower()
    local n = tonumber(arg1)
    local variant = (arg2 or ""):lower()
    if not NP_VARIANTS[variant] then variant = "styled" end
    local ok, err = pcall(function()
        if cmd == "build" then
            NPBuildSync(n or 20, variant)
        elseif cmd == "trickle" then
            print("|cff33ff99UberUI debug|r building " .. (n or 20) .. " " .. variant .. " bundles, one per frame...")
            NPBuildTrickle(n or 20, variant, function()
                print("|cff33ff99UberUI debug|r nameplate pool trickle build done.")
                ShowReport(NPReport())
            end)
            return "noreport"
        elseif cmd == "attach" then
            NPAttachTest((arg1 or ""):lower() == "show")
        elseif cmd == "live" then
            if (arg1 or ""):lower() == "off" then
                uuidb.general.debug_nppool_live = nil
                NPLiveOff()
                NPAddResult(NPLiveSummary())
                print("|cff33ff99UberUI debug|r nameplate live mode off.")
            else
                uuidb.general.debug_nppool_live = true
                NPLiveOn()
                print("|cff33ff99UberUI debug|r nameplate live mode ON (stays on across /reload): our styled auras"
                    .. " (magenta boxes) follow nameplates as they appear. /uuidebugnppool live off to stop, report for stats.")
                return "noreport"
            end
        elseif cmd == "detach" then
            NPAddResult(string.format("[detach] released %d bundles", NPDetachAll()))
        elseif cmd == "login" then
            uuidb.general.debug_nppool_login = n or 0
            uuidb.general.debug_nppool_variant = variant
            print("|cff33ff99UberUI debug|r nameplate pool login test: "
                .. ((n and n > 0) and (n .. " " .. variant .. " bundles on the next /reload") or "off"))
            return "noreport"
        elseif cmd == "report" or cmd == "" then
            -- just show
        else
            print("|cff33ff99UberUI debug|r usage: /uuidebugnppool build <n> [lean|full|styled|lazy] | trickle <n> [variant] | login <n> [variant] | attach [show] | live on|off | detach | report")
            return "noreport"
        end
    end)
    if not ok then NPAddResult("ERROR: " .. tostring(err)) end
    if ok and err == "noreport" then return end
    ShowReport(NPReport())
end

-------------------------------------------------------------------------------
-- Nameplate health bar layering/border diagnostics (/uuidebugnpbar).
-- Reports, for the target's nameplate (or the first visible one), the draw
-- layers, textures/atlases, vertex colors and screen rects of the health
-- bar's fill (barTexture) and border (bgTexture), so overlap and our
-- darkening can be read off directly. A/B switches (visible plates only,
-- until reload / the next re-style):
--   /uuidebugnpbar           report
--   /uuidebugnpbar border    set the border's (bgTexture) tint back to white
--   /uuidebugnpbar dark      re-apply our darkness tint to the border
--   /uuidebugnpbar blizzbar  put Blizzard's own bar atlas back on the fill
--   /uuidebugnpbar layers | snap | diff   full draw-order dump / compare
--   /uuidebugnpbar level                  Forever level badge regions (alpha, shown)
--   /uuidebugnpbar bgtop | bgback         raise the border texture above the
--                                         fill / put it back (test)
-- Read-only except for those switches; never touches Lua fields.
-------------------------------------------------------------------------------

local function NBSecret(v) return issecretvalue and issecretvalue(v) end

local function NBFmt(...)
    local out = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if NBSecret(v) then
            out[#out + 1] = "<secret>"
        elseif type(v) == "number" then
            out[#out + 1] = string.format("%.2f", v)
        else
            out[#out + 1] = tostring(v)
        end
    end
    return table.concat(out, ", ")
end

local function NBCall(obj, method, ...)
    if not obj or not obj[method] then return "n/a" end
    local r = { pcall(obj[method], obj, ...) }
    if not r[1] then return "error: " .. tostring(r[2]) end
    return NBFmt(select(2, unpack(r)))
end

local function NBRect(region)
    if not region then return "n/a" end
    local ok, l, b, w, h = pcall(region.GetRect, region)
    if not ok then return "error" end
    if NBSecret(l) or NBSecret(b) or NBSecret(w) or NBSecret(h) then return "<secret>" end
    if not l then return "(no rect)" end
    return string.format("left %.1f right %.1f bottom %.1f top %.1f (w %.1f h %.1f)", l, l + w, b, b + h, w, h)
end

local function NBTargetPlates()
    local plates = {}
    local target = C_NamePlate.GetNamePlateForUnit("target")
    if target then plates[1] = target end
    for _, p in ipairs(C_NamePlate.GetNamePlates() or {}) do
        if p ~= target then plates[#plates + 1] = p end
    end
    return plates
end

local function NBHealthBar(plate)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return nil end
    local uf = plate.UnitFrame
    if not uf or (uf.IsForbidden and uf:IsForbidden()) then return nil end
    local hb = uf.healthBar
    if not hb or (hb.IsForbidden and hb:IsForbidden()) then return nil end
    return hb, uf
end

local function BuildNamePlateBarReport()
    local lines = { "==== nameplate health bar report ====" }
    local function add(s) lines[#lines + 1] = s end
    local style = NamePlateConstants and CVarCallbackRegistry
        and CVarCallbackRegistry:GetCVarNumberOrDefault(NamePlateConstants.STYLE_CVAR)
    add("client: " .. tostring(select(4, GetBuildInfo())) .. "  nameplateStyle cvar: " .. tostring(style))
    local dc = uuidb and uuidb.general and uuidb.general.darkencolor
    add("our darkness color: " .. (dc and NBFmt(dc.r, dc.g, dc.b, dc.a) or "n/a"))

    local shown = 0
    for _, plate in ipairs(NBTargetPlates()) do
        local hb, uf = NBHealthBar(plate)
        if hb and shown < 2 then
            shown = shown + 1
            local unit = plate.unitToken or plate.namePlateUnitToken or uf.unit
            add("")
            add(string.format("-- %s%s --", tostring(unit),
                (unit and UnitIsUnit(unit, "target")) and " (target)" or ""))
            local bar, fill, bg = hb.barTexture, hb:GetStatusBarTexture(), hb.bgTexture
            add("healthBar frame level: " .. NBCall(hb, "GetFrameLevel") .. "  strata: " .. NBCall(hb, "GetFrameStrata"))
            add("healthBar rect: " .. NBRect(hb))
            add("fill = barTexture (same object)? " .. tostring(fill == bar))
            for label, t in pairs({ ["barTexture (fill)"] = bar, ["GetStatusBarTexture"] = (fill ~= bar) and fill or nil,
                                    ["bgTexture (border)"] = bg }) do
                add(label .. ":")
                add("    draw layer: " .. NBCall(t, "GetDrawLayer"))
                add("    texture: " .. NBCall(t, "GetTexture") .. "   atlas: " .. NBCall(t, "GetAtlas"))
                add("    vertex color: " .. NBCall(t, "GetVertexColor") .. "   alpha: " .. NBCall(t, "GetAlpha")
                    .. "   shown: " .. NBCall(t, "IsShown"))
                add("    texcoords: " .. NBCall(t, "GetTexCoord"))
                add("    rect: " .. NBRect(t))
            end
            add("selectedBorder: layer " .. NBCall(hb.selectedBorder, "GetDrawLayer") .. ", shown " .. NBCall(hb.selectedBorder, "IsShown"))
        end
    end
    if shown == 0 then add("no readable nameplates -- target something with a nameplate showing") end
    return table.concat(lines, "\n")
end

local function NBForEachBar(fn)
    local n = 0
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local hb = NBHealthBar(plate)
        if hb then
            if pcall(fn, hb) then n = n + 1 end
        end
    end
    return n
end


-- Full draw-order dump of a nameplate's health bar (/uuidebugnpbar layers),
-- with snapshot/diff to compare Blizzard's texture against ours:
--   /uuidebugnpbar layers   every region of the health bar and its container,
--                           sorted in actual draw order
--   /uuidebugnpbar snap     remember the current dump
--   /uuidebugnpbar diff     show only what changed since the snapshot
-- Within one frame, regions draw BACKGROUND < BORDER < ARTWORK < OVERLAY <
-- HIGHLIGHT, then by sublevel (-8..7); a child frame draws above all of its
-- parent's regions, and frames draw by frame level.
local NB_LAYER_ORDER = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4, HIGHLIGHT = 5 }
local npbarSnapshot

-- parentKey names: Blizzard stores regions as fields on their frame, so a
-- reverse lookup of the frame's own fields names them (read-only).
local function NBKeyNames(frame)
    local names = {}
    pcall(function()
        for k, v in pairs(frame) do
            if type(k) == "string" and type(v) == "table" and not NBSecret(v) and v.GetObjectType then
                names[v] = names[v] or k
            end
        end
    end)
    return names
end

local function NBRegionLines(frame, frameLabel, out)
    local names = NBKeyNames(frame)
    local entries = {}
    local ok, regions = pcall(function() return { frame:GetRegions() } end)
    if not ok then return end
    for _, r in ipairs(regions) do
        local okL, layer, sub = pcall(r.GetDrawLayer, r)
        if okL and not NBSecret(layer) then
            local okT, objType = pcall(r.GetObjectType, r)
            local tex = r.GetAtlas and select(2, pcall(r.GetAtlas, r)) or nil
            if not tex or tex == "" then tex = r.GetTexture and select(2, pcall(r.GetTexture, r)) or nil end
            if NBSecret(tex) then tex = "<secret>" end
            local okS, shown = pcall(r.IsShown, r)
            local okV, vr, vg, vb, va = pcall(r.GetVertexColor, r)
            entries[#entries + 1] = {
                order = (NB_LAYER_ORDER[layer] or 9) * 100 + ((not NBSecret(sub) and sub) or 0),
                text = string.format("  %-9s %2s  %-22s %-12s shown=%-5s tint=%s  %s",
                    tostring(layer), tostring(NBSecret(sub) and "?" or sub), names[r] or "(unnamed)",
                    okT and tostring(objType) or "?", okS and tostring(shown) or "?",
                    okV and NBFmt(vr, vg, vb, va) or "n/a", tostring(tex)),
            }
        end
    end
    table.sort(entries, function(a, b) return a.order < b.order end)
    out[#out + 1] = string.format("%s  [frame level %s]  -- draw order, bottom to top:", frameLabel,
        NBCall(frame, "GetFrameLevel"))
    for _, e in ipairs(entries) do out[#out + 1] = e.text end
end

local function BuildNamePlateLayerLines()
    local out = {}
    local plate
    local target = C_NamePlate.GetNamePlateForUnit("target")
    for _, p in ipairs(target and { target } or (C_NamePlate.GetNamePlates() or {})) do
        if NBHealthBar(p) then plate = p break end
    end
    local hb = plate and NBHealthBar(plate)
    if not hb then
        out[1] = "no readable nameplate -- target something with a nameplate showing"
        return out
    end
    local container = hb:GetParent()
    NBRegionLines(container, "HealthBarsContainer", out)
    NBRegionLines(hb, "healthBar (StatusBar)", out)
    out[#out + 1] = "  fill (GetStatusBarTexture) is barTexture? " .. tostring(hb:GetStatusBarTexture() == hb.barTexture)
    -- Child frames draw above all of healthBar's own regions.
    local ok, kids = pcall(function() return { hb:GetChildren() } end)
    if ok then
        local names = NBKeyNames(hb)
        for _, k in ipairs(kids) do
            out[#out + 1] = string.format("  child frame %-20s level %s shown %s", names[k] or "(unnamed)",
                NBCall(k, "GetFrameLevel"), NBCall(k, "IsShown"))
        end
    end
    return out
end

SLASH_UBERUIDEBUGNPBAR1 = "/uuidebugnpbar"
SlashCmdList["UBERUIDEBUGNPBAR"] = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "layers" or cmd == "snap" or cmd == "diff" then
        local ok, lines = pcall(BuildNamePlateLayerLines)
        if not ok then
            ShowReport("ERROR building layer dump: " .. tostring(lines))
            return
        end
        if cmd == "snap" then
            npbarSnapshot = lines
            print("|cff33ff99UberUI debug|r nameplate layer snapshot saved (" .. #lines .. " lines). Change something, then /uuidebugnpbar diff.")
            return
        elseif cmd == "diff" then
            if not npbarSnapshot then
                print("|cff33ff99UberUI debug|r no snapshot yet -- run /uuidebugnpbar snap first.")
                return
            end
            local before, after = {}, {}
            for _, l in ipairs(npbarSnapshot) do before[l] = true end
            for _, l in ipairs(lines) do after[l] = true end
            local out = { "==== nameplate layer diff (snapshot -> now) ====", "-- only in SNAPSHOT:" }
            for _, l in ipairs(npbarSnapshot) do if not after[l] then out[#out + 1] = l end end
            out[#out + 1] = "-- only NOW:"
            for _, l in ipairs(lines) do if not before[l] then out[#out + 1] = l end end
            out[#out + 1] = ""
            out[#out + 1] = "==== full dump now ===="
            for _, l in ipairs(lines) do out[#out + 1] = l end
            ShowReport(table.concat(out, "\n"))
            return
        end
        ShowReport("==== nameplate health bar draw layers ====\n" .. table.concat(lines, "\n"))
        return
    elseif cmd == "level" then
        -- Forever's level badge (PlayerLevelDiffFrame) on every visible
        -- plate: which regions it has, their alpha/vertex alpha/shown state,
        -- so we can see what's still drawing Blizzard's badge art.
        local out = { "==== nameplate level badge report ====",
            "square border on: " .. tostring(uuidb.general.nameplatesquareborder) }
        local function fmt(v)
            if issecretvalue and issecretvalue(v) then return "<secret>" end
            if type(v) == "number" then return string.format("%.2f", v) end
            return tostring(v)
        end
        local count = 0
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local hb, uf = NBHealthBar(plate)
            local badge = uf and uf.PlayerLevelDiffFrame
            if badge and count < 6 then
                count = count + 1
                local okS, shown = pcall(badge.IsShown, badge)
                out[#out + 1] = string.format("-- %s  badge shown=%s alpha=%s target=%s",
                    tostring(uf.unit), fmt(okS and shown), fmt(badge:GetAlpha()),
                    tostring(hb.IsTarget and hb:IsTarget()))
                for _, region in ipairs({ badge:GetRegions() }) do
                    local name = "?"
                    for k, v in pairs(badge) do if v == region then name = k break end end
                    local okV, r, g, b, a = pcall(region.GetVertexColor, region)
                    local atlas = region.GetAtlas and region:GetAtlas()
                    local layer, sub = region:GetDrawLayer()
                    out[#out + 1] = string.format("   %-20s %-12s %s %s shown=%s alpha=%s vertexA=%s atlas=%s",
                        name, region:GetObjectType(), tostring(layer), tostring(sub),
                        fmt(region:IsShown()), fmt(region:GetAlpha()), fmt(okV and a), tostring(atlas))
                end
            end
        end
        if count == 0 then out[#out + 1] = "(no level badges found on visible plates)" end
        ShowReport(table.concat(out, "\n"))
        return
    elseif cmd == "bgtop" then
        -- Test: raise the border texture above the fill. Blizzard's own is
        -- BACKGROUND 0 (Blizzard_NamePlateUnitFrame.lua UpdateAnchors).
        local n = NBForEachBar(function(hb) hb.bgTexture:SetDrawLayer("ARTWORK", 6) end)
        print("|cff33ff99UberUI debug|r bgTexture raised above the fill (ARTWORK 6) on " .. n
            .. " nameplates. /uuidebugnpbar bgback to restore (a re-style or reload also restores it).")
        return
    elseif cmd == "bgback" then
        local n = NBForEachBar(function(hb) hb.bgTexture:SetDrawLayer("BACKGROUND", 0) end)
        print("|cff33ff99UberUI debug|r bgTexture back on BACKGROUND 0 on " .. n .. " nameplates.")
        return
    elseif cmd == "border" then
        local n = NBForEachBar(function(hb) hb.bgTexture:SetVertexColor(1, 1, 1, 1) end)
        print("|cff33ff99UberUI debug|r border tint reset to white on " .. n .. " nameplates (reload to undo).")
        return
    elseif cmd == "dark" then
        local dc = uuidb.general.darkencolor
        local n = NBForEachBar(function(hb) hb.bgTexture:SetVertexColor(dc.r, dc.g, dc.b, dc.a) end)
        print("|cff33ff99UberUI debug|r darkness tint re-applied to the border on " .. n .. " nameplates.")
        return
    elseif cmd == "blizzbar" then
        local n = NBForEachBar(function(hb) hb.barTexture:SetAtlas("UI-HUD-CoolDownManager-Bar", true) end)
        print("|cff33ff99UberUI debug|r Blizzard's bar atlas put back on " .. n .. " nameplates (next re-style/reload undoes it).")
        return
    end
    local ok, report = pcall(BuildNamePlateBarReport)
    if not ok then report = "ERROR building nameplate bar report: " .. tostring(report) end
    print("|cff33ff99UberUI debug|r nameplate bar report ready -- see the popup window (Ctrl+A, Ctrl+C to copy).")
    ShowReport(report)
end
