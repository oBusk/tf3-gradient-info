function data()
	return {
		type = "react-plugin ::VehicleEowExtensionPoint",
		data = {
			filePath = "nulldozzer_gradients::/gui/nulldozzer_gradients/vehicle_gradient.script@VehicleGradientPlugin",
			condition = "nulldozzer_gradients::/gui/nulldozzer_gradients/vehicle_gradient.script@conditionTrainOnRailLine",
			-- Right after the base game's "Basics" card (order 10).
			order = 20,
		},
	}
end
