local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local network_scan = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/network_scan.tl" as NullDozzerNetworkScan

local gradient_tooltip : NullDozzerGradientTooltip = {}

local type Piece = NullDozzerNetworkScan.Piece

local MAX_DISTANCE_TO_NETWORK <const> = 6.0
-- Shift by default; the same modifier the build tools use for precision mode.
local DETAIL_ACTION <const> = "IA_PRECISION_MODE"

local STRUCTURE_NAMES : {NullDozzerNetworkScan.Structure : string} = {
	bridge = "Bridge",
	tunnel = "Tunnel",
	ground = "Structure",
}

local function percent(gradient : number) : string
	return api.util.toStringPercentPrecision(gradient, 1)
end

function gradient_tooltip.isDetailHeld() : boolean
	local ok, held = pcall(api.gui.inputAction.modifierOnlyActionIsActive, DETAIL_ACTION)
	return ok and held == true
end

local function summary(label : string, average : number, steepest : number) : string
	return label .. ": " .. percent(average) .. " average\nSteepest: " .. percent(steepest)
end

local function piecesOfStructure(structureEntity : Engine.Entity, pieces : {Engine.Entity : Piece}) : {Piece}
	local strip = api.engine.getComponent(structureEntity, api.type.ComponentType.BASE_PARALLEL_STRIP) as Engine.Component.BaseParallelStrip
	if strip == nil then
		return nil
	end
	local result : {Piece} = {}
	local seen : {Engine.Entity : boolean} = {}
	for _, rangeGroup in ipairs(strip.rangeGroups) do
		for _, range in ipairs(rangeGroup) do
			local piece = pieces[range.edge]
			if piece and not seen[piece.entity] then
				seen[piece.entity] = true
				result[#result + 1] = piece
			end
		end
	end
	if #result == 0 then
		return nil
	end
	return result
end

-- Length-weighted mean of the segment averages, so a bridge that climbs and then
-- falls still reads as steep instead of cancelling out.
local function describeStructure(structurePieces : {Piece}) : string
	local weighted, length, steepest = 0.0, 0.0, 0.0
	for _, piece in ipairs(structurePieces) do
		weighted = weighted + piece.averageGradient * piece.horizontalLength
		length = length + piece.horizontalLength
		steepest = math.max(steepest, network_scan.profileOf(piece).maxGradient)
	end
	local average = length > 0.0 and weighted / length or 0.0
	return summary(STRUCTURE_NAMES[structurePieces[1].structure], average, steepest)
end

local function describeStructureSegments(structurePieces : {Piece}) : string
	local lines : {string} = {}
	for i, piece in ipairs(structurePieces) do
		lines[#lines + 1] = "Segment " .. i .. ": " .. percent(piece.averageGradient)
			.. " average, " .. percent(network_scan.profileOf(piece).maxGradient) .. " steepest"
	end
	return table.concat(lines, "\n")
end

-- The sample nearest to (x, y) on the pieces within reach, measuring them if needed.
local function nearestSample(x : number, y : number, pieces : {Engine.Entity : Piece}) : NullDozzerEdgeProfile.Sample, Piece
	local center = api.type.Vec2f.new(x, y)
	local candidates = api.engine.util.octree.findEntitiesInCircle(center, MAX_DISTANCE_TO_NETWORK, api.type.ComponentType.BASE_EDGE)
	local bestSample : NullDozzerEdgeProfile.Sample = nil
	local bestPiece : Piece = nil
	local bestDistanceSquared = MAX_DISTANCE_TO_NETWORK * MAX_DISTANCE_TO_NETWORK
	for _, entity in ipairs(candidates) do
		local piece = pieces[entity]
		if piece ~= nil then
			for _, sample in ipairs(network_scan.profileOf(piece).samples) do
				local dx = sample.x - x
				local dy = sample.y - y
				local distanceSquared = dx * dx + dy * dy
				if distanceSquared < bestDistanceSquared then
					bestSample, bestPiece, bestDistanceSquared = sample, piece, distanceSquared
				end
			end
		end
	end
	return bestSample, bestPiece
end

local function describePoint(sample : NullDozzerEdgeProfile.Sample, piece : Piece, detail : boolean) : string
	if detail then
		return "Gradient here: " .. percent(sample.gradient)
	end
	return summary("Segment", piece.averageGradient, network_scan.profileOf(piece).maxGradient)
end

local function describeHoveredStructure(param : NullDozzerGradientTooltip.Param, detail : boolean) : string
	local hovered = param.hoveredRef:get()
	if hovered == nil or hovered < 0 then
		return nil
	end
	local structurePieces = piecesOfStructure(hovered, param.pieces)
	if structurePieces == nil then
		return nil
	end
	return detail and describeStructureSegments(structurePieces) or describeStructure(structurePieces)
end

local function describePointUnderMouse(param : NullDozzerGradientTooltip.Param, detail : boolean) : string
	if not api.gui.mouse.hasTerrainPosition() then
		return nil
	end
	local ground = api.gui.mouse.getTerrainPosition()
	local sample, piece = nearestSample(ground.x, ground.y, param.pieces)
	return sample and describePoint(sample, piece, detail)
end

-- Shift raises the resolution one step: structure -> its segments, segment -> point.
local function tooltipText(param : NullDozzerGradientTooltip.Param, detail : boolean) : string
	return describeHoveredStructure(param, detail) or describePointUnderMouse(param, detail)
end

-- What the last frame's text was worked out from, to skip frames where nothing changed.
local record LastQuery
	x : number
	y : number
	hovered : Engine.Entity
	detail : boolean
	-- The pieces shown, which change when another network choice is picked.
	pieces : {Engine.Entity : Piece}
	text : string
end

local function sameQuery(last : LastQuery, query : LastQuery) : boolean
	return last ~= nil and last.x == query.x and last.y == query.y and last.hovered == query.hovered
		and last.detail == query.detail and last.pieces == query.pieces
end

local function TooltipBox(text : string) : TreeNodeId
	return builtin.BoxLayout{
		children = {
			builtin.TextView{
				meta = {
					class = "default-tooltip-configuration, font-scale-tooltip",
					mouseTransparent = true,
				},
				text = text,
			},
		},
	}
end

gradient_tooltip.Tooltip = react.RegisterRecipe("NullDozzerGradientsTooltip", function(param : NullDozzerGradientTooltip.Param) : TreeNodeId
	react.setMouseTransparent(true)

	local textState : ReactStateT<string> = react.useState(nil)
	local lastRef : ReactRefT<LastQuery> = react.useRef()
	react.onStep(function()
		local detail = gradient_tooltip.isDetailHeld()
		local hovered = param.hoveredRef:get()
		local x, y = 0.0, 0.0
		if api.gui.mouse.hasTerrainPosition() then
			local ground = api.gui.mouse.getTerrainPosition()
			x, y = ground.x, ground.y
		end
		local last = lastRef:get()
		local query : LastQuery = { x = x, y = y, hovered = hovered, detail = detail, pieces = param.pieces }
		local text : string
		if sameQuery(last, query) then
			text = last.text
		else
			text = tooltipText(param, detail)
			query.text = text
			lastRef:set(query)
		end
		textState:transform(function() : string
			return text
		end)
	end)

	local text = textState:old()
	if text == nil then
		return builtin.BoxLayout{}
	end
	return TooltipBox(text)
end)

return gradient_tooltip
