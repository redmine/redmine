// GEPPETTO SCRIPT FOR VISUALISING CHANNELS IN OSB
var plotMaxWidth = 450;
var plotMinWidth = 250;
var plotMaxMinHeight = 200;
var elementMargin = 20;

var realHeightScreen = heightScreen - marginTop - marginBottom;
var realWidthScreen = widthScreen - marginRight - marginLeft - defaultWidgetWidth - elementMargin;

// Adding TreeVisualiserDAT Widget for Model Tree
var treeVisualiserDAT1 = initialiseTreeWidget("Model - $ENTER_ID", marginLeft, marginTop);
treeVisualiserDAT1.setData(Model.neuroml.$ENTER_ID, {
	expandNodes : true
});
generatePlotForFunctionNodes();


//Adding TreeVisualiserDAT Widget for Visualization Tree
if (Model.neuroml.$ENTER_ID.getVisualType()){
	var tv = initialiseTreeWidget("Visual aspects - $ENTER_ID", widthScreen - marginLeft - defaultWidgetWidth, marginTop);
	tv.setData(Model.neuroml.$ENTER_ID.getVisualType(), {
		expandNodes : true
	});
}