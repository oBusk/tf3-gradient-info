local climb_window = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/climb_window.tl" as NullDozzerClimbWindow
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute

local line_climb : NullDozzerLineClimb = {}

-- Used when the line's platforms report no length.
local FALLBACK_WINDOW <const> = 200.0

local function measureRoute(lineEntity : Engine.Entity, window : number) : NullDozzerLineClimb.LineInfo
	local route = line_route.measure(lineEntity)
	if window == nil then
		window = route.shortestPlatform > 0.0 and route.shortestPlatform or FALLBACK_WINDOW
	end
	local length = 0.0
	for _, leg in ipairs(route.legs) do
		length = length + leg[#leg].distance
	end
	return {
		climb = climb_window.steepestOfLegs(route.legs, window),
		length = length,
		stops = route.stops,
		complete = route.stops >= 2 and #route.legs == route.stops,
	}
end

-- The route API calls are unverified against the running game, so a failure
-- must not take the window showing it down with it.
function line_climb.measure(lineEntity : Engine.Entity, window? : number) : NullDozzerLineClimb.LineInfo
	local clock = api.type.Clock.new()
	local ok, result = pcall(measureRoute, lineEntity, window)
	log.message(string.format("[nulldozzer_gradients] line climb for %s took %.1f ms", tostring(lineEntity), clock:getTime() / 1000.0))
	if not ok then
		log.message("[nulldozzer_gradients] could not measure line " .. tostring(lineEntity) .. ": " .. tostring(result))
		return nil
	end
	return result as NullDozzerLineClimb.LineInfo
end

return line_climb
