// Check if there is one single cell and select it so that TreeVisualisers work from the beginning 
var cells = GEPPETTO.ModelFactory.getAllTypesOfType(GEPPETTO.ModelFactory.geppettoModel.neuroml.cell);
// If there are two cells -> SuperType and cell
if (cells.length == 2){
	$ENTER_ID.select();
}