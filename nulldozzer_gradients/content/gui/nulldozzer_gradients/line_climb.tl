local climb_window = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/climb_window.tl" as NullDozzerClimbWindow
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute

local line_climb : NullDozzerLineClimb = {}

-- Used when the line's platforms report no length.
local FALLBACK_WINDOW <const> = 200.0

-- The vehicle store rates a train by the steepest reference slope it holds its
-- top speed on (0%, 3.75%, 7.5%), each with a third of a step as margin. See
-- getPowerRatingTextAndToolTip in the base game's gui/line_vehicle_mgmt/vehicle_util.tl.
local RATING_STEP <const> = 0.0375
local RATING_MARGIN <const> = RATING_STEP * 0.33
local RATINGS : {{number, string}} = {
	{ RATING_MARGIN, "Mediocre" },
	{ RATING_STEP + RATING_MARGIN, "Good" },
	{ 2 * RATING_STEP + RATING_MARGIN, "Excellent" },
}

local function steepestClimb(lineEntity : Engine.Entity) : NullDozzerClimbWindow.Climb
	local route = line_route.measure(lineEntity)
	local window = route.shortestPlatform > 0.0 and route.shortestPlatform or FALLBACK_WINDOW
	return climb_window.steepestOfLegs(route.legs, window)
end

-- The route API calls are unverified against the running game, so a failure
-- must not take the window showing it down with it.
function line_climb.measure(lineEntity : Engine.Entity) : NullDozzerClimbWindow.Climb
	local clock = api.type.Clock.new()
	local ok, result = pcall(steepestClimb, lineEntity)
	log.message(string.format("[nulldozzer_gradients] line climb for %s took %.1f ms", tostring(lineEntity), clock:getTime() / 1000.0))
	if not ok then
		log.message("[nulldozzer_gradients] could not measure line " .. tostring(lineEntity) .. ": " .. tostring(result))
		return nil
	end
	return result as NullDozzerClimbWindow.Climb
end

function line_climb.ratingFor(gradient : number) : string
	for _, rating in ipairs(RATINGS) do
		if gradient <= rating[1] then
			return rating[2]
		end
	end
	return nil
end

function line_climb.describe(climb : NullDozzerClimbWindow.Climb) : string
	return "Steepest climb: " .. api.util.toStringPercentPrecision(climb.gradient, 1)
		.. " (over " .. api.util.formatLength(climb.window) .. ")"
end

function line_climb.describeRating(climb : NullDozzerClimbWindow.Climb) : string
	local rating = line_climb.ratingFor(climb.gradient)
	if rating == nil then
		return "Too steep for any train to hold full speed"
	end
	return "Full speed uphill needs Performance: " .. rating
end

return line_climb
