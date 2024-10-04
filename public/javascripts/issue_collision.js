$(document).ready(function(){

  $('input[value="Submit"], input[value="Create"], input[value="Create and continue"], #save-event').click(function(e, params){
    var event = e.originalEvent;
    var assigned_to_id = $('#issue_assigned_to_id').val();
    var start_date = $('#issue_start_date').val();
    var due_date = $('#issue_due_date').val();
    var id = $('#fullCalModal-event-id').val();
    if(!id){
      var arr = $('#issue-form').attr("action").split('/');
      id = arr[arr.length - 1];
    }
    if(!params) {
      e.preventDefault();
      $.ajax({
        method: 'GET',
        beforeSend: function(xhr) {xhr.setRequestHeader('X-CSRF-Token', $('meta[name="csrf-token"]').attr('content'))},
        url: "/issues_collision_check",
        data: {
          assigned_to_id: assigned_to_id,
          start_date: start_date,
          due_date: due_date,
          id: id
        },
        success: function(resp) {
          if(resp && resp != start_date){
            var answer = confirm("Užduoties koalizija, artimiausia galima data nuo " + resp + ". Ar sukurti užduotį su koalizija?");
            if (answer) {
              $(event.target).trigger("click",["Bypass"]);
              if($('#fullCalModal').length){
                $('#fullCalModal').modal("hide");
              }
              // $('#issue-form').trigger("submit");
            } else {
              return false;
            }
          } else {
            $(event.target).trigger("click",["Bypass"]);
            if($('#fullCalModal').length){
              $('#fullCalModal').modal("hide");
            }
            // $('#issue-form').trigger("submit");
          }
        }
      })
    } else {
      if($('#fullCalModal').length){
        $('#fullCalModal').modal("hide");
      }
      return; // do nothing, let the event go
    }
  });

});