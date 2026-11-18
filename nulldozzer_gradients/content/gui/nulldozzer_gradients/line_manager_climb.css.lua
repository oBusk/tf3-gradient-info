local ssu = require "::/gui/main/stylesheetutil.lua"

-- The base game sizes the five statistics cells as shares of a 456 px budget, with
-- 2 px spacers between them (gui/line_vehicle_mgmt/line_vehicle_mgmt.css.lua).
-- The row below lines up with them: the length cell sits under Capacity, the climb
-- cell spans Utilization and Frequency, the performance cell spans Rate and Balance.
local BUDGET = 456
local SPACER = 2
-- Each cell's padding, left plus right; a cell is drawn this much wider than its size.
local PADDING = 3 + 3
local CAPACITY, UTILIZATION, FREQUENCY, RATE, BALANCE = 0.19, 0.22, 0.22, 0.14, 0.23

-- Size of a cell spanning `columns` cells above, whose shares add up to `share`:
-- their sizes, plus the padding and spacers between them.
local function spanSize(share, columns)
	return share * BUDGET + (columns - 1) * (PADDING + SPACER)
end

function data()
	local result = {}
	local a = ssu.makeAdder(result)

	-- The top margin is the gap to the row above, as wide as the gaps between cells.
	a("R::LineStatisticDetails R::Component!details!nulldozzer-length", {
		size = { spanSize(CAPACITY, 1), -1 },
		margin = { SPACER, 0, 0, 0 },
	})

	a("R::LineStatisticDetails R::Component!details!nulldozzer-climb", {
		size = { spanSize(UTILIZATION + FREQUENCY, 2), -1 },
		margin = { SPACER, 0, 0, 0 },
	})

	a("R::LineStatisticDetails R::Component!details!nulldozzer-performance", {
		size = { spanSize(RATE + BALANCE, 2), -1 },
		margin = { SPACER, 0, 0, 0 },
	})

	return result
end
