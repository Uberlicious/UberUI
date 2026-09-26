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
            ScanTable(add, plabel .. ".UnitFrame.castBar", uf.castBar, seen)
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
