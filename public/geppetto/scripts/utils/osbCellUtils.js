var addSuggestionsToSpotlight = function(){
	var recordSample = {
        "label": "Record all membrane potentials",
        "actions": [
            "var instances=Instances.getInstance(GEPPETTO.ModelFactory.getAllPotentialInstancesEndingWith('.v'));",
            "GEPPETTO.ExperimentsController.watchVariables(instances,true);"
        ],
        "icon": "fa-dot-circle-o"
    };
	
	var lightUpSample = {
        "label": "Link morphology colour to recorded membrane potentials",
        "actions": [
            "G.addBrightnessFunctionBulkSimplified(GEPPETTO.ModelFactory.instances.getInstance(GEPPETTO.ModelFactory.getAllPotentialInstancesEndingWith('.v'),false), function(x){return (x+0.07)/0.1;});"
        ],
        "icon": "fa-lightbulb-o"
    };
	
	GEPPETTO.Spotlight.addSuggestion(recordSample, GEPPETTO.Resources.RUN_FLOW);
	GEPPETTO.Spotlight.addSuggestion(lightUpSample, GEPPETTO.Resources.PLAY_FLOW);
};

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
		
		var ionChannel = GEPPETTO.ModelFactory.getAllTypesOfType(GEPPETTO.ModelFactory.geppettoModel.neuroml.ionChannel);
		var ionChannelFiltered = [];
		for (ionChannelIndex in ionChannel){
			var ionChannelItem = ionChannel[ionChannelIndex];
			if (ionChannelItem.getId()!='ionChannel'){
				ionChannelFiltered.push(ionChannelItem);
			}
		}
		tv.setData(ionChannelFiltered);
	}
};

var showInputTreeView = function(csel) {
	if (GEPPETTO.ModelFactory.geppettoModel.neuroml.pulseGenerator){
		var tv = initialiseTreeWidget('Inputs on ' + csel.getName(), widthScreen - marginLeft - defaultWidgetWidth, marginTop);
		var pulseGenerator = GEPPETTO.ModelFactory.getAllTypesOfType(GEPPETTO.ModelFactory.geppettoModel.neuroml.pulseGenerator);
		var pulseGeneratorFiltered = [];
		for (pulseGeneratorIndex in pulseGenerator){
			var pulseGeneratorItem = pulseGenerator[pulseGeneratorIndex];
			if (pulseGeneratorItem.getId()!='pulseGenerator'){
				pulseGeneratorFiltered.push(pulseGeneratorItem);
			}
		}
		tv.setData(pulseGeneratorFiltered);
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

// Commands
initialiseControlPanel();
addSuggestionsToSpotlight();