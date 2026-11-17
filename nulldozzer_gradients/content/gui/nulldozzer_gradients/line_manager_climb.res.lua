-- Adds a "Climb" cell to the line manager's statistics row for rail lines.
function data()
	return {
		type = "react-replacement-config",
		data = {
			filePath = "nulldozzer_gradients::/gui/nulldozzer_gradients/line_manager_climb.script",
			doReplaceFn = "doReplace",
			order = 0,
		},
	}
end
