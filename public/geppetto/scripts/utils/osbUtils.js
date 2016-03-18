var widthScreen = this.innerWidth;
var heightScreen = this.innerHeight;

var marginLeft = 100;
var marginTop = 70;
var marginRight = 10;
var marginBottom = 50;

var defaultWidgetWidth = 450;
var defaultWidgetHeight = 500;

var initialiseTreeWidget = function(title, posX, posY, widgetWidth, widgetHeight) {
	widgetWidth = typeof widgetWidth !== 'undefined' ? widgetWidth : defaultWidgetWidth;
	widgetHeight = typeof widgetHeight !== 'undefined' ? widgetHeight : defaultWidgetHeight;
	
	var tv = G.addWidget(3);
	tv.setSize(widgetHeight, widgetWidth);
	tv.setName(title);
	tv.setPosition(posX, posY);
	return tv;
};

var initialiseControlPanel = function(){
	var posX = 88;
	var posY = 5;
	var barDef = $CONTROL_PANEL;
	G.addWidget(7).renderBar('OSB Control Panel', barDef['OSB Control Panel']);
	ButtonBar1.setPosition(posX, posY);
};

var showModelDescription = function(model){
	var mdPopup = G.addWidget(1).setName('Model Description - ' + model.getName());
	mdPopup.addCustomNodeHandler(function(node){G.addWidget(3).setData(node);}, 'click');
	mdPopup.setHTML(GEPPETTO.ModelFactory.getAllVariablesOfMetaType(model,GEPPETTO.Resources.HTML_TYPE)[0]);	
};
