local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local engine_react_util = ug_require "::/gui/main/engine_react_util.tl" as EngineReactUtil
local layer_react_util = ug_require "::/gui/layers/layer_react_util.tl" as LayerReactUtil
local table_util = ug_require "::/scripts/table_util.tl" as TableUtil
local TerrainLayer = ug_require "::/gui/layers/layer_terrain.tl" as Recipe<LayersButtonRidge.LayerContentParam>

local gradient_scale = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/gradient_scale.tl" as NullDozzerGradientScale
local gradient_tooltip = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/gradient_tooltip.tl" as NullDozzerGradientTooltip
local network_scan = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/network_scan.tl" as NullDozzerNetworkScan
local point_grid = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/point_grid.tl" as NullDozzerPointGrid

local type Piece = NullDozzerNetworkScan.Piece
local type Strip = Builtin.Type.EdgeRenderable.Edge

local STRIP_OPACITY <const> = 0.6
local STRIP_OFFSET_Z <const> = 0.3
local STRIP_STEP <const> = 2.0
local STRIP_WIDTH : {NullDozzerNetworkScan.Kind : number} = {
	track = 1.8,
	road = 2.5,
}

local GRID_CELL_SIZE <const> = 20.0
local LEGEND_LEVELS_PER_STEP <const> = 4

local record LayerState
	piecesByEntity : {Engine.Entity : Piece}
	grid : NullDozzerPointGrid.Grid
	-- One colour per piece from its average gradient.
	segmentStrips : {Strip}
	-- One colour per 4 m stretch, shown while the detail modifier is held.
	detailStrips : {Strip}
end

-- One colour per 4 m sample, in order along the piece. Unverified: assumes the
-- engine spreads the colour list evenly along the strip (the base game only
-- ever passes two). A single sample is doubled so the list has a start and end.
local function distanceSquared(position : Vec3f, sample : NullDozzerEdgeProfile.Sample) : number
	local dx = position.x - sample.x
	local dy = position.y - sample.y
	return dx * dx + dy * dy
end

-- Samples are measured along the piece's first lane; a road lane running the other
-- way starts at the last sample, so its colours must be reversed.
local function runsBackwards(lane : EdgeGeometry, samples : {NullDozzerEdgeProfile.Sample}) : boolean
	local start = api.engine.util.transport.calcPosition(lane, 0.0)
	return distanceSquared(start, samples[#samples]) < distanceSquared(start, samples[1])
end

local function detailColors(lane : EdgeGeometry, piece : Piece) : {Vec4f}
	local scale = gradient_scale.forKind(piece.kind)
	local samples = piece.profile.samples
	local backwards = runsBackwards(lane, samples)
	local colors : {Vec4f} = {}
	for i = 1, #samples do
		local sample = backwards and samples[#samples + 1 - i] or samples[i]
		colors[i] = gradient_scale.colorFor(scale, sample.gradient, STRIP_OPACITY)
	end
	if #colors == 1 then
		colors[2] = colors[1]
	end
	return colors
end

local function segmentColors(piece : Piece) : {Vec4f}
	local color = gradient_scale.colorFor(gradient_scale.forKind(piece.kind), piece.profile.averageGradient, STRIP_OPACITY)
	return { color, color }
end

local function makeStrip(lane : EdgeGeometry, piece : Piece, colors : {Vec4f}) : Strip
	local strip = builtin.type.EdgeRenderable.Edge.new(lane)
	strip.colors = colors
	strip.width = STRIP_WIDTH[piece.kind]
	strip.offsetZ = STRIP_OFFSET_Z
	strip.stepSize = STRIP_STEP
	return strip
end

local function addToGrid(grid : NullDozzerPointGrid.Grid, piece : Piece)
	for _, sample in ipairs(piece.profile.samples) do
		point_grid.add(grid, { x = sample.x, y = sample.y, gradient = sample.gradient, piece = piece.entity })
	end
end

local function buildLayerState() : LayerState
	local state : LayerState = { piecesByEntity = {}, grid = point_grid.new(GRID_CELL_SIZE), segmentStrips = {}, detailStrips = {} }
	for _, piece in ipairs(network_scan.scanAll()) do
		state.piecesByEntity[piece.entity] = piece
		addToGrid(state.grid, piece)
		for _, lane in ipairs(piece.lanes) do
			state.segmentStrips[#state.segmentStrips + 1] = makeStrip(lane, piece, segmentColors(piece))
			state.detailStrips[#state.detailStrips + 1] = makeStrip(lane, piece, detailColors(lane, piece))
		end
	end
	return state
end

local function ColorBar(scale : NullDozzerGradientScale.Scale) : TreeNodeId
	local colors : {Vec4f} = {}
	for _, gradient in ipairs(scale.legendGradients) do
		colors[#colors + 1] = gradient_scale.colorFor(scale, gradient, 1.0)
	end
	return builtin.GradientLegend{
		colors = layer_react_util.makeGradientColorsOfN({ colors = colors, numberOfLevels = LEGEND_LEVELS_PER_STEP * (#colors - 1) }),
		horizontal = true,
		discrete = true,
		internalLabels = false,
	}
end

local LegendLabels = react.RegisterRecipe("NullDozzerGradientLegendLabels", function(scale : NullDozzerGradientScale.Scale) : TreeNodeId
	local children : {TreeNodeId} = {}
	for i, gradient in ipairs(scale.legendGradients) do
		if i > 1 then
			children[#children + 1] = builtin.Component{ meta = { class = "nulldozzer-legend-spacer" } }
		end
		children[#children + 1] = builtin.TextView{ meta = { class = "font-scale-annotation" }, text = api.util.toStringPercentPrecision(gradient, 1) }
	end
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = children,
	}
end)

local function Legend(kind : NullDozzerNetworkScan.Kind) : TreeNodeId
	local scale = gradient_scale.forKind(kind)
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = { ColorBar(scale), LegendLabels(scale) },
	}
end

local function Subtitle(text : string) : TreeNodeId
	return builtin.TextView{ meta = { class = "font-scale-title-4, layer-subtitle" }, text = text }
end

local record CombinedTooltipParam
	terrainRecipe : Recipe<GameTooltips.TerrainTooltipParam>
	terrainParam : GameTooltips.TerrainTooltipParam
	gradientParam : NullDozzerGradientTooltip.Param
end

-- The terrain layer's height tooltip, with the gradient below it while the mouse is on a track or road.
local CombinedTooltip = react.RegisterRecipe("NullDozzerTerrainGradientTooltip", function(param : CombinedTooltipParam) : TreeNodeId
	react.setMouseTransparent(true)
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = {
			param.terrainRecipe(param.terrainParam),
			gradient_tooltip.Tooltip(param.gradientParam),
		},
	}
end)

-- Wraps the terrain layer's action so it also draws the gradient strips. The terrain
-- layer builds its action as one opaque node, so while its action function runs,
-- builtin.ActionDescriptor and builtin.ActionTooltip are swapped for versions that
-- add the strips and the gradient tooltip, and restored afterwards.
local function withGradients(terrainActionFn : (function() : TreeNodeId), state : LayerState, detail : boolean) : function() : TreeNodeId
	return function() : TreeNodeId
		local patchable = builtin as {string : any}
		local originalDescriptor = builtin.ActionDescriptor
		local originalTooltip = builtin.ActionTooltip
		local extended = false

		patchable.ActionDescriptor = function(param : Builtin.ActionDescriptorParam) : TreeNodeId
			if extended then
				return originalDescriptor(param)
			end
			extended = true
			local children : {TreeNodeId} = {}
			for i, child in ipairs(param.children or {}) do
				children[i] = child
			end
			-- Only one EdgeRenderable is allowed per ActionDescriptor, so swap the list.
			children[#children + 1] = builtin.EdgeRenderable{ edges = detail and state.detailStrips or state.segmentStrips, ignoreDepth = true }
			param.children = children
			return originalDescriptor(param)
		end

		patchable.ActionTooltip = function(param : Builtin.ActionTooltipParam<GameTooltips.TerrainTooltipParam>) : TreeNodeId
			local hoveredRef = param.param and param.param.entityRef
			if hoveredRef == nil then
				return originalTooltip(param)
			end
			return originalTooltip{
				recipe = CombinedTooltip,
				param = {
					terrainRecipe = param.recipe,
					terrainParam = param.param,
					gradientParam = { hoveredRef = hoveredRef, grid = state.grid, pieces = state.piecesByEntity },
				},
			}
		end

		local ok, result = pcall(terrainActionFn)
		patchable.ActionDescriptor = originalDescriptor
		patchable.ActionTooltip = originalTooltip
		if not ok then
			error(result, 0)
		end
		if not extended then
			log.warning("nulldozzer_gradients: could not extend the terrain layer action, gradients are not shown")
		end
		return result as TreeNodeId
	end
end

local GradientLegend = react.RegisterRecipe("NullDozzerGradientLegend", function() : TreeNodeId
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = {
			Subtitle("Track gradient"),
			Legend("track"),
			Subtitle("Road gradient"),
			Legend("road"),
			builtin.TextView{ text = "Colours show each segment's average.\nHold Shift to see the gradient every 4 m." },
		},
	}
end)

-- Stands in for the base game's Terrain data layer: the original layer, plus the
-- gradient strips on the map and their legend below the terrain legend.
local TerrainLayerWithGradients = react.RegisterRecipe("NullDozzerTerrainLayerWithGradients", function(param : LayersButtonRidge.LayerContentParam) : TreeNodeId
	local stateRef : ReactRefT<LayerState> = react.useRef()
	if stateRef:get() == nil then
		stateRef:set(buildLayerState())
	end
	local detailState = engine_react_util.useStepState(gradient_tooltip.isDetailHeld)
	local detail = detailState:old() == true

	-- The terrain layer sets its action while it renders. Keep the latest one, so a
	-- change of detail re-wraps it even when the terrain layer does not re-render.
	local terrainActionRef : ReactRefT<(function() : TreeNodeId)> = react.useRef()
	local terrainActionKeyRef : ReactRefT<string> = react.useRef()
	if terrainActionRef:get() ~= nil then
		param.setActionFn(withGradients(terrainActionRef:get(), stateRef:get(), detail), terrainActionKeyRef:get())
	end

	local terrainParam = table_util.copy(param)
	terrainParam.setActionFn = function(actionFn : (function() : TreeNodeId), key? : string)
		terrainActionRef:set(actionFn)
		terrainActionKeyRef:set(key)
		param.setActionFn(withGradients(actionFn, stateRef:get(), detail), key)
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = {
			react.CallOriginalRecipe(TerrainLayer, terrainParam),
			layer_react_util.LayerLegendWrapper{ content = GradientLegend() },
		},
	}
end)

local function replaceTerrainLayer(replacementApi : ReactReplacementApi)
	replacementApi.ReplaceRecipe(TerrainLayer, TerrainLayerWithGradients)
end

return {
	replaceTerrainLayer = replaceTerrainLayer,
}
