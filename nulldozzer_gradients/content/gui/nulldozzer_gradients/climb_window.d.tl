global record NullDozzerClimbWindow
	--- A point along a route, in travel order.
	record Point
		--- Horizontal distance from the start of the route.
		distance : number
		height : number
	end

	record Climb
		--- Height gained over the window, divided by the window length. Never negative.
		gradient : number
		--- Length the gradient was measured over; shorter than asked if the route is shorter.
		window : number
	end

	--- Steepest average uphill gradient over any stretch of the given length.
	steepest : function(points : {Point}, window : number) : Climb
	--- Steepest climb over any of the legs; nil if there are no legs.
	steepestOfLegs : function(legs : {{Point}}, window : number) : Climb
end
