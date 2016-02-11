var executeOnSelection = function(callback) {
	var csel = G.getSelection()[0];
	if (typeof csel !== 'undefined') {
		callback(csel);
	} else {
		G.addWidget(1).setMessage('No cell selected! Please select one of the cells and click here for information on its properties.').setName('Warning Message');
	}
};
var showSummaryTreeView = function(csel) {
	var tv = initialiseTreeWidget('Information on cell ' + csel.getName(), marginLeft, marginTop);
	if (typeof csel.electrical.ModelTree.Summary !== 'undefined') {
		tv.setData(csel.electrical.ModelTree.Summary.getChildren(), {
			expandNodes : true
		});
	} else {
		tv.registerEvent(Events.ModelTree_populated, function() {
			tv.setData(csel.electrical.ModelTree.Summary.getChildren(), {
				expandNodes : true
			});
			tv.unregisterEvent(Events.ModelTree_populated);
		});
		csel.electrical.getModelTree();
	}
};
var showChannelTreeView = function(csel) {
	if (GEPPETTO.ModelFactory.geppettoModel.neuroml.ionChannel){
		var tv = initialiseTreeWidget('Ion Channels on cell ' + csel.getName(), widthScreen - marginLeft - defaultWidgetWidth, marginTop);
		tv.setData(GEPPETTO.ModelFactory.getAllTypesOfType(GEPPETTO.ModelFactory.geppettoModel.neuroml.ionChannel));
	}
};

var showInputTreeView = function(csel) {
	if (GEPPETTO.ModelFactory.geppettoModel.neuroml.pulseGenerator){
		var tv = initialiseTreeWidget('Inputs on ' + csel.getName(), widthScreen - marginLeft - defaultWidgetWidth, marginTop);
		tv.setData(GEPPETTO.ModelFactory.getAllTypesOfType(GEPPETTO.ModelFactory.geppettoModel.neuroml.pulseGenerator));
	}
};

var showVisualTreeView = function(csel) {
	var visualWidgetWidth = 350;
	var visualWidgetHeight = 400;

	var tv = initialiseTreeWidget('Visual information on cell ' + csel.getName(), widthScreen - marginLeft - visualWidgetWidth, heightScreen - marginBottom - visualWidgetHeight, visualWidgetWidth, visualWidgetHeight);
	tv.setData(csel.getType().getVisualType(), {
		expandNodes : true
	});
};

var showSelection = function(csel) {
	var visualWidgetWidth = 350;
	var visualWidgetHeight = 400;

	var tv = initialiseTreeWidget('Visual information on cell ' + csel.getName(), widthScreen - marginLeft - visualWidgetWidth, heightScreen - marginBottom - visualWidgetHeight, visualWidgetWidth, visualWidgetHeight);
	tv.setData(csel.getType(), {
		expandNodes : true
	});
};
initialiseControlPanel();