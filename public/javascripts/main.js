jQuery(function()
{
	setupFilter('#cellsfilter','#cellslist');
	setupFilter('#groupsfilter','#groupslist');
	setupFilter('#technologyfilter','#technologylist');
	setupFilter('#peoplefilter','#peoplelist');
	var lists=new Array();
	lists=jQuery(".projects-list");
	for(l in lists){
		jQuery(lists[l]).find("a").first().click();	
	}
});

function setupFilter(idFilter,idList)
{
	jQuery(idFilter).keyup(function()
			{
				var a = $(this).val();
				if (a.length > 2)
				{
					// this finds all links in the list that contain the input,
					// and hide the ones not containing the input while showing the ones that do
					var containing = $(idList+' li').filter(function()
					{
						var regex = new RegExp('\\b' + a, 'i');
						return regex.test($('a', this).text());
					}).slideDown();
					$(idList+' li').not(containing).slideUp();
				}
				else
				{
					$(idList+' li').slideDown();
				}
			});
}
				
