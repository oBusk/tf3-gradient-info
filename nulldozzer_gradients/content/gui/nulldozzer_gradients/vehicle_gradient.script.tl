local react = ug_require "::/gui/main/react.lua" as React
local vehicle_eow = ug_require "::/gui/entity_window/vehicle/vehicle_eow.script.tl" as VehicleEow

local line_info_card = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_info_card.tl" as NullDozzerLineInfoCard
local line_climb = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_climb.tl" as NullDozzerLineClimb
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute
local store_performance = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/store_performance.tl" as NullDozzerStorePerformance

local type Train = NullDozzerStorePerformance.Train

local function transportVehicleOf(vehicleEntity : Engine.Entity) : Engine.Component.TransportVehicle
	return api.engine.getComponent(vehicleEntity, api.type.ComponentType.TRANSPORT_VEHICLE) as Engine.Component.TransportVehicle
end

-- "Current train: Good", the train's own rating, to read against the one required.
-- nil if the train has no rating (e.g. no locomotive).
local function currentTrainText(train : Train) : string
	local rating = store_performance.ratingOf(train)
	return rating and ("Current train: " .. rating) or nil
end

local function summaryFor(vehicleEntity : Engine.Entity) : NullDozzerLineInfoCard.Summary
	local tv = transportVehicleOf(vehicleEntity)
	local ok, result = pcall(store_performance.trainOf, tv)
	if not ok then
		log.message("[nulldozzer_gradients] could not read train " .. tostring(vehicleEntity) .. ": " .. tostring(result))
		return { note = "Could not read the train" }
	end
	local train = result as Train
	local info = line_climb.measure(tv.line, train.length)
	if info == nil or info.climb == nil then
		return { note = "Route unknown: the path between the line's stops was not found" }
	end
	local cells = line_info_card.routeCells(tv.line, info)
	cells[#cells + 1] = line_info_card.slopeCell(info.climb, { currentTrainText(train) })
	return { cells = cells }
end

local VehicleInfoSummary = line_info_card.registerSummary("NullDozzerVehicleLineInfoSummary", summaryFor)

local VehicleGradientPlugin = react.RegisterPluginRecipe(vehicle_eow.VehicleEowExtensionPoint, "NullDozzerVehicleGradientPlugin", function(params : VehicleEow.VehicleWidgetPluginParams) : TreeNodeId
	return line_info_card.Card(params, "nullDozzerVehicleGradient", VehicleInfoSummary)
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
