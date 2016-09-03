var addSuggestionsToSpotlight = function(){
	var recordAll = {
        "label": "Record all membrane potentials",
        "actions": [
            "var instances=Instances.getInstance(GEPPETTO.ModelFactory.getAllPotentialInstancesEndingWith('.v'));",
            "GEPPETTO.ExperimentsController.watchVariables(instances,true);"
        ],
        "icon": "fa-dot-circle-o"
    };
	
	var recordSoma = {
	        "label": "Record all membrane potentials at soma",
	        "actions": [
	            "var instances=Instances.getInstance(GEPPETTO.ModelFactory.getAllPotentialInstancesEndingWith('_0.v'));",
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
	
	GEPPETTO.Spotlight.addSuggestion(recordSoma, GEPPETTO.Resources.RUN_FLOW);
	GEPPETTO.Spotlight.addSuggestion(recordAll, GEPPETTO.Resources.RUN_FLOW);
	GEPPETTO.Spotlight.addSuggestion(lightUpSample, GEPPETTO.Resources.PLAY_FLOW);
};

var executeOnSelection = function(callback) {
	if (GEPPETTO.ModelFactory.geppettoModel.neuroml.cell){
		var csel = G.getSelection()[0];
		if (typeof csel !== 'undefined') {
			callback(csel);
		} else {
			G.addWidget(1).setMessage('No cell selected! Please select one of the cells and click here for information on its properties.').setName('Warning Message');
		}
	}
};
var showConnectivityMatrix = function(instance){
	loadConnections();
	if (GEPPETTO.ModelFactory.geppettoModel.neuroml.projection == undefined){
		G.addWidget(1).setMessage('No connection found in this network').setName('Warning Message');
	}else{
		G.addWidget(6).setData(instance,
				{linkType:
					function(c){
						if (GEPPETTO.ModelFactory.geppettoModel.neuroml.synapse != undefined){
							var synapseType = GEPPETTO.ModelFactory.getAllVariablesOfType(c.getParent(),GEPPETTO.ModelFactory.geppettoModel.neuroml.synapse)[0];
							if(synapseType != undefined){
								return synapseType.getId();
							}
						}
						return c.getName().split("-")[0];
					}
				}).setName('Connectivity Widget on network ' + instance.getId()).configViaGUI();
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
		var tv = initialiseTreeWidget('Inputs on ' + csel.getId(), widthScreen - marginLeft - defaultWidgetWidth, marginTop);
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

var customHandler = function(node, path, widget) {
    var n;
    try {
        n = eval(path);
    } catch (ex) {
        node = undefined;
    }

    var metaType = n.getMetaType();
    if (metaType == GEPPETTO.Resources.VARIABLE_NODE) {
    	//A plot function inside a channel
        G.addWidget(Widgets.PLOT).plotFunctionNode(n);
    } else if (metaType == GEPPETTO.Resources.VISUAL_GROUP_NODE) {
    	//A visual group
        n.show(true);
    } else if (metaType == GEPPETTO.Resources.COMPOSITE_TYPE_NODE) {
    	//Another composite
        var target = widget;
        if (GEPPETTO.isKeyPressed("meta")) {
            target = G.addWidget(1).addCustomNodeHandler(customHandler, 'click');
        }
        target.setName('Information for ' + n.getId()).setData(n,[GEPPETTO.Resources.HTML_TYPE]);
   }

};


var showSelection = function(csel) {
	if(mainPopup==undefined){
		mainPopup=G.addWidget(1).addCustomNodeHandler(customHandler, 'click').setPosition(95, 140);
	}
    mainPopup.setName("Cell Information for " + csel.getType().getId()).setData(csel.getType(),[GEPPETTO.Resources.HTML_TYPE]);
};


// Commands
initialiseControlPanel();
addSuggestionsToSpotlight();