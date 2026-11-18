global record NullDozzerLineClimb
	--- What one measurement of a rail line's route gives.
	record LineInfo
		--- Steepest climb over the window; nil if no leg of the route was found.
		climb : NullDozzerClimbWindow.Climb
		--- Length of the round trip through every stop, ignoring height.
		length : number
		stops : integer
		--- False if the route between some stops could not be found, so length
		--- leaves those legs out.
		complete : boolean
	end

	--- Measures a rail line's route. The climb is over `window` metres, or over
	--- its shortest platform's length if `window` is nil.
	--- nil if the route could not be measured; the reason is logged.
	measure : function(lineEntity : Engine.Entity, window? : number) : LineInfo
end
