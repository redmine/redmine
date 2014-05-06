jQuery(function()
{
	console.log("Initializing OMV Js");

});

function removeSpace(str)
{
	return str.replace(/\s/g, '');
}

function toTitleCase(str)
{
    return str.replace(/\w\S*/g, function(txt){return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();});
}

// This method adds filtering abilities to a text input and a linked list
function addExpectedFields(expectedFieldName)
{
	console.log("Change on expected fields");
	var td = $("#expectedFields");
	var tdContent = '';
	var expectedType = expectedAnalyzerOutputs["optional"][expectedFieldName];
	if (expectedType == '//num'){
		tdContent = '<input id="' + removeSpace(expectedFieldName) + '" data-name="' + expectedFieldName + '" type="textfield" class="expectedOutputs">';
	}
	else if (expectedType == '//any') {
		tdContent = '<input id="' + removeSpace(expectedFieldName) + '" data-name="' + expectedFieldName + '" type="textfield" class="expectedOutputs">';
	}
	else{
		if (expectedType["type"] == '//rec') {
			for (var key in expectedType["required"]){
				tdContent += '<label class="control-label" for="' + removeSpace(key) + '">' + toTitleCase(key) + '</label> ' +
				'<input id="' + removeSpace(key) + '" data-name="' + key + '" type="textfield" class="expectedOutputs"><br>';
			}
		}
		else if (expectedType["type"] == '//arr') {
			tdContent = '<input id="' + removeSpace(expectedFieldName) + '" data-name="' + key + '" type="textfield"  class="expectedOutputs">';
		}
	}
	
	if (tdContent != ''){
		tdContent += '<a href="#" id="addExpectedOutputLink"><icon class="icon-plus-sign"></icon></a>';
	}
	
	td.html(tdContent);
	td.show();
	
	$('#addExpectedOutputLink').click(function(){ addExpectedOutput(); return false; });
}

function addExpectedOutput(){
	var expectedOutput = {};
	var expectedOutputLabel = $("#expected").val();
	var expectedOutputValue = {};
	var expectedTableBodyContent = '<tr><td>'+expectedOutputLabel+'</td><td>';
	$(".expectedOutputs").each(function(){
		expectedOutputValue[$(this).id] = {'value': $(this).val(), 'name': $(this).data('name')};
		expectedTableBodyContent += $(this).data('name') + ': ' + $(this).val() + ' | ';
	});
	expectedTableBodyContent += '</td></tr>';
	expectedOutput[expectedOutputLabel] = expectedOutputValue; 
	
	console.log('expectedOutput');
	console.log(expectedOutput);

	$("#expectedTableBody").append(expectedTableBodyContent);	
	
	
}
