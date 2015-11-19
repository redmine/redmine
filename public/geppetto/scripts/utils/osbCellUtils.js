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
	var tv = initialiseTreeWidget('Ion Channels on cell ' + csel.getName(), widthScreen - marginLeft - defaultWidgetWidth, marginTop);
	if (typeof csel.electrical.ModelTree.Summary !== 'undefined') {
		tv.setData(csel.getSubNodesOfDomainType('IonChannel'), {
			labelName : 'id'
		});
	} else {
		tv.registerEvent(Events.ModelTree_populated, function() {
			tv.setData(csel.getSubNodesOfDomainType('IonChannel'), {
				labelName : 'id'
			});
			tv.unregisterEvent(Events.ModelTree_populated);
		});
		csel.electrical.getModelTree();
	}
};
var showVisualTreeView = function(csel) {
	var visualWidgetWidth = 350;
	var visualWidgetHeight = 400;

	var tv = initialiseTreeWidget('Visual information on cell ' + csel.getName(), widthScreen - marginLeft - visualWidgetWidth, heightScreen - marginBottom - visualWidgetHeight, visualWidgetWidth, visualWidgetHeight);
	tv.setData(csel.electrical.VisualizationTree, {
		expandNodes : true
	});
};
initialiseControlPanel();