local addon, ns = ...
local partyframes = {}

partyframes = UberUI:CreateFrame("frame")
partyframes:RegisterEvent("ADDON_LOADED")
partyframes:RegisterEvent("PLAYER_ENTERING_WORLD")
partyframes:RegisterEvent("GROUP_ROSTER_UPDATE")

partyframes:SetScript("OnEvent", function(self, event)
    if InCombatLockdown() then
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
    partyframes:Color();
    partyframes:HealthBarColor();
    partyframes:HealthManaBarTexture();
    partyframes:ColorBuffTooltip();
end)

function partyframes:IteratePartyFrames()
    local frames = {}
    if PartyFrame then
        for _, p in pairs({ PartyFrame:GetChildren() }) do
            -- Filter out EditMode selection frames and other non-unit frames
            if p.unit or p.layoutIndex or (p.GetName and p:GetName() and p:GetName():find("MemberFrame")) then
                table.insert(frames, p)
            end
        end
    else
        for i = 1, 4 do
            local p = _G["PartyMemberFrame"..i]
            if p then table.insert(frames, p) end
        end
    end
    return frames
end

function partyframes:Color()
    local dc = uuidb.general.darkencolor;
    for _, p in pairs(self:IteratePartyFrames()) do
        local tex = p.Texture
        if not tex and p.GetName and p:GetName() then
            tex = _G[p:GetName().."Texture"]
        end
        if (tex ~= nil) then
            tex:SetVertexColor(dc.r, dc.g, dc.b, dc.a);
        end
    end
end

function partyframes:HealthBarColor()
    if (not uuidb.partyframes.classcolor) then return end
    for _, p in pairs(self:IteratePartyFrames()) do
        local healthBar = p.HealthBarContainer and p.HealthBarContainer.HealthBar
        if not healthBar and p.GetName and p:GetName() then
            healthBar = _G[p:GetName().."HealthBar"]
        end
        if healthBar then
            local idx = p.unit or p:GetAttribute("unit") or (p.GetID and p:GetID() and "party"..p:GetID());
            if (idx and UnitIsConnected(idx)) then
                local _, class = UnitClass(idx)
                local classColor = class and ((C_ClassColor and C_ClassColor.GetClassColor(class)) or (GetClassColorObj and GetClassColorObj(class)) or RAID_CLASS_COLORS[class]);
                if (classColor ~= nil) then
                    healthBar:SetStatusBarDesaturated(true);
                    healthBar:SetStatusBarColor(classColor.r, classColor.g, classColor.b, classColor.a);
                end
            end
        end
    end
end

function partyframes:HealthManaBarTexture()
    local textureToApply
    if uuidb.general.partybartextures and uuidb.general.partybartexture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.partybartexture]
    elseif uuidb.general.allbartextures and uuidb.general.texture ~= "Blizzard" then
        textureToApply = uuidb.statusbars[uuidb.general.texture]
    end

    for _, p in pairs(self:IteratePartyFrames()) do
        local healthBar = p.HealthBarContainer and p.HealthBarContainer.HealthBar
        if not healthBar and p.GetName and p:GetName() then
            healthBar = _G[p:GetName().."HealthBar"]
        end
        local manaBar = p.ManaBar
        if not manaBar and p.GetName and p:GetName() then
            manaBar = _G[p:GetName().."ManaBar"]
        end
        if healthBar then
            local idx = p.unit or p:GetAttribute("unit") or (p.GetID and p:GetID() and "party"..p:GetID());
            if textureToApply then
                healthBar:SetStatusBarTexture(textureToApply);
                if idx then
                    local partyPowerType = UnitPowerType(idx);
                    if (partyPowerType ~= nil and partyPowerType < 4) then
                        if manaBar then
                            manaBar:SetStatusBarTexture(textureToApply);
                            local pc = PowerBarColor[partyPowerType];
                            manaBar:SetStatusBarColor(pc.r, pc.g, pc.b);
                        end
                    end
                end
            end
        end
    end
end

-- Party member aura styling. Unlike compact/raid frames (forbidden native
-- renderer) or target/focus (custom AuraContainer widgets), the classic
-- party frame's aura buttons are plain, addon-visible PartyAuraFrameTemplate
-- buttons -- see docs/compact-frame-auras.md for the compact-frame design
-- this deliberately does NOT need. Blizzard's own PartyAuraFrameMixin:Setup
-- is the single choke point every one of these buttons passes through: the
-- on-frame debuffs (AuraFrameContainer), pet debuffs (PetFrame.
-- AuraFrameContainer), and the on-hover PartyMemberBuffTooltip's buff/debuff
-- icons all call button:Setup(unit, aura, isBuff) -- confirmed identical
-- between retail 12.1 and WoW Forever 1.60.1 (Shared/PartyMemberFrame.lua).
-- Hooking it once covers all four, styled exactly when their content
-- actually changes -- no per-tick re-application needed.
--
-- Buffs never appear on the frame itself (MAX_PARTY_TOOLTIP_BUFFS==0 means
-- Setup is only ever called with isBuff=true for the hover tooltip); only up
-- to MAX_PARTY_DEBUFFS debuffs show directly on the frame, each already
-- carrying Blizzard's own real dispel-colored DebuffBorder (AuraUtil.
-- SetAuraBorderColor, done by Blizzard's own Setup before our hook runs).
--
-- "Dark Border" style reuses that same DebuffBorder widget (retinting it)
-- rather than drawing a separate custom texture. A first attempt drew our
-- own overlay using the "ui-debuff-border-default-noicon" atlas -- the same
-- one aurakit.lua uses for target/focus/compact -- but that atlas is tuned
-- for their much larger (20-40px) icons; at party's tiny 15x15 size its ring
-- proportions don't scale down cleanly and render oversized/misshapen.
-- DebuffBorder is already exactly sized and anchored for this button by
-- Blizzard, so retinting it sidesteps the problem entirely, for both buffs
-- and debuffs (Blizzard hides it on buff buttons by default, but nothing
-- stops us from showing/tinting it as a plain flat border there too).
function partyframes:StyleAuraButton(button, isBuff)
    if not button or not button.DebuffBorder then return end
    local style = (isBuff and uuidb.general.aurastyle_partybuffs or uuidb.general.aurastyle_partydebuffs)
        or (isBuff and "both" or "zoom")
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    if button.Icon then
        UberUI.general:ApplyIconZoom(button.Icon, zoomEnabled)
    end

    -- Square borders (core/squareborders.lua): same rules as every other
    -- location -- the Buff/Debuff Border choice picks the color (dark, or
    -- Blizzard's look: dispel color on debuffs, no border on buffs); None
    -- style is never overridden. Replaces DebuffBorder while on.
    local SB = UberUI.squareborders
    local square = SB and button.Icon and style ~= "none" and SB.IsEnabled("party")
    if square and (not isBuff or darkBorderEnabled) then
        button.DebuffBorder:Hide()
        local sb = SB.Get(button)
        SB.LayoutFor(sb, button.Icon, "party")
        SB.RaiseAbove(sb, button, 2)
        if darkBorderEnabled then
            SB.SetDarkColor(sb)
        else
            local instID = button.auraInstanceID
            SB.ApplyDispelColor(sb, nil, button.unit, instID)
        end
        sb:Show()
        return
    elseif square then
        -- Buff in Zoom Only: native "no border on buffs" look.
        button.DebuffBorder:Hide()
        SB.Hide(button)
        return
    end
    if SB then SB.Hide(button) end

    if darkBorderEnabled then
        local dc = uuidb.general.darkencolor or { r = 0.4, g = 0.4, b = 0.4, a = 1 }
        button.DebuffBorder:SetDesaturated(true)
        button.DebuffBorder:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
        button.DebuffBorder:Show()
    elseif isBuff then
        -- Native "no border on buffs" look.
        button.DebuffBorder:Hide()
    else
        -- Restore Blizzard's real per-dispel-type color. We may have
        -- overwritten it with the dark tint above on a previous style
        -- change, so re-derive it from the aura instead of assuming the
        -- widget still holds it.
        --
        -- GetAuraDataByAuraInstanceID doesn't just return a secret value
        -- when the aura is secret while the CALLER is tainted (as ours is,
        -- running inside a hooksecurefunc) -- it throws ("Auras cannot be
        -- accessed when secret while tainted by 'Uber UI'"), confirmed live.
        -- core/buffsandauras.lua already established the correct three-layer
        -- guard for this exact API elsewhere in this addon (secret-check the
        -- ID, pcall the call itself, secret-check the result) -- mirrored
        -- here.
        button.DebuffBorder:SetDesaturated(false)
        local dispelName
        local instID = button.auraInstanceID
        local isSecretID = issecretvalue and issecretvalue(instID)
        if button.unit and instID and not isSecretID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
            local aura
            pcall(function()
                aura = C_UnitAuras.GetAuraDataByAuraInstanceID(button.unit, instID)
            end)
            if aura and not (issecretvalue and issecretvalue(aura)) then
                dispelName = aura.dispelName
                if issecretvalue and issecretvalue(dispelName) then
                    dispelName = nil
                end
            end
        end
        pcall(AuraUtil.SetAuraBorderColor, button.DebuffBorder, dispelName)
        button.DebuffBorder:Show()
    end
end

-- Restyles every currently-active button across every pool (on-frame,
-- pet, and tooltip) immediately -- used when the style dropdown changes,
-- since the Setup hook alone only re-styles buttons the next time their
-- aura content actually changes.
function partyframes:RefreshAuraStyle()
    for _, p in pairs(self:IteratePartyFrames()) do
        if p.AuraFramePool then
            for btn in p.AuraFramePool:EnumerateActive() do
                self:StyleAuraButton(btn, btn.isBuff)
            end
        end
        if p.PetFrame and p.PetFrame.AuraFramePool then
            for btn in p.PetFrame.AuraFramePool:EnumerateActive() do
                self:StyleAuraButton(btn, btn.isBuff)
            end
        end
    end
    if PartyMemberBuffTooltip then
        if PartyMemberBuffTooltip.PartyMemberBuffPool then
            for btn in PartyMemberBuffTooltip.PartyMemberBuffPool:EnumerateActive() do
                self:StyleAuraButton(btn, true)
            end
        end
        if PartyMemberBuffTooltip.PartyMemberDebuffPool then
            for btn in PartyMemberBuffTooltip.PartyMemberDebuffPool:EnumerateActive() do
                self:StyleAuraButton(btn, false)
            end
        end
    end
end

function partyframes:ForceZoom()
    self:RefreshAuraStyle()
end

-- Tooltip border darkening -- unrelated to aura style, just the addon's
-- usual darken-color treatment applied to the tooltip's own frame art.
function partyframes:ColorBuffTooltip()
    if not PartyMemberBuffTooltip or not PartyMemberBuffTooltip.NineSlice then return end
    local dc = uuidb.general.darkencolor
    if dc then
        PartyMemberBuffTooltip.NineSlice:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
    end
end

if PartyMemberFrameMixin then
    hooksecurefunc(PartyMemberFrameMixin, "OnUpdate", function(self)
        UberUI.partyframes:Color()
        UberUI.partyframes:HealthBarColor()
        UberUI.partyframes:HealthManaBarTexture()
    end)
end

if PartyAuraFrameMixin then
    hooksecurefunc(PartyAuraFrameMixin, "Setup", function(self, unit, aura, isBuff)
        UberUI.partyframes:StyleAuraButton(self, isBuff)
    end)
end

if PartyMemberBuffTooltip then
    hooksecurefunc(PartyMemberBuffTooltip, "UpdateTooltip", function()
        UberUI.partyframes:ColorBuffTooltip()
    end)
end



UberUI.partyframes = partyframes
