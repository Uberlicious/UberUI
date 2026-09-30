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
                local classColor = UberUI.util.ClassColor(class);
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

local countTouched = setmetatable({}, { __mode = "k" }) -- aura button -> true

-- Party member aura styling (on-frame debuffs, pet debuffs, and hover tooltip).
function partyframes:StyleAuraButton(button, isBuff)
    if not button or not button.DebuffBorder then return end

    -- Stack count: Blizzard's (PartyAuraFrameTemplate: NumberFontNormalSmall,
    -- right-justified, BOTTOMRIGHT x=5) is left exactly as the template made
    -- it at the default settings, and restored if we'd changed it.
    local count = button.Count
    local kit = UberUI.aurakit
    if count and kit and NumberFontNormalSmall then
        local t = kit.TextSettings("party")
        if t.stack == 1 and t.anchor == "BOTTOMRIGHT" and t.x == 0 and t.y == 0 then
            if countTouched[button] then
                count:SetFontObject(NumberFontNormalSmall)
                count:ClearAllPoints()
                count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 5, 0)
                count:SetJustifyH("RIGHT")
                countTouched[button] = nil
            end
        else
            local font, fsize, flags = NumberFontNormalSmall:GetFont()
            if font then count:SetFont(font, math.max(4, fsize * t.stack), flags) end
            kit.PlaceCount(count, button, t, 5, 0)
            countTouched[button] = true
        end
    end
    local style = (isBuff and uuidb.general.aurastyle_partybuffs or uuidb.general.aurastyle_partydebuffs)
        or (isBuff and "both" or "zoom")
    local zoomEnabled = (style == "both" or style == "zoom")
    local darkBorderEnabled = (style == "both" or style == "border")

    if button.Icon then
        UberUI.general:ApplyIconZoom(button.Icon, zoomEnabled)
    end

    local SB = UberUI.squareborders
    local square = SB and button.Icon and style ~= "none" and SB.IsEnabled("party")
    if square and (not isBuff or darkBorderEnabled) then
        button.DebuffBorder:Hide()
        local sb = SB.Get(button)
        SB.RaiseAbove(sb, button, 2)
        if darkBorderEnabled then
            SB.LayoutFor(sb, button.Icon, "party")
            SB.SetDarkColor(sb)
        else
            -- Dispel color: 1px thicker than the dark border.
            SB.LayoutDispelFor(sb, button.Icon, "party")
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
        button.DebuffBorder:Hide()
    else
        button.DebuffBorder:SetDesaturated(false)
        local dispelName
        local instID = button.auraInstanceID
        local isSecretID = UberUI.util.IsSecret(instID)
        if button.unit and instID and not isSecretID and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
            local aura
            pcall(function()
                aura = C_UnitAuras.GetAuraDataByAuraInstanceID(button.unit, instID)
            end)
            if aura and not UberUI.util.IsSecret(aura) then
                dispelName = aura.dispelName
                if UberUI.util.IsSecret(dispelName) then
                    dispelName = nil
                end
            end
        end
        pcall(AuraUtil.SetAuraBorderColor, button.DebuffBorder, dispelName)
        button.DebuffBorder:Show()
    end
end

-- Restyles every active button (on-frame, pet, tooltip) now; the Setup hook
-- only restyles when a button's aura changes.
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

-- Tooltip frame darkening.
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
