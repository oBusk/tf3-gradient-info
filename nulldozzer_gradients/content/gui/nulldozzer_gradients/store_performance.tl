local vehicle_store_util = ug_require "::/gui/line_vehicle_mgmt/vehicle_store_util.tl" as VehicleStoreUtil

local store_performance : NullDozzerStorePerformance = {}

local type Train = NullDozzerStorePerformance.Train

-- The store's reference slopes (0%, 3.75%, 7.5%); a train is rated by the steepest
-- it holds its top speed on, with a third of a step as margin.
local RATING_STEP <const> = 0.0375
local RATING_MARGIN <const> = RATING_STEP * 0.33
local RATINGS : {{number, string}} = {
	{ RATING_MARGIN, "Mediocre" },
	{ RATING_STEP + RATING_MARGIN, "Good" },
	{ 2 * RATING_STEP + RATING_MARGIN, "Excellent" },
}

-- Slope force is SLOPE_FORCE_FACTOR * slope * weight, and only USABLE_SHARE of
-- power and tractive effort count.
local SLOPE_FORCE_FACTOR <const> = 3.27
local USABLE_SHARE <const> = 0.95

function store_performance.trainOf(tv : Engine.Component.TransportVehicle) : Train
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

function store_performance.ratingFor(gradient : number) : string
	for _, rating in ipairs(RATINGS) do
		if gradient <= rating[1] then
			return rating[2]
		end
	end
	return nil
end

function store_performance.speedOn(train : Train, gradient : number) : number
	if train.power <= 0.0 or train.tractiveEffort <= 0.0 then
		return nil
	end
	local resistance = SLOPE_FORCE_FACTOR * gradient * train.weight + train.rollingFriction
	if resistance > USABLE_SHARE * train.tractiveEffort then
		return 0.0
	end
	return math.min(train.topSpeed, USABLE_SHARE * train.power / resistance)
end

return store_performance
