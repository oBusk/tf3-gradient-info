local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local content_card = ug_require "::/gui/main/content_card.tl" as ContentCard
local vehicle_eow = ug_require "::/gui/entity_window/vehicle/vehicle_eow.script.tl" as VehicleEow
local vehicle_store_util = ug_require "::/gui/line_vehicle_mgmt/vehicle_store_util.tl" as VehicleStoreUtil

local climb_window = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/climb_window.tl" as NullDozzerClimbWindow
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute

-- Same model as the vehicle store's Performance rating (getPowerRatingTextAndToolTip in
-- the base game's gui/line_vehicle_mgmt/vehicle_util.tl): slope force is
-- 3.27 * slope * weight, and only 95% of power and tractive effort count.
local SLOPE_FORCE_FACTOR <const> = 3.27
local USABLE_SHARE <const> = 0.95

local record Train
	length : number
	-- Fully loaded, in the units the vehicle store uses.
	weight : number
	power : number
	tractiveEffort : number
	topSpeed : number
	rollingFriction : number
end

local record Summary
	-- nil if the route could not be measured.
	climb : NullDozzerClimbWindow.Climb
	train : Train
end

local function transportVehicleOf(vehicleEntity : Engine.Entity) : Engine.Component.TransportVehicle
	return api.engine.getComponent(vehicleEntity, api.type.ComponentType.TRANSPORT_VEHICLE) as Engine.Component.TransportVehicle
end

-- The train's figures as the vehicle store computes them for its rating.
local function trainOf(tv : Engine.Component.TransportVehicle) : Train
	local vehicles : {VehicleStoreUtil.Vehicle} = {}
	for _, vehiclePart in ipairs(tv.transportVehicleConfig.vehicles) do
		vehicles[#vehicles + 1] = vehicle_store_util.makeSingleVehicle(api.res.modelRep.get(vehiclePart.part.modelId))
	end
	local data = vehicle_store_util.collectVehicleData(vehicles)
	return {
		length = data.length,
		weight = data.weight + data.weightMaxPayload,
		power = data.power,
		tractiveEffort = data.tractiveEffort,
		topSpeed = data.speed,
		rollingFriction = data.rollingFriction,
	}
end

local function measure(vehicleEntity : Engine.Entity) : Summary
	local tv = transportVehicleOf(vehicleEntity)
	local train = trainOf(tv)
	local route = line_route.measure(tv.line)
	return { climb = climb_window.steepestOfLegs(route.legs, train.length), train = train }
end

-- The route API calls are unverified against the running game, so a failure
-- must not take the whole vehicle window down with it.
local function summarize(vehicleEntity : Engine.Entity) : Summary
	local clock = api.type.Clock.new()
	local ok, result = pcall(measure, vehicleEntity)
	log.message(string.format("[nulldozzer_gradients] vehicle window card for %s took %.1f ms", tostring(vehicleEntity), clock:getTime() / 1000.0))
	if not ok then
		log.message("[nulldozzer_gradients] could not measure vehicle " .. tostring(vehicleEntity) .. ": " .. tostring(result))
		return {}
	end
	return result as Summary
end

local function performanceLine(train : Train, gradient : number) : string
	if train.power <= 0.0 or train.tractiveEffort <= 0.0 then
		return nil
	end
	local resistance = SLOPE_FORCE_FACTOR * gradient * train.weight + train.rollingFriction
	if resistance > USABLE_SHARE * train.tractiveEffort then
		return "Fully loaded, this train lacks the power to climb it"
	end
	local speed = math.min(train.topSpeed, USABLE_SHARE * train.power / resistance)
	if speed >= train.topSpeed then
		return "Fully loaded, this train holds its top speed (" .. api.util.formatSpeed(train.topSpeed) .. ") there"
	end
	return "Fully loaded, this train slows to " .. api.util.formatSpeed(speed)
		.. " there (top speed " .. api.util.formatSpeed(train.topSpeed) .. ")"
end

local function summaryLines(summary : Summary) : {string}
	local climb = summary.climb
	if climb == nil then
		return { "Steepest climb: unknown (no route found)" }
	end
	local lines = {
		"Steepest climb on its line: " .. api.util.toStringPercentPrecision(climb.gradient, 1)
			.. " (over " .. api.util.formatLength(climb.window) .. ", the train's length)",
	}
	lines[#lines + 1] = performanceLine(summary.train, climb.gradient)
	return lines
end

local VehicleGradientSummary = react.RegisterRecipe("NullDozzerVehicleGradientSummary", function(vehicleEntity : Engine.Entity) : TreeNodeId
	-- Measured once per opened window; reopen the window after changing the line, track or train.
	local summaryRef : ReactRefT<Summary> = react.useRef()
	if summaryRef:get() == nil then
		summaryRef:set(summarize(vehicleEntity))
	end
	local children : {TreeNodeId} = {}
	for _, line in ipairs(summaryLines(summaryRef:get())) do
		children[#children + 1] = builtin.TextView{ meta = { class = "font-scale-body" }, text = line }
	end
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = children,
	}
end)

local VehicleGradientPlugin = react.RegisterPluginRecipe(vehicle_eow.VehicleEowExtensionPoint, "NullDozzerVehicleGradientPlugin", function(params : VehicleEow.VehicleWidgetPluginParams) : TreeNodeId
	return builtin.BoxLayout{
		meta = { class = "box-plugin-vertical-space" },
		orientation = builtin.type.Orientation.Vertical,
		children = {
			content_card.ContentCard{
				meta = { localKey = "nullDozzerVehicleGradient" },
				title = "Gradient",
				initialCalloutTextPermanent = "",
				recipeAndParamPermanent = content_card.makeRecipeAndParam(VehicleGradientSummary, params.entityId),
				gameCtx = params.gameCtx,
				showOnRightSide = params.showCalloutOnRightSide,
			},
		},
	}
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
