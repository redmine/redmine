/* Redmine - project management software
   Copyright (C) 2006-2022  Jean-Philippe Lang */

var draw_gantt = null;
var draw_top;
var draw_right;
var draw_left;

var rels_stroke_width = 2;

function setDrawArea() {
  draw_top   = $("#gantt_draw_area").position().top;
  draw_right = $("#gantt_draw_area").width();
  draw_left  = $("#gantt_area").scrollLeft();
}

function getRelationsArray() {
  var arr = new Array();
  $.each($('div.task_todo[data-rels]'), function(index_div, element) {
    if(!$(element).is(':visible')) return true;
    var element_id = $(element).attr("id");
    if (element_id != null) {
      var issue_id = element_id.replace("task-todo-issue-", "");
      var data_rels = $(element).data("rels");
      for (rel_type_key in data_rels) {
        $.each(data_rels[rel_type_key], function(index_issue, element_issue) {
          arr.push({issue_from: issue_id, issue_to: element_issue,
                    rel_type: rel_type_key});
        });
      }
    }
  });
  return arr;
}

function drawRelations() {
  var arr = getRelationsArray();
  $.each(arr, function(index_issue, element_issue) {
    var issue_from = $("#task-todo-issue-" + element_issue["issue_from"]);
    var issue_to   = $("#task-todo-issue-" + element_issue["issue_to"]);
    if (issue_from.length == 0 || issue_to.length == 0) {
      return;
    }
    var issue_height = issue_from.height();
    var issue_from_top   = issue_from.position().top  + (issue_height / 2) - draw_top;
    var issue_from_right = issue_from.position().left + issue_from.width();
    var issue_to_top   = issue_to.position().top  + (issue_height / 2) - draw_top;
    var issue_to_left  = issue_to.position().left;
    var color = issue_relation_type[element_issue["rel_type"]]["color"];
    var landscape_margin = issue_relation_type[element_issue["rel_type"]]["landscape_margin"];
    var issue_from_right_rel = issue_from_right + landscape_margin;
    var issue_to_left_rel    = issue_to_left    - landscape_margin;
    draw_gantt.path(["M", issue_from_right + draw_left,     issue_from_top,
                     "L", issue_from_right_rel + draw_left, issue_from_top])
                   .attr({stroke: color,
                          "stroke-width": rels_stroke_width
                          });
    if (issue_from_right_rel < issue_to_left_rel) {
      draw_gantt.path(["M", issue_from_right_rel + draw_left, issue_from_top,
                       "L", issue_from_right_rel + draw_left, issue_to_top])
                     .attr({stroke: color,
                          "stroke-width": rels_stroke_width
                          });
      draw_gantt.path(["M", issue_from_right_rel + draw_left, issue_to_top,
                       "L", issue_to_left + draw_left,        issue_to_top])
                     .attr({stroke: color,
                          "stroke-width": rels_stroke_width
                          });
    } else {
      var issue_middle_top = issue_to_top +
                                (issue_height *
                                   ((issue_from_top > issue_to_top) ? 1 : -1));
      draw_gantt.path(["M", issue_from_right_rel + draw_left, issue_from_top,
                       "L", issue_from_right_rel + draw_left, issue_middle_top])
                     .attr({stroke: color,
                          "stroke-width": rels_stroke_width
                          });
      draw_gantt.path(["M", issue_from_right_rel + draw_left, issue_middle_top,
                       "L", issue_to_left_rel + draw_left,    issue_middle_top])
                     .attr({stroke: color,
                          "stroke-width": rels_stroke_width
                          });
      draw_gantt.path(["M", issue_to_left_rel + draw_left, issue_middle_top,
                       "L", issue_to_left_rel + draw_left, issue_to_top])
                     .attr({stroke: color,
                          "stroke-width": rels_stroke_width
                          });
      draw_gantt.path(["M", issue_to_left_rel + draw_left, issue_to_top,
                       "L", issue_to_left + draw_left,     issue_to_top])
                     .attr({stroke: color,
                          "stroke-width": rels_stroke_width
                          });
    }
    draw_gantt.path(["M", issue_to_left + draw_left, issue_to_top,
                     "l", -4 * rels_stroke_width, -2 * rels_stroke_width,
                     "l", 0, 4 * rels_stroke_width, "z"])
                   .attr({stroke: "none",
                          fill: color,
                          "stroke-linecap": "butt",
                          "stroke-linejoin": "miter"
                          });
  });
}

function getProgressLinesArray() {
  var arr = new Array();
  var today_left = $('#today_line').position().left;
  arr.push({left: today_left, top: 0});
  $.each($('div.issue-subject, div.version-name'), function(index, element) {
    if(!$(element).is(':visible')) return true;
    var t = $(element).position().top - draw_top ;
    var h = ($(element).height() / 9);
    var element_top_upper  = t - h;
    var element_top_center = t + (h * 3);
    var element_top_lower  = t + (h * 8);
    var issue_closed   = $(element).children('span').hasClass('issue-closed');
    var version_closed = $(element).children('span').hasClass('version-closed');
    if (issue_closed || version_closed) {
      arr.push({left: today_left, top: element_top_center});
    } else {
      var issue_done = $("#task-done-" + $(element).attr("id"));
      var is_behind_start = $(element).children('span').hasClass('behind-start-date');
      var is_over_end     = $(element).children('span').hasClass('over-end-date');
      if (is_over_end) {
        arr.push({left: draw_right, top: element_top_upper, is_right_edge: true});
        arr.push({left: draw_right, top: element_top_lower, is_right_edge: true, none_stroke: true});
      } else if (issue_done.length > 0) {
        var done_left = issue_done.first().position().left +
                           issue_done.first().width();
        arr.push({left: done_left, top: element_top_center});
      } else if (is_behind_start) {
        arr.push({left: 0 , top: element_top_upper, is_left_edge: true});
        arr.push({left: 0 , top: element_top_lower, is_left_edge: true, none_stroke: true});
      } else {
        var todo_left = today_left;
        var issue_todo = $("#task-todo-" + $(element).attr("id"));
        if (issue_todo.length > 0){
          todo_left = issue_todo.first().position().left;
        }
        arr.push({left: Math.min(today_left, todo_left), top: element_top_center});
      }
    }
  });
  return arr;
}

function drawGanttProgressLines() {
  var arr = getProgressLinesArray();
  var color = $("#today_line")
                    .css("border-left-color");
  var i;
  for(i = 1 ; i < arr.length ; i++) {
    if (!("none_stroke" in arr[i]) &&
        (!("is_right_edge" in arr[i - 1] && "is_right_edge" in arr[i]) &&
         !("is_left_edge"  in arr[i - 1] && "is_left_edge"  in arr[i]))
        ) {
      var x1 = (arr[i - 1].left == 0) ? 0 : arr[i - 1].left + draw_left;
      var x2 = (arr[i].left == 0)     ? 0 : arr[i].left     + draw_left;
      draw_gantt.path(["M", x1, arr[i - 1].top,
                       "L", x2, arr[i].top])
                   .attr({stroke: color, "stroke-width": 2});
    }
  }
}

function drawSelectedColumns(){
  if ($("#draw_selected_columns").prop('checked')) {
    if(isMobile()) {
      $('td.gantt_selected_column').each(function(i) {
        $(this).hide();
      });
    }else{
      $('.gantt_subjects_container').addClass('draw_selected_columns');
      $('td.gantt_selected_column').each(function() {
        $(this).show();
        var column_name = $(this).attr('id');
        $(this).resizable({
          alsoResize: '.gantt_' + column_name + '_container, .gantt_' + column_name + '_container > .gantt_hdr',
          minWidth: 20,
          handles: "e",
          create: function() {
            $(".ui-resizable-e").css("cursor","ew-resize");
          }
        }).on('resize', function (e) {
            e.stopPropagation();
        });
      });
    }
  }else{
    $('td.gantt_selected_column').each(function (i) {
      $(this).hide();
      $('.gantt_subjects_container').removeClass('draw_selected_columns');
    });
  }
}

function drawGanttHandler() {
  var folder = document.getElementById('gantt_draw_area');
  if(draw_gantt != null)
    draw_gantt.clear();
  else
    draw_gantt = Raphael(folder);
  setDrawArea();
  drawSelectedColumns();
  if ($("#draw_progress_line").prop('checked'))
    try{drawGanttProgressLines();}catch(e){}
  if ($("#draw_relations").prop('checked'))
    drawRelations();
  $('#content').addClass('gantt_content');
}

function resizableSubjectColumn(){
  $('.issue-subject, .project-name, .version-name').each(function(){
    $(this).width($(".gantt_subjects_column").width()-$(this).position().left);
  });
  $('td.gantt_subjects_column').resizable({
    alsoResize: '.gantt_subjects_container, .gantt_subjects_container>.gantt_hdr, .project-name, .issue-subject, .version-name',
    minWidth: 100,
    handles: 'e',
    create: function( event, ui ) {
      $('.ui-resizable-e').css('cursor','ew-resize');
    }
  }).on('resize', function (e) {
      e.stopPropagation();
  });
  if(isMobile()) {
    $('td.gantt_subjects_column').resizable('disable');
  }else{
    $('td.gantt_subjects_column').resizable('enable');
  };
}

ganttEntryClick = function(e){
  var icon_expander = e.target;
  var subject = $(icon_expander.parentElement);
  var subject_left = parseInt(subject.css('left')) + parseInt(icon_expander.offsetWidth);
  var target_shown = null;
  var target_top = 0;
  var total_height = 0;
  var out_of_hierarchy = false;
  var iconChange = null;
  if(subject.hasClass('open'))
    iconChange = function(element){
      $(element).find('.expander').switchClass('icon-expanded', 'icon-collapsed');
      $(element).removeClass('open');
    };
  else
    iconChange = function(element){
      $(element).find('.expander').switchClass('icon-collapsed', 'icon-expanded');
      $(element).addClass('open');
    };
  iconChange(subject);
  subject.nextAll('div').each(function(_, element){
    var el = $(element);
    var json = el.data('collapse-expand');
    var number_of_rows = el.data('number-of-rows');
    var el_task_bars = '#gantt_area form > div[data-collapse-expand="' + json.obj_id + '"][data-number-of-rows="' + number_of_rows + '"]';
    var el_selected_columns = 'td.gantt_selected_column div[data-collapse-expand="' + json.obj_id + '"][data-number-of-rows="' + number_of_rows + '"]';
    if(out_of_hierarchy || parseInt(el.css('left')) <= subject_left){
      out_of_hierarchy = true;
      if(target_shown == null) return false;

      var new_top_val = parseInt(el.css('top')) + total_height * (target_shown ? -1 : 1);
      el.css('top', new_top_val);
      $([el_task_bars, el_selected_columns].join()).each(function(_, el){
        $(el).css('top', new_top_val);
      });
      return true;
    }

    var is_shown = el.is(':visible');
    if(target_shown == null){
      target_shown = is_shown;
      target_top = parseInt(el.css('top'));
      total_height = 0;
    }
    if(is_shown == target_shown){
      $(el_task_bars).each(function(_, task) {
        var el_task = $(task);
        if(!is_shown)
          el_task.css('top', target_top + total_height);
        if(!el_task.hasClass('tooltip'))
          el_task.toggle(!is_shown);
      });
      $(el_selected_columns).each(function (_, attr) {
        var el_attr = $(attr);
        if (!is_shown)
          el_attr.css('top', target_top + total_height);
          el_attr.toggle(!is_shown);
      });
      if(!is_shown)
        el.css('top', target_top + total_height);
      iconChange(el);
      el.toggle(!is_shown);
      total_height += parseInt(json.top_increment);
    }
  });
  drawGanttHandler();
};

function disable_unavailable_columns(unavailable_columns) {
  $.each(unavailable_columns, function (index, value) {
    $('#available_c, #selected_c').children("[value='" + value + "']").prop('disabled', true);
  });
}
