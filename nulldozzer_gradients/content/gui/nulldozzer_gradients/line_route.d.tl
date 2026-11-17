global record NullDozzerLineRoute
	record Route
		--- Height profile of each stop-to-stop leg, in travel order.
		legs : {{NullDozzerClimbWindow.Point}}
		--- Shortest platform the line stops at; 0 if unknown.
		shortestPlatform : number
	end

	--- True for lines that trains run on.
	isRailLine : function(lineEntity : Engine.Entity) : boolean
	--- The route trains take between the line's stops, through its waypoints.
	--- Recomputed with the game's pathfinder; the line does not store its route.
	measure : function(lineEntity : Engine.Entity) : Route
end
