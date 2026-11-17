local react = ug_require "::/gui/main/react.lua" as React
local line_eow = ug_require "::/gui/entity_window/line/line_eow.script.tl" as LineEow

local gradient_card = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/gradient_card.tl" as NullDozzerGradientCard
local line_climb = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_climb.tl" as NullDozzerLineClimb
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute

local function summaryLines(lineEntity : Engine.Entity) : {string}
	local climb = line_climb.measure(lineEntity)
	if climb == nil then
		return { "Steepest climb: unknown (no route found)" }
	end
	return { line_climb.describe(climb), line_climb.describeRating(climb) }
end

local LineGradientSummary = gradient_card.registerSummary("NullDozzerLineGradientSummary", summaryLines)

local LineGradientPlugin = react.RegisterPluginRecipe(line_eow.LineEowExtensionPoint, "NullDozzerLineGradientPlugin", function(params : LineEow.LineWidgetPluginParams) : TreeNodeId
	return gradient_card.Card(params, "nullDozzerLineGradient", LineGradientSummary)
end)

-- Lines already reported as hidden, so the log gets one entry per line.
local reportedHidden : {Engine.Entity : boolean} = {}

local function conditionRailLine(params : LineEow.LineWidgetPluginParams) : boolean
	local ok, isRail = pcall(line_route.isRailLine, params.entityId)
	local show = ok and isRail == true
	if not show and not reportedHidden[params.entityId] then
		reportedHidden[params.entityId] = true
		log.message("[nulldozzer_gradients] no gradient card for line " .. tostring(params.entityId) .. ": "
			.. (ok and "not a rail line" or tostring(isRail)))
	end
	return show
end

return {
	LineGradientPlugin = LineGradientPlugin,
	conditionRailLine = conditionRailLine,
}
