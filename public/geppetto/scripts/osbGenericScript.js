// GEPPETTO SCRIPT FOR VISUALISING CHANNELS IN OSB
var plotMaxWidth = 450;
var plotMinWidth = 250;
var plotMaxMinHeight = 200;
var elementMargin = 20;

var realHeightScreen = heightScreen - marginTop - marginBottom;
var realWidthScreen = widthScreen - marginRight - marginLeft - defaultWidgetWidth - elementMargin;

// Adding TreeVisualiserDAT Widget for Model Tree
var treeVisualiserDAT1 = initialiseTreeWidget("Model - $ENTER_ID", marginLeft, marginTop);

if (typeof $ENTER_ID.electrical.ModelTree.Summary !== 'undefined') {
	treeVisualiserDAT1.setData($ENTER_ID.electrical.ModelTree, {
		expandNodes : true
	});
	generatePlotForFunctionNodes();
} else {
	treeVisualiserDAT1.registerEvent(Events.ModelTree_populated, function() {
		treeVisualiserDAT1.setData($ENTER_ID.electrical.ModelTree, {
			expandNodes : true
		});
		generatePlotForFunctionNodes();
		treeVisualiserDAT1.unregisterEvent(Events.ModelTree_populated);
	});
	// Retrieve model tree
	$ENTER_ID.electrical.getModelTree();
}

//Adding TreeVisualiserDAT Widget for Visualization Tree
if ($ENTER_ID.electrical.VisualizationTree.getChildren().length > 0){
	var treeVisualiserDAT2 = initialiseTreeWidget("Visual aspects - $ENTER_ID", widthScreen - marginLeft - defaultWidgetWidth, marginTop);
	treeVisualiserDAT2.setData($ENTER_ID.electrical.VisualizationTree, {
		expandNodes : true
	});
}