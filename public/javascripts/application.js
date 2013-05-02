/* Redmine - project management software
   Copyright (C) 2006-2013  Jean-Philippe Lang */

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
  $(selector).attr('checked', !all_checked);
}

function showAndScrollTo(id, focus) {
  $('#'+id).show();
  if (focus !== null) {
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

function initFilters() {
  $('#add_filter_select').change(function() {
    addFilter($(this).val(), '', []);
  });
  $('#filters-table td.field input[type=checkbox]').each(function() {
    toggleFilter($(this).val());
  });
  $('#filters-table td.field input[type=checkbox]').live('click', function() {
    toggleFilter($(this).val());
  });
  $('#filters-table .toggle-multiselect').live('click', function() {
    toggleMultiSelect($(this).siblings('select'));
  });
  $('#filters-table input[type=text]').live('keypress', function(e) {
    if (e.keyCode == 13) submit_query_form("query_form");
  });
}

function addFilter(field, operator, values) {
  var fieldId = field.replace('.', '_');
  var tr = $('#tr_'+fieldId);
  if (tr.length > 0) {
    tr.show();
  } else {
    buildFilterRow(field, operator, values);
  }
  $('#cb_'+fieldId).attr('checked', true);
  toggleFilter(field);
  $('#add_filter_select').val('').children('option').each(function() {
    if ($(this).attr('value') == field) {
      $(this).attr('disabled', true);
    }
  });
}

function buildFilterRow(field, operator, values) {
  var fieldId = field.replace('.', '_');
  var filterTable = $("#filters-table");
  var filterOptions = availableFilters[field];
  var operators = operatorByType[filterOptions['type']];
  var filterValues = filterOptions['values'];
  var i, select;

  var tr = $('<tr class="filter">').attr('id', 'tr_'+fieldId).html(
    '<td class="field"><input checked="checked" id="cb_'+fieldId+'" name="f[]" value="'+field+'" type="checkbox"><label for="cb_'+fieldId+'"> '+filterOptions['name']+'</label></td>' +
    '<td class="operator"><select id="operators_'+fieldId+'" name="op['+field+']"></td>' +
    '<td class="values"></td>'
  );
  filterTable.append(tr);

  select = tr.find('td.operator select');
  for (i = 0; i < operators.length; i++) {
    var option = $('<option>').val(operators[i]).text(operatorLabels[operators[i]]);
    if (operators[i] == operator) { option.attr('selected', true); }
    select.append(option);
  }
  select.change(function(){ toggleOperator(field); });

  switch (filterOptions['type']) {
  case "list":
  case "list_optional":
  case "list_status":
  case "list_subprojects":
    tr.find('td.values').append(
      '<span style="display:none;"><select class="value" id="values_'+fieldId+'_1" name="v['+field+'][]"></select>' +
      ' <span class="toggle-multiselect">&nbsp;</span></span>'
    );
    select = tr.find('td.values select');
    if (values.length > 1) { select.attr('multiple', true); }
    for (i = 0; i < filterValues.length; i++) {
      var filterValue = filterValues[i];
      var option = $('<option>');
      if ($.isArray(filterValue)) {
        option.val(filterValue[1]).text(filterValue[0]);
        if ($.inArray(filterValue[1], values) > -1) {option.attr('selected', true);}
      } else {
        option.val(filterValue).text(filterValue);
        if ($.inArray(filterValue, values) > -1) {option.attr('selected', true);}
      }
      select.append(option);
    }
    break;
  case "date":
  case "date_past":
    tr.find('td.values').append(
      '<span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'_1" size="10" class="value date_value" /></span>' +
      ' <span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'_2" size="10" class="value date_value" /></span>' +
      ' <span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'" size="3" class="value" /> '+labelDayPlural+'</span>'
    );
    $('#values_'+fieldId+'_1').val(values[0]).datepicker(datepickerOptions);
    $('#values_'+fieldId+'_2').val(values[1]).datepicker(datepickerOptions);
    $('#values_'+fieldId).val(values[0]);
    break;
  case "string":
  case "text":
    tr.find('td.values').append(
      '<span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'" size="30" class="value" /></span>'
    );
    $('#values_'+fieldId).val(values[0]);
    break;
  case "relation":
    tr.find('td.values').append(
      '<span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'" size="6" class="value" /></span>' +
      '<span style="display:none;"><select class="value" name="v['+field+'][]" id="values_'+fieldId+'_1"></select></span>'
    );
    $('#values_'+fieldId).val(values[0]);
    select = tr.find('td.values select');
    for (i = 0; i < allProjects.length; i++) {
      var filterValue = allProjects[i];
      var option = $('<option>');
      option.val(filterValue[1]).text(filterValue[0]);
      if (values[0] == filterValue[1]) { option.attr('selected', true); }
      select.append(option);
    }
  case "integer":
  case "float":
    tr.find('td.values').append(
      '<span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'_1" size="6" class="value" /></span>' +
      ' <span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'_2" size="6" class="value" /></span>'
    );
    $('#values_'+fieldId+'_1').val(values[0]);
    $('#values_'+fieldId+'_2').val(values[1]);
    break;
  }
}

function toggleFilter(field) {
  var fieldId = field.replace('.', '_');
  if ($('#cb_' + fieldId).is(':checked')) {
    $("#operators_" + fieldId).show().removeAttr('disabled');
    toggleOperator(field);
  } else {
    $("#operators_" + fieldId).hide().attr('disabled', true);
    enableValues(field, []);
  }
}

function enableValues(field, indexes) {
  var fieldId = field.replace('.', '_');
  $('#tr_'+fieldId+' td.values .value').each(function(index) {
    if ($.inArray(index, indexes) >= 0) {
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
}

function toggleOperator(field) {
  var fieldId = field.replace('.', '_');
  var operator = $("#operators_" + fieldId);
  switch (operator.val()) {
    case "!*":
    case "*":
    case "t":
    case "ld":
    case "w":
    case "lw":
    case "l2w":
    case "m":
    case "lm":
    case "y":
    case "o":
    case "c":
      enableValues(field, []);
      break;
    case "><":
      enableValues(field, [0,1]);
      break;
    case "<t+":
    case ">t+":
    case "><t+":
    case "t+":
    case ">t-":
    case "<t-":
    case "><t-":
    case "t-":
      enableValues(field, [2]);
      break;
    case "=p":
    case "=!p":
    case "!p":
      enableValues(field, [1]);
      break;
    default:
      enableValues(field, [0]);
      break;
  }
}

function toggleMultiSelect(el) {
  if (el.attr('multiple')) {
    el.removeAttr('multiple');
  } else {
    el.attr('multiple', true);
  }
}

function submit_query_form(id) {
  selectAllOptions("selected_columns");
  $('#'+id).submit();
}

function showTab(name, url) {
  $('div#content .tab-content').hide();
  $('div.tabs a').removeClass('selected');
  $('#tab-content-' + name).show();
  $('#tab-' + name).addClass('selected');
  //replaces current URL with the "href" attribute of the current link
  //(only triggered if supported by browser)
  if ("replaceState" in window.history) {
    window.history.replaceState(null, document.title, url);
  }
  return false;
}

function moveTabRight(el) {
  var lis = $(el).parents('div.tabs').first().find('ul').children();
  var tabsWidth = 0;
  var i = 0;
  lis.each(function() {
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
  while (i < lis.length && !lis.eq(i).is(':visible')) { i++; }
  if (i > 0) {
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
  var el = $('#'+id).first();
  if (el.length === 0 || el.is(':visible')) {return;}
  var title = el.find('h3.title').text();
  el.dialog({
    width: width,
    modal: true,
    resizable: false,
    dialogClass: 'modal',
    title: title
  });
  el.find("input[type=text], input[type=submit]").first().focus();
}

function hideModal(el) {
  var modal;
  if (el) {
    modal = $(el).parents('.ui-dialog-content');
  } else {
    modal = $('#ajax-modal');
  }
  modal.dialog("close");
}

function submitPreview(url, form, target) {
  $.ajax({
    url: url,
    type: 'post',
    data: $('#'+form).serialize(),
    success: function(data){
      $('#'+target).html(data);
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
      success: function(data) {
        el.after(data);
        el.addClass('open').addClass('loaded').removeClass('loading');
      }
    });
    return true;
}

function randomKey(size) {
  var chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  var key = '';
  for (var i = 0; i < size; i++) {
    key += chars.charAt(Math.floor(Math.random() * chars.length));
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

function observeAutocompleteField(fieldId, url, options) {
  $(document).ready(function() {
    $('#'+fieldId).autocomplete($.extend({
      source: url,
      minLength: 2,
      search: function(){$('#'+fieldId).addClass('ajax-loading');},
      response: function(){$('#'+fieldId).removeClass('ajax-loading');}
    }, options));
    $('#'+fieldId).addClass('autocomplete');
  });
}

function observeSearchfield(fieldId, targetId, url) {
  $('#'+fieldId).each(function() {
    var $this = $(this);
    $this.addClass('autocomplete');
    $this.attr('data-value-was', $this.val());
    var check = function() {
      var val = $this.val();
      if ($this.attr('data-value-was') != val){
        $this.attr('data-value-was', val);
        $.ajax({
          url: url,
          type: 'get',
          data: {q: $this.val()},
          success: function(data){ if(targetId) $('#'+targetId).html(data); },
          beforeSend: function(){ $this.addClass('ajax-loading'); },
          complete: function(){ $this.removeClass('ajax-loading'); }
        });
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
    } else {
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
}

function setupAjaxIndicator() {
  $('#ajax-indicator').bind('ajaxSend', function(event, xhr, settings) {
    if ($('.ajax-loading').length === 0 && settings.contentType != 'application/octet-stream') {
      $('#ajax-indicator').show();
    }
  });
  $('#ajax-indicator').bind('ajaxStop', function() {
    $('#ajax-indicator').hide();
  });
}

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

function blockEventPropagation(event) {
  event.stopPropagation();
  event.preventDefault();
}

$(document).ready(setupAjaxIndicator);
$(document).ready(hideOnLoad);
$(document).ready(addFormObserversForDoubleSubmit);
