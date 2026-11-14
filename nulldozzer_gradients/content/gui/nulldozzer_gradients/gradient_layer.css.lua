local ssu = require "::/gui/main/stylesheetutil.lua"

function data()
	local result = {}
	local a = ssu.makeAdder(result)

	a("R::NullDozzerGradientLegendLabels", {
		gravity = { -1, 0 },
	})

	a("R::NullDozzerGradientLegendLabels !nulldozzer-legend-spacer", {
		gravity = { -1, 0 },
	})

	return result
end
