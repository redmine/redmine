jQuery(function()
{
	// Show/hide sections in doc
	function enableDocSection(sectionId){
		$("#project_overview_sections section").hide();
		$(sectionId).show();
		window.scrollTo(0,0);
	}
	
	//	Show/hide sections when section click in side menu
	$("#docContainer #project_overview_list a").click(
		function(event){
			enableDocSection($(this).attr("href").substring());
			event.preventDefault();
		}
	);

	//Check if url points to a specific section 
	var a = location.href.split("#");
	if ( a.length > 1){
		enableDocSection("#"+a[1]);
		
		setTimeout(function() {
		  if (location.hash) {
		    window.scrollTo(0, 0);
		  }
		}, 1);
	}
	


});