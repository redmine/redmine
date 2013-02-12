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
	
	// -- Add bootstrap class to all the tables
	jQuery('table').addClass('table table-bordered');
	
	$(":submit").addClass('btn');

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