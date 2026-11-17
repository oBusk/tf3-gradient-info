local line_route : NullDozzerLineRoute = {}

local type Point = NullDozzerClimbWindow.Point

local SAMPLE_SPACING <const> = 4.0

local RAIL_MODES : {TransportMode} = {
	api.type["enum"].TransportMode.TRAIN,
	api.type["enum"].TransportMode.ELECTRIC_TRAIN,
}

local function lineOf(lineEntity : Engine.Entity) : Engine.Component.Line
	return api.engine.getComponent(lineEntity, api.type.ComponentType.LINE) as Engine.Component.Line
end

-- A line's own vehicleInfo is empty until it has vehicles, so the modes its
-- stops offer are checked too.
local function railModesOf(lineEntity : Engine.Entity, line : Engine.Component.Line) : {TransportMode}
	local offered = api.engine.util.line.getLineTransportModesUnion(lineEntity) or {}
	local configured = line and line.vehicleInfo and line.vehicleInfo.transportModes or {}
	local modes : {TransportMode} = {}
	for _, mode in ipairs(RAIL_MODES) do
		if offered[mode] or configured[mode] then
			modes[#modes + 1] = mode
		end
	end
	return modes
end

-- Stop.station and Stop.terminal are zero-based.
local function terminalOf(stop : Engine.Component.Line.Stop) : Terminal
	local group = api.engine.getComponent(stop.stationGroup, api.type.ComponentType.STATION_GROUP) as Engine.Component.StationGroup
	local stationEntity = group and group.stations[stop.station + 1]
	if stationEntity == nil then
		return nil
	end
	local station = api.engine.getComponent(stationEntity, api.type.ComponentType.STATION) as Engine.Component.Station
	return station and station.terminals[stop.terminal + 1]
end

-- Same rule as the base game's line_util.getTerminalLength.
local function platformLength(terminal : Terminal) : number
	local length = 0.0
	for _, transferSpeed in ipairs(terminal.cargoTransferSpeeds or {}) do
		length = math.max(length, transferSpeed.length)
	end
	return length
end

local function edgeOf(edgeId : EdgeId) : Edge
	local network = api.engine.getComponent(edgeId.entity, api.type.ComponentType.TRANSPORT_NETWORK) as Engine.Component.TransportNetwork
	return network and network.edges and network.edges[edgeId.index + 1]
end

local function horizontalDistance(a : Vec3f, b : Vec3f) : number
	local dx = b.x - a.x
	local dy = b.y - a.y
	return math.sqrt(dx * dx + dy * dy)
end

-- Appends the edge's heights to the leg, walking it in the direction of travel.
local function appendEdge(points : {Point}, geometry : EdgeGeometry, forward : boolean)
	local steps = math.max(1, math.ceil(geometry.length / SAMPLE_SPACING))
	local previous : Vec3f = nil
	local distance = #points > 0 and points[#points].distance or 0.0
	for step = 0, steps do
		local t = step / steps
		local position = api.engine.util.transport.calcPosition(geometry, forward and t or 1.0 - t)
		if previous ~= nil then
			distance = distance + horizontalDistance(previous, position)
		end
		-- An edge's first sample repeats the previous edge's last one.
		if previous ~= nil or #points == 0 then
			points[#points + 1] = { distance = distance, height = position.z }
		end
		previous = position
	end
end

local type Step = {EdgeId, boolean}

local function sameNode(a : NodeId, b : NodeId) : boolean
	return a.entity == b.entity and a.index == b.index
end

local function sameEdge(a : EdgeId, b : EdgeId) : boolean
	return a.entity == b.entity and a.index == b.index
end

-- Node a step ends on, given its direction of travel.
local function endNodeOf(step : Step) : NodeId
	local edge = edgeOf(step[1])
	return edge and edge.conns[step[2] and 2 or 1]
end

local function findSteps(from : NodeId, targets : {NodeId}, modes : {TransportMode}) : {Step}
	return api.engine.util.pathfinding.findPathNodeToNode({ from }, targets, modes) or {}
end

local function appendSteps(steps : {Step}, more : {Step})
	for _, step in ipairs(more) do
		steps[#steps + 1] = step
	end
end

-- Extends the steps from `from` across the waypoint's edge and returns the node
-- the train leaves it by, or nil if the waypoint cannot be reached. The train
-- is assumed to cross the edge from whichever end the pathfinder reaches first.
local function routeThroughWaypoint(steps : {Step}, from : NodeId, waypoint : Waypoint, modes : {TransportMode}) : NodeId
	local edgeId = waypoint.edgePos and waypoint.edgePos.edgeId
	local edge = edgeId and edgeOf(edgeId)
	if edge == nil then
		return nil
	end
	local first, second = edge.conns[1], edge.conns[2]
	local forward = true
	if not sameNode(from, first) and not sameNode(from, second) then
		local approach = findSteps(from, { first, second }, modes)
		if #approach == 0 then
			return nil
		end
		appendSteps(steps, approach)
		local last = approach[#approach]
		if sameEdge(last[1], edgeId) then
			-- The pathfinder already crossed the waypoint's edge.
			return endNodeOf(last)
		end
		forward = sameNode(endNodeOf(last), first)
	else
		forward = sameNode(from, first)
	end
	steps[#steps + 1] = { edgeId, forward }
	return forward and second or first
end

-- Edges the train takes from one stop to the next, through the waypoints set
-- after the first stop. An unreachable waypoint is skipped.
local function legSteps(from : Terminal, waypoints : {Waypoint}, to : Terminal, modes : {TransportMode}) : {Step}
	local steps : {Step} = {}
	local current = from.vehicleNodeId
	for _, waypoint in ipairs(waypoints or {}) do
		local viaWaypoint : {Step} = {}
		local exit = routeThroughWaypoint(viaWaypoint, current, waypoint, modes)
		if exit ~= nil then
			appendSteps(steps, viaWaypoint)
			current = exit
		end
	end
	appendSteps(steps, findSteps(current, { to.vehicleNodeId }, modes))
	return steps
end

-- Timing for the measurement in progress, logged by line_route.measure.
local record Timing
	pathfindingMicros : integer
	samplingMicros : integer
	edges : integer
end

local function measureLeg(from : Terminal, waypoints : {Waypoint}, to : Terminal, modes : {TransportMode}, timing : Timing) : {Point}
	local points : {Point} = {}
	local pathfindingClock = api.type.Clock.new()
	local steps = legSteps(from, waypoints, to, modes)
	timing.pathfindingMicros = timing.pathfindingMicros + pathfindingClock:getTime()
	timing.edges = timing.edges + #steps
	local samplingClock = api.type.Clock.new()
	for _, step in ipairs(steps) do
		local edge = edgeOf(step[1])
		if edge ~= nil and edge.geometry ~= nil then
			appendEdge(points, edge.geometry, step[2])
		end
	end
	timing.samplingMicros = timing.samplingMicros + samplingClock:getTime()
	return points
end

local function millis(micros : integer) : string
	return string.format("%.1f ms", micros / 1000.0)
end

function line_route.isRailLine(lineEntity : Engine.Entity) : boolean
	return #railModesOf(lineEntity, lineOf(lineEntity)) > 0
end

function line_route.measure(lineEntity : Engine.Entity) : NullDozzerLineRoute.Route
	local line = lineOf(lineEntity)
	local modes = railModesOf(lineEntity, line)
	local route : NullDozzerLineRoute.Route = { legs = {}, shortestPlatform = 0.0 }
	if #modes == 0 or line.stops == nil or #line.stops < 2 then
		return route
	end
	local terminals : {Terminal} = {}
	local waypointsAfter : {{Waypoint}} = {}
	for _, stop in ipairs(line.stops) do
		local terminal = terminalOf(stop)
		if terminal ~= nil then
			terminals[#terminals + 1] = terminal
			waypointsAfter[#terminals] = stop.waypoints
			local length = platformLength(terminal)
			if length > 0.0 and (route.shortestPlatform == 0.0 or length < route.shortestPlatform) then
				route.shortestPlatform = length
			end
		end
	end
	local totalClock = api.type.Clock.new()
	local timing : Timing = { pathfindingMicros = 0, samplingMicros = 0, edges = 0 }
	local pointCount = 0
	for i, terminal in ipairs(terminals) do
		local nextTerminal = terminals[i % #terminals + 1]
		local points = measureLeg(terminal, waypointsAfter[i], nextTerminal, modes, timing)
		if #points >= 2 then
			route.legs[#route.legs + 1] = points
			pointCount = pointCount + #points
		end
	end
	log.message("[nulldozzer_gradients] measured line " .. tostring(lineEntity) .. " in " .. millis(totalClock:getTime())
		.. " (pathfinding " .. millis(timing.pathfindingMicros) .. ", sampling " .. millis(timing.samplingMicros)
		.. "; " .. #terminals .. " stops, " .. timing.edges .. " edges, " .. pointCount .. " points)")
	return route
end

return line_route
