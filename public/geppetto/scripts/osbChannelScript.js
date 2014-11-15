// GEPPETTO SCRIPT FOR VISUALISING CHANNELS IN OSB

// Retrieve model tree
$ENTER_ID.electrical.getModelTree();

// Adding Scatter3d 1
G.addWidget(3);
TreeVisualiserDAT1.setData($ENTER_ID.electrical.ModelTree.Summary, {expandNodes: true});

// Retrieve function nodes from model tree summary
var nodes = Simulation.searchNodeByMetaType($ENTER_ID.electrical.ModelTree.Summary, "FunctionNode", G.plotFunctionNode);

// Create a plot widget for every function node with plot metadata information
//TODO: This needs to be changed once "addWidget" returns the widget just created
for (var i = 0; i<nodes.length; i++){if (nodes[i].getPlotMetadata()!=undefined){G.addWidget(Widgets.PLOT); var plotObject = eval("Plot" + (i + 1)); plotObject.plotFunctionNode(nodes[i]); plotObject.setSize(200,450);}}