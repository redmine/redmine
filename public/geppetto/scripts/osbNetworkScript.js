// GEPPETTO SCRIPT FOR VISUALISING CHANNELS IN OSB
var widthScreen = this.innerWidth;
var heightScreen = this.innerHeight;

var marginTop = 10;
var marginRight = 10;
var marginBottom = 50;

var connectivityWidth = 500;
var connectivityHeight = 400;

var connectivityPosX = widthScreen - connectivityWidth - marginRight;
var connectivityPosY = marginTop;

var tvWidth = 500;
var tvHeight = 300;

var tvPosX = widthScreen - tvWidth - marginRight;
var tvPosY = 2 * marginTop + connectivityHeight;

//Adding Network
var connectivity1 = G.addWidget(Widgets.CONNECTIVITY);
connectivity1.setData($ENTER_ID);
connectivity1.setName("Connectivity matrix");
connectivity1.setSize(connectivityHeight,connectivityWidth);
connectivity1.setPosition(connectivityPosX,connectivityPosY);

// Retrieve model tree
$ENTER_ID.getChildren()[1].electrical.getModelTree();

//Select entity
$ENTER_ID.getChildren()[1].select();

// Adding Scatter3d 1
var treeVisualiserDAT1 = G.addWidget(Widgets.TREEVISUALISERDAT);
treeVisualiserDAT1.setData($ENTER_ID.getChildren()[1].electrical.ModelTree.Summary);
treeVisualiserDAT1.setName("Cell - " + $ENTER_ID.getChildren()[1].getName());
treeVisualiserDAT1.setSize(tvHeight,tvWidth);
treeVisualiserDAT1.setPosition(tvPosX,tvPosY);
treeVisualiserDAT1.toggleFolder($ENTER_ID.getChildren()[1].electrical.ModelTree.Summary.getChildren()[0]);

//Move cell to the left
G.incrementCameraPan(-0.15, 0);