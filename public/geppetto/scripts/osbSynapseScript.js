// GEPPETTO SCRIPT FOR VISUALISING CHANNELS IN OSB
var plotMaxWidth = 450;
var plotMinWidth = 250;
var plotMaxMinHeight = 200;
var elementMargin = 20;

var realHeightScreen = heightScreen - marginTop - marginBottom;
var realWidthScreen = widthScreen - marginRight - marginLeft - defaultWidgetWidth - elementMargin;

var generatePlotForFunctionNodes = function() {
	// Retrieve function nodes from model tree summary
	var nodes = $ENTER_ID.electrical.ModelTree.Summary.getSubNodesOfMetaType("FunctionNode");
	
	// Create a plot widget for every function node with plot metadata
	// information

	// Generate dimensions depending on number of nodes and iframe size
	var plottableNodes = [];
	for ( var nodesIndex in nodes) {
		if (nodes[nodesIndex].getPlotMetadata() != undefined && !nodes[nodesIndex].getExpression().startsWith('org.neuroml.export.info')) {
			plottableNodes.push(nodes[nodesIndex]);
		}
	}

	var plotHeight = realHeightScreen / plottableNodes.length;
	var plotLayout = [];
	if (plotHeight < plotMaxMinHeight) {
		var plotHeight = plotMaxMinHeight;
		var plotWidth = realWidthScreen / 2;
		if (plotWidth < plotMinWidth) {
			plotWidth = plotMinWidth;
		}
		for ( var plottableNodesIndex in plottableNodes) {
			if (plottableNodesIndex % 2 == 0) {
				plotLayout.push({
					'posX' : widthScreen - plotWidth - marginRight,
					'posY' : (plotHeight + elementMargin) * Math.floor(plottableNodesIndex / 2) + marginTop
				});
			} else {
				plotLayout.push({
					'posX' : widthScreen - plotWidth - marginRight - (plotWidth + elementMargin),
					'posY' : (plotHeight + elementMargin) * Math.floor(plottableNodesIndex / 2) + marginTop
				});
			}
		}
	} else {
		var plotHeight = plotMaxMinHeight;
		var plotWidth = plotMaxWidth;
		for ( var plottableNodesIndex in plottableNodes) {
			plotLayout.push({
				'posX' : widthScreen - plotWidth - marginRight,
				'posY' : (plotHeight + elementMargin) * plottableNodesIndex	+ marginTop
			});
		}
	}

	for ( var plottableNodesIndex in plottableNodes) {
		var plotObject = G.addWidget(Widgets.PLOT);
		plotObject.plotFunctionNode(plottableNodes[plottableNodesIndex]);
		plotObject.setSize(plotHeight, plotWidth);
		plotObject.setPosition(plotLayout[plottableNodesIndex].posX, plotLayout[plottableNodesIndex].posY);
	}
};

// Adding TreeVisualiserDAT Widget
var treeVisualiserDAT1 = initialiseTreeWidget("Synapse - $ENTER_ID", marginLeft, marginTop);

if (typeof $ENTER_ID.electrical.ModelTree.Summary !== 'undefined') {
	treeVisualiserDAT1.setData($ENTER_ID.electrical.ModelTree.Summary, {
		expandNodes : true
	});
	generatePlotForFunctionNodes();
} else {
	treeVisualiserDAT1.registerEvent(Events.ModelTree_populated, function() {
		treeVisualiserDAT1.setData($ENTER_ID.electrical.ModelTree.Summary, {
			expandNodes : true
		});
		generatePlotForFunctionNodes();
		treeVisualiserDAT1.unregisterEvent(Events.ModelTree_populated);
	});
	// Retrieve model tree
	$ENTER_ID.electrical.getModelTree();
}
