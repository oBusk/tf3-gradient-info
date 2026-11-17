local react = ug_require "::/gui/main/react.lua" as React
local vehicle_eow = ug_require "::/gui/entity_window/vehicle/vehicle_eow.script.tl" as VehicleEow

local gradient_card = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/gradient_card.tl" as NullDozzerGradientCard
local line_climb = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_climb.tl" as NullDozzerLineClimb
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute
local store_performance = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/store_performance.tl" as NullDozzerStorePerformance

local type Train = NullDozzerStorePerformance.Train

local function transportVehicleOf(vehicleEntity : Engine.Entity) : Engine.Component.TransportVehicle
	return api.engine.getComponent(vehicleEntity, api.type.ComponentType.TRANSPORT_VEHICLE) as Engine.Component.TransportVehicle
end

local function performanceLine(train : Train, gradient : number) : string
	local speed = store_performance.speedOn(train, gradient)
	if speed == nil then
		return nil
	elseif speed <= 0.0 then
		return "Fully loaded, this train lacks the power to climb it"
	elseif speed >= train.topSpeed then
		return "Fully loaded, this train holds its top speed (" .. api.util.formatSpeed(train.topSpeed) .. ") there"
	end
	return "Fully loaded, this train slows to " .. api.util.formatSpeed(speed)
		.. " there (top speed " .. api.util.formatSpeed(train.topSpeed) .. ")"
end

local function summaryLines(vehicleEntity : Engine.Entity) : {string}
	local tv = transportVehicleOf(vehicleEntity)
	local ok, result = pcall(store_performance.trainOf, tv)
	if not ok then
		log.message("[nulldozzer_gradients] could not read train " .. tostring(vehicleEntity) .. ": " .. tostring(result))
		return { "Steepest climb: unknown (could not read the train)" }
	end
	local train = result as Train
	local climb = line_climb.measure(tv.line, train.length)
	if climb == nil then
		return { "Steepest climb: unknown (no route found)" }
	end
	return {
		"Steepest climb on its line: " .. api.util.toStringPercentPrecision(climb.gradient, 1)
			.. " (over " .. api.util.formatLength(climb.window) .. ", the train's length)",
		performanceLine(train, climb.gradient),
	}
end

local VehicleGradientSummary = gradient_card.registerSummary("NullDozzerVehicleGradientSummary", summaryLines)

local VehicleGradientPlugin = react.RegisterPluginRecipe(vehicle_eow.VehicleEowExtensionPoint, "NullDozzerVehicleGradientPlugin", function(params : VehicleEow.VehicleWidgetPluginParams) : TreeNodeId
	return gradient_card.Card(params, "nullDozzerVehicleGradient", VehicleGradientSummary)
end)

local function isTrainOnRailLine(vehicleEntity : Engine.Entity) : boolean
	local tv = transportVehicleOf(vehicleEntity)
	return tv ~= nil and tv.line ~= nil and tv.line >= 0 and line_route.isRailLine(tv.line)
end

local function conditionTrainOnRailLine(params : VehicleEow.VehicleWidgetPluginParams) : boolean
	local ok, show = pcall(isTrainOnRailLine, params.entityId)
	return ok and show == true
end

return {
	VehicleGradientPlugin = VehicleGradientPlugin,
	conditionTrainOnRailLine = conditionTrainOnRailLine,
}
