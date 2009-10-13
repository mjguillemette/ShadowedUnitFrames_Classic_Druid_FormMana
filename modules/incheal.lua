local IncHeal = {}
local frames = {}
local playerEndTime, playerGUID
local HealComm = LibStub("LibHealComm-4.0", true)
ShadowUF:RegisterModule(IncHeal, "incHeal", ShadowUFLocals["Incoming heals"])
	
-- How far ahead to show heals at most
local INCOMING_SECONDS = 3

function IncHeal:OnEnable(frame)
	frames[frame] = true
	frame.incHeal = frame.incHeal or ShadowUF.Units:CreateBar(frame)
	frame.incHeal:SetFrameLevel(frame.topFrameLevel - 2)
	
	frame:RegisterUnitEvent("UNIT_MAXHEALTH", self, "UpdateFrame")
	frame:RegisterUnitEvent("UNIT_HEALTH", self, "UpdateFrame")
	frame:RegisterUpdateFunc(self, "UpdateFrame")
	
	self:Setup()
end

function IncHeal:OnDisable(frame)
	frame:UnregisterAll(self)
	frame.incHeal:Hide()
	
	if( not frame.hasHCTag ) then
		frames[frame] = nil
		self:Setup()
	end
end

function IncHeal:OnLayoutApplied(frame)
	if( frame.visibility.incHeal and frame.visibility.healthBar ) then
		frame.incHeal:SetWidth(frame.healthBar:GetWidth() * ShadowUF.db.profile.units[frame.unitType].incHeal.cap)
		frame.incHeal:SetHeight(frame.healthBar:GetHeight())
		frame.incHeal:SetStatusBarTexture(ShadowUF.Layout.mediaPath.statusbar)
		frame.incHeal:SetStatusBarColor(ShadowUF.db.profile.healthColors.inc.r, ShadowUF.db.profile.healthColors.inc.g, ShadowUF.db.profile.healthColors.inc.b, ShadowUF.db.profile.bars.alpha)
		frame.incHeal:SetPoint("TOPLEFT", frame.healthBar)
		frame.incHeal:SetPoint("BOTTOMLEFT", frame.healthBar)
		frame.incHeal:Hide()
	end
end

-- Since I don't want a more complicated system where both incheal.lua and tags.lua are watching the same events
-- I'll update the HC tags through here instead
function IncHeal:EnableTag(frame)
	frames[frame] = true
	frame.hasHCTag = true
	
	self:Setup()
end

function IncHeal:DisableTag(frame)
	frame.hasHCTag = nil
	
	if( not frame.visibility.incHeal ) then
		frames[frame] = nil
		self:Setup()
	end
end

-- Check if we need to register callbacks
function IncHeal:Setup()
	playerGUID = UnitGUID("player")
	
	local enabled
	for frame in pairs(frames) do
		enabled = true
		break
	end
	
	if( not enabled ) then
		if( HealComm ) then
			HealComm:UnregisterAllCallbacks(IncHeal)
		end
		return
	end

	HealComm.RegisterCallback(self, "HealComm_HealStarted", "HealComm_HealUpdated")
	HealComm.RegisterCallback(self, "HealComm_HealStopped")
	HealComm.RegisterCallback(self, "HealComm_HealDelayed", "HealComm_HealUpdated")
	HealComm.RegisterCallback(self, "HealComm_HealUpdated")
	HealComm.RegisterCallback(self, "HealComm_ModifierChanged")
	HealComm.RegisterCallback(self, "HealComm_GUIDDisappeared")
end

-- Update any tags using HC
function IncHeal:UpdateTags(frame, amount)
	if( not frame.fontStrings or not frame.hasHCTag ) then return end
	
	for _, fontString in pairs(frame.fontStrings) do
		if( fontString.hasHCTag ) then
			fontString.incoming = amount > 0 and amount or nil
			fontString:UpdateTags()
		end
	end
end

local function updateHealthBar(frame, interrupted)
	-- This makes sure that when a heal like Tranquility is cast, it won't show the entire cast but cap it at 4 seconds into the future
	local time = GetTime()
	local timeBand = playerEndTime and math.min(playerEndTime - time, INCOMING_SECONDS) or INCOMING_SECONDS
	local healed = (HealComm:GetHealAmount(frame.unitGUID, HealComm.ALL_HEALS, time + timeBand) or 0) * HealComm:GetHealModifier(frame.unitGUID)
	
	-- Update any tags that are using HC data
	IncHeal:UpdateTags(frame, healed)
	
	-- Bar is also supposed to be enabled, lets update that too
	if( frame.visibility.incHeal ) then
		if( healed > 0 ) then
			frame.incHeal.total = UnitHealth(frame.unit) + healed
			frame.incHeal:SetMinMaxValues(0, UnitHealthMax(frame.unit) * ShadowUF.db.profile.units[frame.unitType].incHeal.cap)
			frame.incHeal:SetValue(frame.incHeal.total)
			frame.incHeal.nextUpdate = nil
			frame.incHeal.hasHeal = true
			frame.incHeal:Show()
			
		elseif( frame.incHeal.hasHeal ) then
			if( not interrupted ) then
				frame.incHeal.nextUpdate = true
			else
				frame.incHeal:Hide()
			end
			
			frame.incHeal.hasHeal = nil
	
			-- If it's an overheal, we won't have anything to do on a next update anyway
			local maxHealth = UnitHealthMax(frame.unit)
			if( maxHealth <= frame.incHeal.total ) then
				frame.incHeal:SetValue(maxHealth)
			end
		end
	end
end

function IncHeal:UpdateFrame(frame)
	updateHealthBar(frame, true)
end

function IncHeal:UpdateIncoming(interrupted, ...)
	for frame in pairs(frames) do
		for i=1, select("#", ...) do
			if( select(i, ...) == frame.unitGUID ) then
				updateHealthBar(frame, interrupted)
			end
		end
	end
end

-- Handle callbacks from HealComm
function IncHeal:HealComm_HealUpdated(event, casterGUID, spellID, healType, endTime, ...)
	if( casterGUID == playerGUID and bit.band(healType, HealComm.CASTED_HEALS) > 0 ) then playerEndTime = endTime end
	self:UpdateIncoming(nil, ...)
end

function IncHeal:HealComm_HealStopped(event, casterGUID, spellID, healType, interrupted, ...)
	if( casterGUID == playerGUID and bit.band(healType, HealComm.CASTED_HEALS) > 0 ) then playerEndTime = nil end
	self:UpdateIncoming(interrupted, ...)
end

function IncHeal:HealComm_ModifierChanged(event, guid)
	self:UpdateIncoming(nil, guid)
end

function IncHeal:HealComm_GUIDDisappeared(event, guid)
	self:UpdateIncoming(true, guid)
end

-- "Upgrade code" remove later
if( not HealComm ) then
	local blank = function() end
	IncHeal.OnEnable = blank
	IncHeal.OnDisable = blank
	IncHeal.EnableTag = blank
	IncHeal.DisableTag = blank
	IncHeal.Setup = blank
	IncHeal.OnLayoutApplied = blank
end
