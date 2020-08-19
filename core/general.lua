  ---------------------------------------
-- VARIABLES
---------------------------------------

--get the addon namespace
local addon, ns = ...
local general = {}
--get the config values
local cfg = ns.cfg
local dragFrameList = ns.dragFrameList

local classcolor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
local class = UnitClass("player")

---------------------------------------
-- ACTIONS
---------------------------------------

-- REMOVING UGLY PARTS OF UI

local general = CreateFrame("frame")
general:RegisterEvent("PLAYER_LOGIN")
general:SetScript("OnEvent", function(self, event)
	uuidb.actionbars.overridecol = false
	if uuidb.general.bartexture ~= "Blizzard" then
		self:BarTexture(uuidb.general.bartexture)
	end
	if uuidb.general.classcolorhealth then
		self:HealthColor()
	end

	if uuidb.general.classcolorhealth then
		hooksecurefunc("UnitFrameHealthBar_Update", function()
			general:HealthColor()
		end)
		hooksecurefunc("HealthBar_OnValueChanged", function()
			general:HealthColor()
		end)
	end
	self:ColorAllFrames()
	self:MicroBar()
end)


local function HealthBars()
	return {
        PlayerFrameHealthBar,
        TargetFrameHealthBar,
        TargetFrameToTHealthBar,
        FocusFrameHealthBar,
        FocusFrameToTHealthBar,
        PetFrameHealthBar,
		}
end

local function ManaBars()
    return {
        PlayerFrameManaBar,
        PlayerFrameAlternateManaBar,
        TargetFrameManaBar,
        TargetFrameToTManaBar,
        FocusFrameManaBar,
        FocusFrameToTManaBar,
        PetFrameManaBar,
    }
end

local function NonStatusBars()
	return {
		PlayerFrameMyHealPredictionBar,
		PlayerFrameOtherHealPredictionBar,
		TargetFrameMyHealPredictionBar,
		TargetFrameOtherHealPredictionBar,
		PlayerFrameManaCostPredictionBar,
	}
end

 -- COLORING THE MAIN BAR
function general:MainMenuColor(color)
	if not (color) then
		color = uuidb.mainmenu.mainbarcolor
	end

	for _,v in pairs({
		MainMenuBarArtFrameBackground.BackgroundLarge,
		MainMenuBarArtFrameBackground.BackgroundSmall,
		SlidingActionBarTexture0,
		SlidingActionBarTexture1,
		StatusTrackingBarManager.SingleBarLarge,
		StatusTrackingBarManager.SingleBarLargeUpper,
		StatusTrackingBarManager.SingleBarSmall,
		StatusTrackingBarManager.SingleBarSmallUpper,
		MicroButtonAndBagsBar.MicroBagBar,
		}) do
		local frameAtlas = v:GetAtlas()
		if frameAtlas ~= nil then
			local txl, txr, txt, txb = select(4, GetAtlasInfo(frameAtlas))
			v:SetTexture("Interface\\AddOns\\Uber UI\\Textures\\MainMenuBar")
			v:SetTexCoord(txl, txr, txt, txb)
			v:SetVertexColor(color.r, color.g, color.b, color.a)
		else
			v:SetVertexColor(color.r, color.g, color.b, color.a)
		end
	end
end

function general:Gryphons(color)
	if not (color) then
		color = uuidb.mainmenu.gryphcolor
	end
	for _,v in pairs({
		MainMenuBarArtFrame.LeftEndCap,
		MainMenuBarArtFrame.RightEndCap,
		}) do
		if uuidb.mainmenu.gryphon then
			local frameAtlas = v:GetAtlas()
			if frameAtlas ~= nil then
				local txl, txr, txt, txb = select(4, GetAtlasInfo(frameAtlas))
				v:SetTexture("Interface\\AddOns\\Uber UI\\Textures\\MainMenuBar")
				v:SetTexCoord(txl, txr, txt, txb)
				if v == MainMenuBarArtFrame.RightEndCap then
					v:SetTexCoord(txr, txl, txt, txb)
				end
				v:SetVertexColor(color.r, color.g, color.b, color.a)
				v:Show()
			else
				v:SetVertexColor(color.r, color.g, color.b, color.a)
				v:Show()
			end
		else
			v:Hide()
		end
	end
end

function general:BarTexture(value)
    local texture = uuidb.textures.statusbars[value]
    local striped = uuidb.textures.statusbars.Striped

    local healthBars = HealthBars()
    local manaBars = ManaBars()
    local nonStatusBars = NonStatusBars()

    for _, healthbar in pairs(healthBars) do
        healthbar:SetStatusBarTexture(texture)
    end

    PlayerFrameHealthBar.AnimatedLossBar:SetStatusBarTexture(texture) -- fix for blinking red texture

    for _, manabar in pairs(manaBars) do
        manabar:SetStatusBarTexture(texture)
    end

    local function manaBarTexture(manaBar)
    	currentBar = manaBar.texture:GetTexture()
    	if string.match(currentBar, "UI%-StatusBar") and uuidb.general.bartexture ~= "Blizzard" then
        	manaBar:SetStatusBarTexture(texture)
        end
    end

    if (not PlayerFrameManaBar.EasyFramesHookUpdateType) then
        hooksecurefunc("UnitFrameManaBar_UpdateType", manaBarTexture)

        PlayerFrameManaBar.EasyFramesHookUpdateType = true
    end

    for _,v in pairs(nonStatusBars) do
    	v:SetTexture(texture)
    end

    PlayerFrameTotalAbsorbBar:SetTexture(striped)
	PlayerFrameTotalAbsorbBar:SetVertexColor(.6, .9, .9)
	TargetFrameTotalAbsorbBar:SetTexture(striped)
	TargetFrameTotalAbsorbBar:SetVertexColor(.6, .9, .9)

end

--class color target frames / health
local function ClassColored(statusbar, unit)
    if (UnitIsPlayer(unit) and UnitClass(unit)) then
        -- player
        if (uuidb.general.classcolorhealth) then
            local _, class, classColor

            _, class = UnitClass(unit)
            classColor = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS[class]

            statusbar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
        else
            local colors

            if (UnitIsFriend("player", unit)) then
                colors = {0,1,0}
            else
                colors = {1,0,0}
            end

            statusbar:SetStatusBarColor(colors[1], colors[2], colors[3])
        end
    else
        -- non player

        local colors

        local red, green, _ = UnitSelectionColor(unit)

        if (red == 0) then
            colors = {0,1,0}
        elseif (green == 0) then
            colors = {1,0,0}
        else
            colors = {1,1,0}
        end

        if (not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
            colors = {0.5, 0.5, 0.5}
        end

        statusbar:SetStatusBarColor(colors[1], colors[2], colors[3])
    end
end

function general:HealthColor()
	local healthbars = HealthBars()

    for _, healthbar in pairs(healthbars) do
		if (UnitIsConnected(healthbar.unit)) then
			ClassColored(healthbar, healthbar.unit)
		end
    end
end

function general:HealthColorDisable()
	local healthbars = HealthBars()

	for _, healthbar in pairs(healthbars) do
		healthbar:SetStatusBarColor(0,1,0)
	end
end

function general:MicroBar()
	for _,v in pairs({
		MicroButtonAndBagsBar,
	}) do
		if not uuidb.mainmenu.microbuttonbar then
			local point, rf, rp, ofsx, ofxy = v:GetPoint()
			v:ClearAllPoints()
			v:SetPoint(point, rf, rp, ofsx, ofxy-100)
		else
			local point, rf, rp, ofsx, ofxy = v:GetPoint()
			if ofxy ~= 0 then
				v:ClearAllPoints()
				v:SetPoint(point, rf, rp, ofsx, ofxy+100)
			end
		end
	end
end

function general:MicroBar()
	for _,v in pairs({
		MicroButtonAndBagsBar,
	}) do
		if not uuidb.mainmenu.microbuttonbar then
			local point, rf, rp, ofsx, ofxy = v:GetPoint()
			v:ClearAllPoints()
			v:SetPoint(point, rf, rp, ofsx, ofxy-100)
		else
			local point, rf, rp, ofsx, ofxy = v:GetPoint()
			if ofxy ~= 0 then
				v:ClearAllPoints()
				v:SetPoint(point, rf, rp, ofsx, ofxy+100)
			end
		end
	end
end	

local ccount = 0

function general:ColorAllFrames()
	if uuidb.general.customcolor or uuidb.general.classcolorframes then
		color = uuidb.general.customcolorval
		self:MainMenuColor(color)
		self:Gryphons(color)
		UberUI.playerframes:ReworkAllColor(color)
		UberUI.targetframes:ReworkAllColor(color)
		UberUI.misc:ReworkAllColor(color)
		UberUI.auras:ReworkAllColors(color)
		UberUI.minimap:ReworkAllColor(color)
		if ccount == 0 then
			UberUI.actionbars:ReworkAllColors(color)
		end
	else
		self:MainMenuColor()
		self:Gryphons()
		UberUI.playerframes:ReworkAllColor()
		UberUI.targetframes:ReworkAllColor()
		UberUI.misc:ReworkAllColor()
		UberUI.auras:ReworkAllColors()
		UberUI.minimap:ReworkAllColor()
		if ccount == 0 then
			UberUI.actionbars:ReworkAllColors()
		end
	end
	UberUI.buffs:ReworkAllColor()
	ccount = ccount + 1
end

function general:ReworkColors()
	if uuidb.general.customcolor or uuidb.general.classcolorframes then
		color = uuidb.general.customcolorval
		self:MainMenuColor(color)
		self:Gryphons(color)
		UberUI.playerframes:ReworkAllColor(color)
		UberUI.targetframes:ReworkAllColor(color)
		UberUI.misc:ReworkAllColor(color)
		UberUI.auras:ReworkAllColors(color)
		UberUI.minimap:ReworkAllColor(color)
		UberUI.actionbars.EditColors(color)
		UberUI.buffs:UpdateColors(color)
	else
		self:MainMenuColor()
		self:Gryphons()
		UberUI.playerframes:ReworkAllColor()
		UberUI.targetframes:ReworkAllColor()
		UberUI.misc:ReworkAllColor()
		UberUI.auras:ReworkAllColors()
		UberUI.minimap:ReworkAllColor()
		UberUI.actionbars.EditColors()
		UberUI.buffs:UpdateColors()
	end
end

UberUI.general = general