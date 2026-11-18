local react = ug_require "::/gui/main/react.lua" as React
local line_eow = ug_require "::/gui/entity_window/line/line_eow.script.tl" as LineEow

local line_info_card = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_info_card.tl" as NullDozzerLineInfoCard
local line_climb = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_climb.tl" as NullDozzerLineClimb
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute

local NO_ROUTE <const> = "Route unknown: the path between the line's stops was not found"

local function summaryFor(lineEntity : Engine.Entity) : NullDozzerLineInfoCard.Summary
	local info = line_climb.measure(lineEntity)
	if info == nil or info.climb == nil then
		return { note = NO_ROUTE }
	end
	local cells = line_info_card.routeCells(lineEntity, info)
	cells[#cells + 1] = line_info_card.slopeCell(info.climb)
	return { cells = cells }
end

local LineInfoSummary = line_info_card.registerSummary("NullDozzerLineInfoSummary", summaryFor)

local LineGradientPlugin = react.RegisterPluginRecipe(line_eow.LineEowExtensionPoint, "NullDozzerLineGradientPlugin", function(params : LineEow.LineWidgetPluginParams) : TreeNodeId
	return line_info_card.Card(params, "nullDozzerLineGradient", LineInfoSummary)
end)

-- Lines already reported as hidden, so the log gets one entry per line.
local reportedHidden : {Engine.Entity : boolean} = {}

local function conditionRailLine(params : LineEow.LineWidgetPluginParams) : boolean
	local ok, isRail = pcall(line_route.isRailLine, params.entityId)
	local show = ok and isRail == true
	if not show and not reportedHidden[params.entityId] then
		reportedHidden[params.entityId] = true
		log.message("[nulldozzer_gradients] no line info card for line " .. tostring(params.entityId) .. ": "
			.. (ok and "not a rail line" or tostring(isRail)))
	end
	return show
end

return {
	LineGradientPlugin = LineGradientPlugin,
	conditionRailLine = conditionRailLine,
}
