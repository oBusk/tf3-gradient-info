local climb_window = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/climb_window.tl" as NullDozzerClimbWindow
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute
local store_performance = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/store_performance.tl" as NullDozzerStorePerformance

local line_climb : NullDozzerLineClimb = {}

-- Used when the line's platforms report no length.
local FALLBACK_WINDOW <const> = 200.0

local function steepestClimb(lineEntity : Engine.Entity, window : number) : NullDozzerClimbWindow.Climb
	local route = line_route.measure(lineEntity)
	if window == nil then
		window = route.shortestPlatform > 0.0 and route.shortestPlatform or FALLBACK_WINDOW
	end
	return climb_window.steepestOfLegs(route.legs, window)
end

-- The route API calls are unverified against the running game, so a failure
-- must not take the window showing it down with it.
function line_climb.measure(lineEntity : Engine.Entity, window? : number) : NullDozzerClimbWindow.Climb
	local clock = api.type.Clock.new()
	local ok, result = pcall(steepestClimb, lineEntity, window)
	log.message(string.format("[nulldozzer_gradients] line climb for %s took %.1f ms", tostring(lineEntity), clock:getTime() / 1000.0))
	if not ok then
		log.message("[nulldozzer_gradients] could not measure line " .. tostring(lineEntity) .. ": " .. tostring(result))
		return nil
	end
	return result as NullDozzerClimbWindow.Climb
end

function line_climb.describe(climb : NullDozzerClimbWindow.Climb) : string
	return "Steepest climb: " .. api.util.toStringPercentPrecision(climb.gradient, 1)
		.. " (over " .. api.util.formatLength(climb.window) .. ")"
end

function line_climb.describeRating(climb : NullDozzerClimbWindow.Climb) : string
	local rating = store_performance.ratingFor(climb.gradient)
	if rating == nil then
		return "Too steep for any train to hold full speed"
	end
	return "Full speed uphill needs Performance: " .. rating
end

return line_climb
