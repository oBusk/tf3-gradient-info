-- Replaces the base game's Terrain data layer with one that also shows gradients.
function data()
	return {
		type = "react-replacement-config",
		data = {
			filePath = "nulldozzer_gradients::/gui/nulldozzer_gradients/gradient_layer.script",
			doReplaceFn = "replaceTerrainLayer",
			order = 0,
		},
	}
end
