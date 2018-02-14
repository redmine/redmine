$(document).ready(function(){
    $('.expand-btn').click(function(){
	if($(this).hasClass('collapse-btn')){
	    $('.result-info.collapse').collapse('hide');
	}
	else $('.result-info.collapse').collapse('show');

	$(this).toggleClass('collapse-btn expand-btn');
	return false;
    });
});
