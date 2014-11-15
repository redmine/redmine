// GEPPETTO SCRIPT FOR VISUALISING CHANNELS IN OSB

// Retrieve model tree
$ENTER_ID.electrical.getModelTree();

// Adding Scatter3d 1
G.addWidget(3);
TreeVisualiserDAT1.setData($ENTER_ID, {expandNodes: true});