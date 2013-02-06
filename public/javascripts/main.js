	jQuery(function()
		{
		jQuery('.filterinput').keyup(function() {
	        var a = $(this).val();
	        if (a.length > 2) {
	            // this finds all links in the list that contain the input,
	            // and hide the ones not containing the input while showing the ones that do
	            var containing = $('#projectlist li').filter(function () {
	                var regex = new RegExp('\\b' + a, 'i');
	                return regex.test($('a', this).text());
	            }).slideDown();
	            $('#projectlist li').not(containing).slideUp();
	        } else {
	            $('#projectlist li').slideDown();
	        }
	        return false;
	    })
		});