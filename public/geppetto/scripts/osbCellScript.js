// GEPPETTO SCRIPT FOR VISUALISING CHANNELS IN OSB
var widthScreen = this.innerWidth;
var heightScreen = this.innerHeight;
var marginTop = 10;
var marginRight = 10;
var marginBottom = 50;

var tvWidth = 500;
var tvHeight = 350;

var tvPosX = widthScreen - tvWidth - marginRight;
var tvPosY = marginTop;

var tvPosX2 = widthScreen - tvWidth - marginRight;
var tvPosY2 = 2 * marginTop + tvHeight;

// Retrieve model tree
$ENTER_ID.electrical.getModelTree();

// Adding Scatter3d 1
var treeVisualiserDAT1 = G.addWidget(3);
treeVisualiserDAT1.setData($ENTER_ID.electrical.ModelTree);
treeVisualiserDAT1.setSize(tvHeight,tvWidth);
treeVisualiserDAT1.setPosition(tvPosX,tvPosY);
treeVisualiserDAT1.setName("Cell Model - $ENTER_ID");
treeVisualiserDAT1.toggleFolder($ENTER_ID.electrical.ModelTree.getChildren()[0]);

//Adding Scatter3d 1
var treeVisualiserDAT2 = G.addWidget(3);
treeVisualiserDAT2.setData($ENTER_ID.electrical.VisualizationTree, {expandNodes: true});
treeVisualiserDAT2.setSize(tvHeight,tvWidth);
treeVisualiserDAT2.setPosition(tvPosX2,tvPosY2);
treeVisualiserDAT2.setName("Visualization - $ENTER_ID");

//Move cell to the left
G.incrementCameraPan(-0.15, 0);