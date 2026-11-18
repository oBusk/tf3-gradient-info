local edge_profile = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/edge_profile.tl" as NullDozzerEdgeProfile

local network_scan : NullDozzerNetworkScan = {}

local type Kind = NullDozzerNetworkScan.Kind
local type Piece = NullDozzerNetworkScan.Piece

local WHOLE_MAP_CENTER <const> = { 0.0, 0.0 }
local WHOLE_MAP_RADIUS <const> = 1e10
-- Profiles kept for the tooltip; when there are more, all are dropped.
local MAX_KEPT_PROFILES <const> = 64

local ROAD_LANE_MODES : {TransportMode} = {
	api.type["enum"].TransportMode.CAR,
	api.type["enum"].TransportMode.BUS,
	api.type["enum"].TransportMode.TRUCK,
	api.type["enum"].TransportMode.TRAM,
	api.type["enum"].TransportMode.ELECTRIC_TRAM,
}

-- What is known about one edge entity, kept between scans.
local record Entry
	-- nil for edges that are neither track nor road.
	kind : Kind
	-- The edge's ends when it was read. If they differ, the entity was rebuilt
	-- or reused, and the entry is read again.
	x0 : number
	y0 : number
	z0 : number
	x1 : number
	y1 : number
	z1 : number
	-- nil until the edge is shown, or while its lanes cannot be read yet.
	piece : Piece
end

local entries : {Engine.Entity : Entry} = {}

local keptProfiles : {Piece : NullDozzerEdgeProfile.Profile} = {}
local keptProfileCount = 0

local function allBaseEdges() : {Engine.Entity}
	local center = api.type.Vec2f.new(WHOLE_MAP_CENTER[1], WHOLE_MAP_CENTER[2])
	return api.engine.util.octree.findEntitiesInCircle(center, WHOLE_MAP_RADIUS, api.type.ComponentType.BASE_EDGE)
end

local function kindOf(baseEdge : Engine.Component.BaseEdge) : Kind
	if baseEdge.roadType == api.type["enum"].RoadType.TRACK then
		return "track"
	end
	if baseEdge.roadType == api.type["enum"].RoadType.STREET then
		return "road"
	end
	return nil
end

local function structureOf(baseEdge : Engine.Component.BaseEdge) : NullDozzerNetworkScan.Structure
	if baseEdge.type == api.type["enum"].BaseEdgeType.BRIDGE then
		return "bridge"
	end
	if baseEdge.type == api.type["enum"].BaseEdgeType.TUNNEL then
		return "tunnel"
	end
	return "ground"
end

local function carriesRoadTraffic(edge : Edge) : boolean
	for _, mode in ipairs(ROAD_LANE_MODES) do
		if edge.transportModes[mode] then
			return true
		end
	end
	return false
end

local function lanesOf(network : Engine.Component.TransportNetwork, kind : Kind) : {EdgeGeometry}
	if kind == "track" then
		return { network.edges[1].geometry }
	end
	local lanes : {EdgeGeometry} = {}
	for _, edge in ipairs(network.edges) do
		if carriesRoadTraffic(edge) then
			lanes[#lanes + 1] = edge.geometry
		end
	end
	if #lanes == 0 then
		lanes[1] = network.edges[1].geometry
	end
	return lanes
end

local function newEntry(baseEdge : Engine.Component.BaseEdge) : Entry
	local p0, p1 = baseEdge.position0, baseEdge.position1
	return {
		kind = kindOf(baseEdge),
		x0 = p0.x, y0 = p0.y, z0 = p0.z,
		x1 = p1.x, y1 = p1.y, z1 = p1.z,
	}
end

local function isUnchanged(entry : Entry, baseEdge : Engine.Component.BaseEdge) : boolean
	local p0, p1 = baseEdge.position0, baseEdge.position1
	return entry.x0 == p0.x and entry.y0 == p0.y and entry.z0 == p0.z
		and entry.x1 == p1.x and entry.y1 == p1.y and entry.z1 == p1.z
end

-- Lane geometry must be read fresh each time it is used: geometry kept from an
-- earlier frame can point at engine memory that has since been freed or moved,
-- and calcPosition on it fails an engine assertion that ends the game.
local function readLanes(entity : Engine.Entity, kind : Kind) : {EdgeGeometry}, Engine.Component.TransportNetwork
	local network = api.engine.getComponent(entity, api.type.ComponentType.TRANSPORT_NETWORK) as Engine.Component.TransportNetwork
	if network == nil or network.edges == nil or #network.edges == 0 then
		return nil, nil
	end
	return lanesOf(network, kind), network
end

-- The average from the ends alone: height change over the horizontal length.
-- Assumes the lane's length includes height, as a length along a slope does.
local function makePiece(entity : Engine.Entity, entry : Entry, baseEdge : Engine.Component.BaseEdge) : Piece
	local lanes = readLanes(entity, entry.kind)
	if lanes == nil then
		return nil
	end
	local rise = entry.z1 - entry.z0
	local length = lanes[1].length
	local run = math.sqrt(math.max(0.0, length * length - rise * rise))
	return {
		entity = entity,
		kind = entry.kind,
		structure = structureOf(baseEdge),
		averageGradient = run > 0.01 and math.abs(rise) / run or 0.0,
		horizontalLength = run,
	}
end

function network_scan.lanesOf(piece : Piece) : {EdgeGeometry}, Engine.Component.TransportNetwork
	if not api.engine.entityExists(piece.entity) then
		return nil, nil
	end
	return readLanes(piece.entity, piece.kind)
end

local EMPTY_PROFILE : NullDozzerEdgeProfile.Profile = { averageGradient = 0.0, maxGradient = 0.0, horizontalLength = 0.0, samples = {} }

function network_scan.current(kinds : {Kind : boolean}) : {Piece}
	local clock = api.type.Clock.new()
	local entities = allBaseEdges()
	local findMicros = clock:getTime()

	local pieces : {Piece} = {}
	local seen : {Engine.Entity : boolean} = {}
	local read, made, removed = 0, 0, 0
	for _, entity in ipairs(entities) do
		seen[entity] = true
		local baseEdge = api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE) as Engine.Component.BaseEdge
		if baseEdge ~= nil then
			local entry = entries[entity]
			if entry == nil or not isUnchanged(entry, baseEdge) then
				entry = newEntry(baseEdge)
				entries[entity] = entry
				read = read + 1
			end
			if entry.kind ~= nil and kinds[entry.kind] then
				if entry.piece == nil then
					-- Tried again on every scan until the lanes can be read.
					entry.piece = makePiece(entity, entry, baseEdge)
					if entry.piece ~= nil then
						made = made + 1
					end
				end
				if entry.piece ~= nil then
					pieces[#pieces + 1] = entry.piece
				end
			end
		end
	end
	for entity in pairs(entries) do
		if not seen[entity] then
			entries[entity] = nil
			removed = removed + 1
		end
	end

	log.message(string.format(
		"[nulldozzer_gradients] scan: %.1f ms (find %.1f ms; %d edges, %d new or changed, %d pieces made, %d removed)",
		clock:getTime() / 1000.0, findMicros / 1000.0, #entities, read, made, removed))
	return pieces
end

function network_scan.profileOf(piece : Piece) : NullDozzerEdgeProfile.Profile
	local profile = keptProfiles[piece]
	if profile == nil then
		if keptProfileCount >= MAX_KEPT_PROFILES then
			keptProfiles = {}
			keptProfileCount = 0
		end
		-- `network` holds the lanes' component while they are measured.
		local lanes, network = network_scan.lanesOf(piece)
		if lanes == nil or network == nil then
			return EMPTY_PROFILE
		end
		profile = edge_profile.measure(lanes[1])
		keptProfiles[piece] = profile
		keptProfileCount = keptProfileCount + 1
	end
	return profile
end

return network_scan
