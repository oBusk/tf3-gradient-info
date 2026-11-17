--- The vehicle store's model of how trains cope with slopes, from
--- getPowerRatingTextAndToolTip in the base game's gui/line_vehicle_mgmt/vehicle_util.tl.
global record NullDozzerStorePerformance
	record Train
		length : number
		--- Fully loaded, in the units the vehicle store uses.
		weight : number
		power : number
		tractiveEffort : number
		topSpeed : number
		rollingFriction : number
	end

	--- A train's figures as the vehicle store computes them for its rating.
	trainOf : function(tv : Engine.Component.TransportVehicle) : Train
	--- Performance rating a train needs to hold full speed on the gradient
	--- ("Mediocre", "Good" or "Excellent"); nil if no rating is enough.
	ratingFor : function(gradient : number) : string
	--- Speed the train holds on the gradient; 0 if it lacks the power to climb
	--- it, nil if the train has no power figures (e.g. no locomotive).
	speedOn : function(train : Train, gradient : number) : number
end
