// GEPPETTO SCRIPT FOR VISUALISING ANY KIND OF MODEL IN OSB
var mdPopupWidth = 350;
var mdPopupHeight = 400;
var elementMargin = 20;

var realHeightScreen = heightScreen - marginTop - marginBottom;
var realWidthScreen = widthScreen - marginRight - marginLeft - defaultWidgetWidth - elementMargin;

showModelDescription((typeof($ENTER_ID) === 'undefined')?GEPPETTO.ModelFactory.geppettoModel.neuroml.$ENTER_ID:$ENTER_ID.getType());

G.setCameraPosition(-60,-250,370);