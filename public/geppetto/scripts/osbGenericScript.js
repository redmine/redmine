// GEPPETTO SCRIPT FOR VISUALISING CHANNELS IN OSB

var widthScreen = this.innerWidth;
var heightScreen = this.innerHeight;
var marginLeft = 100;
var marginTop = 60;
var marginRight = 10;
var marginBottom = 50;

var tvWidth = 450;
var tvHeight = 510;
var tvPosX = widthScreen - tvWidth - marginRight;
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
TreeVisualiserDAT1.setSize(tvWidth,tvHeight);
TreeVisualiserDAT1.setPosition(tvPosX,tvPosY);
TreeVisualiserDAT1.setName("Model - $ENTER_ID");