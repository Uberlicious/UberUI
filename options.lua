--[[--------------------------------------------------------------------
	Uber UI
	Darkens default UI
	Maintained by Uberlicious
----------------------------------------------------------------------]]

local addon, ns = ...
local cfg = ns.cfg

local SOUND_OFF = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
local SOUND_ON = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON

local classcolor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]

local Options = CreateFrame("Frame", "UberUI-Options", InterfaceOptionsFramePanelContainer)
Options.name = GetAddOnMetadata(addon, "Title") or addon
InterfaceOptions_AddCategory(Options)

function ns.ShowOptions()
	InterfaceOptionsFrame_OpenToCategory(Options)
end

Options:Hide()
Options:SetScript("OnShow", function(self)
	local Title = self:CreateFontString("$parentTitle", "ARTWORK", "GameFontNormalLarge")
	Title:SetPoint("TOPLEFT", 16, -16)
	Title:SetText(self.name)

	local SubText = self:CreateFontString("$parentSubText", "ARTWORK", "GameFontHighlightSmall")
	SubText:SetPoint("TOPLEFT", Title, "BOTTOMLEFT", 0, -8)
	SubText:SetPoint("RIGHT", -32, 0)
	SubText:SetHeight(32)
	SubText:SetJustifyH("LEFT")
	SubText:SetJustifyV("TOP")
	SubText:SetText("Darkens the default blizzard UI.")

	local Reload = CreateFrame("Button", "$parentReload" , self, "UIPanelButtonTemplate")
	Reload:SetPoint("TOPRIGHT", InterfaceOptionsFrameCancel, "TOPRIGHT", -15, 50)
	Reload:SetWidth(100)
	Reload:SetHeight(25)
	Reload:SetText("Save & Reload")

	Reload:SetScript(
		"OnClick",
		function(self, button, down)
			Options:Hide()
			ReloadUI()
		end
	)

	local Gryphon = CreateFrame("CheckButton", "$parentGryphon", self, "InterfaceOptionsCheckButtonTemplate")
	Gryphon:SetPoint("TOPLEFT", SubText, "BOTTOMLEFT", 0, -12)
	Gryphon.Text:SetText("Show Gryphons")
	Gryphon.tooltipText = "Shows the gryphons on the sides of actionbars."
	Gryphon:SetScript("OnClick", function(this)
		local checked = not not this:GetChecked()
		PlaySound(checked and SOUND_ON or SOUND_OFF)
		UberuiDB.Gryphon = checked
			if UberuiDB.Gryphon and UberuiDB.ClassColorFrames then
				MainMenuBarArtFrame.LeftEndCap:Show()
				MainMenuBarArtFrame.RightEndCap:Show()
				if MainMenuBarArtFrame.LeftEndCap:GetAtlas() == nil then
					MainMenuBarArtFrame.LeftEndCap:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
					MainMenuBarArtFrame.RightEndCap:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
				else
					MainMenuBarArtFrame.LeftEndCap:Show()
					MainMenuBarArtFrame.RightEndCap:Show()
					local Atlas = MainMenuBarArtFrame.RightEndCap:GetAtlas()
					local txl, txr, txt, txb = select(4, GetAtlasInfo(Atlas))
					MainMenuBarArtFrame.LeftEndCap:SetTexture("Interface\\AddOns\\Uber UI\\Textures\\MainMenuBar")
   					MainMenuBarArtFrame.LeftEndCap:SetTexCoord(txl, txr, txt, txb)
   					MainMenuBarArtFrame.RightEndCap:SetTexture("Interface\\AddOns\\Uber UI\\Textures\\MainMenuBar")
   					MainMenuBarArtFrame.RightEndCap:SetTexCoord(txr, txl, txt, txb)
   				end
   			elseif UberuiDB.Gryphon and not UberuiDB.ClassColorFrames then
   				MainMenuBarArtFrame.LeftEndCap:SetVertexColor(.35,.35,.35)
				MainMenuBarArtFrame.RightEndCap:SetVertexColor(.35,.35,.35)
				MainMenuBarArtFrame.LeftEndCap:Show()
				MainMenuBarArtFrame.RightEndCap:Show()
			else
				MainMenuBarArtFrame.LeftEndCap:Hide()
				MainMenuBarArtFrame.RightEndCap:Hide()
			end
    	end)

	local Hotkey = CreateFrame("CheckButton", "$parentHotkey", self, "InterfaceOptionsCheckButtonTemplate")
	Hotkey:SetPoint("TOPLEFT", Gryphon, "BOTTOMLEFT", 0, -12)
	Hotkey.Text:SetText("Show Hotkeys")
	Hotkey.tooltipText = "Shows the Hotkeys on the actionbar buttons."
	Hotkey:SetScript("OnClick", function(this)
		local checked = not not this:GetChecked()
		PlaySound(checked and SOUND_ON or SOUND_OFF)
		UberuiDB.Hotkey = checked
		for i = 1, NUM_ACTIONBAR_BUTTONS do
			if UberuiDB.Hotkey then
				_G["ActionButton"..i]["HotKey"]:Show()
				_G["MultiBarBottomLeftButton"..i]["HotKey"]:Show()
				_G["MultiBarBottomRightButton"..i]["HotKey"]:Show()
				_G["MultiBarRightButton"..i]["HotKey"]:Show()
				_G["MultiBarLeftButton"..i]["HotKey"]:Show()
				if _G["PetactionButton"] then
					_G["PetActionButton"..i]["HotKey"]:Show()
				end
			else
				_G["ActionButton"..i]["HotKey"]:Hide()
				_G["MultiBarBottomLeftButton"..i]["HotKey"]:Hide()
				_G["MultiBarBottomRightButton"..i]["HotKey"]:Hide()
				_G["MultiBarRightButton"..i]["HotKey"]:Hide()
				_G["MultiBarLeftButton"..i]["HotKey"]:Hide()
				if _G["PetactionButton"] then
					_G["PetActionButton"..i]["HotKey"]:Hide()
				end
			end
    	end
	end)

	local Macroname = CreateFrame("CheckButton", "$parentMacroname", self, "InterfaceOptionsCheckButtonTemplate")
	Macroname:SetPoint("TOPLEFT", Hotkey, "BOTTOMLEFT", 0, -12)
	Macroname.Text:SetText("Show Macronames")
	Macroname.tooltipText = "Shows the Macronames on the actionbar buttons."
	Macroname:SetScript("OnClick", function(this)
		local checked = not not this:GetChecked()
		PlaySound(checked and SOUND_ON or SOUND_OFF)
		UberuiDB.Macroname = checked
		for i = 1, NUM_ACTIONBAR_BUTTONS do
			if UberuiDB.Macroname then
				_G["ActionButton"..i]["Name"]:Show()
				_G["MultiBarBottomLeftButton"..i]["Name"]:Show()
				_G["MultiBarBottomRightButton"..i]["Name"]:Show()
				_G["MultiBarRightButton"..i]["Name"]:Show()
				_G["MultiBarLeftButton"..i]["Name"]:Show()
				if _G["PetactionButton"] then
					_G["PetActionButton"..i]["HotKey"]:Show()
				end
			else
				_G["ActionButton"..i]["Name"]:Hide()
				_G["MultiBarBottomLeftButton"..i]["Name"]:Hide()
				_G["MultiBarBottomRightButton"..i]["Name"]:Hide()
				_G["MultiBarRightButton"..i]["Name"]:Hide()
				_G["MultiBarLeftButton"..i]["Name"]:Hide()
				if _G["PetactionButton"] then
					_G["PetActionButton"..i]["HotKey"]:Hide()
				end
			end
    	end
	end)

	local BigFrames = CreateFrame("CheckButton", "$parentBigFrames", self, "InterfaceOptionsCheckButtonTemplate")
	BigFrames:SetPoint("TOPLEFT", Macroname, "BOTTOMLEFT", 0, -12)
	BigFrames.Text:SetText("Big Player / Target Frame")
	BigFrames.tooltipText = "Makes UI Health Bars Larger"
	BigFrames:SetScript("OnClick", function(this)
		local checked = not not this:GetChecked()
		PlaySound(checked and SOUND_ON or SOUND_OFF)
		UberuiDB.BigFrames = checked
		if UberuiDB.BigFrames then
			UUI_BigFrames()
			cfg.BigFrames = true
		else
			UUI_BigFrames()
			cfg.BigFrames = false
    	end
	end)

	local LargeHealth = CreateFrame("CheckButton", "$parentLargeHealth", self, "InterfaceOptionsCheckButtonTemplate")
	LargeHealth:SetPoint("TOPLEFT", BigFrames, "BOTTOMLEFT", 0, -12)
	LargeHealth.Text:SetText("Enlarge Health Bars")
	LargeHealth.tooltipText = "Makes UI Health Bars Larger"
	LargeHealth:SetScript("OnClick", function(this)
		local checked = not not this:GetChecked()
		PlaySound(checked and SOUND_ON or SOUND_OFF)
		UberuiDB.LargeHealth = checked
		if UberuiDB.LargeHealth then
			PlayerFrameHealth()
			--UberuiDB.LargeHealth = true
    	end
	end)

	local ClassColorFrames = CreateFrame("CheckButton", "$parentClassColorFrames", self, "InterfaceOptionsCheckButtonTemplate")
	ClassColorFrames:SetPoint("TOPLEFT", LargeHealth, "BOTTOMLEFT", 0, -12)
	ClassColorFrames.Text:SetText("Class Color Unitframes")
	ClassColorFrames.tooltipText = "Changes UI from dark to your class color. (requires reload)"
	ClassColorFrames:SetScript("OnClick", function(this)
		local checked = not not this:GetChecked()
		PlaySound(checked and SOUND_ON or SOUND_OFF)
		UberuiDB.ClassColorFrames = checked
		if UberuiDB.ClassColorFrames then
			DEFAULT_CHAT_FRAME:AddMessage("Class Colors Enabled", 0, 1, 0)
		else
			DEFAULT_CHAT_FRAME:AddMessage("Class Colors Disabled", 1, 0, 0)
    	end
	end)

	local ClassColorHealth = CreateFrame("CheckButton", "$parentClassColorHealth", self, "InterfaceOptionsCheckButtonTemplate")
	ClassColorHealth:SetPoint("TOPLEFT", ClassColorFrames, "BOTTOMLEFT", 0, -12)
	ClassColorHealth.Text:SetText("Class Color Unit Health")
	ClassColorHealth.tooltipText = "Changes Frame Health to units class color. (disable requires reload)"
	ClassColorHealth:SetScript("OnClick", function(this)
		local checked = not not this:GetChecked()
		PlaySound(checked and SOUND_ON or SOUND_OFF)
		UberuiDB.ClassColorHealth = checked
		if UberuiDB.ClassColorHealth then
			UberuiDB.ClassColorHealth = true
			DEFAULT_CHAT_FRAME:AddMessage("Class Colors Enabled", 0, 1, 0)
		else
			UberuiDB.ClassColorHealth = false
			DEFAULT_CHAT_FRAME:AddMessage("Class Colors Disabled", 1, 0, 0)
    	end
	end)

	local MicroButtonBagBar = CreateFrame("CheckButton", "$parentMicroButtonBagBar", self, "InterfaceOptionsCheckButtonTemplate")
	MicroButtonBagBar:SetPoint("TOPLEFT", ClassColorHealth, "BOTTOMLEFT", 0, -12)
	MicroButtonBagBar.Text:SetText("MicroButtonBagBar")
	MicroButtonBagBar.tooltipText = "Enable / Disable the Bag Bar Menu in the lower right corner."
	MicroButtonBagBar:SetScript("OnClick", function(this)
		local checked = not not this:GetChecked()
		PlaySound(checked and SOUND_ON or SOUND_OFF)
		UberuiDB.MBBB = checked
		if checked then
			MBBB_Toggle()
		else
			MBBB_Toggle()
		end
	end)

	local Pvpicons = CreateFrame("CheckButton", "$parentPvpicons", self, "InterfaceOptionsCheckButtonTemplate")
	Pvpicons:SetPoint("TOPLEFT", MicroButtonBagBar, "BOTTOMLEFT", 0, -12)
	Pvpicons.Text:SetText("Toggle PVP Icons")
	Pvpicons.tooltipText = "Toggles showing of the Player / Target PVP icons. (will not be colored)"
	Pvpicons:SetScript("OnClick", function(this)
		local checked = not not this:GetChecked()
		PlaySound(checked and SOUND_ON or SOUND_OFF)
		UberuiDB.pvpicons = checked
		if checked then
			uui_pvpicons()
		else
			uui_pvpicons()
		end
	end)


	function self:refresh()
		Gryphon:SetChecked(UberuiDB.Gryphon)
		Hotkey:SetChecked(UberuiDB.Hotkey)
		Macroname:SetChecked(UberuiDB.Macroname)
		LargeHealth:SetChecked(UberuiDB.LargeHealth)
		ClassColorFrames:SetChecked(UberuiDB.ClassColorFrames)
		ClassColorHealth:SetChecked(UberuiDB.ClassColorHealth)
		BigFrames:SetChecked(UberuiDB.BigFrames)
		MicroButtonBagBar:SetChecked(UberuiDB.MBBB)
		Pvpicons:SetChecked(UberuiDB.pvpicons)
	end

	self:refresh()
	self:SetScript("OnShow", nil)
end)