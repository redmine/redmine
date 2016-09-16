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
	var posX = 90;
	var posY = 5;
	var barDef = $CONTROL_PANEL;
	var target = G.addWidget(7).renderBar('OSB Control Panel', barDef['OSB Control Panel']);
	target.setPosition(posX, posY).showTitleBar(false);
	$("#" + target.id).find(".btn-lg").css("font-size","15px");
};


var mainPopup=undefined;


	
var showModelDescription = function(model){
	if(mainPopup==undefined || mainPopup.destroyed){
		mainPopup=G.addWidget(1).setName('Model Description - ' + model.getName()).addCustomNodeHandler(customHandler, 'click').setPosition(95,140);
	}
	mainPopup.setData(model,[GEPPETTO.Resources.HTML_TYPE]);	
};

var getMainType = function(){
	return (typeof($ENTER_ID) === 'undefined')?GEPPETTO.ModelFactory.geppettoModel.neuroml.$ENTER_ID:$ENTER_ID.getType();
};
