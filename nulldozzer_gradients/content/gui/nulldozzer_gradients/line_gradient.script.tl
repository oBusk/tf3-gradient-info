local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local content_card = ug_require "::/gui/main/content_card.tl" as ContentCard
local line_eow = ug_require "::/gui/entity_window/line/line_eow.script.tl" as LineEow

local climb_window = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/climb_window.tl" as NullDozzerClimbWindow
local line_route = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/line_route.tl" as NullDozzerLineRoute

-- Used when the line's platforms report no length.
local FALLBACK_WINDOW <const> = 200.0

-- The vehicle store rates a train by the steepest reference slope it holds its
-- top speed on (0%, 3.75%, 7.5%), each with a third of a step as margin. See
-- getPowerRatingTextAndToolTip in the base game's gui/line_vehicle_mgmt/vehicle_util.tl.
local RATING_STEP <const> = 0.0375
local RATING_MARGIN <const> = RATING_STEP * 0.33
local RATINGS : {{number, string}} = {
	{ RATING_MARGIN, "Mediocre" },
	{ RATING_STEP + RATING_MARGIN, "Good" },
	{ 2 * RATING_STEP + RATING_MARGIN, "Excellent" },
}

local record Summary
	-- nil if the route could not be measured.
	climb : NullDozzerClimbWindow.Climb
end

local function ratingFor(gradient : number) : string
	for _, rating in ipairs(RATINGS) do
		if gradient <= rating[1] then
			return rating[2]
		end
	end
	return nil
end

local function steepestClimb(lineEntity : Engine.Entity) : NullDozzerClimbWindow.Climb
	local route = line_route.measure(lineEntity)
	local window = route.shortestPlatform > 0.0 and route.shortestPlatform or FALLBACK_WINDOW
	return climb_window.steepestOfLegs(route.legs, window)
end

-- The route API calls are unverified against the running game, so a failure
-- must not take the whole line window down with it.
local function summarize(lineEntity : Engine.Entity) : Summary
	local clock = api.type.Clock.new()
	local ok, result = pcall(steepestClimb, lineEntity)
	log.message(string.format("[nulldozzer_gradients] line window card for %s took %.1f ms", tostring(lineEntity), clock:getTime() / 1000.0))
	if not ok then
		log.message("[nulldozzer_gradients] could not measure line " .. tostring(lineEntity) .. ": " .. tostring(result))
		return {}
	end
	return { climb = result as NullDozzerClimbWindow.Climb }
end

local function summaryLines(summary : Summary) : {string}
	local climb = summary.climb
	if climb == nil then
		return { "Steepest climb: unknown (no route found)" }
	end
	local lines = {
		"Steepest climb: " .. api.util.toStringPercentPrecision(climb.gradient, 1)
			.. " (over " .. api.util.formatLength(climb.window) .. ")",
	}
	local rating = ratingFor(climb.gradient)
	if rating ~= nil then
		lines[2] = "Full speed uphill needs Performance: " .. rating
	else
		lines[2] = "Too steep for any train to hold full speed"
	end
	return lines
end

local LineGradientSummary = react.RegisterRecipe("NullDozzerLineGradientSummary", function(lineEntity : Engine.Entity) : TreeNodeId
	-- Measured once per opened window; reopen the window after changing the line or track.
	local summaryRef : ReactRefT<Summary> = react.useRef()
	if summaryRef:get() == nil then
		summaryRef:set(summarize(lineEntity))
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
