global record NullDozzerNetworkScan
	enum Kind
		"track"
		"road"
	end

	enum Structure
		"ground"
		"bridge"
		"tunnel"
	end

	record Piece
		entity : Engine.Entity
		kind : Kind
		structure : Structure
		--- Height change between the ends over the horizontal length, like the build tool.
		averageGradient : number
		--- Length along the piece, ignoring height.
		horizontalLength : number
	end

	--- Every track or road segment on the map whose kind is in kinds. Results are
	--- kept between calls: only segments that are new or changed are read again.
	current : function(kinds : {Kind : boolean}) : {Piece}
	--- The piece's lanes as they are now: a track's one, or a road's driving lanes.
	--- Use them at once and keep the network in a local while doing so: geometry
	--- kept to a later frame may point at freed engine memory. nil if the piece is gone.
	lanesOf : function(piece : Piece) : {EdgeGeometry}, Engine.Component.TransportNetwork
	--- The piece's gradient every 4 m along its first lane. The last few are kept.
	profileOf : function(piece : Piece) : NullDozzerEdgeProfile.Profile
end
