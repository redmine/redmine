// GEPPETTO SCRIPT FOR VISUALISING CHANNELS IN OSB

var widthScreen = this.innerWidth;
var heightScreen = this.innerHeight;
var marginLeft = 100;
var marginTop = 60;
var marginRight = 10;
var marginBottom = 50;

var tvWidth = 510;
var tvHeight = 500;
var tvPosX = marginLeft;
var tvPosY = marginTop;

var plotMaxWidth = 450;
var plotMinWidth = 250;
var plotMaxMinHeight = 200;
var elementMargin = 20;

var realHeightScreen = heightScreen - marginTop - marginBottom;
var realWidthScreen = widthScreen - marginRight - marginLeft - tvWidth - elementMargin;

// Retrieve model tree
$ENTER_ID.electrical.getModelTree();

// Adding Scatter3d 1
G.addWidget(3);
TreeVisualiserDAT1.setData($ENTER_ID.electrical.ModelTree.Summary, {expandNodes: true});
TreeVisualiserDAT1.setSize(tvHeight,tvWidth);
TreeVisualiserDAT1.setPosition(tvPosX,tvPosY);
TreeVisualiserDAT1.setName("Channel - $ENTER_ID");

// Retrieve function nodes from model tree summary
var nodes = Simulation.searchNodeByMetaType($ENTER_ID.electrical.ModelTree.Summary, "FunctionNode", G.plotFunctionNode);

// Create a plot widget for every function node with plot metadata information

// Generate dimensions depending on number of nodes and iframe size 
//TODO: This needs to be changed once "addWidget" returns the widget just created

var plottableNodes = [];
for (var nodesIndex in nodes){if (nodes[nodesIndex].getPlotMetadata()!=undefined){plottableNodes.push(nodes[nodesIndex]);}}

var plotHeight = realHeightScreen / plottableNodes.length;
var plotLayout = [];
if (plotHeight < plotMaxMinHeight){var plotHeight = plotMaxMinHeight;var plotWidth = realWidthScreen / 2;if (plotWidth < plotMinWidth){plotWidth = plotMinWidth;}for (var plottableNodesIndex in plottableNodes){if (plottableNodesIndex % 2 == 0){plotLayout.push({'posX':widthScreen - plotWidth - marginRight, 'posY':(plotHeight + elementMargin)*Math.floor(plottableNodesIndex/2) + marginTop});}else{plotLayout.push({'posX':widthScreen - plotWidth - marginRight - (plotWidth + elementMargin), 'posY':(plotHeight + elementMargin)*Math.floor(plottableNodesIndex/2) + marginTop});}}}else{var plotHeight = plotMaxMinHeight;var plotWidth = plotMaxWidth;for (var plottableNodesIndex in plottableNodes){plotLayout.push({'posX':widthScreen - plotWidth - marginRight, 'posY':(plotHeight + elementMargin)*plottableNodesIndex + marginTop});}}

for (var plottableNodesIndex in plottableNodes){G.addWidget(Widgets.PLOT); var plotObject = eval("Plot" + (parseInt(plottableNodesIndex) + 1)); plotObject.plotFunctionNode(plottableNodes[plottableNodesIndex]); plotObject.setSize(plotHeight, plotWidth);plotObject.setPosition(plotLayout[plottableNodesIndex].posX, plotLayout[plottableNodesIndex].posY);}
