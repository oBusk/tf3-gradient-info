local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local content_card = ug_require "::/gui/main/content_card.tl" as ContentCard
local line_eow = ug_require "::/gui/entity_window/line/line_eow.script.tl" as LineEow

local line_climb = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_climb.tl" as NullDozzerLineClimb
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute

local record Summary
	-- nil if the route could not be measured.
	climb : NullDozzerClimbWindow.Climb
end

local function summaryLines(summary : Summary) : {string}
	local climb = summary.climb
	if climb == nil then
		return { "Steepest climb: unknown (no route found)" }
	end
	return { line_climb.describe(climb), line_climb.describeRating(climb) }
end

local LineGradientSummary = react.RegisterRecipe("NullDozzerLineGradientSummary", function(lineEntity : Engine.Entity) : TreeNodeId
	-- Measured once per opened window; reopen the window after changing the line or track.
	local summaryRef : ReactRefT<Summary> = react.useRef()
	if summaryRef:get() == nil then
		summaryRef:set({ climb = line_climb.measure(lineEntity) })
	end
	local children : {TreeNodeId} = {}
	for _, line in ipairs(summaryLines(summaryRef:get())) do
		children[#children + 1] = builtin.TextView{ meta = { class = "font-scale-body" }, text = line }
	end
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = children,
	}
end)

local LineGradientPlugin = react.RegisterPluginRecipe(line_eow.LineEowExtensionPoint, "NullDozzerLineGradientPlugin", function(params : LineEow.LineWidgetPluginParams) : TreeNodeId
	return builtin.BoxLayout{
		meta = { class = "box-plugin-vertical-space" },
		orientation = builtin.type.Orientation.Vertical,
		children = {
			content_card.ContentCard{
				meta = { localKey = "nullDozzerLineGradient" },
				title = "Gradient",
				initialCalloutTextPermanent = "",
				recipeAndParamPermanent = content_card.makeRecipeAndParam(LineGradientSummary, params.entityId),
				gameCtx = params.gameCtx,
				showOnRightSide = params.showCalloutOnRightSide,
			},
		},
	}
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
