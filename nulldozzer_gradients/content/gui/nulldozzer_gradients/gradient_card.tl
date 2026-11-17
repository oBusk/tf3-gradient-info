local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local content_card = ug_require "::/gui/main/content_card.tl" as ContentCard

local gradient_card : NullDozzerGradientCard = {}

-- A factory rather than one recipe taking `linesFor` as a parameter: recipe
-- parameters are compared between renders, and the game logs an error for
-- every function it is asked to compare.
function gradient_card.registerSummary(name : string, linesFor : function(entity : Engine.Entity) : {string}) : Recipe<Engine.Entity>
	return react.RegisterRecipe(name, function(entity : Engine.Entity) : TreeNodeId
		local linesRef : ReactRefT<{string}> = react.useRef()
		if linesRef:get() == nil then
			linesRef:set(linesFor(entity))
		end
		local children : {TreeNodeId} = {}
		for _, line in ipairs(linesRef:get()) do
			children[#children + 1] = builtin.TextView{ meta = { class = "font-scale-body" }, text = line }
		end
		return builtin.BoxLayout{
			orientation = builtin.type.Orientation.Vertical,
			children = children,
		}
	end)
end

function gradient_card.Card(params : EowExtensionUtil.IEowWidgetsExtensionParams, localKey : string, summary : Recipe<Engine.Entity>) : TreeNodeId
	return builtin.BoxLayout{
		meta = { class = "box-plugin-vertical-space" },
		orientation = builtin.type.Orientation.Vertical,
		children = {
			content_card.ContentCard{
				meta = { localKey = localKey },
				title = "Gradient",
				initialCalloutTextPermanent = "",
				recipeAndParamPermanent = content_card.makeRecipeAndParam(summary, params.entityId),
				gameCtx = params.gameCtx,
				showOnRightSide = params.showCalloutOnRightSide,
			},
		},
	}
end

return gradient_card
