local Power = {}
local powerMap = ShadowUF.Tags.powerMap
ShadowUF:RegisterModule(Power, "powerBar", ShadowUF.L["Power bar"], true)

function Power:OnEnable(frame)
    frame.powerBar = frame.powerBar or ShadowUF.Units:CreateBar(frame)

    frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", self, "Update")
    frame:RegisterUnitEvent("UNIT_MAXPOWER", self, "Update")
    frame:RegisterUnitEvent("UNIT_CONNECTION", self, "Update")
    frame:RegisterUnitEvent("UNIT_POWER_BAR_SHOW", self, "Update")
    frame:RegisterUnitEvent("UNIT_POWER_BAR_HIDE", self, "Update")
    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "UpdateColor")
    frame:RegisterUnitEvent("UNIT_CLASSIFICATION_CHANGED", self, "UpdateClassification")

    -- Register for shapeshift form changes
    if frame.unit == "player" then
        frame:RegisterNormalEvent("UPDATE_SHAPESHIFT_FORM", self, "UpdateForm")
    end

    -- run an update after returning to life
    if frame.unit == "player" then
        frame:RegisterNormalEvent("PLAYER_UNGHOST", self, "Update")
    end

    -- UNIT_MANA fires after repopping at a spirit healer, make sure to update powers then
    frame:RegisterUnitEvent("UNIT_MANA", self, "Update")

    frame:RegisterUpdateFunc(self, "UpdateClassification")
    frame:RegisterUpdateFunc(self, "UpdateColor")
    frame:RegisterUpdateFunc(self, "Update")
end


function Power:OnDisable(frame)
	frame:UnregisterAll(self)
end

local altColor = {}
function Power:UpdateColor(frame)
	local powerID, currentType, altR, altG, altB = UnitPowerType(frame.unit)
	frame.powerBar.currentType = currentType

	-- Overridden power types like Warlock pets, or Ulduar vehicles use "POWER_TYPE_#####" but triggers power events with "ENERGY", so this fixes that
	-- by using the powerID to figure out the event type
	if( not powerMap[currentType] ) then
		frame.powerBar.currentType = powerMap[powerID] or "ENERGY"
	end

	if( ShadowUF.db.profile.units[frame.unitType].powerBar.onlyMana ) then
		ShadowUF.Layout:SetBarVisibility(frame, "powerBar", currentType == "MANA")
		if( currentType ~= "MANA" ) then return end
	end


	local color
	if( frame.powerBar.minusMob ) then
		color = ShadowUF.db.profile.healthColors.offline
	elseif( ShadowUF.db.profile.units[frame.unitType].powerBar.colorType == "class" and UnitIsPlayer(frame.unit) ) then
		local class = frame:UnitClassToken()
		color = class and ShadowUF.db.profile.classColors[class]
	end

	if( not color ) then
		color = ShadowUF.db.profile.powerColors[frame.powerBar.currentType]
		if( not color ) then
			if( altR ) then
				altColor.r, altColor.g, altColor.b = altR, altG, altB
				color = altColor
			else
				color = ShadowUF.db.profile.powerColors.MANA
			end
		end
	end

	frame:SetBarColor("powerBar", color.r, color.g, color.b)

	self:Update(frame)
end

function Power:UpdateClassification(frame, event, unit)
	local classif = UnitClassification(frame.unit)
	local minus = nil
	if( classif == "minus" ) then
		minus = true

		frame.powerBar:SetMinMaxValues(0, 1)
		frame.powerBar:SetValue(0)
	end

	if( minus ~= frame.powerBar.minusMob ) then
		frame.powerBar.minusMob = minus

		-- Only need to force an update if it was event driven, otherwise the update func will hit color/etc next
		if( event ) then
			self:UpdateColor(frame)
		end
	end
end

local function UpdateFormOverlay(frame)
    -- Check if the unit is a Druid
    local _, unitClass = UnitClass(frame.unit)
    if unitClass ~= "DRUID" then
        return
    end

    -- Get the current shapeshift form ID
    local formID = GetShapeshiftFormID()

    if formID == 1 or formID == 8 then
        -- In Bear or Cat form, hide the overlay
        if frame.powerBar.costBars then
            for _, bar in ipairs(frame.powerBar.costBars) do
                bar:Hide()
            end
        end
    else
        -- Not in Bear or Cat form, show the overlay after a short delay
        if frame.powerBar.costBars then
            for _, bar in ipairs(frame.powerBar.costBars) do
                C_Timer.After(0.2, function()
                    if not (GetShapeshiftFormID() == 1 or GetShapeshiftFormID() == 8) then
                        bar:Show()
                    end
                end)
            end
        end
    end
end

function Power:UpdateForm(frame)
    -- Update the frame on form change
    if frame.unit == "player" then
        frame:RegisterNormalEvent("UPDATE_SHAPESHIFT_FORM", self, "Update")
        UpdateFormOverlay(frame) -- Update the form overlay immediately
        self:Update(frame) -- Force a frame update
    end
end

function Power:Update(frame, event, unit, powerType)
    -- Only update the frame when the event is triggered by a form change
    if event == "UPDATE_SHAPESHIFT_FORM" then
        -- Update the frame based on the form change
        UpdateFormOverlay(frame)
    else
        if event and powerType and powerType ~= frame.powerBar.currentType then return end
        if frame.powerBar.minusMob then return end

        frame.powerBar.currentPower = UnitPower(frame.unit)
        local totalPower = UnitPowerMax(frame.unit)
        frame.powerBar:SetMinMaxValues(0, totalPower)
        frame.powerBar:SetValue(UnitIsDeadOrGhost(frame.unit) and 0 or not UnitIsConnected(frame.unit) and 0 or frame.powerBar.currentPower)

        -- Check if the unit is a Druid
        local _, unitClass = UnitClass(frame.unit)
        if unitClass == "DRUID" then
            -- Get the current shapeshift form ID
            local formID = GetShapeshiftFormID()

            -- Only show overlays in normal form and travel form
            if not formID or formID == 0 or formID == 3 then
                -- Get the spell costs
                local bearCost = GetSpellPowerCost("Dire Bear Form")[1].cost or 0
                local travelCost = GetSpellPowerCost("Travel Form")[1].cost or 0
                local doubleBearCost = bearCost * 2

                -- Create or update texture overlays
                frame.powerBar.costBars = frame.powerBar.costBars or {}
                for i, cost in ipairs({bearCost, travelCost, doubleBearCost}) do
                    local bar = frame.powerBar.costBars[i]
                    if not bar then
                        bar = frame.powerBar:CreateTexture(nil, "OVERLAY")
                        bar:SetTexture("Interface\\Buttons\\WHITE8X8")
                        bar:SetVertexColor(0, 1, 1, 0.12)  -- Change this to the color you want. Format: (Red, Green, Blue, Alpha)
                        frame.powerBar.costBars[i] = bar
                    end
                    bar:SetWidth(frame.powerBar:GetWidth() * (cost / totalPower))
                    bar:SetHeight(frame.powerBar:GetHeight())
                    bar:SetPoint("LEFT", frame.powerBar, "LEFT", 0, 0)
                end
            else
                -- Hide overlays in other forms
                if frame.powerBar.costBars then
                    for _, bar in ipairs(frame.powerBar.costBars) do
                        bar:Hide()
                    end
                end
            end
        end
    end
end
