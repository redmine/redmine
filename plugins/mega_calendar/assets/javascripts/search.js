$( document ).ready(function() {
  var obj = $('.search-select');
  obj.select2();

  if(navigator.userAgent.match(/Android/i)){
    obj.on('open', function(e) {
      $('.select2-search input').prop('focus',false);
    });
  }
});