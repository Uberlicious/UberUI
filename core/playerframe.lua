local addon, ns = ...
local playerframes = {}

playerframes = CreateFrame("frame")
playerframes:RegisterEvent("ADDON_LOADED")
playerframes:RegisterEvent("PLAYER_LOGIN")
playerframes:RegisterEvent("PLAYER_ENTERING_WORLD")
playerframes:SetScript("OnEvent", function(self,event)
if not ((IsAddOnLoaded("EasyFrames")) or (IsAddOnLoaded("Shadowed Unit Frames")) or (IsAddOnLoaded("PitBull Unit Frames 4.0")) or (IsAddOnLoaded("X-Perl UnitFrames"))) then
end

player = uuidb.playerframe

end)

local function MiscFrames(color)
	if not (color) then
		color = uuidb.playerframe.color
	end

	if uuidb.playerframe.largehealth then
		frametexture = uuidb.textures.targetframebig
	else
		frametexture = uuidb.textures.targetframe
	end

	for _,v in pairs({
		PlayerFrameTexture,
		PlayerFrameAlternateManaBarBorder, 
		PlayerFrameAlternateManaBarRightBorder, 
		PlayerFrameAlternateManaBarLeftBorder,
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
		CastingBarFrame.Border,
		PaladinPowerBarFrameBG,
		PaladinPowerBarFrameBankBG
	}) do
		--texture frames to appropriately color
		if v:GetTexture() == "Interface\\TargetingFrame\\UI-TargetingFrame" and not uuidb.playerframe.LargeHealth then
			v:SetTexture(frametexture.targetingframe)
        elseif v:GetTexture() == "Interface\\TargetingFrame\\UI-SmallTargetingFrame" then
			v:SetTexture(uuidb.textures.other.smalltarget) 
        elseif v:GetTexture() == "Interface\\TargetingFrame\\UI-PartyFrame" then
			v:SetTexture(uuidb.textures.other.party)
        elseif v:GetTexture() == "Interface\\TargetingFrame\\UI-TargetofTargetFrame" then
			v:SetTexture(uuidb.textures.other.tot)
		end
		v:SetVertexColor(color.r, color.g, color.g, color.a)
    end
    CastingBarFrame.Border:SetTexture("Interface\\AddOns\\Uber UI\\textures\\castingbarborder")
end

function uui_playerframes_LargeHealth(color)
	if uuidb.general.customcolor then
		color = uuidb.general.customcolorval
	else
		color = uuidb.playerframe.color
	end

	if uuidb.playerframe.largehealth then
		PlayerFrameTexture:SetTexture("Interface\\Addons\\Uber UI\\textures\\target\\targetingframebig")
		PlayerFrameTexture:SetVertexColor(color.r, color.g, color.b, color.a)
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
		PlayerFrameManaBar.FullPowerFrame.SpikeFrame.AlertSpikeStay:SetPoint("CENTER",PlayerFrameManaBar.FullPowerFrame,"RIGHT",-6,-3)
		PlayerFrameManaBar.FullPowerFrame.SpikeFrame.AlertSpikeStay:SetSize(30, 29)
		PlayerFrameManaBar.FullPowerFrame.PulseFrame:ClearAllPoints()
		PlayerFrameManaBar.FullPowerFrame.PulseFrame:SetPoint("CENTER", PlayerFrameManaBar.FullPowerFrame, "CENTER", -6, -2)
		PlayerFrameManaBar.FullPowerFrame.SpikeFrame.BigSpikeGlow:ClearAllPoints()
		PlayerFrameManaBar.FullPowerFrame.SpikeFrame.BigSpikeGlow:SetPoint("CENTER",PlayerFrameManaBar.FullPowerFrame,"RIGHT",5,-4)
		PlayerFrameManaBar.FullPowerFrame.SpikeFrame.BigSpikeGlow:SetSize(30, 50)

		hooksecurefunc("PlayerFrame_UpdateStatus",function()
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

		hooksecurefunc("PlayerFrame_ToPlayerArt", uui_playerframes_LargeHealth)
	end
	PlayerFrameGroupIndicator:SetAlpha(0)
	PlayerHitIndicator:SetText(nil) 
	PlayerHitIndicator.SetText = function() end
end

function playerframes:Name()
	--print(uuidb.playerframe.name)
	--print(uuidb.playerframe.largehealth)
	--print(PlayerName:GetPoint())
	--if uuidb.playerframe.name and not uuidb.playerframe.largehealth then
	--	PlayerName:ClearAllPoints()
	--	PlayerName:SetPoint("CENTER", PlayerFrameTexture, "CENTER", 50, 19.000001907349)
	--elseif uuidb.playerframe.name then
	--	PlayerName:ClearAllPoints()
	--	PlayerName:SetPoint("CENTER", PlayerFrameTexture, "CENTER", 50, 39)
	--else
		PlayerName:Hide()

end

function playerframes:Scale(value)
	PlayerFrame:SetScale(value)
end


function playerframes:PetFrame()
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
	PetHitIndicator:SetText(nil) 
	PetHitIndicator.SetText = function() end
end

function playerframes:ReworkAllColor(color)
	if not ((IsAddOnLoaded("EasyFrames")) or (IsAddOnLoaded("Shadowed Unit Frames")) or (IsAddOnLoaded("PitBull Unit Frames 4.0")) or (IsAddOnLoaded("X-Perl UnitFrames"))) then
		if not (self) then
			self = playerframes
		end
		if not (color) then
			color = uuidb.playerframe.color
		end

		MiscFrames(color)

		--enable large health style
		if uuidb.playerframe.largehealth then
			uui_playerframes_LargeHealth(color)
		end
		self:Name()
		self:Scale(uuidb.playerframe.scale)
	end
end

UberUI.playerframes = playerframes