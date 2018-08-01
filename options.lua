--[[--------------------------------------------------------------------
	Uber UI
	Darkens default UI
	Maintained by Uberlicious
----------------------------------------------------------------------]]

local addon, ns = ...

local SOUND_OFF = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
local SOUND_ON = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON

local Options = CreateFrame("Frame", "LortiUI-DevOptions", InterfaceOptionsFramePanelContainer)
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

	local Gryphon = CreateFrame("CheckButton", "$parentGryphon", self, "InterfaceOptionsCheckButtonTemplate")
	Gryphon:SetPoint("TOPLEFT", SubText, "BOTTOMLEFT", 0, -12)
	Gryphon.Text:SetText("Show Gryphons")
	Gryphon.tooltipText = "Shows the gryphons on the sides of actionbars."
	Gryphon:SetScript("OnClick", function(this)
		local checked = not not this:GetChecked()
		PlaySound(checked and SOUND_ON or SOUND_OFF)
		UberuiDB.Gryphon = checked
		if UberuiDB.Gryphon and UberuiDB.Classcolor then
			MainMenuBarArtFrame.LeftEndCap:SetTexture("Interface\\AddOns\\Uber UI\\textures\\classtextures\\"..class.."\\mainmenubar-endcap-dwarf")
			MainMenuBarArtFrame.LeftEndCap:SetVertexColor(1, 1, 1)
			MainMenuBarArtFrame.LeftEndCap:SetTexCoord(0,1,.40625,1)
			MainMenuBarArtFrame.LeftEndCap:Show()
			MainMenuBarArtFrame.RightEndCap:SetTexture("Interface\\AddOns\\Uber UI\\textures\\classtextures\\"..class.."\\mainmenubar-endcap-dwarf")
			MainMenuBarArtFrame.RightEndCap:SetVertexColor(1, 1, 1)
			MainMenuBarArtFrame.RightEndCap:SetTexCoord(1,0,.40625,1)
			MainMenuBarArtFrame.RightEndCap:Show()
		else
    		for i,v in ipairs({
				MainMenuBarArtFrame.LeftEndCap,
    		    MainMenuBarArtFrame.RightEndCap, 
			}) do
				if UberuiDB.Gryphon then
					v:SetVertexColor(.35, .35, .35)
					v:Show()
				else
    		    	v:Hide()
    		    end
    	   	end
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
				_G["PetActionButton"..i]["HotKey"]:Show()
			else
				_G["ActionButton"..i]["HotKey"]:Hide()
				_G["MultiBarBottomLeftButton"..i]["HotKey"]:Hide()
				_G["MultiBarBottomRightButton"..i]["HotKey"]:Hide()
				_G["MultiBarRightButton"..i]["HotKey"]:Hide()
				_G["MultiBarLeftButton"..i]["HotKey"]:Hide()
				_G["PetActionButton"..i]["HotKey"]:Hide()
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
				_G["PetActionButton"..i]["Name"]:Show()
			else
				_G["ActionButton"..i]["Name"]:Hide()
				_G["MultiBarBottomLeftButton"..i]["Name"]:Hide()
				_G["MultiBarBottomRightButton"..i]["Name"]:Hide()
				_G["MultiBarRightButton"..i]["Name"]:Hide()
				_G["MultiBarLeftButton"..i]["Name"]:Hide()
				_G["PetActionButton"..i]["Name"]:Hide()
			end
    	end
	end)


	function self:refresh()
		Gryphon:SetChecked(UberuiDB.Gryphon)
		Hotkey:SetChecked(UberuiDB.Hotkey)
		Macroname:SetChecked(UberuiDB.Macroname)
	end

	self:refresh()
	self:SetScript("OnShow", nil)
end)