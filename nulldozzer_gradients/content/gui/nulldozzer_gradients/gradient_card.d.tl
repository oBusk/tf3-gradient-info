--- The "Gradient" card shown in entity windows (line window, train window).
global record NullDozzerGradientCard
	--- Registers a recipe showing the lines `linesFor` returns for an entity.
	--- They are computed once per opened window; reopen it to see changes.
	registerSummary : function(name : string, linesFor : function(entity : Engine.Entity) : {string}) : Recipe<Engine.Entity>
	--- The card, for a plugin of an entity window extension point.
	Card : function(params : EowExtensionUtil.IEowWidgetsExtensionParams, localKey : string, summary : Recipe<Engine.Entity>) : TreeNodeId
end
