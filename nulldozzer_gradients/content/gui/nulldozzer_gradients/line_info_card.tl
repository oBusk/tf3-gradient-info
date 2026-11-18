local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local content_card = ug_require "::/gui/main/content_card.tl" as ContentCard
local gui_react_util = ug_require "::/gui/main/gui_react_util.tl" as GuiReactUtil

local store_performance = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/store_performance.tl" as NullDozzerStorePerformance

local line_info_card : NullDozzerLineInfoCard = {
	-- A route between two points.
	ICON_LENGTH = "::/gui/line_vehicle_mgmt/icons/line_stations.tga",
	-- A station building.
	ICON_STOPS = "::/gui/entity_window/icons/building_stations.tga",
	ICON_SPEED = "::/gui/entity_window/icons/symbol_speed.tga",
	-- The build tool's gradient symbol, which the train grade mod also uses.
	ICON_SLOPE = "::/gui/construction/build_control/symbol_slope_2_20.tga",
}

-- Drawn like the game's own figures in the Basics card (Rate, Frequency): the
-- entity window's stylesheet lays out IconLabelIndicator.
local function Cells(cells : {NullDozzerLineInfoCard.Cell}) : TreeNodeId
	local children : {TreeNodeId} = {}
	for _, cell in ipairs(cells) do
		children[#children + 1] = gui_react_util.IconLabelIndicator{
			iconPath = cell.icon,
			label = cell.label,
			tooltip = cell.tooltip,
		}
	end
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = children,
	}
end

-- Average speed over a round trip, stops included. The game keeps no round trip
-- time, but its frequency does: vehicles are spread over the round trip, so one
-- round trip takes the interval between vehicles times the number of vehicles.
local function speedCell(lineEntity : Engine.Entity, length : number) : NullDozzerLineInfoCard.Cell
	local frequency = api.engine.util.line.getMaxFrequency(lineEntity)
	local vehicles = #api.engine.system.transportVehicleSystem.getLineVehicles(lineEntity)
	if frequency == nil or frequency < 0.0001 or vehicles == 0 then
		return nil
	end
	local roundTripSeconds = vehicles / frequency
	local speed = api.util.formatSpeed(length / roundTripSeconds)
	return {
		icon = line_info_card.ICON_SPEED,
		label = speed,
		tooltip = "Average speed: " .. speed .. ", stops included\n"
			.. "A round trip takes about " .. api.util.formatMinutesSeconds(math.floor(roundTripSeconds))
			.. " (" .. tostring(vehicles) .. (vehicles == 1 and " vehicle" or " vehicles")
			.. " at the line's frequency)",
	}
end

function line_info_card.lengthCell(info : NullDozzerLineClimb.LineInfo) : NullDozzerLineInfoCard.Cell
	local length = api.util.formatLength(info.length)
	if not info.complete then
		-- Some legs were not found, so the length falls short.
		return {
			icon = line_info_card.ICON_LENGTH,
			label = length .. "+",
			tooltip = "Round trip: at least " .. length .. " (the route between some stops was not found)",
		}
	end
	return { icon = line_info_card.ICON_LENGTH, label = length, tooltip = "Round trip: " .. length }
end

function line_info_card.routeCells(lineEntity : Engine.Entity, info : NullDozzerLineClimb.LineInfo) : {NullDozzerLineInfoCard.Cell}
	local stops : NullDozzerLineInfoCard.Cell = {
		icon = line_info_card.ICON_STOPS,
		label = tostring(info.stops),
		tooltip = "Stops: " .. tostring(info.stops),
	}
	if not info.complete then
		-- Some legs were not found, so anything from the length falls short.
		return { line_info_card.lengthCell(info), stops }
	end
	stops.tooltip = stops.tooltip .. "\nAverage distance between stops: " .. api.util.formatLength(info.length / info.stops)
	local cells : {NullDozzerLineInfoCard.Cell} = { line_info_card.lengthCell(info), stops }
	local ok, speed = pcall(speedCell, lineEntity, info.length)
	if ok and speed ~= nil then
		cells[#cells + 1] = speed
	end
	return cells
end

function line_info_card.slopeCell(climb : NullDozzerClimbWindow.Climb, details? : {string}) : NullDozzerLineInfoCard.Cell
	local percent = api.util.toStringPercentPrecision(climb.gradient, 1)
	local rating = store_performance.ratingFor(climb.gradient)
	local lines = {
		"Steepest climb: " .. percent .. " over " .. api.util.formatLength(climb.window),
		rating and ("To maintain full speed requires Performance: " .. rating) or "Too steep for any train to maintain full speed",
	}
	for _, detail in ipairs(details or {}) do
		lines[#lines + 1] = detail
	end
	return { icon = line_info_card.ICON_SLOPE, label = percent, tooltip = table.concat(lines, "\n") }
end

-- A factory rather than one recipe taking `summaryFor` as a parameter: recipe
-- parameters are compared between renders, and the game logs an error for
-- every function it is asked to compare.
function line_info_card.registerSummary(name : string, summaryFor : function(entity : Engine.Entity) : NullDozzerLineInfoCard.Summary) : Recipe<Engine.Entity>
	return react.RegisterRecipe(name, function(entity : Engine.Entity) : TreeNodeId
		local summaryRef : ReactRefT<NullDozzerLineInfoCard.Summary> = react.useRef()
		if summaryRef:get() == nil then
			summaryRef:set(summaryFor(entity))
		end
		local summary = summaryRef:get()
		if summary.cells ~= nil and #summary.cells > 0 then
			return Cells(summary.cells)
		end
		return builtin.BoxLayout{
			children = {
				builtin.TextView{ meta = { class = "font-scale-body" }, text = summary.note or "" },
			},
		}
	end)
end

function line_info_card.Card(params : EowExtensionUtil.IEowWidgetsExtensionParams, localKey : string, summary : Recipe<Engine.Entity>) : TreeNodeId
	return builtin.BoxLayout{
		meta = { class = "box-plugin-vertical-space" },
		orientation = builtin.type.Orientation.Vertical,
		children = {
			content_card.ContentCard{
				meta = { localKey = localKey },
				title = "Line info",
				initialCalloutTextPermanent = "",
				recipeAndParamPermanent = content_card.makeRecipeAndParam(summary, params.entityId),
				gameCtx = params.gameCtx,
				showOnRightSide = params.showCalloutOnRightSide,
			},
		},
	}
end

return line_info_card
