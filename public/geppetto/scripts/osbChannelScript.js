// GEPPETTO SCRIPT FOR VISUALISING CHANNELS IN OSB
var plotMaxWidth = 450;
var plotMinWidth = 250;
var plotMaxMinHeight = 200;
var elementMargin = 20;

var realHeightScreen = heightScreen - marginTop - marginBottom;
var realWidthScreen = widthScreen - marginRight - marginLeft - defaultWidgetWidth - elementMargin;

var generatePlotForFunctionNodes = function() {
	// Retrieve function nodes from model tree
	var nodes = GEPPETTO.ModelFactory.getAllVariablesOfMetaType(Model.neuroml.$ENTER_ID, GEPPETTO.Resources.DYNAMICS_TYPE, true);
	
	// Create a plot widget for every function node with plot metadata
	// information

	// Generate dimensions depending on number of nodes and iframe size
	var plottableNodes = [];
	for ( var nodesIndex in nodes) {
		if (nodes[nodesIndex].getInitialValues()[0].value.dynamics.functionPlot != undefined && !nodes[nodesIndex].getInitialValues()[0].value.dynamics.expression.expression.startsWith('org.neuroml.export.info')) {
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
var treeVisualiserDAT1 = initialiseTreeWidget("Channel - $ENTER_ID", marginLeft, marginTop);
treeVisualiserDAT1.setData(Model.neuroml.$ENTER_ID, {
	expandNodes : true
});
generatePlotForFunctionNodes();