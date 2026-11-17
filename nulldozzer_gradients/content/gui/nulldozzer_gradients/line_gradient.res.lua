function data()
	return {
		type = "react-plugin ::LineEowExtensionPoint",
		data = {
			filePath = "nulldozzer_gradients::/gui/nulldozzer_gradients/line_gradient.script@LineGradientPlugin",
			condition = "nulldozzer_gradients::/gui/nulldozzer_gradients/line_gradient.script@conditionRailLine",
			-- Right after the base game's "Basics" card (order 20).
			order = 25,
		},
	}
end
