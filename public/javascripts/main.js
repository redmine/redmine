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

jQuery(function()
{
	setupFilter('#cellsfilter', '#cellslist');
	setupFilter('#groupsfilter', '#groupslist');
	setupFilter('#technologyfilter', '#technologylist');
	setupFilter('#peoplefilter', '#peoplelist');

	jQuery("#header_menu > ul").addClass("pull-right");
	jQuery("#header_menu > ul").append('<li id="loggedelement"></li>');
	jQuery("#loggedas > a").appendTo("#loggedelement");
	jQuery("#loggedas").remove();

	var $window = jQuery(window);

	jQuery("#menucontainer > ul").append('<li class="dropdown"><a class="dropdown-toggle" data-toggle="dropdown" href="#">Actions<b class="caret"></b></a><ul class="dropdown-menu" id="actionsmenu"></ul></li>');
	jQuery("#actionsmenu").append("<li><a href='javascript:showMenu();'>OSB 3D Explorer</a></li>");

	var splitProjectName = jQuery('#pname').html();
	if (splitProjectName != undefined)
	{

		splitProjectName = splitProjectName.split("-");
		jQuery('#pname').html(jQuery.trim(splitProjectName[0]) + " <small>" + jQuery.trim(splitProjectName[1]) + "</small>");

	}

	jQuery('.dropdown-toggle').dropdown();
	// side bar
	jQuery('.bs-docs-sidenav').affix(
	{
		offset :
		{
			top : function()
			{
				return $window.width() <= 980 ? 290 : 210
			},
			bottom : 270
		}
	});

	jQuery.each(jQuery(".projects-list"), function()
	{
		jQuery(this).find("a").first().click();
	});
	
	jQuery("li > .selected").parent().addClass("active");

});

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
