// Check if there is one single cell and select it so that TreeVisualisers work from the beginning 
var population = GEPPETTO.ModelFactory.getAllTypesOfType(GEPPETTO.ModelFactory.geppettoModel.neuroml.population);
// If there are two cells -> SuperType and cell
if (population.length == 2){
	for (var i = 0; i<population.length; i++){
		if (typeof population[i].getSize === "function" && population[i].getSize() == 1){
			population[i].select();
		}
	}
}