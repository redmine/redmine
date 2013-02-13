jQuery(function()
{
	//**************
	//COMMON
	//**************
	var $window = jQuery(window);
	
	// -- SIDE BAR
	 setTimeout(function () {
	      $('.bs-docs-sidenav').affix({
	        offset: {
	          top: function () { return $window.width() <= 980 ? 290 : 210 }
	        , bottom: 270
	        }
	      })
	    }, 100)
	    
	// -- Bootstrap widget calls
	jQuery('.dropdown-toggle').dropdown();
	jQuery(".alert").alert();
	
	// -- Add bootstrap class to all the tables
	jQuery('table').addClass('table table-bordered');
	
	jQuery(":submit").addClass('btn');
	
	replaceIconWithFontAwesome();
	
	// make code pretty
    window.prettyPrint && prettyPrint();
    
	//**************
	//HEADER
	//**************
	jQuery("#header_menu > ul").addClass("pull-right");
	jQuery("#header_menu > ul").append('<li id="loggedelement"></li>');
	jQuery("#loggedas > a").appendTo("#loggedelement");
	jQuery("#loggedas").remove();
	
	
	//**************
	//EXPLORE PAGE
	//**************
	
	// -- Add filters
	setupFilter('#cellsfilter', '#cellslist');
	setupFilter('#groupsfilter', '#groupslist');
	setupFilter('#technologyfilter', '#technologylist');
	setupFilter('#peoplefilter', '#peoplelist');

	// -- Expands the first element of every list
	jQuery.each(jQuery(".projects-list"), function()
	{
		jQuery(this).find("a").first().click();
	});
	
	//**************
	//PROJECT PAGE
	//**************
	
	// -- Add actions menu
	jQuery("#menucontainer > ul").append('<li class="dropdown"><a class="dropdown-toggle" data-toggle="dropdown" href="#">Actions<b class="caret"></b></a><ul class="dropdown-menu" id="actionsmenu"></ul></li>');
	jQuery("#actionsmenu").append("<li><a href='javascript:showMenu();'>OSB 3D Explorer</a></li>");
	
	// -- Split the project name field in two in the title bar
	var splitProjectName = jQuery('#pname').html();
	if (splitProjectName != undefined)
	{

		splitProjectName = splitProjectName.split("-");
		jQuery('#pname').html(jQuery.trim(splitProjectName[0]) + " <small>" + jQuery.trim(splitProjectName[1]) + "</small>");

	}
	
	// -- Transforms redmine selected in bootstrap active flag
	jQuery("li > .selected").parent().addClass("active");
	
	// -- Builds the nav menu in the ovewview section
	jQuery("#project_overview_sections section").each(function(){
		var id=jQuery(this).attr("id");
		var name=jQuery(this).find(".page-header h1").html();
		jQuery("#project_overview_list").append("<li><a href='#"+id+"'><i class='icon-chevron-right'></i>"+name+"</a></li>");
	});
	
	jQuery('#project_overview_list li').click(function(e)
	{
		jQuery('#project_overview_list li').removeClass('active');
		
		var $this = jQuery(this);
		if (!$this.hasClass('active'))
		{
			$this.addClass('active');
		}
		
	});
	
	//draws the revision graph handler. this moved from _revision_graph since it needs to happen after the tabeles have been bootstraped
	revisionGraphHandler();

});

//This method adds filtering abilities to a text input and a linked list
function setupFilter(idFilter, idList)
{
	jQuery(idFilter).keyup(function()
	{
		var a = jQuery(this).val();
		if (a.length > 2)
		{
			// this finds all links in the list that contain the input,
			// and hide the ones not containing the input while showing the ones that do
			var containing = jQuery(idList + ' li').filter(function()
			{
				var regex = new RegExp('\\b' + a, 'i');
				return regex.test(jQuery('a', this).text());
			}).slideDown();
			jQuery(idList + ' li').not(containing).slideUp();
		}
		else
		{
			jQuery(idList + ' li').slideDown();
		}
	});
}


function replaceIconWithFontAwesome()
{

	jQuery("a.icon-add").removeClass("icon-add").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-edit").removeClass("icon-edit").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-copy").removeClass("icon-copy").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-duplicate").removeClass("icon-duplicate").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-del").removeClass("icon-del").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-move").removeClass("icon-move").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-save").removeClass("icon-save").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-cancel").removeClass("icon-cancel").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-multiple").removeClass("icon-multiple").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-folder").removeClass("icon-folder").prepend("<icon class='icon-folder-open-alt'/>");
	
	jQuery("a.open").removeClass("icon-folder").prepend("<icon class='icon-folder-open-alt'/>");
	
	jQuery("a.icon-package").removeClass("icon-package").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-user").removeClass("icon-user").prepend("<icon class='icon-user'/>");
	jQuery("a.icon-projects").removeClass("icon-projects").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-help").removeClass("icon-help").prepend("<icon class='icon-help'/>");
	jQuery("a.icon-attachment").removeClass("icon-attachment").prepend("<icon class='icon-attachment'/>");
	jQuery("a.icon-history").removeClass("icon-history").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-time").removeClass("icon-time").prepend("<icon class='icon-time'/>");
	jQuery("a.icon-time-add").removeClass("icon-time-add").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-stats").removeClass("icon-stats").prepend("<icon class='icon-bar-chart'/>");
	jQuery("a.icon-warning").removeClass("icon-warning").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-fav").removeClass("icon-fav").prepend("<icon class='icon-heart'/>");
	jQuery("a.icon-fav-off").removeClass("icon-fav-off").prepend("<icon class='icon-heart-empty'/>");
	jQuery("a.icon-reload").removeClass("icon-reload").prepend("<icon class='icon-repeat'/>");
	jQuery("a.icon-lock").removeClass("icon-lock").prepend("<icon class='icon-lock'/>");
	jQuery("a.icon-unlock").removeClass("icon-unlock").prepend("<icon class='icon-unlock'/>");
	jQuery("a.icon-checked").removeClass("icon-checked").prepend("<icon class='icon-check'/>");
	jQuery("a.icon-details").removeClass("icon-details").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-report").removeClass("icon-report").prepend("<icon class='icon-list-alt'/>");
	jQuery("a.icon-comment").removeClass("icon-comment").prepend("<icon class='icon-comment'/>");
	jQuery("a.icon-summary").removeClass("icon-summary").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-server-authentication").removeClass("icon-server-authentication").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-issue").removeClass("icon-issue").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-zoom-in").removeClass("icon-zoom-in").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-zoom-out").removeClass("icon-zoom-out").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-passwd").removeClass("icon-passwd").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-test").removeClass("icon-test").prepend("<icon class='icon-folder-open-alt'/>");
	jQuery("a.icon-file").removeClass("icon-file").prepend("<icon class='icon-file'/>");

}
//Google Analytics
var _gaq = _gaq || [];
_gaq.push([ '_setAccount', 'UA-29853802-1' ]);
_gaq.push([ '_trackPageview' ]);

(function()
{
	var ga = document.createElement('script');
	ga.type = 'text/javascript';
	ga.async = true;
	ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
	var s = document.getElementsByTagName('script')[0];
	s.parentNode.insertBefore(ga, s);
})();