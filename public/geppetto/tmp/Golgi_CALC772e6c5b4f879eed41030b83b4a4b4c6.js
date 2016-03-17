var widthScreen = this.innerWidth;var heightScreen = this.innerHeight;var marginLeft = 100;var marginTop = 70;var marginRight = 10;var marginBottom = 50;var defaultWidgetWidth = 450;var defaultWidgetHeight = 500;var initialiseTreeWidget = function(title, posX, posY, widgetWidth, widgetHeight) {	widgetWidth = typeof widgetWidth !== 'undefined' ? widgetWidth : defaultWidgetWidth;	widgetHeight = typeof widgetHeight !== 'undefined' ? widgetHeight : defaultWidgetHeight;		var tv = G.addWidget(3);	tv.setSize(widgetHeight, widgetWidth);	tv.setName(title);	tv.setPosition(posX, posY);	return tv;};var initialiseControlPanel = function(){	var posX = 88;	var posY = 5;	var barDef = {    "OSB Control Panel": {        "Network Info": {            "Connectivity": {                "actions": [                	"showConnectivityMatrix(Golgi_CALC)"                ],                "icon": "gpt-make-group",                "label": "Connectivity",                "tooltip": "Loads the connectivity matrix widget"            },            "Model Description": {                "actions": [                    "var mdPopup = G.addWidget(1).setName('Model Description - Golgi_CALC');mdPopup.addCustomNodeHandler(function(node){G.addWidget(3).setData(node);}, 'click');mdPopup.setHTML(GEPPETTO.ModelFactory.getAllVariablesOfMetaType((Golgi_CALC == undefined)?GEPPETTO.ModelFactory.geppettoModel.neuroml.Golgi_CALC:Golgi_CALC.getType(),GEPPETTO.Resources.HTML_TYPE)[0]);"                ],                "icon": "gpt-pyramidal-cell",                "label": "Model Description",                "tooltip": "Information on the model"            },            "Inputs": {                "actions": [                    "showInputTreeView(Golgi_CALC)"                ],                "icon": "gpt-inputs",                "label": "Inputs",                "tooltip": "Inputs present on the network"            }        },        "Cell Info": {            "Cell": {                "actions": [                    "executeOnSelection(showSelection)"                ],                "icon": "gpt-pyramidal-cell",                "label": "Cell Info",                "tooltip": "Information on the selected cell"            },            "Channels": {                "actions": [                    "executeOnSelection(showChannelTreeView)"                ],                "icon": "gpt-ion-channel",                "label": "Channels",                "tooltip": "Ion channels present on the selected cell"            },            "CellVisual": {		      "actions": [		      	"executeOnSelection(showVisualTreeView)"		      ],		      "icon": "gpt-pyramidal-cell",		      "label": "Cell Visual",		      "tooltip": "Visual information on selected cell"		    }        }    }};	G.addWidget(7).renderBar('OSB Control Panel', barDef['OSB Control Panel']);	ButtonBar1.setPosition(posX, posY);};var addSuggestionsToSpotlight = function(){	var recordSample = {        "label": "Record all membrane potentials",        "actions": [            "var instances=Instances.getInstance(GEPPETTO.ModelFactory.getAllPotentialInstancesEndingWith('.v'));",            "GEPPETTO.ExperimentsController.watchVariables(instances,true);"        ],        "icon": "fa-dot-circle-o"    };		var lightUpSample = {        "label": "Link morphology colour to recorded membrane potentials",        "actions": [            "G.addBrightnessFunctionBulkSimplified(GEPPETTO.ModelFactory.instances.getInstance(GEPPETTO.ModelFactory.getAllPotentialInstancesEndingWith('.v'),false), function(x){return (x+0.07)/0.1;});"        ],        "icon": "fa-lightbulb-o"    };		GEPPETTO.Spotlight.addSuggestion(recordSample, GEPPETTO.Resources.RUN_FLOW);	GEPPETTO.Spotlight.addSuggestion(lightUpSample, GEPPETTO.Resources.PLAY_FLOW);};var executeOnSelection = function(callback) {	var csel = G.getSelection()[0];	if (typeof csel !== 'undefined') {		callback(csel);	} else {		G.addWidget(1).setMessage('No cell selected! Please select one of the cells and click here for information on its properties.').setName('Warning Message');	}};var showConnectivityMatrix = function(instance){	if (GEPPETTO.ModelFactory.geppettoModel.neuroml.projection == undefined){		G.addWidget(1).setMessage('No connection found in this network').setName('Warning Message');	}else{		G.addWidget(6).setData(instance,				{linkType:					function(c){						if (GEPPETTO.ModelFactory.geppettoModel.neuroml.synapse != undefined){							var synapseType = GEPPETTO.ModelFactory.getAllVariablesOfType(c.getParent(),GEPPETTO.ModelFactory.geppettoModel.neuroml.synapse)[0];							if(synapseType != undefined){								return synapseType.getId();							}						}						return c.getName().split("-")[0];					}				}).setName('Connectivity Widget on network ' + Golgi_CALC.getName());	}};var showChannelTreeView = function(csel) {	if (GEPPETTO.ModelFactory.geppettoModel.neuroml.ionChannel){		var tv = initialiseTreeWidget('Ion Channels on cell ' + csel.getName(), widthScreen - marginLeft - defaultWidgetWidth, marginTop);				var ionChannel = GEPPETTO.ModelFactory.getAllTypesOfType(GEPPETTO.ModelFactory.geppettoModel.neuroml.ionChannel);		var ionChannelFiltered = [];		for (ionChannelIndex in ionChannel){			var ionChannelItem = ionChannel[ionChannelIndex];			if (ionChannelItem.getId()!='ionChannel'){				ionChannelFiltered.push(ionChannelItem);			}		}		tv.setData(ionChannelFiltered);	}};var showInputTreeView = function(csel) {	if (GEPPETTO.ModelFactory.geppettoModel.neuroml.pulseGenerator){		var tv = initialiseTreeWidget('Inputs on ' + csel.getName(), widthScreen - marginLeft - defaultWidgetWidth, marginTop);		var pulseGenerator = GEPPETTO.ModelFactory.getAllTypesOfType(GEPPETTO.ModelFactory.geppettoModel.neuroml.pulseGenerator);		var pulseGeneratorFiltered = [];		for (pulseGeneratorIndex in pulseGenerator){			var pulseGeneratorItem = pulseGenerator[pulseGeneratorIndex];			if (pulseGeneratorItem.getId()!='pulseGenerator'){				pulseGeneratorFiltered.push(pulseGeneratorItem);			}		}		tv.setData(pulseGeneratorFiltered);	}};var showVisualTreeView = function(csel) {	var visualWidgetWidth = 350;	var visualWidgetHeight = 400;	var tv = initialiseTreeWidget('Visual information on cell ' + csel.getName(), widthScreen - marginLeft - visualWidgetWidth, heightScreen - marginBottom - visualWidgetHeight, visualWidgetWidth, visualWidgetHeight);	tv.setData(csel.getType().getVisualType(), {		expandNodes : true	});};var showSelection = function(csel) {	var visualWidgetWidth = 350;	var visualWidgetHeight = 400;	var tv = initialiseTreeWidget('Visual information on cell ' + csel.getName(), widthScreen - marginLeft - visualWidgetWidth, heightScreen - marginBottom - visualWidgetHeight, visualWidgetWidth, visualWidgetHeight);	tv.setData(csel.getType(), {		expandNodes : true	});};initialiseControlPanel();addSuggestionsToSpotlight();var mdPopupWidth = 350;var mdPopupHeight = 400;var elementMargin = 20;var realHeightScreen = heightScreen - marginTop - marginBottom;var realWidthScreen = widthScreen - marginRight - marginLeft - defaultWidgetWidth - elementMargin;var mdPopup = G.addWidget(1).setName("Model - Golgi_CALC").setPosition(marginLeft, marginTop).setSize(mdPopupHeight,mdPopupWidth);mdPopup.addCustomNodeHandler(function(node){G.addWidget(3).setData(node);}, 'click');mdPopup.setHTML(GEPPETTO.ModelFactory.getAllVariablesOfMetaType((typeof(Golgi_CALC) === 'undefined')?GEPPETTO.ModelFactory.geppettoModel.neuroml.Golgi_CALC:Golgi_CALC.getType(),GEPPETTO.Resources.HTML_TYPE)[0]);G.setCameraPosition(-60,-250,370);