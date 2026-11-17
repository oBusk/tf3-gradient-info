global record NullDozzerLineClimb
	--- Steepest climb on a rail line over its shortest platform's length.
	--- nil if the route could not be measured; the reason is logged.
	measure : function(lineEntity : Engine.Entity) : NullDozzerClimbWindow.Climb
	--- Vehicle store Performance rating a train needs to hold full speed on the
	--- gradient; nil if no rating is enough.
	ratingFor : function(gradient : number) : string
	--- Short text for a climb, such as "Steepest climb: 2.8% (over 160 m)".
	describe : function(climb : NullDozzerClimbWindow.Climb) : string
	--- What the climb asks of a train, such as "Full speed uphill needs Performance: Good".
	describeRating : function(climb : NullDozzerClimbWindow.Climb) : string
end
