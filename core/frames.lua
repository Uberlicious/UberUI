  ---------------------------------------
  -- VARIABLES
  ---------------------------------------

  --get the addon namespace
  local addon, ns = ...
  --get the config values
  local cfg = ns.cfg
  local dragFrameList = ns.dragFrameList

  local classcolor = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
  local class = UnitClass("player")

  ---------------------------------------
  -- ACTIONS
  ---------------------------------------

  -- REMOVING UGLY PARTS OF UI
  
	local event_frame = CreateFrame('Frame')
	local errormessage_blocks = {
	  'Способность пока недоступна',
	  'Выполняется другое действие',
	  'Невозможно делать это на ходу',
	  'Предмет пока недоступен',
	  'Недостаточно',
	  'Некого атаковать',
	  'Заклинание пока недоступно',
	  'У вас нет цели',
	  'Вы пока не можете этого сделать',

	  'Ability is not ready yet',
 	  'Another action is in progress',
	  'Can\'t attack while mounted',
	  'Can\'t do that while moving',
	  'Item is not ready yet',
	  'Not enough',
	  'Nothing to attack',
	  'Spell is not ready yet',
	  'You have no target',
	  'You can\'t do that yet',
	}
	local enable
	local onevent
	local uierrorsframe_addmessage
	local old_uierrosframe_addmessage
	function enable ()
  		old_uierrosframe_addmessage = UIErrorsFrame.AddMessage
  		UIErrorsFrame.AddMessage = uierrorsframe_addmessage
	end

	function uierrorsframe_addmessage (frame, text, red, green, blue, id)
  		for i,v in ipairs(errormessage_blocks) do
    			if text and text:match(v) then
      				return
    			end
  		end
  		old_uierrosframe_addmessage(frame, text, red, green, blue, id)
	end

	local CF = CreateFrame("frame")
	CF:RegisterEvent("PLAYER_LOGIN")
	CF:SetScript("OnEvent", function(self, event)

  -- REWORKING THE MINIMAP
  function minimaprework()
		if not (IsAddOnLoaded("SexyMap")) then
			for i,v in pairs({
				MinimapBorder,
				MiniMapMailBorder,
				QueueStatusMinimapButtonBorder,
				select(1, TimeManagerClockButton:GetRegions()),
              		}) do
					if v == MinimapBorder and UberuiDB.ClassColorFrames then
						v:SetTexture("Interface\\AddOns\\Uber UI\\textures\\minimap-border")
						v:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
					elseif v == MinimapBorder and not UberuiDB.ClassColorFrames then
						v:SetTexture("Interface\\Minimap\\UI-MInimap-Border")
                 		v:SetVertexColor(.05,.05,.05)
                 	else
                 		v:SetVertexColor(.05,.05,.05)
                 	end
			end
			select(2, TimeManagerClockButton:GetRegions()):SetVertexColor(1,1,1)

			hooksecurefunc("GarrisonLandingPageMinimapButton_UpdateIcon", function(self)
				self:GetNormalTexture():SetTexture(nil)
				self:GetPushedTexture():SetTexture(nil)
				if not gb then
					gb = CreateFrame("Frame", nil, GarrisonLandingPageMinimapButton)
					gb:SetFrameLevel(GarrisonLandingPageMinimapButton:GetFrameLevel() - 1)
					gb:SetPoint("CENTER", 0, 0)
					gb:SetSize(36,36)

					gb.icon = gb:CreateTexture(nil, "ARTWORK")
					gb.icon:SetPoint("CENTER", 0, 0)
					gb.icon:SetSize(36,36)
			
					gb.border = CreateFrame("Frame", nil, gb)
					gb.border:SetFrameLevel(gb:GetFrameLevel() + 1)
					gb.border:SetAllPoints()

					gb.border.texture = gb.border:CreateTexture(nil, "ARTWORK")
					gb.border.texture:SetTexture("Interface\\PlayerFrame\\UI-PlayerFrame-Deathknight-Ring")
					if UberuiDB.ClassColorFrames then
						gb.border.texture:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
					else
						gb.border.texture:SetVertexColor(.05,.05,.05)
					end
					gb.border.texture:SetPoint("CENTER", 1, -2)
					gb.border.texture:SetSize(45,45)
				end
				if (C_Garrison.GetLandingPageGarrisonType() == 2) then
					if select(1,UnitFactionGroup("player")) == "Alliance" then	
						SetPortraitToTexture(gb.icon, select(3,GetSpellInfo(61573)))
					elseif select(1,UnitFactionGroup("player")) == "Horde" then
						SetPortraitToTexture(gb.icon, select(3,GetSpellInfo(61574)))
					end
				else
					local t = CLASS_ICON_TCOORDS[select(2,UnitClass("player"))]
                			gb.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                			gb.icon:SetTexCoord(unpack(t))
				end
			end)
  			MinimapBorderTop:Hide()
			MinimapZoomIn:Hide()
			MinimapZoomOut:Hide()
			MiniMapWorldMapButton:Hide()
			MinimapZoneText:SetPoint("CENTER", Minimap, 0, 80)
			GameTimeFrame:Hide()
			GameTimeFrame:UnregisterAllEvents()
			GameTimeFrame.Show = kill
			MiniMapTracking:Hide()
			MiniMapTracking.Show = kill
			MiniMapTracking:UnregisterAllEvents()
			Minimap:EnableMouseWheel(true)
			Minimap:SetScript("OnMouseWheel", function(self, z)
				local c = Minimap:GetZoom()
				if(z > 0 and c < 5) then
					Minimap:SetZoom(c + 1)
				elseif(z < 0 and c > 0) then
					Minimap:SetZoom(c - 1)
				end
			end)
			Minimap:SetScript("OnMouseUp", function(self, btn)
				if btn == "RightButton" then
					_G.GameTimeFrame:Click()
				elseif btn == "MiddleButton" then
					_G.ToggleDropDownMenu(1, nil, _G.MiniMapTrackingDropDown, self)
				else
					_G.Minimap_OnClick(self)
				end
			end)
		end
	end

minimaprework()

--color health bars
local function ClassColor(statusbar, unit)
if UberuiDB.ClassColorHealth == true then
	local _, class, c
	if UnitIsPlayer(unit) and UnitIsConnected(unit) and unit == statusbar.unit and UnitClass(unit) then
		_, class = UnitClass(unit)
		c = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS[class]
		statusbar:SetStatusBarColor(c.r, c.g, c.b)
	end
	if not UnitIsPlayer("target") then
		color = FACTION_BAR_COLORS[UnitReaction("target", "player")]
		if (not UnitPlayerControlled("target") and UnitIsTapDenied("target")) then
			TargetFrameHealthBar:SetStatusBarColor(0.5, 0.5, 0.5)
		else
			if color then
				TargetFrameHealthBar:SetStatusBarColor(color.r, color.g, color.b)
				TargetFrameHealthBar.lockColor = true
			end
		end
	end
	if not UnitIsPlayer("focus") then
		color = FACTION_BAR_COLORS[UnitReaction("focus", "player")]
		if (not UnitPlayerControlled("focus") and UnitIsTapDenied("focus")) then
			FocusFrameHealthBar:SetStatusBarColor(0.5, 0.5, 0.5)
		else
			if color then
				FocusFrameHealthBar:SetStatusBarColor(color.r, color.g, color.b)
				FocusFrameHealthBar.lockColor = true
			end
		end
	end
	if not UnitIsPlayer("targettarget") then
		color = FACTION_BAR_COLORS[UnitReaction("targettarget", "player")]
		if (not UnitPlayerControlled("targettarget") and UnitIsTapDenied("targettarget")) then
			TargetFrameToTHealthBar:SetStatusBarColor(0.5, 0.5, 0.5)
		else
			if color then
				TargetFrameToTHealthBar:SetStatusBarColor(color.r, color.g, color.b)
				TargetFrameToTHealthBar.lockColor = true
			end
		end
	end
	if not UnitIsPlayer("focustarget") then
		color = FACTION_BAR_COLORS[UnitReaction("focustarget", "player")]
		if (not UnitPlayerControlled("focustarget") and UnitIsTapDenied("focustarget")) then
			FocusFrameToTHealthBar:SetStatusBarColor(0.5, 0.5, 0.5)
		else
			if color then
				FocusFrameToTHealthBar:SetStatusBarColor(color.r, color.g, color.b)
				FocusFrameToTHealthBar.lockColor = true
			end
		end
	end
end
end

hooksecurefunc(
	"UnitFrameHealthBar_Update",
	function(self)
		ClassColor(self, self.unit)
	end
)

hooksecurefunc(
	"HealthBar_OnValueChanged",
	function(self)
		ClassColor(self, self.unit)
	end
)

  --PLAYER
function PlayerFrameHealth(self)
	if not (IsAddOnLoaded("EasyFrames")) then
	PlayerFrameTexture:SetTexture("Interface\\Addons\\Uber UI\\textures\\target\\targetingframebig")
	if UberuiDB.ClassColorFrames then
		PlayerFrameTexture:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
	else
		PlayerFrameTexture:SetVertexColor(.05, .05, .05)
	end
	PlayerName:Hide()
	PlayerFrameGroupIndicatorText:ClearAllPoints()
	PlayerFrameGroupIndicatorText:SetPoint("BOTTOMLEFT", PlayerFrame, "TOP", 0, -20)
	PlayerFrameGroupIndicatorLeft:Hide()
	PlayerFrameGroupIndicatorMiddle:Hide()
	PlayerFrameGroupIndicatorRight:Hide()
	PlayerFrameHealthBar:SetPoint("TOPLEFT", 106, -24)
	PlayerFrameHealthBar:SetHeight(29)
	PlayerFrameHealthBar.LeftText:ClearAllPoints()
	PlayerFrameHealthBar.LeftText:SetPoint("LEFT", PlayerFrameHealthBar, "LEFT", 10, 0)
	PlayerFrameHealthBar.RightText:ClearAllPoints()
	PlayerFrameHealthBar.RightText:SetPoint("RIGHT", PlayerFrameHealthBar, "RIGHT", -5, 0)
	PlayerFrameHealthBarText:SetPoint("CENTER", PlayerFrameHealthBar, "CENTER", 0, 0)
	PlayerFrameManaBar:SetPoint("TOPLEFT", 106, -52)
	PlayerFrameManaBar:SetHeight(13)
	PlayerFrameManaBar.LeftText:ClearAllPoints()
	PlayerFrameManaBar.LeftText:SetPoint("LEFT", PlayerFrameManaBar, "LEFT", 10, 0)
	PlayerFrameManaBar.RightText:ClearAllPoints()
	PlayerFrameManaBar.RightText:SetPoint("RIGHT", PlayerFrameManaBar, "RIGHT", -5, 1)
	PlayerFrameManaBarText:SetPoint("CENTER", PlayerFrameManaBar, "CENTER", 0, 0)
	PlayerFrameManaBar.FeedbackFrame:ClearAllPoints()
	PlayerFrameManaBar.FeedbackFrame:SetPoint("CENTER", PlayerFrameManaBar, "CENTER", 0, 0)
	PlayerFrameManaBar.FeedbackFrame:SetHeight(13)
	PlayerFrameManaBar.FullPowerFrame.SpikeFrame.AlertSpikeStay:ClearAllPoints()
	PlayerFrameManaBar.FullPowerFrame.SpikeFrame.AlertSpikeStay:SetPoint(
		"CENTER",
		PlayerFrameManaBar.FullPowerFrame,
		"RIGHT",
		-6,
		-3
	)
	PlayerFrameManaBar.FullPowerFrame.SpikeFrame.AlertSpikeStay:SetSize(30, 29)
	PlayerFrameManaBar.FullPowerFrame.PulseFrame:ClearAllPoints()
	PlayerFrameManaBar.FullPowerFrame.PulseFrame:SetPoint("CENTER", PlayerFrameManaBar.FullPowerFrame, "CENTER", -6, -2)
	PlayerFrameManaBar.FullPowerFrame.SpikeFrame.BigSpikeGlow:ClearAllPoints()
	PlayerFrameManaBar.FullPowerFrame.SpikeFrame.BigSpikeGlow:SetPoint(
		"CENTER",
		PlayerFrameManaBar.FullPowerFrame,
		"RIGHT",
		5,
		-4
	)
	PlayerFrameManaBar.FullPowerFrame.SpikeFrame.BigSpikeGlow:SetSize(30, 50)

	hooksecurefunc(
	"PlayerFrame_UpdateStatus",
	function()
		PlayerStatusTexture:Hide()
		PlayerRestGlow:Hide()
		PlayerStatusGlow:Hide()
		PlayerPrestigeBadge:SetAlpha(0)
		PlayerPrestigePortrait:SetAlpha(0)
		TargetFrameTextureFramePrestigeBadge:SetAlpha(0)
		TargetFrameTextureFramePrestigePortrait:SetAlpha(0)
		FocusFrameTextureFramePrestigeBadge:SetAlpha(0)
		FocusFrameTextureFramePrestigePortrait:SetAlpha(0)
	end)
	end
	hooksecurefunc("PlayerFrame_ToPlayerArt", PlayerFrameHealth)
end

if UberuiDB.LargeHealth then
	PlayerFrameHealth()
end

--TARGET
function StyleTargetFrame(self, forceNormalTexture)
	if not (IsAddOnLoaded("EasyFrames")) and UberuiDB.LargeHealth then
		self.deadText:ClearAllPoints()
		self.deadText:SetPoint("CENTER", self.healthbar, "CENTER", 0, 0)
		self.levelText:SetPoint("RIGHT", self.healthbar, "BOTTOMRIGHT", 63, 10)
		self.nameBackground:Hide()
		self.Background:SetSize(119, 42)
		self.manabar.pauseUpdates = false
		self.manabar:Show()
		TextStatusBar_UpdateTextString(self.manabar)
		self.threatIndicator:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Flash")
		self.name:SetPoint("LEFT", self, 15, 36)
		self.healthbar:SetSize(119, 29)
		self.healthbar:ClearAllPoints()
		self.healthbar:SetPoint("TOPLEFT", 5, -24)
		self.healthbar.LeftText:ClearAllPoints()
		self.healthbar.LeftText:SetPoint("LEFT", self.healthbar, "LEFT", 8, 0)
		self.healthbar.RightText:ClearAllPoints()
		self.healthbar.RightText:SetPoint("RIGHT", self.healthbar, "RIGHT", -5, 0)
		self.healthbar.TextString:SetPoint("CENTER", self.healthbar, "CENTER", 0, 0)
		self.manabar:ClearAllPoints()
		self.manabar:SetPoint("TOPLEFT", 5, -52)
		self.manabar:SetSize(119, 13)
		self.manabar.LeftText:ClearAllPoints()
		self.manabar.LeftText:SetPoint("LEFT", self.manabar, "LEFT", 8, 0)
		self.manabar.RightText:ClearAllPoints()
		self.manabar.RightText:SetPoint("RIGHT", self.manabar, "RIGHT", -5, 0)
		self.manabar.TextString:SetPoint("CENTER", self.manabar, "CENTER", 0, 0)
	
		--TargetOfTarget
		TargetFrameToTHealthBar:ClearAllPoints()
		TargetFrameToTHealthBar:SetPoint("TOPLEFT", 44, -15)
		TargetFrameToTHealthBar:SetHeight(8)
		TargetFrameToTManaBar:ClearAllPoints()
		TargetFrameToTManaBar:SetPoint("TOPLEFT", 44, -24)
		TargetFrameToTManaBar:SetHeight(5)
		FocusFrameToTHealthBar:ClearAllPoints()
		FocusFrameToTHealthBar:SetPoint("TOPLEFT", 45, -15)
		FocusFrameToTHealthBar:SetHeight(8)
		FocusFrameToTManaBar:ClearAllPoints()
		FocusFrameToTManaBar:SetPoint("TOPLEFT", 45, -25)
		FocusFrameToTManaBar:SetHeight(3)
		FocusFrameToT.deadText:SetWidth(0.01)
	end

			if UberuiDB.LargeHealth then
				frametexture = cfg.targetframebig
			else
				frametexture = cfg.targetframe
			end

			local classification = UnitClassification(self.unit)
			if ( classification == "minus" ) then
				self.borderTexture:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Minus");
				self.borderTexture:SetVertexColor(.05, .05, .05)
				self.nameBackground:Hide();
				self.manabar.pauseUpdates = true;
				self.manabar:Hide();
				self.manabar.TextString:Hide();
				self.manabar.LeftText:Hide();
				self.manabar.RightText:Hide();
				forceNormalTexture = true;
			elseif ( classification == "worldboss" or classification == "elite" ) then
				self.borderTexture:SetTexture(frametexture.elite)
				if UberuiDB.ClassColorFrames then
					self.borderTexture:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
				else
					self.borderTexture:SetVertexColor(.05, .05, .05)
				end
			elseif ( classification == "rareelite" ) then
				self.borderTexture:SetTexture(frametexture.rareelite)
				if UberuiDB.ClassColorFrames then
					self.borderTexture:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
				else
					self.borderTexture:SetVertexColor(.05, .05, .05)
				end
			elseif ( classification == "rare" ) then
				self.borderTexture:SetTexture(frametexture.rare)
				if UberuiDB.ClassColorFrames then
					self.borderTexture:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
				else
					self.borderTexture:SetVertexColor(.05, .05, .05)
				end
			else
				self.borderTexture:SetTexture(frametexture.targetingframe)
				if UberuiDB.ClassColorFrames then
					self.borderTexture:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
				else
					self.borderTexture:SetVertexColor(.05, .05, .05)
				end
			end
		end
hooksecurefunc("TargetFrame_CheckClassification", StyleTargetFrame)

	hooksecurefunc("PetFrame_Update", function(self, override)
		  if ( (not PlayerFrame.animating or UnitInVehicle("player") or UnitisDead("player")) or (override) ) then
  			  if ( UnitIsVisible(self.unit) and PetUsesPetFrame() and not PlayerFrame.vehicleHidesPet ) then
  			    if ( self:IsShown() ) then
  			      UnitFrame_Update(self);
  			    else
  			      self:Show();
  			    end
  			    --self.flashState = 1;
  			    --self.flashTimer = PET_FLASH_ON_TIME;
  			    if ( UnitPowerMax(self.unit) == 0 ) then
  			      PetFrameTexture:SetTexture("Interface\\AddOns\\Uber UI\\textures\\target\\smalltargetingframe-nomana");
  			      PetFrameManaBarText:Hide();
  			    else
  			      PetFrameTexture:SetTexture("Interface\\AddOns\\Uber UI\\textures\\target\\smalltargetingframe");
  			    end
  			    PetAttackModeTexture:Hide();
 			
  			    RefreshDebuffs(self, self.unit, nil, nil, true);
  			  else
  			    self:Hide();
  			  end
  			end
		end)

	function ColorRaid()
		for g = 1, NUM_RAID_GROUPS do
			local group = _G["CompactRaidGroup"..g.."BorderFrame"]
			if group then
				for _, region in pairs({group:GetRegions()}) do
					if region:IsObjectType("Texture") then
						if UberuiDB.ClassColorFrames then
							region:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
						else
							region:SetVertexColor(.05, .05, .05)
						end
					end
				end
			end
			for m = 1, 5 do
				local frame = _G["CompactRaidGroup"..g.."Member"..m]
				if frame then
					groupcolored = true
					for _, region in pairs({frame:GetRegions()}) do
						if region:GetName():find("Border") then
							if UberuiDB.ClassColorFrames then
								region:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
							else
								region:SetVertexColor(.05, .05, .05)
							end
						end
					end
				end
				local frame = _G["CompactRaidFrame"..m]
				if frame then
					singlecolored = true
					for _, region in pairs({frame:GetRegions()}) do
						if region:GetName():find("Border") then
							if UberuiDB.ClassColorFrames then
								region:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
							else
								region:SetVertexColor(.05, .05, .05)
							end
						end
					end
				end
			end
		end
		for _, region in pairs({CompactRaidFrameContainerBorderFrame:GetRegions()}) do
			if region:IsObjectType("Texture") then
				if UberuiDB.ClassColorFrames then
					region:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
				else
					region:SetVertexColor(.05, .05, .05)
				end
			end
		end
		if CompactPartyFrameBorderFrame then
			for _,region in pairs({CompactPartyFrameBorderFrame:GetRegions()}) do
   				if UberuiDB.ClassColorFrames then
					region:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
				else
					region:SetVertexColor(.05, .05, .05)
				end
			end
		end
	end
	
	CF:RegisterEvent("PLAYER_ENTERING_WORLD")
	CF:RegisterEvent("GROUP_ROSTER_UPDATE")
	CF:SetScript("OnEvent", function(self, event)
		ColorRaid()
		CF:SetScript("OnUpdate", function()
			if CompactRaidGroup1 and not groupcolored == true then
				ColorRaid()
			end
			if CompactRaidFrame1 and not singlecolored == true then
				ColorRaid()
			end
		end)
	end)
		if UberuiDB.LargeHealth then
			frametexture = cfg.targetframebig
		else
			frametexture = cfg.targetframe
		end

		if event == "GROUP_ROSTER_UPDATE" then return end
		if not (IsAddOnLoaded("Shadowed Unit Frames") or IsAddOnLoaded("PitBull Unit Frames 4.0") or IsAddOnLoaded("X-Perl UnitFrames")) then
                if not IsAddOnLoaded("EasyFrames") then
                	for i,v in pairs({
                		PlayerFrameTexture,
						PlayerFrameAlternateManaBarBorder, 
						PlayerFrameAlternateManaBarRightBorder, 
						PlayerFrameAlternateManaBarLeftBorder,
						--TargetFrameTextureFrameTexture, 
						TargetFrameToTTextureFrameTexture,
						PetFrameTexture, 
						FocusFrameTextureFrameTexture, 
						FocusFrameToTTextureFrameTexture,
						PartyMemberFrame1Texture, 
						PartyMemberFrame2Texture, 
						PartyMemberFrame3Texture, 
						PartyMemberFrame4Texture,
						PartyMemberFrame1PetFrameTexture, 
						PartyMemberFrame2PetFrameTexture, 
						PartyMemberFrame3PetFrameTexture,
						PartyMemberFrame4PetFrameTexture
                		}) do
                	    if UberuiDB.ClassColorFrames then
                	    	if v:GetTexture() == "Interface\\TargetingFrame\\UI-TargetingFrame" and not UberuiDB.LargeHealth then
                	    		v:SetTexture(frametexture.targetingframe)
                	    		v:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
                	    	elseif v:GetTexture() == "Interface\\TargetingFrame\\UI-SmallTargetingFrame" then
                	    		v:SetTexture("Interface\\AddOns\\Uber UI\\textures\\target\\smalltargetingframe") 
                				v:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
                			elseif v:GetTexture() == "Interface\\TargetingFrame\\UI-PartyFrame" then
                				v:SetTexture("Interface\\AddOns\\Uber UI\\textures\\partyframe")
                				v:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
                			elseif v:GetTexture() == "Interface\\TargetingFrame\\UI-TargetofTargetFrame" then
                				v:SetTexture("Interface\\AddOns\\Uber UI\\textures\\target\\targetoftargetframe")
                				v:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
       						end
                		else
                 			v:SetVertexColor(.05,.05,.05)
                 		end
                	end
                end
                	for i,v in pairs({
				ComboPointPlayerFrame.Background,
				ComboPointPlayerFrame.Combo1.PointOff,
				ComboPointPlayerFrame.Combo2.PointOff,
				ComboPointPlayerFrame.Combo3.PointOff,
				ComboPointPlayerFrame.Combo4.PointOff,
				ComboPointPlayerFrame.Combo5.PointOff,
				ComboPointPlayerFrame.Combo6.PointOff,
				AlternatePowerBarBorder,
				AlternatePowerBarLeftBorder,
				AlternatePowerBarRightBorder,
  				PetFrameTexture,
				Boss1TargetFrameTextureFrameTexture,
				Boss2TargetFrameTextureFrameTexture,
				Boss3TargetFrameTextureFrameTexture,
				Boss4TargetFrameTextureFrameTexture,
				Boss5TargetFrameTextureFrameTexture,
				Boss1TargetFrameSpellBar.Border,
				Boss2TargetFrameSpellBar.Border,
				Boss3TargetFrameSpellBar.Border,
				Boss4TargetFrameSpellBar.Border,
				Boss5TargetFrameSpellBar.Border,
				CastingBarFrame.Border,
				FocusFrameSpellBar.Border,
				TargetFrameSpellBar.Border,
				PaladinPowerBarFrameBG,
				PaladinPowerBarFrameBankBG
			}) do
                	if UberuiDB.ClassColorFrames then
                		v:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
                	else
                 		v:SetVertexColor(.05, .05, .05)
                 	end
			end

			for _, region in pairs({StopwatchFrame:GetRegions()}) do
				if UberuiDB.ClassColorFrames then
					region:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
				else
 					region:SetVertexColor(.05, .05, .05)
 				end
 			end
			
			for _, region in pairs({CompactRaidFrameManager:GetRegions()}) do
				if region:IsObjectType("Texture") and UberuiDB.ClassColorFrames then
					region:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
				else region:IsObjectType("Texture")
 					region:SetVertexColor(.05, .05, .05)
 				end
			end
			for _, region in pairs({CompactRaidFrameManagerContainerResizeFrame:GetRegions()}) do
				if region:GetName():find("Border") and UberuiDB.ClassColorFrames then
					region:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
				else region:IsObjectType("Border")
 					region:SetVertexColor(.05, .05, .05)
				end
			end
			CompactRaidFrameManagerToggleButton:SetNormalTexture("Interface\\AddOns\\Uber UI\\textures\\raid\\RaidPanel-Toggle")
			
			hooksecurefunc("GameTooltip_ShowCompareItem", function(self, anchorFrame)
				if (self) then
					local shoppingTooltip1, shoppingTooltip2 = unpack(self.shoppingTooltips)
					if UberuiDB.ClassColorFrames then
						shoppingTooltip1:SetBackdropBorderColor(classcolor.r, classcolor.g, classcolor.b)
						shoppingTooltip2:SetBackdropBorderColor(classcolor.r, classcolor.g, classcolor.b)
					else
						shoppingTooltip1:SetBackdropBorderColor(.05, .05, .05)
						shoppingTooltip2:SetBackdropBorderColor(.05, .05, .05)
					end
				end
			end)
			
			hooksecurefunc("GameTooltip_SetBackdropStyle", function(self, style)
				if UberuiDB.ClassColorFrames then
					self:SetBackdropBorderColor(classcolor.r, classcolor.g, classcolor.b)
				elseif self then
					self:SetBackdropBorderColor(.05, .05, .05);
				end
			end)

			--GameTooltip.SetBackdropBorderColor = function() end
		function uui_pvpicons()
			for i,v in pairs({
				PlayerPVPIcon,
				TargetFrameTextureFramePVPIcon,
				FocusFrameTextureFramePVPIcon,
			}) do
				if not UberuiDB.pvpicons then
					v:SetAlpha(0)
				else
					v:SetVertexColor(.75,.75,.75,1)
				end
			end
		end

			for i=1,4 do 
				_G["PartyMemberFrame"..i.."PVPIcon"]:SetAlpha(0)
				_G["PartyMemberFrame"..i.."NotPresentIcon"]:Hide()
				_G["PartyMemberFrame"..i.."NotPresentIcon"].Show = function() end
			end
			PlayerFrameGroupIndicator:SetAlpha(0)
			PlayerHitIndicator:SetText(nil) 
			PlayerHitIndicator.SetText = function() end
			PetHitIndicator:SetText(nil) 
			PetHitIndicator.SetText = function() end

		if UberuiDB.ClassColorFrames then
			TargetFrameSpellBar.Border:SetTexture("Interface\\AddOns\\Uber UI\\textures\\castingbar-small")
			TargetFrameSpellBar.Border:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
		else
			TargetFrameSpellBar.Border:SetVertexColor(.05,.05,.05)
		end

 		if UberuiDB.ClassColorFrames then
 			CastingBarFrame.Border:SetTexture("Interface\\AddOns\\Uber UI\\textures\\castingbarborder")
 			CastingBarFrame.Border:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
		else
			CastingBarFrame.Border:SetVertexColor(.05,.05,.05)    
		end
	end
	MBBB_Toggle()
	UUI_BigFrames()
	uui_pvpicons()
end)


 -- COLORING THE MAIN BAR
 	local CF=CreateFrame("Frame")
 	CF:RegisterEvent("PLAYER_LOGIN")
 	CF:SetScript("OnEvent", function(self, event)
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
			MainMenuBarArtFrame.LeftEndCap,
    	    MainMenuBarArtFrame.RightEndCap,
		}) do
			if UberuiDB.ClassColorFrames then
				local frameAtlas = v:GetAtlas()
   				if frameAtlas ~= nil then
   				   	local txl, txr, txt, txb = select(4, GetAtlasInfo(frameAtlas))
   				   	v:SetTexture("Interface\\AddOns\\Uber UI\\Textures\\MainMenuBar")
   				   	v:SetTexCoord(txl, txr, txt, txb)
   				   	if v == MainMenuBarArtFrame.RightEndCap then
   				   		v:SetTexCoord(txr, txl, txt, txb)
   				   	end
   				   	v:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
   				else
   				   v:SetVertexColor(classcolor.r, classcolor.g, classcolor.b)
   				end
   			else 
   				v:SetVertexColor(.2,.2,.2)
   			end
   			if v == MainMenuBarArtFrame.RightEndCap or v == MainMenuBarArtFrame.LeftEndCap then
   				if UberuiDB.Gryphon then
					v:Show()
				else
				  	v:Hide()
				end
			end
		end
	end)
	
 -- COLORING ARENA FRAMES
	local CF = CreateFrame("Frame")
	local _, instanceType = IsInInstance()
	CF:RegisterEvent("ADDON_LOADED")
	CF:RegisterEvent("PLAYER_ENTERING_WORLD")
	CF:RegisterEvent("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
        CF:SetScript("OnEvent", function(self, event, addon)
             	if addon == "Blizzard_ArenaUI" and not (IsAddOnLoaded("Shadowed Unit Frames")) then
			for i,v in pairs({
 				ArenaEnemyFrame1Texture,
				ArenaEnemyFrame2Texture,
				ArenaEnemyFrame3Texture, 
				ArenaEnemyFrame4Texture,
				ArenaEnemyFrame5Texture,
				ArenaEnemyFrame1SpecBorder,
				ArenaEnemyFrame2SpecBorder,
				ArenaEnemyFrame3SpecBorder,
				ArenaEnemyFrame4SpecBorder,
				ArenaEnemyFrame5SpecBorder,
				ArenaEnemyFrame1PetFrameTexture,
				ArenaEnemyFrame2PetFrameTexture,
				ArenaEnemyFrame3PetFrameTexture,
				ArenaEnemyFrame4PetFrameTexture, 
				ArenaEnemyFrame5PetFrameTexture,
              		}) do
                		v:SetVertexColor(.05, .05, .05)
	      		end 
		elseif event == "ARENA_PREP_OPPONENT_SPECIALIZATIONS" or (event == "PLAYER_ENTERING_WORLD" and instanceType == "arena") then
			for i,v in pairs({
				ArenaPrepFrame1Texture,
				ArenaPrepFrame2Texture,
				ArenaPrepFrame3Texture,
				ArenaPrepFrame4Texture,
				ArenaPrepFrame5Texture,
				ArenaPrepFrame1SpecBorder,
				ArenaPrepFrame2SpecBorder,
				ArenaPrepFrame3SpecBorder,
				ArenaPrepFrame4SpecBorder,
				ArenaPrepFrame5SpecBorder,
			}) do
                	v:SetVertexColor(.05, .05, .05)
	      	end 		
		end 
	if IsAddOnLoaded("Blizzard_ArenaUI") then
		for i,v in pairs({
 			ArenaEnemyFrame1Texture,
			ArenaEnemyFrame2Texture,
			ArenaEnemyFrame3Texture, 
			ArenaEnemyFrame4Texture,
			ArenaEnemyFrame5Texture,
			ArenaEnemyFrame1SpecBorder,
			ArenaEnemyFrame2SpecBorder,
			ArenaEnemyFrame3SpecBorder,
			ArenaEnemyFrame4SpecBorder,
			ArenaEnemyFrame5SpecBorder,
			ArenaEnemyFrame1PetFrameTexture,
			ArenaEnemyFrame2PetFrameTexture,
			ArenaEnemyFrame3PetFrameTexture,
			ArenaEnemyFrame4PetFrameTexture, 
			ArenaEnemyFrame5PetFrameTexture,
            }) do
                	v:SetVertexColor(.05, .05, .05)
	    end 
	end
end)
	function UUI_BigFrames()
		if UberuiDB.BigFrames == true then
			PlayerFrame:SetScale(1.2)
			TargetFrame:SetScale(1.2)
		else
			PlayerFrame:SetScale(1)
			TargetFrame:SetScale(1)
		end
	end

local CF = CreateFrame("Frame")
local _, instanceType = IsInInstance()
CF:RegisterEvent("ADDON_LOADED")
CF:RegisterEvent("PLAYER_ENTERING_WORLD")
CF:SetScript("OnEvent", function(self, event, addon)

	function MBBB_Toggle()
		for _,v in pairs({
			MicroButtonAndBagsBar,
		}) do
			if UberuiDB.MBBB then
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
end)
