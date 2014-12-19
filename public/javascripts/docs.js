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
			enableDocSection($(this).attr("href"));
			//Update url
			if(history.pushState) {history.pushState(null, null, $(this).attr('href'));}
			event.preventDefault();
		}
	);

	//Capture click event when a section link is found
	$(document).on('click', 'a[target="_blank"]', function(event) {
	    var newUrl = $(this).attr("href");
		if (newUrl.indexOf("#") != -1){
			var oldUrl = window.location.href.split(location.hash||"#")[0];
			if (newUrl.split("#")[0] == oldUrl){
				event.preventDefault();
				$('a[href="#'+newUrl.split("#")[1]+'"]').trigger("click");
			}
		}
	});

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
	else{
		$("#docContainer #project_overview_list a").first().trigger("click");
	}
	


});