global record NullDozzerLineClimb
	--- Steepest climb on a rail line over `window` metres, or over its shortest
	--- platform's length if `window` is nil.
	--- nil if the route could not be measured; the reason is logged.
	measure : function(lineEntity : Engine.Entity, window? : number) : NullDozzerClimbWindow.Climb
	--- Short text for a climb, such as "Steepest climb: 2.8% (over 160 m)".
	describe : function(climb : NullDozzerClimbWindow.Climb) : string
	--- What the climb asks of a train, such as "Full speed uphill needs Performance: Good".
	describeRating : function(climb : NullDozzerClimbWindow.Climb) : string
end
