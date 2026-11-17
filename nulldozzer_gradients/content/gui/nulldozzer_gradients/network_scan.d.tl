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
		profile : NullDozzerEdgeProfile.Profile
		-- The engine frees geometry that nothing references, so the network stays referenced with its lanes.
		network : Engine.Component.TransportNetwork
		lanes : {EdgeGeometry}
	end

	--- Every track or road segment on the map whose kind is in kinds.
	scanAll : function(kinds : {Kind : boolean}) : {Piece}
end
