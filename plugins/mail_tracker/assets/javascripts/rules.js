$( document ).ready(function() {
  $('.search-select').select2();
  $('.input-duration').durationPicker();
  $('#duration').durationPicker({
    lang: 'en',
    formatter: function (s) {
      return s;
    },
    showSeconds: false
  });

  $('#add_rule').on('click', function(){
    var auth = $('meta[name=csrf-token]').attr('content');
    var userId = $('#add_rule').data('user-id')
    $.ajax({
      method: 'get',
      url: "/mail_tracking_rules/add_rule?&authenticity_token=" + auth,
      data: {
        obj: "realThing",
        user_id: userId,

      },
      success: function(resp) {
        location.reload();
      }
    })
  });

  $('.delete_rule').on('click', function(e){
    // var auth = $('meta[name=csrf-token]').attr('content');
    var id = $(this).attr('data-id');
    if(confirm("Do you really want to delete this rule?")){
      if(id && id.length > 0){
        $.ajax({
          method: 'DELETE',
          beforeSend: function(xhr) {xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))},
          url: "/mail_tracking_rules/" + id,
          data: {
            obj: "realThing"
          },
          success: function(resp) {
            location.reload();
          }
        })
      }
    }

  });
});