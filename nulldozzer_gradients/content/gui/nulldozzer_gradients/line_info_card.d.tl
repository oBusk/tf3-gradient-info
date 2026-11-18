--- The "Line info" card shown in entity windows (line window, train window).
global record NullDozzerLineInfoCard
	--- One figure: an icon with a short value below it, and the full text as tooltip.
	record Cell
		icon : string
		label : string
		tooltip : string
	end

	record Summary
		cells : {Cell}
		--- Shown instead of the cells when there are none, such as why.
		note : string
	end

	--- Registers a recipe showing the summary `summaryFor` returns for an entity.
	--- It is computed once per opened window; reopen it to see changes.
	registerSummary : function(name : string, summaryFor : function(entity : Engine.Entity) : Summary) : Recipe<Engine.Entity>
	--- Round trip length, stops and average speed, for both windows.
	routeCells : function(lineEntity : Engine.Entity, info : NullDozzerLineClimb.LineInfo) : {Cell}
	--- The steepest climb, with the Performance rating it requires; each of
	--- `details` is added to the tooltip on a line of its own.
	slopeCell : function(climb : NullDozzerClimbWindow.Climb, details? : {string}) : Cell
	--- The card, for a plugin of an entity window extension point.
	Card : function(params : EowExtensionUtil.IEowWidgetsExtensionParams, localKey : string, summary : Recipe<Engine.Entity>) : TreeNodeId

	--- Icons from the base game for the cells.
	ICON_LENGTH : string
	ICON_STOPS : string
	ICON_SPEED : string
	ICON_SLOPE : string
end
