
local Furious = {
	-- ui values
	Frame = nil,
	Indicator = nil,
	Skull = null,
	TexLight = nil,
	TexSkull = nil,

	FuryTextFrame = nil,
	FuryText = nil,
	StatusTextTime = 0,
	StatusTextFrame = nil,
	StatusText = nil,
	FootTextFrame = nil,
	FootText = nil,

	-- status values
	TargetSmashed = false,
	Enraged = false,
	Reckless = false,
	Avatar = false,
	Level = 0,
	Buff = 0,
	HasTarget = false,
	ExecuteRange = false,
	Rage = 0,
	RageMax = 0,

	-- timer tracking
	TimeSmash = nil,
	TimeEnrage = nil,
	TimeCombat = nil,
	TotalTimeCombat = 0,
	TotalTimeEnrage = 0,
	RatioEnrage = 0,

	-- methods
	CheckPlayerState = function(self)
		if(UnitAura("player","Enrage",nil,"PLAYER|HELPFUL")) then
			self.Enraged = true
			if(not self.TimeEnrage) then
				self.TimeEnrage = GetTime()
			end
		else
			self.Enraged = false
			if(self.TimeEnrage) then
				self.TotalTimeEnrage = self.TotalTimeEnrage + (GetTime() - self.TimeEnrage)
				self.TimeEnrage = nil
			end
		end

		if(UnitAura("player","Recklessness",nil,"PLAYER|HELPFUL")) then
			self.Reckless = true
		else self.Reckless = false end

		if(UnitAura("player","Avatar",nil,"PLAYER|HELPFUL")) then
			self.Avatar = true
		else self.Avatar = false end
	end,

	CheckPlayerRage = function(self)
		self.Rage = UnitPower("player")
		self.RageMax = UnitPowerMax("player")

		if(self.TimeCombat) then
			self:UpdateCombatFoot()
		end
	end,

	CheckTargetState = function(self)
		if(UnitAura("target","Colossus Smash",nil,"PLAYER|HARMFUL")) then
			self.TargetSmashed = true
		else self.TargetSmashed = false end

		local max = UnitHealthMax("target")
		local cur = UnitHealth("target")

		if(max == 0) then
			self.ExecuteRange = false
		else
			if(cur / max <= 0.2) then self.ExecuteRange = true
			else self.ExecuteRange = false end
		end
	end,

	--
	-- combat timers
	--

	CombatStarted = function(self)
		self.TotalTimeCombat = 0
		self.TotalTimeEnrage = 0
		self.TimeCombat = GetTime()
	end,

	CombatEnded = function(self)

		-- end the combat timer
		self.TotalTimeCombat = GetTime() - self.TimeCombat
		self.TimeCombat = nil

		-- end the enrage timer
		if(self.TimeEnrage) then
			self.TotalTimeEnrage = self.TotalTimeEnrage + (GetTime() - self.TimeEnrage)
			self.TimeEnrage = nil
		end

		self.RatioEnrage = math.floor((self.TotalTimeEnrage/self.TotalTimeCombat)*100)

		Furious_Shout("[FURIOUS] combat time: " .. self.TotalTimeCombat)
		Furious_Shout("[FURIOUS] enrage time: " .. self.TotalTimeEnrage)
		Furious_Shout("[FURIOUS] enraged " .. self.RatioEnrage .. "% of the time")

		self.StatusText:SetText(self.RatioEnrage .. "% ECR")
		self.FootText:SetText(
			"[CT: " .. math.ceil(self.TotalTimeCombat) .. "sec] "..
			"[ET: " .. math.ceil(self.TotalTimeEnrage) .. "sec]"
		)
	end,

	--
	-- mood text stuff
	--

	MoodText = {
		"Nonchalant",         -- 0
		"Enraged",            -- 1
		"Reckless",           -- 2
		"Recklessly Enraged", -- 3
		"Mighty",             -- 4
		"Mightly Enraged",    -- 5
		"Mightly Reckless",   -- 6
		"FUCKING FURIOUS"     -- 7
	},

	UpdateMoodText = function(self)
		self.FuryText:SetText(self.MoodText[self.Buff+1])
	end,

	--
	-- indicator stuff
	--

	UpdateIndicator = function(self)
		if(not self.HasTarget) then
			-- if no unit is targted then set to a disabled looking state
			-- and leave it at that.

			self.TexLight:SetTexture("Interface\\AddOns\\Furious\\Images\\grey")
			self.Skull:Hide()
		else
			-- else decide what colour to set the indicator to to display
			-- how well setup we are.

			if(self.Enraged and self.TargetSmashed) then
				self.TexLight:SetTexture("Interface\\AddOns\\Furious\\Images\\green")
			elseif(not self.Enraged and self.TargetSmashed) then
				self.TexLight:SetTexture("Interface\\AddOns\\Furious\\Images\\amber")
			else
				self.TexLight:SetTexture("Interface\\AddOns\\Furious\\Images\\red")
			end

			if(self.ExecuteRange) then self.Skull:Show()
			else self.Skull:Hide() end
		end
	end,

	--
	-- cooldown stuff
	--

	UpdateCooldown = function(self)
		if(GetTime() - self.StatusTextTime < 0.5) then return end
		if(not self.TimeCombat) then return end

		local start, duration = GetSpellCooldown("Colossus Smash")
		if(start > 0 and duration > 0) then
			self.StatusText:SetText("CS IN " .. math.ceil(duration - (GetTime() - start)))
		else
			self.StatusText:SetText("SMASH IT")
		end

		self.StatusTextTime = GetTime()
	end,

	--
	-- footer stuff
	--

	UpdateCombatFoot = function(self)
		self.FootText:SetText(
			"Rage: " .. math.floor((self.Rage/self.RageMax)*100) .. "% [" .. self.Rage .. "/" .. self.RageMax .. "]"
		)
	end,

	--
	-- frame update
	--

	Update = function(self)
		-- reset indicator level
		self.Level = 0

		-- reset buff status
		self.Buff = 0
		if(self.Enraged) then self.Buff = self.Buff + 1 end
		if(self.Reckless) then self.Buff = self.Buff + 2 end
		if(self.Avatar) then self.Buff = self.Buff + 4 end

		-- reset targeting
		self.HasTarget = UnitCanAttack("player","target")

		self:UpdateMoodText()
		self:UpdateIndicator()
	end
}

function Furious_OnEvent(self,event,...)
-- When an event is fired that we wanted to catch check what kind it is and
-- decide what to do about it.

	if(event=="UNIT_AURA") then
		-- track when buffs/debuffs arrive and fall off of units. we need to
		-- watch this so we know when our target has the proper debuffs on it
		-- and when the player has the proper buffs.

		local unit = ...
		if(unit == "target") then
			Furious:CheckTargetState()
		elseif(unit == "player") then
			Furious:CheckPlayerState()
		end

	elseif(event=="UNIT_HEALTH") then
		-- track when a unit's health is changed. we need to track this to
		-- know when the target is below 20% health for the execute range.

		local unit = ...
		if(unit == "target") then
			Furious:CheckTargetState()
		end

	elseif(event=="UNIT_POWER") then
		-- track when a unit's power is changed. we need to track this to show
		-- how much rage we have.

		local unit = ...
		if(unit == "player") then
			Furious:CheckPlayerRage()
		end


	elseif(event=="PLAYER_TARGET_CHANGED") then
		-- track when the player changes targets.

		Furious:CheckTargetState()

	elseif(event=="PLAYER_REGEN_DISABLED") then
		-- track combat and enraged time

		Furious:CombatStarted()

	elseif(event=="PLAYER_REGEN_ENABLED") then
		-- stop tracking and combat/enraged time

		Furious:CombatEnded()

	elseif(event=="SPELL_UPDATE_COOLDOWN") then
		-- update cooldown list

		Furious:UpdateCooldown()

	end

	Furious:Update()
end





-- -------------------------------------------------------------------------- --
-- -------------------------------------------------------------------------- --

function Furious_CreateFrame()
	Furious.Frame = CreateFrame("Frame","FuriousFrame",UIParent,nil)

	-- setup the furious frame
	Furious.Frame:RegisterEvent("UNIT_AURA")
	Furious.Frame:RegisterEvent("UNIT_HEALTH")
	Furious.Frame:RegisterEvent("UNIT_POWER")
	Furious.Frame:RegisterEvent("PLAYER_TARGET_CHANGED")
	Furious.Frame:RegisterEvent("PLAYER_REGEN_DISABLED")
	Furious.Frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	Furious.Frame:SetScript("OnEvent",Furious_OnEvent)
	Furious.Frame:SetScript("OnMouseDown",function() Furious.Frame:StartMoving() end)
	Furious.Frame:SetScript("OnMouseUp",function() Furious.Frame:StopMovingOrSizing() end)

	Furious.Frame:SetPoint("CENTER",0,0)
	Furious.Frame:SetWidth(350)
	Furious.Frame:SetHeight(128)
	Furious.Frame:EnableMouse(true)
	Furious.Frame:SetMovable(true)
	Furious.Frame:RegisterForDrag("LeftButton")
	Furious.Frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = nil,
		tile = true,
		tileSize = 32,
		edgeSize = 0,
		insets = nil
	})
	Furious.Frame:SetBackdropColor(0.0, 0.0, 0.0, 1.0)
	Furious.Frame:Show()

	-- setup indicator
	Furious.Indicator = CreateFrame("Frame","FuriousIndicator",Furious.Frame,nil)
	Furious.Indicator:SetSize(128,128)
	Furious.Indicator:SetPoint("TOPLEFT",0,0)
	Furious.Indicator:SetFrameLevel(1)
	Furious.TexLight = Furious.Indicator:CreateTexture()
	Furious.TexLight:SetAllPoints(Furious.Indicator)
	Furious.TexLight:SetTexture("Interface\\AddOns\\Furious\\Images\\red")
	Furious.Indicator:Show()

	-- setup skull indicator
	Furious.Skull = CreateFrame("Frame","FuriousSkull",Furious.Frame,nil)
	Furious.Skull:SetSize(128,128)
	Furious.Skull:SetPoint("TOPLEFT",0,0)
	Furious.Skull:SetFrameLevel(2)
	Furious.TexSkull = Furious.Skull:CreateTexture()
	Furious.TexSkull:SetAllPoints(Furious.Skull)
	Furious.TexSkull:SetTexture("Interface\\AddOns\\Furious\\Images\\skull")
	Furious.Skull:Show()

	-- setup text frame
	Furious.FuryTextFrame = CreateFrame("Frame","FuriousTextFrame",Furious.Frame,nil)
	Furious.FuryTextFrame:SetSize(226,32)
	Furious.FuryTextFrame:SetPoint("TOPLEFT",128,0)
	Furious.FuryText = Furious.FuryTextFrame:CreateFontString(nil,nil,"PVPInfoTextFont")
	Furious.FuryText:SetAllPoints()
	Furious.FuryText:SetTextHeight(14)
	--Furious.FuryText:SetText("-- MOOD --")

	-- status text frame
	Furious.StatusTextFrame = CreateFrame("Frame","FuriousStatusFrame",Furious.Frame,nil)
	Furious.StatusTextFrame:SetSize(226,64)
	Furious.StatusTextFrame:SetPoint("TOPLEFT",128,-32)
	Furious.StatusTextFrame:SetScript("OnUpdate",function() Furious:UpdateCooldown() end)
	Furious.StatusText = Furious.StatusTextFrame:CreateFontString(nil,nil,"PVPInfoTextFont")
	Furious.StatusText:SetAllPoints()
	Furious.StatusText:SetTextHeight(30)
	Furious.StatusText:SetText("Hello There")

	-- footer text frame
	Furious.FootTextFrame = CreateFrame("Frame","FuriousFootFrame",Furious.Frame,nil)
	Furious.FootTextFrame:SetSize(226,32)
	Furious.FootTextFrame:SetPoint("TOPLEFT",128,-94)
	Furious.FootText = Furious.FootTextFrame:CreateFontString(nil,nil,"PVPInfoTextFont")
	Furious.FootText:SetAllPoints()
	Furious.FootText:SetTextHeight(14)
	--Furious.FootText:SetText("-- FOOTER --")

	Furious:Update()
end

function Furious_Shout(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function Furious_SlashCommand(msg)
	Furious_Shout("furious: " .. msg);
end

function Furious_OnLoad()
	Furious_Shout("Furious: v1.0");
	Furious_Shout("i are fury warrior hear me enrage");

	SLASH_FURIOUS1 = "/furious";
	SlashCmdList["FURIOUS"] = function(msg)
		Furious_SlashCommand(msg);
	end

	Furious_CreateFrame()
end
