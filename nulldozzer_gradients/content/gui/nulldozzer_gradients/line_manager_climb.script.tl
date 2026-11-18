-- Adds "Length", "Steepest climb" and "Needs Performance" cells to the line manager's statistics, on a row below
-- Capacity, Utilization, Frequency, Rate and Balance, for rail lines.
--
-- The row is built inside the base game's LineStatisticDetails recipe, which is
-- private to gui/line_vehicle_mgmt/manager_window.tl, so it cannot be replaced
-- directly. Instead, two shared pieces it uses are wrapped, and both act only while
-- LineStatisticDetails is rendering:
-- - line_react_util.LineBalance, its Balance value, is handed the line entity;
--   the replacement notes it and draws the original.
-- - builtin.Component builds the row as Component{ class = "statistics-details" }
--   right after that; the wrapper adds the Climb cell on a row below it.
-- If a game update renames either, the cell simply does not appear.

local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local line_react_util = ug_require "::/gui/line_vehicle_mgmt/line_react_util.tl" as LineReactUtil

local line_climb = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_climb.tl" as NullDozzerLineClimb
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute
local store_performance = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/store_performance.tl" as NullDozzerStorePerformance
local line_info_card = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_info_card.tl" as NullDozzerLineInfoCard

local STATISTICS_RECIPE <const> = "LineStatisticDetails"
local ROW_CLASS <const> = "statistics-details"
local CLIMB_TOOLTIP <const> = "Steepest climb on the line over its shortest platform's length, "
	.. "and the vehicle store Performance rating a train needs to hold full speed on it."

-- Line shown by the LineStatisticDetails render in progress.
local renderingLine : Engine.Entity = nil

local function isRenderingStatistics() : boolean
	local ok, name = pcall(react.getCurrentRecipeName)
	return ok and name == STATISTICS_RECIPE
end

-- A cell styled like the base game's statistics cells: a title above a value.
local function DetailsCell(title : string, value : string, class : string, tooltip : string) : TreeNodeId
	return builtin.Component{
		meta = { class = "details, " .. class, tooltip = tooltip },
		layout = builtin.BoxLayout{
			orientation = builtin.type.Orientation.Vertical,
			children = {
				builtin.TextView{ meta = { class = "font-scale-body, details-title" }, text = title },
				builtin.TextView{ meta = { class = "font-scale-body, details-value" }, text = value },
			},
		},
	}
end

local ClimbCell = react.RegisterRecipe("NullDozzerLineManagerClimb", function(lineEntity : Engine.Entity) : TreeNodeId
	-- One measurement per line while the line manager is open, so switching
	-- between lines does not measure them again.
	local climbsRef : ReactRefT<{Engine.Entity : NullDozzerLineClimb.LineInfo | boolean}> = react.useRef()
	if climbsRef:get() == nil then
		climbsRef:set({})
	end
	local climbs = climbsRef:get()
	if climbs[lineEntity] == nil then
		climbs[lineEntity] = line_climb.measure(lineEntity) or false
	end
	local info = climbs[lineEntity]

	local climbText = "Unknown (no route found)"
	local performanceText = "-"
	local lengthText = "-"
	local lengthTooltip = "Round trip length; unknown as no route was found."
	if info is NullDozzerLineClimb.LineInfo then
		local length = line_info_card.lengthCell(info)
		lengthText = length.label
		lengthTooltip = length.tooltip
	end
	if info is NullDozzerLineClimb.LineInfo and info.climb ~= nil then
		local climb = info.climb
		climbText = api.util.toStringPercentPrecision(climb.gradient, 1) .. " over " .. api.util.formatLength(climb.window)
		performanceText = store_performance.ratingFor(climb.gradient) or "Too steep"
	end

	-- A recipe used as a layout child must itself return a layout.
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = {
			DetailsCell("Length", lengthText, "nulldozzer-length", lengthTooltip),
			builtin.Component{ meta = { class = "details-spacer" } },
			DetailsCell("Steepest climb", climbText, "nulldozzer-climb", CLIMB_TOOLTIP),
			builtin.Component{ meta = { class = "details-spacer" } },
			DetailsCell("Needs Performance", performanceText, "nulldozzer-performance", CLIMB_TOOLTIP),
		},
	}
end)

-- Builtins are called either as Component(param) or as Component(ref, param),
-- so the wrapper takes and forwards both arguments.
local originalComponent : function(first : any, second? : any) : TreeNodeId = nil

local function isStatisticsRow(param : Builtin.ComponentParam) : boolean
	local meta = param and (param as {string : any}).meta as {string : any}
	return meta ~= nil and meta.class == ROW_CLASS and isRenderingStatistics()
end

-- The original row of cells, with the Climb cell on a row of its own below it.
local function withClimbCell(param : Builtin.ComponentParam, lineEntity : Engine.Entity) : Builtin.ComponentParam
	param.layout = builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = {
			param.layout,
			ClimbCell(lineEntity),
		},
	}
	return param
end

local function component(first : any, second : any) : TreeNodeId
	local lineEntity = renderingLine
	-- The statistics row is built with the one-argument form, without a ref.
	if lineEntity ~= nil and second == nil and isStatisticsRow(first as Builtin.ComponentParam) then
		renderingLine = nil
		local ok, isRail = pcall(line_route.isRailLine, lineEntity)
		if ok and isRail then
			return originalComponent(withClimbCell(first as Builtin.ComponentParam, lineEntity))
		end
	end
	if second == nil then
		return originalComponent(first)
	end
	return originalComponent(first, second)
end

local function lineBalance(param : LineReactUtil.LineBalanceParams) : TreeNodeId
	if param ~= nil and isRenderingStatistics() then
		renderingLine = param.entity
	end
	return react.CallOriginalRecipe(line_react_util.LineBalance, param)
end

local function doReplace(replacementApi : ReactReplacementApi)
	if originalComponent ~= nil then
		return
	end
	-- Keep whatever is there now, so this chains with other mods that wrap it too.
	originalComponent = builtin.Component as function(first : any, second? : any) : TreeNodeId
	local patchable = builtin as {string : any}
	patchable.Component = component
	replacementApi.ReplaceRecipe(line_react_util.LineBalance, lineBalance as Recipe<LineReactUtil.LineBalanceParams>)
end

return {
	doReplace = doReplace,
}
