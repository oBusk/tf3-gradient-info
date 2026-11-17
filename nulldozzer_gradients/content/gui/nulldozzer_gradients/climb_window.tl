local climb_window : NullDozzerClimbWindow = {}

local type Point = NullDozzerClimbWindow.Point

local MIN_WINDOW <const> = 0.01

-- Height at a distance that may fall between two points; `index` is the last
-- point at or before it.
local function heightAt(points : {Point}, index : integer, distance : number) : number
	local before = points[index]
	local after = points[index + 1]
	if after == nil or after.distance <= before.distance then
		return before.height
	end
	local t = (distance - before.distance) / (after.distance - before.distance)
	return before.height + (after.height - before.height) * t
end

function climb_window.steepest(points : {Point}, window : number) : NullDozzerClimbWindow.Climb
	if #points < 2 then
		return { gradient = 0.0, window = 0.0 }
	end
	local total = points[#points].distance - points[1].distance
	local span = math.min(window, total)
	if span < MIN_WINDOW then
		return { gradient = 0.0, window = 0.0 }
	end
	-- The steepest window always starts or ends on a point, because height is
	-- linear between points. Slide both ways with one trailing index each.
	local best = 0.0
	local behind = 1
	for i = 1, #points do
		local startDistance = points[i].distance - span
		if startDistance >= points[1].distance then
			while points[behind + 1].distance <= startDistance do
				behind = behind + 1
			end
			best = math.max(best, points[i].height - heightAt(points, behind, startDistance))
		end
	end
	local ahead = 1
	for i = 1, #points do
		local endDistance = points[i].distance + span
		if endDistance <= points[#points].distance then
			while ahead < #points and points[ahead + 1].distance <= endDistance do
				ahead = ahead + 1
			end
			best = math.max(best, heightAt(points, ahead, endDistance) - points[i].height)
		end
	end
	return { gradient = best / span, window = span }
end

function climb_window.steepestOfLegs(legs : {{Point}}, window : number) : NullDozzerClimbWindow.Climb
	local steepest : NullDozzerClimbWindow.Climb = nil
	for _, leg in ipairs(legs) do
		local climb = climb_window.steepest(leg, window)
		if steepest == nil or climb.gradient > steepest.gradient then
			steepest = climb
		end
	end
	return steepest
end

return climb_window
