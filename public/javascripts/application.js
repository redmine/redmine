/* Redmine - project management software
   Copyright (C) 2006-2012  Jean-Philippe Lang */

function checkAll(id, checked) {
  if (checked) {
    $('#'+id).find('input[type=checkbox]').attr('checked', true);
  } else {
    $('#'+id).find('input[type=checkbox]').removeAttr('checked');
  }
}

function toggleCheckboxesBySelector(selector) {
  var all_checked = true;
  $(selector).each(function(index) {
    if (!$(this).is(':checked')) { all_checked = false; }
  });
  $(selector).attr('checked', !all_checked)
}

function showAndScrollTo(id, focus) {
  $('#'+id).show();
  if (focus!=null) {
    $('#'+focus).focus();
  }
  $('html, body').animate({scrollTop: $('#'+id).offset().top}, 100);
}

function toggleRowGroup(el) {
  var tr = $(el).parents('tr').first();
  var n = tr.next();
  tr.toggleClass('open');
  while (n.length && !n.hasClass('group')) {
    n.toggle();
    n = n.next('tr');
  }
}

function collapseAllRowGroups(el) {
  var tbody = $(el).parents('tbody').first();
  tbody.children('tr').each(function(index) {
    if ($(this).hasClass('group')) {
      $(this).removeClass('open');
    } else {
      $(this).hide();
    }
  });
}

function expandAllRowGroups(el) {
  var tbody = $(el).parents('tbody').first();
  tbody.children('tr').each(function(index) {
    if ($(this).hasClass('group')) {
      $(this).addClass('open');
    } else {
      $(this).show();
    }
  });
}

function toggleAllRowGroups(el) {
  var tr = $(el).parents('tr').first();
  if (tr.hasClass('open')) {
    collapseAllRowGroups(el);
  } else {
    expandAllRowGroups(el);
  }
}

function toggleFieldset(el) {
  var fieldset = $(el).parents('fieldset').first();
  fieldset.toggleClass('collapsed');
  fieldset.children('div').toggle();
}

function hideFieldset(el) {
  var fieldset = $(el).parents('fieldset').first();
  fieldset.toggleClass('collapsed');
  fieldset.children('div').hide();
}

function add_filter() {
  var select = $('#add_filter_select');
  var field = select.val();
  $('#tr_'+field).show();
  var check_box = $('#cb_' + field);
  check_box.attr('checked', true);
  toggle_filter(field);
  select.val('');

  select.children('option').each(function(index) {
    if ($(this).attr('value') == field) {
      $(this).attr('disabled', true);
    }
  });
}

function toggle_filter(field) {
  check_box = $('#cb_' + field);
  if (check_box.is(':checked')) {
    $("#operators_" + field).show().removeAttr('disabled');
    toggle_operator(field);
  } else {
    $("#operators_" + field).hide().attr('disabled', true);
    enableValues(field, []);
  }
}

function enableValues(field, indexes) {
  $(".values_" + field).each(function(index) {
    if (indexes.indexOf(index) >= 0) {
      $(this).removeAttr('disabled');
      $(this).parents('span').first().show();
    } else {
      $(this).val('');
      $(this).attr('disabled', true);
      $(this).parents('span').first().hide();
    }

    if ($(this).hasClass('group')) {
      $(this).addClass('open');
    } else {
      $(this).show();
    }
  });

  if (indexes.length > 0) {
    $("#div_values_" + field).show();
  } else {
    $("#div_values_" + field).hide();
  }
}

function toggle_operator(field) {
  operator = $("#operators_" + field);
  switch (operator.val()) {
    case "!*":
    case "*":
    case "t":
    case "w":
    case "o":
    case "c":
      enableValues(field, []);
      break;
    case "><":
      enableValues(field, [0,1]);
      break;
    case "<t+":
    case ">t+":
    case "t+":
    case ">t-":
    case "<t-":
    case "t-":
      enableValues(field, [2]);
      break;
    default:
      enableValues(field, [0]);
      break;
  }
}

function toggle_multi_select(id) {
  var select = $('#'+id);
  if (select.attr('multiple')) {
    select.removeAttr('multiple');
  } else {
    select.attr('multiple', true);
  }
}

function submit_query_form(id) {
  selectAllOptions("selected_columns");
  $('#'+id).submit();
}

function observeIssueFilters() {
  $('#query_form input[type=text]').keypress(function(e){
    if (e.keyCode == 13) submit_query_form("query_form");
  });
}

var fileFieldCount = 1;
function addFileField() {
  var fields = $('#attachments_fields');
  if (fields.children().length >= 10) return false;
  fileFieldCount++;
  var s = fields.children('span').first().clone();
  s.children('input.file').attr('name', "attachments[" + fileFieldCount + "][file]").val('');
  s.children('input.description').attr('name', "attachments[" + fileFieldCount + "][description]").val('');
  fields.append(s);
}

function removeFileField(el) {
  var fields = $('#attachments_fields');
  var s = $(el).parents('span').first();
  if (fields.children().length > 1) {
    s.remove();
  } else {
    s.children('input.file').val('');
    s.children('input.description').val('');
  }
}

function checkFileSize(el, maxSize, message) {
  var files = el.files;
  if (files) {
    for (var i=0; i<files.length; i++) {
      if (files[i].size > maxSize) {
        alert(message);
        el.value = "";
      }
    }
  }
}

function showTab(name) {
  $('div#content .tab-content').hide();
  $('div.tabs a').removeClass('selected');
  $('#tab-content-' + name).show();
  $('#tab-' + name).addClass('selected');
  return false;
}

function moveTabRight(el) {
  var lis = $(el).parents('div.tabs').first().find('ul').children();
  var tabsWidth = 0;
  var i = 0;
  lis.each(function(){
    if ($(this).is(':visible')) {
      tabsWidth += $(this).width() + 6;
    }
  });
  if (tabsWidth < $(el).parents('div.tabs').first().width() - 60) { return; }
  while (i<lis.length && !lis.eq(i).is(':visible')) { i++; }
  lis.eq(i).hide();
}

function moveTabLeft(el) {
  var lis = $(el).parents('div.tabs').first().find('ul').children();
  var i = 0;
  while (i<lis.length && !lis.eq(i).is(':visible')) { i++; }
  if (i>0) {
    lis.eq(i-1).show();
  }
}

function displayTabsButtons() {
  var lis;
  var tabsWidth = 0;
  var el;
  $('div.tabs').each(function() {
    el = $(this);
    lis = el.find('ul').children();
    lis.each(function(){
      if ($(this).is(':visible')) {
        tabsWidth += $(this).width() + 6;
      }
    });
    if ((tabsWidth < el.width() - 60) && (lis.first().is(':visible'))) {
      el.find('div.tabs-buttons').hide();
    } else {
      el.find('div.tabs-buttons').show();
    }
  });
}

function setPredecessorFieldsVisibility() {
  var relationType = $('#relation_relation_type');
  if (relationType.val() == "precedes" || relationType.val() == "follows") {
    $('#predecessor_fields').show();
  } else {
    $('#predecessor_fields').hide();
  }
}

function showModal(id, width) {
  el = $('#'+id).first();
  if (el.length == 0 || el.is(':visible')) {return;}
  var h = $('body').height();
  var d = document.createElement("div");
  d.id = 'modalbg';
  $(d).appendTo('#main').css('width', '100%').css('height', h + 'px').show();

  var pageWidth = $(window).width();
  if (width) {
    el.css('width', width);
  }
  el.css('left', (((pageWidth - el.width())/2  *100) / pageWidth) + '%');
  el.addClass('modal');
  el.show();

  el.find("input[type=text], input[type=submit]").first().focus();
}

function hideModal(el) {
  var modal;
  if (el) {
    modal = $(el).parents('div.modal').first();
  } else {
    modal = $('#ajax-modal');
  }
  modal.hide();
  $('#modalbg').remove();
}

function submitPreview(url, form, target) {
  $.ajax({
    url: url,
    type: 'post',
    data: $('#'+form).serialize(),
    success: function(data){
      $('#'+target).html(data);
      $('html, body').animate({scrollTop: $('#'+target).offset().top}, 100);
    }
  });
}

function collapseScmEntry(id) {
  $('.'+id).each(function() {
    if ($(this).hasClass('open')) {
      collapseScmEntry($(this).attr('id'));
    }
    $(this).hide();
  });
  $('#'+id).removeClass('open');
}

function expandScmEntry(id) {
  $('.'+id).each(function() {
    $(this).show();
    if ($(this).hasClass('loaded') && !$(this).hasClass('collapsed')) {
      expandScmEntry($(this).attr('id'));
    }
  });
  $('#'+id).addClass('open');
}

function scmEntryClick(id, url) {
    el = $('#'+id);
    if (el.hasClass('open')) {
        collapseScmEntry(id);
        el.addClass('collapsed');
        return false;
    } else if (el.hasClass('loaded')) {
        expandScmEntry(id);
        el.removeClass('collapsed');
        return false;
    }
    if (el.hasClass('loading')) {
        return false;
    }
    el.addClass('loading');
    $.ajax({
      url: url,
      success: function(data){
        el.after(data);
        el.addClass('open').addClass('loaded').removeClass('loading');
      }
    });
    return true;
}

function randomKey(size) {
  var chars = new Array('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z');
  var key = '';
  for (i = 0; i < size; i++) {
    key += chars[Math.floor(Math.random() * chars.length)];
  }
  return key;
}

// Can't use Rails' remote select because we need the form data
function updateIssueFrom(url) {
  $.ajax({
    url: url,
    type: 'post',
    data: $('#issue-form').serialize()
  });
}

function updateBulkEditFrom(url) {
  $.ajax({
    url: url,
    type: 'post',
    data: $('#bulk_edit_form').serialize()
  });
}

function observeAutocompleteField(fieldId, url) {
  $('#'+fieldId).autocomplete({
    source: url,
    minLength: 2,
  });
}

function observeSearchfield(fieldId, targetId, url) {
  $('#'+fieldId).each(function() {
    var $this = $(this);
    $this.attr('data-value-was', $this.val());
    var check = function() {
      var val = $this.val();
      if ($this.attr('data-value-was') != val){
        $this.attr('data-value-was', val);
        if (val != '') {
          $.ajax({
            url: url,
            type: 'get',
            data: {q: $this.val()},
            success: function(data){ $('#'+targetId).html(data); },
            beforeSend: function(){ $this.addClass('ajax-loading'); },
            complete: function(){ $this.removeClass('ajax-loading'); }
          });
        }
      }
    };
    var reset = function() {
      if (timer) {
        clearInterval(timer);
        timer = setInterval(check, 300);
      }
    };
    var timer = setInterval(check, 300);
    $this.bind('keyup click mousemove', reset);
  });
}

function observeProjectModules() {
  var f = function() {
    /* Hides trackers and issues custom fields on the new project form when issue_tracking module is disabled */
    if ($('#project_enabled_module_names_issue_tracking').attr('checked')) {
      $('#project_trackers').show();
    }else{
      $('#project_trackers').hide();
    }
  };

  $(window).load(f);
  $('#project_enabled_module_names_issue_tracking').change(f);
}

function initMyPageSortable(list, url) {
  $('#list-'+list).sortable({
    connectWith: '.block-receiver',
    tolerance: 'pointer',
    update: function(){
      $.ajax({
        url: url,
        type: 'post',
        data: {'blocks': $.map($('#list-'+list).children(), function(el){return $(el).attr('id');})}
      });
    }
  });
  $("#list-top, #list-left, #list-right").disableSelection();
}

var warnLeavingUnsavedMessage;
function warnLeavingUnsaved(message) {
  warnLeavingUnsavedMessage = message;

  $('form').submit(function(){
    $('textarea').removeData('changed');
  });
  $('textarea').change(function(){
    $(this).data('changed', 'changed');
  });
  window.onbeforeunload = function(){
    var warn = false;
    $('textarea').blur().each(function(){
      if ($(this).data('changed')) {
        warn = true;
      }
    });
    if (warn) {return warnLeavingUnsavedMessage;}
  };
};

$(document).ready(function(){
  $('#ajax-indicator').bind('ajaxSend', function(){
    if ($('.ajax-loading').length == 0) {
      $('#ajax-indicator').show();
    }
  });
  $('#ajax-indicator').bind('ajaxStop', function(){
    $('#ajax-indicator').hide();
  });
});

function hideOnLoad() {
  $('.hol').hide();
}

function addFormObserversForDoubleSubmit() {
  $('form[method=post]').each(function() {
    if (!$(this).hasClass('multiple-submit')) {
      $(this).submit(function(form_submission) {
        if ($(form_submission.target).attr('data-submitted')) {
          form_submission.preventDefault();
        } else {
          $(form_submission.target).attr('data-submitted', true);
        }
      });
    }
  });
}

$(document).ready(hideOnLoad);
$(document).ready(addFormObserversForDoubleSubmit);
