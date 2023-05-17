local Druid = {}
ShadowUF:RegisterModule(Druid, "druidBar", ShadowUF.L["Druid mana bar"], true, "DRUID")

function Druid:OnEnable(frame)
    frame.druidBar = frame.druidBar or ShadowUF.Units:CreateBar(frame)
    
    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "PowerChanged")
    frame:RegisterUpdateFunc(self, "PowerChanged")
    frame:RegisterUpdateFunc(self, "Update")
end

function Druid:OnDisable(frame)
	frame:UnregisterAll(self)
end

function Druid:OnLayoutApplied(frame)
	if( not frame.visibility.druidBar ) then return end

	local color = ShadowUF.db.profile.powerColors.MANA
	frame:SetBarColor("druidBar", color.r, color.g, color.b)
end

function Druid:PowerChanged(frame)
	local visible = UnitPowerType(frame.unit) ~= Enum.PowerType.Mana
	local type = visible and "RegisterUnitEvent" or "UnregisterSingleEvent"

	frame[type](frame, "UNIT_POWER_FREQUENT", self, "Update")
	frame[type](frame, "UNIT_MAXPOWER", self, "Update")
	ShadowUF.Layout:SetBarVisibility(frame, "druidBar", visible)

	if( visible ) then self:Update(frame) end
end


-- Function to get spell cost
function Druid:GetShapeshiftCost(spellName)
    local spellCost = GetSpellPowerCost(spellName)
    if spellCost then
        for _, costInfo in ipairs(spellCost) do
            if costInfo.type == "MANA" then
                return costInfo.cost
            end
        end
    end
    return 0
end

function Druid:OnEnable(frame)
    frame.druidBar = frame.druidBar or ShadowUF.Units:CreateBar(frame)
    frame.druidBar.costBars = frame.druidBar.costBars or {}  -- Initialize costBars table

    frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", self, "PowerChanged")

    frame:RegisterUpdateFunc(self, "PowerChanged")
    frame:RegisterUpdateFunc(self, "Update")
end

function Druid:Update(frame, event, unit, powerType)
    if( powerType and powerType ~= "MANA" ) then return end
    
    local totalMana = UnitPowerMax(frame.unit, Enum.PowerType.Mana)
    frame.druidBar:SetMinMaxValues(0, totalMana)
    frame.druidBar:SetValue(UnitIsDeadOrGhost(frame.unit) and 0 or not UnitIsConnected(frame.unit) and 0 or UnitPower(frame.unit, Enum.PowerType.Mana))

    local bearCost = GetSpellPowerCost("Dire Bear Form")[1].cost or 0
    local travelCost = GetSpellPowerCost("Travel Form")[1].cost or 0
    local doubleBearCost = bearCost * 2

    -- Create or update texture overlays
    for i, cost in ipairs({bearCost, travelCost, doubleBearCost}) do
        local bar = frame.druidBar.costBars[i]
        if not bar then
            bar = frame.druidBar:CreateTexture(nil, "OVERLAY")
            bar:SetTexture("Interface\\Buttons\\WHITE8X8")
            bar:SetVertexColor(0, 1, 1, 0.12)  -- Change this to the color you want. Format: (Red, Green, Blue, Alpha)
            frame.druidBar.costBars[i] = bar
        end
        bar:SetWidth(frame.druidBar:GetWidth() * (cost / totalMana))
        bar:SetHeight(frame.druidBar:GetHeight())
        bar:SetPoint("LEFT", frame.druidBar, "LEFT", 0, 0)
    end
end
