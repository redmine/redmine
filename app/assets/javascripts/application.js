/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */

function sanitizeHTML(string) {
  var temp = document.createElement('span');
  temp.textContent = string;
  return temp.innerHTML;
}

function checkAll(id, checked) {
  $('#'+id).find('input[type=checkbox]:enabled').prop('checked', checked);
}

function toggleCheckboxesBySelector(selector) {
  var all_checked = true;
  $(selector).each(function(index) {
    if (!$(this).is(':checked')) { all_checked = false; }
  });
  $(selector).prop('checked', !all_checked).trigger('change');
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
  $(el).toggleClass('icon-expanded icon-collapsed');
  toggleExpendCollapseIcon(el)
  while (n.length && !n.hasClass('group')) {
    n.toggle();
    n = n.next('tr');
  }
}

function toggleExpendCollapseIcon(el) {
  if (el.classList.contains('icon-expanded')) {
    updateSVGIcon(el, 'angle-down')
  } else {
    updateSVGIcon(el, 'angle-right')
  }
}

function updateSVGIcon(element, icon) {
  const iconElement = element.getElementsByTagName("use").item(0)

  if (iconElement === null) {
    return false;
  }

  const iconPath = iconElement.getAttribute('href');
  iconElement.setAttribute('href', iconPath.replace(/#.*$/g, "#icon--" + icon))
}

function collapseAllRowGroups(el) {
  var tbody = $(el).parents('tbody').first();
  tbody.children('tr').each(function(index) {
    if ($(this).hasClass('group')) {
      $(this).removeClass('open');
      $(this).find('.expander').switchClass('icon-expanded', 'icon-collapsed');
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
      $(this).find('.expander').switchClass('icon-collapsed', 'icon-expanded');
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
  fieldset.children('legend').toggleClass('icon-expanded icon-collapsed');
  toggleExpendCollapseIcon(fieldset.children('legend')[0])
  fieldset.children('div').toggle();
}

function hideFieldset(el) {
  var fieldset = $(el).parents('fieldset').first();
  fieldset.toggleClass('collapsed');
  fieldset.children('div').hide();
}

// columns selection
function moveOptions(theSelFrom, theSelTo) {
  $(theSelFrom).find('option:selected').detach().prop("selected", false).appendTo($(theSelTo));
}

function moveOptionUp(theSel) {
  $(theSel).find('option:selected').each(function(){
    $(this).prev(':not(:selected)').detach().insertAfter($(this));
  });
}

function moveOptionTop(theSel) {
  $(theSel).find('option:selected').detach().prependTo($(theSel));
}

function moveOptionDown(theSel) {
  $($(theSel).find('option:selected').get().reverse()).each(function(){
    $(this).next(':not(:selected)').detach().insertBefore($(this));
  });
}

function moveOptionBottom(theSel) {
  $(theSel).find('option:selected').detach().appendTo($(theSel));
}

function initFilters() {
  $('#add_filter_select').change(function() {
    addFilter($(this).val(), '', []);
  });
  $('#filters-table .field input[type=checkbox]').each(function() {
    toggleFilter($(this).val());
  });
  $('#filters-table').on('click', '.field input[type=checkbox]', function() {
    toggleFilter($(this).val());
  });
  $('#filters-table').on('keypress', 'input[type=text]', function(e) {
    if (e.keyCode == 13) $(this).closest('form').submit();
  });
}

function addFilter(field, operator, values) {
  var fieldId = field.replace('.', '_');
  var tr = $('#tr_'+fieldId);

  var filterOptions = availableFilters[field];
  if (!filterOptions) return;

  if (filterOptions['remote'] && filterOptions['values'] == null) {
    $.getJSON(filtersUrl, {'name': field}).done(function(data) {
      filterOptions['values'] = data;
      addFilter(field, operator, values) ;
    });
    return;
  }

  if (tr.length > 0) {
    tr.show();
  } else {
    buildFilterRow(field, operator, values);
  }
  $('#cb_'+fieldId).prop('checked', true);
  toggleFilter(field);
  toggleMultiSelectIconInit();
  $('#add_filter_select').val('').find('option').each(function() {
    if ($(this).attr('value') == field) {
      $(this).attr('disabled', true);
    }
  });
}

function buildFilterRow(field, operator, values) {
  var fieldId = field.replace('.', '_');
  var filterTable = $("#filters-table");
  var filterOptions = availableFilters[field];
  if (!filterOptions) return;
  var operators = operatorByType[filterOptions['type']];
  var filterValues = filterOptions['values'];
  var select;

  var tr = $('<div class="filter">').attr('id', 'tr_'+fieldId).html(
    '<div class="field"><input checked="checked" id="cb_'+fieldId+'" name="f[]" value="'+field+'" type="checkbox"><label for="cb_'+fieldId+'"> '+filterOptions['name']+'</label></div>' +
    '<div class="operator"><select id="operators_'+fieldId+'" name="op['+field+']"></select></div>' +
    '<div class="values"></div>'
  );
  filterTable.append(tr);

  select = tr.find('.operator select');
  operators.forEach(function(op) {
    var option = $('<option>').val(op).text(operatorLabels[op]);
    if (op == operator) { option.prop('selected', true); }
    select.append(option);
  });
  select.change(function(){ toggleOperator(field); });

  switch (filterOptions['type']) {
  case "list":
  case "list_with_history":
  case "list_optional":
  case "list_optional_with_history":
  case "list_status":
  case "list_subprojects":
    tr.find('.values').append(
      '<span style="display:none;"><select class="value" id="values_'+fieldId+'_1" name="v['+field+'][]"></select>' +
      ' <span class="toggle-multiselect icon-only '+(values.length > 1 ? 'icon-toggle-minus' : 'icon-toggle-plus')+'">&nbsp;</span></span>'
    );
    select = tr.find('.values select');
    if (values.length > 1) { select.attr('multiple', true); }
    filterValues.forEach(function(filterValue) {
      var option = $('<option>');
      if ($.isArray(filterValue)) {
        option.val(filterValue[1]).text(filterValue[0]);
        if ($.inArray(filterValue[1], values) > -1) {option.prop('selected', true);}
        if (filterValue.length == 3) {
          var optgroup = select.find('optgroup').filter(function(){return $(this).attr('label') == filterValue[2]});
          if (!optgroup.length) {optgroup = $('<optgroup>').attr('label', filterValue[2]);}
          option = optgroup.append(option);
        }
      } else {
        option.val(filterValue).text(filterValue);
        if ($.inArray(filterValue, values) > -1) {option.prop('selected', true);}
      }
      select.append(option);
    });
    break;
  case "date":
  case "date_past":
    tr.find('.values').append(
      '<span style="display:none;"><input type="date" name="v['+field+'][]" id="values_'+fieldId+'_1" size="10" class="value date_value" /></span>' +
      ' <span style="display:none;"><input type="date" name="v['+field+'][]" id="values_'+fieldId+'_2" size="10" class="value date_value" /></span>' +
      ' <span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'" size="3" class="value" /> '+labelDayPlural+'</span>'
    );
    $('#values_'+fieldId+'_1').val(values[0]).datepickerFallback(datepickerOptions);
    $('#values_'+fieldId+'_2').val(values[1]).datepickerFallback(datepickerOptions);
    $('#values_'+fieldId).val(values[0]);
    break;
  case "string":
  case "text":
  case "search":
    tr.find('.values').append(
      '<span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'" size="30" class="value" /></span>'
    );
    $('#values_'+fieldId).val(values[0]);
    break;
  case "relation":
    tr.find('.values').append(
      '<span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'" size="6" class="value" /></span>' +
      '<span style="display:none;"><select class="value" name="v['+field+'][]" id="values_'+fieldId+'_1"></select></span>'
    );
    $('#values_'+fieldId).val(values[0]);
    select = tr.find('.values select');
    filterValues.forEach(function(filterValue) {
      var option = $('<option>');
      option.val(filterValue[1]).text(filterValue[0]);
      if (values[0] == filterValue[1]) { option.prop('selected', true); }
      select.append(option);
    });
    break;
  case "integer":
  case "float":
  case "tree":
    tr.find('.values').append(
      '<span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'_1" size="14" class="value" /></span>' +
      ' <span style="display:none;"><input type="text" name="v['+field+'][]" id="values_'+fieldId+'_2" size="14" class="value" /></span>'
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
  $('#tr_'+fieldId+' .values .value').each(function(index) {
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
    case "nd":
    case "t":
    case "ld":
    case "nw":
    case "w":
    case "lw":
    case "l2w":
    case "nm":
    case "m":
    case "lm":
    case "y":
    case "o":
    case "c":
    case "*o":
    case "!o":
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
  var isWorkflow = el.closest('.controller-workflows');
  if (el.attr('multiple')) {
    el.removeAttr('multiple');
    if (isWorkflow) { el.find("option[value=all]").show(); }
    el.attr('size', 1);
  } else {
    el.attr('multiple', true);
    if (isWorkflow) { el.find("option[value=all]").attr("selected", false).hide(); }
    if (el.children().length > 10)
      el.attr('size', 10);
    else
      el.attr('size', 4);
  }
}

function showTab(name, url) {
  $('#tab-content-' + name).parent().find('.tab-content').hide();
  $('#tab-content-' + name).show();
  $('#tab-' + name).closest('.tabs').find('a').removeClass('selected');
  $('#tab-' + name).addClass('selected');

  replaceInHistory(url)

  return false;
}

function showIssueHistory(journal, url) {
  tab_content = $('#tab-content-history');
  tab_content.parent().find('.tab-content').hide();
  tab_content.show();
  tab_content.parent().children('div.tabs').find('a').removeClass('selected');

  $('#tab-' + journal).addClass('selected');

  replaceInHistory(url)

  switch(journal) {
    case 'notes':
      tab_content.find('.journal').show();
      tab_content.find('.journal:not(.has-notes)').hide();
      tab_content.find('.journal .wiki').show();
      tab_content.find('.journal .contextual .journal-actions').show();

      // always show thumbnails in notes tab
      var thumbnails = tab_content.find('.journal .thumbnails');
      thumbnails.show();
      // show journals without notes, but with thumbnails
      thumbnails.parents('.journal').show();
      break;
    case 'properties':
      tab_content.find('.journal').show();
      tab_content.find('.journal:not(.has-details)').hide();
      tab_content.find('.journal .wiki').hide();
      tab_content.find('.journal .thumbnails').hide();
      tab_content.find('.journal .contextual .journal-actions').hide();
      break;
    default:
      tab_content.find('.journal').show();
      tab_content.find('.journal .wiki').show();
      tab_content.find('.journal .thumbnails').show();
      tab_content.find('.journal .contextual .journal-actions').show();
  }

  return false;
}

function getRemoteTab(name, remote_url, url, load_always) {
  load_always = load_always || false;
  var tab_content = $('#tab-content-' + name);

  tab_content.parent().find('.tab-content').hide();
  tab_content.parent().children('div.tabs').find('a').removeClass('selected');
  $('#tab-' + name).addClass('selected');

  replaceInHistory(url);

  if (tab_content.children().length == 0 && load_always == false) {
    $.ajax({
      url: remote_url,
      type: 'get',
      success: function(data){
        tab_content.html(data)
      }
    });
  }

  tab_content.show();
  return false;
}

//replaces current URL with the "href" attribute of the current link
//(only triggered if supported by browser)
function replaceInHistory(url) {
  if ("replaceState" in window.history && url !== undefined) {
    window.history.replaceState(null, document.title, url);
  }
}

function moveTabRight(el) {
  var lis = $(el).parents('div.tabs').first().find('ul').children();
  var bw = $(el).parents('div.tabs-buttons').outerWidth(true);
  var tabsWidth = 0;
  var i = 0;
  lis.each(function() {
    if ($(this).is(':visible')) {
      tabsWidth += $(this).outerWidth(true);
    }
  });
  if (tabsWidth < $(el).parents('div.tabs').first().width() - bw) { return; }
  $(el).siblings('.tab-left').removeClass('disabled');
  while (i<lis.length && !lis.eq(i).is(':visible')) { i++; }
  var w = lis.eq(i).width();
  lis.eq(i).hide();
  if (tabsWidth - w < $(el).parents('div.tabs').first().width() - bw) {
    $(el).addClass('disabled');
  }
}

function moveTabLeft(el) {
  var lis = $(el).parents('div.tabs').first().find('ul').children();
  var i = 0;
  while (i < lis.length && !lis.eq(i).is(':visible')) { i++; }
  if (i > 0) {
    lis.eq(i-1).show();
    $(el).siblings('.tab-right').removeClass('disabled');
  }
  if (i <= 1) {
    $(el).addClass('disabled');
  }
}

function displayTabsButtons() {
  var lis;
  var tabsWidth;
  var el;
  var numHidden;
  $('div.tabs').each(function() {
    el = $(this);
    lis = el.find('ul').children();
    tabsWidth = 0;
    numHidden = 0;
    lis.each(function(){
      if ($(this).is(':visible')) {
        tabsWidth += $(this).outerWidth(true);
      } else {
        numHidden++;
      }
    });
    var bw = $(el).find('div.tabs-buttons').outerWidth(true);
    if ((tabsWidth < el.width() - bw) && (lis.length === 0 || lis.first().is(':visible'))) {
      el.find('div.tabs-buttons').hide();
    } else {
      el.find('div.tabs-buttons').show().children('button.tab-left').toggleClass('disabled', numHidden == 0);
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

function showModal(id, width, title) {
  var el = $('#'+id).first();
  if (el.length === 0 || el.is(':visible')) {return;}
  if (!title) title = el.find('h3.title').text();
  // moves existing modals behind the transparent background
  $(".modal").css('zIndex',99);
  el.dialog({
    width: width,
    modal: true,
    resizable: false,
    dialogClass: 'modal',
    title: title
  }).on('dialogclose', function(){
    $(".modal").css('zIndex',101);
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
    var el = $('#'+id);

    if (el.hasClass('open')) {
        collapseScmEntry(id);
        el.find('.expander').switchClass('icon-expanded', 'icon-collapsed');
        el.addClass('collapsed');
        updateSVGIcon(el.find('.icon-folder')[0], 'folder')

        return false;
    } else if (el.hasClass('loaded')) {
        expandScmEntry(id);
        el.find('.expander').switchClass('icon-collapsed', 'icon-expanded');
        el.removeClass('collapsed');
        updateSVGIcon(el.find('.icon-folder-open')[0], 'folder-open')

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
        updateSVGIcon(el.find('.icon-folder')[0], 'folder-open')
        el.find('.expander').switchClass('icon-collapsed', 'icon-expanded');
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

function copyTextToClipboard(target) {
  if (target) {
    var temp = document.createElement('textarea');
    temp.value = target.getAttribute('data-clipboard-text');
    document.body.appendChild(temp);
    temp.select();
    document.execCommand('copy');
    if (temp.parentNode) {
      temp.parentNode.removeChild(temp);
    }
    if ($(target).closest('.drdn.expanded').length) {
      $(target).closest('.drdn.expanded').removeClass("expanded");
    }
  }
  return false;
}

function updateIssueFrom(url, el) {
  $('#all_attributes input, #all_attributes textarea, #all_attributes select').each(function(){
    $(this).data('valuebeforeupdate', $(this).val());
  });
  if (el) {
    $("#form_update_triggered_by").val($(el).attr('id'));
  }
  return $.ajax({
    url: url,
    type: 'post',
    data: $('#issue-form').serialize()
  });
}

function replaceIssueFormWith(html){
  var replacement = $(html);
  $('#all_attributes input, #all_attributes textarea, #all_attributes select').each(function(){
    var object_id = $(this).attr('id');
    if (object_id && $(this).data('valuebeforeupdate')!=$(this).val()) {
      replacement.find('#'+object_id).val($(this).val());
    }
  });
  $('#all_attributes').empty();
  $('#all_attributes').prepend(replacement);
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
      position: {collision: "flipfit"},
      search: function(){$('#'+fieldId).addClass('ajax-loading');},
      response: function(){$('#'+fieldId).removeClass('ajax-loading');}
    }, options));
    $('#'+fieldId).addClass('autocomplete');
  });
}

function multipleAutocompleteField(fieldId, url, options) {
  function split(val) {
    return val.split(/,\s*/);
  }

  function extractLast(term) {
    return split(term).pop();
  }

  $(document).ready(function () {
    $('#' + fieldId).autocomplete($.extend({
      source: function (request, response) {
        $.getJSON(url, {
          term: extractLast(request.term)
        }, response);
      },
      minLength: 2,
      position: {collision: "flipfit"},
      search: function () {
        $('#' + fieldId).addClass('ajax-loading');
      },
      response: function () {
        $('#' + fieldId).removeClass('ajax-loading');
      },
      select: function (event, ui) {
        var terms = split(this.value);
        // remove the current input
        terms.pop();
        // add the selected item
        terms.push(ui.item.value);
        // add placeholder to get the comma-and-space at the end
        terms.push("");
        this.value = terms.join(", ");
        return false;
      }
    }, options));
    $('#' + fieldId).addClass('autocomplete');
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

$(document).ready(function(){
  $(".drdn .autocomplete").val('');

  // This variable is used to focus selected project
  var selected;
  $(document).on('click', '.drdn-trigger', function(e){
    var drdn = $(this).closest(".drdn");
    if (drdn.hasClass("expanded")) {
      drdn.removeClass("expanded");
    } else {
      $(".drdn").removeClass("expanded");
      drdn.addClass("expanded");
      if ($(this).parent('#project-jump').length) {
        selected = $('.drdn-items a.selected'); // Store selected project
        selected.focus(); // Calling focus to scroll to selected project
      }
      if (!isMobile()) {
        drdn.find(".autocomplete").focus();
      }
      e.stopPropagation();
    }
  });
  $(document).click(function(e){
    if ($(e.target).closest(".drdn").length < 1) {
      $(".drdn.expanded").removeClass("expanded");
    }
  });

  observeSearchfield('projects-quick-search', null, $('#projects-quick-search').data('automcomplete-url'));

  $(".drdn-content").keydown(function(event){
    var items = $(this).find(".drdn-items");

    // If a project is selected set focused to selected only once
    if (selected && selected.length > 0) {
      var focused = selected;
      selected = undefined;
    }
    else {
      var focused = items.find("a:focus");
    }
    switch (event.which) {
    case 40: //down
      if (focused.length > 0) {
        focused.nextAll("a").first().focus();;
      } else {
        items.find("a").first().focus();;
      }
      event.preventDefault();
      break;
    case 38: //up
      if (focused.length > 0) {
        var prev = focused.prevAll("a");
        if (prev.length > 0) {
          prev.first().focus();
        } else {
          $(this).find(".autocomplete").focus();
        }
        event.preventDefault();
      }
      break;
    case 35: //end
      if (focused.length > 0) {
        focused.nextAll("a").last().focus();
        event.preventDefault();
      }
      break;
    case 36: //home
      if (focused.length > 0) {
        focused.prevAll("a").last().focus();
        event.preventDefault();
      }
      break;
    }
  });
});

function beforeShowDatePicker(input, inst) {
  var default_date = null;
  switch ($(input).attr("id")) {
    case "issue_start_date" :
      if ($("#issue_due_date").length > 0) {
        default_date = $("#issue_due_date").val();
      }
      break;
    case "issue_due_date" :
      if ($("#issue_start_date").length > 0) {
        var start_date = $("#issue_start_date").val();
        if (start_date != "") {
          start_date = new Date(Date.parse(start_date));
          if (start_date > new Date()) {
            default_date = $("#issue_start_date").val();
          }
        }
      }
      break;
  }
  $(input).datepickerFallback("option", "defaultDate", default_date);
}

(function($){
  $.fn.positionedItems = function(sortableOptions, options){
    var settings = $.extend({
      firstPosition: 1
    }, options );

    return this.sortable($.extend({
      axis: 'y',
      handle: ".sort-handle",
      helper: function(event, ui){
        ui.children('td').each(function(){
          $(this).width($(this).width());
        });
        return ui;
      },
      update: function(event, ui) {
        var sortable = $(this);
        var handle = ui.item.find(".sort-handle").addClass("ajax-loading");
        var url = handle.data("reorder-url");
        var param = handle.data("reorder-param");
        var data = {};
        data[param] = {position: ui.item.index() + settings['firstPosition']};
        $.ajax({
          url: url,
          type: 'put',
          dataType: 'script',
          data: data,
          error: function(jqXHR, textStatus, errorThrown){
            alert(jqXHR.status);
            sortable.sortable("cancel");
          },
          complete: function(jqXHR, textStatus, errorThrown){
            handle.removeClass("ajax-loading");
          }
        });
      },
    }, sortableOptions));
  }
}( jQuery ));

var warnLeavingUnsavedMessage;
function warnLeavingUnsaved(message) {
  warnLeavingUnsavedMessage = message;
  $(document).on('submit', 'form', function(){
    $('textarea').removeData('changed');
  });
  $(document).on('change', 'textarea', function(){
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
  $(document).bind('ajaxSend', function(event, xhr, settings) {
    if ($('.ajax-loading').length === 0 && settings.contentType != 'application/octet-stream') {
      $('#ajax-indicator').show();
    }
  });
  $(document).bind('ajaxStop', function() {
    $('#ajax-indicator').hide();
  });
}

function setupTabs() {
  if($('.tabs').length > 0) {
    displayTabsButtons();
    $(window).resize(displayTabsButtons);
  }
}

function setupFilePreviewNavigation() {
  // only bind arrow keys when preview navigation is present
  const element = $('.pagination.filepreview').first();
  if (element) {

    const handleArrowKey = function(selector, e){
      const href = $(element).find(selector).attr('href');
      if (href) {
        window.location = href;
        e.preventDefault();
      }
    };

    $(document).keydown(function(e) {
      if(e.shiftKey || e.metaKey || e.ctrlKey || e.altKey) return;
      switch(e.key) {
        case 'ArrowLeft':
          handleArrowKey('.previous a', e);
          break;

        case 'ArrowRight':
          handleArrowKey('.next a', e);
          break;
      }
    });
  }
}

$(document).on('keydown', 'form textarea', function(e) {
  // Submit the form with Ctrl + Enter or Command + Return
  var targetForm = $(e.target).closest('form');
  if(e.keyCode == 13 && ((e.ctrlKey && !e.metaKey) || (!e.ctrlKey && e.metaKey) && targetForm.length)) {
    // For ajax, use click() instead of submit() to prevent "Invalid form authenticity token" error
    if (targetForm.attr('data-remote') == 'true') {
      if (targetForm.find('input[type=submit]').length === 0) { return false; }
      targetForm.find('textarea').blur().removeData('changed');
      targetForm.find('input[type=submit]').first().click();
    } else {
      targetForm.find('textarea').blur().removeData('changed');
      targetForm.submit();
    }
  }
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

function defaultFocus(){
  if (($('#content :focus').length == 0) && (window.location.hash == '')) {
    $('#content input[type=text]:visible, #content textarea:visible').first().focus();
  }
}

function blockEventPropagation(event) {
  event.stopPropagation();
  event.preventDefault();
}

function toggleDisabledOnChange() {
  var checked = $(this).is(':checked');
  $($(this).data('disables')).attr('disabled', checked);
  $($(this).data('enables')).attr('disabled', !checked);
  $($(this).data('shows')).toggle(checked);
}
function toggleDisabledInit() {
  $('input[data-disables], input[data-enables], input[data-shows]').each(toggleDisabledOnChange);
}
function toggleMultiSelectIconInit() {
  $('.toggle-multiselect:not(.icon-toggle-minus), .toggle-multiselect:not(.icon-toggle-plus)').each(function(){
    if ($(this).siblings('select').find('option:selected').length > 1){
      $(this).addClass('icon-toggle-minus');
    } else {
      $(this).addClass('icon-toggle-plus');
    }
  });
}

function toggleNewObjectDropdown() {
  var dropdown = $('#new-object + ul.menu-children');
  if(dropdown.hasClass('visible')){
    dropdown.removeClass('visible');
  }else{
    dropdown.addClass('visible');
  }
}

(function ( $ ) {

  // detect if native date input is supported
  var nativeDateInputSupported = true;

  var input = document.createElement('input');
  input.setAttribute('type','date');
  if (input.type === 'text') {
    nativeDateInputSupported = false;
  }

  var notADateValue = 'not-a-date';
  input.setAttribute('value', notADateValue);
  if (input.value === notADateValue) {
    nativeDateInputSupported = false;
  }

  $.fn.datepickerFallback = function( options ) {
    if (nativeDateInputSupported) {
      return this;
    } else {
      return this.datepicker( options );
    }
  };
}( jQuery ));

$(document).ready(function(){
  $('#content').on('change', 'input[data-disables], input[data-enables], input[data-shows]', toggleDisabledOnChange);
  toggleDisabledInit();

  $('#content').on('click', '.toggle-multiselect', function() {
    toggleMultiSelect($(this).siblings('select'));
    $(this).toggleClass('icon-toggle-plus icon-toggle-minus');
  });
  toggleMultiSelectIconInit();

  $('#history .tabs').on('click', 'a', function(e){
    var tab = $(e.target).attr('id').replace('tab-','');
    document.cookie = 'history_last_tab=' + tab + '; SameSite=Lax'
  });
});

$(document).ready(function(){
  $('#content').on('click', 'div.jstTabs a.tab-preview', function(event){
    var tab = $(event.target);

    var url = tab.data('url');
    var form = tab.parents('form');
    var jstBlock = tab.parents('.jstBlock');

    var element = encodeURIComponent(jstBlock.find('.wiki-edit').val());
    var attachments = form.find('.attachments_fields input').serialize();

    $.ajax({
      url: url,
      type: 'post',
      data: "text=" + element + '&' + attachments,
      success: function(data){
        jstBlock.find('.wiki-preview').html(data);
        setupWikiTableSortableHeader();
      }
    });
  });
});

function keepAnchorOnSignIn(form){
  var hash = decodeURIComponent(self.document.location.hash);
  if (hash) {
    if (hash.indexOf("#") === -1) {
      hash = "#" + hash;
    }
    form.action = form.action + hash;
  }
  return true;
}

$(function ($) {
  $('#auth_source_ldap_mode').change(function () {
    $('.ldaps_warning').toggle($(this).val() != 'ldaps_verify_peer');
  }).change();
});

function setFilecontentContainerHeight() {
  var $filecontainer = $('.filecontent-container');
  var fileTypeSelectors = ['.image', 'video'];

  if($filecontainer.length > 0 && $filecontainer.find(fileTypeSelectors.join(',')).length === 1) {
    var containerOffsetTop = $filecontainer.offset().top;
    var containerMarginBottom = parseInt($filecontainer.css('marginBottom'));
    var paginationHeight = $filecontainer.next('.pagination').height();
    var diff = containerOffsetTop + containerMarginBottom + paginationHeight;

    $filecontainer.css('height', 'calc(100vh - ' + diff + 'px)')
  }
}

function setupAttachmentDetail() {
  setFilecontentContainerHeight();
  $(window).resize(setFilecontentContainerHeight);
}

function setupWikiTableSortableHeader() {
  $('div.wiki table').each(function(i, table){
    if (table.rows.length < 3) return true;
    var tr = $(table.rows).first();
    if (tr.find("TH").length > 0) {
      tr.attr('data-sort-method', 'none');
      tr.find("TD").attr('data-sort-method', 'none');
      new Tablesort(table);
    }
  });
}

$(function () {
  $("[title]:not(.no-tooltip)").tooltip({
    show: {
      delay: 400
    },
    position: {
      my: "center bottom-5",
      at: "center top"
    }
  });
});

function inlineAutoComplete(element) {
    'use strict';

    // do not attach if Tribute is already initialized
    if (element.dataset.tribute === 'true') {return};

    const getDataSource = function(entity) {
      const dataSources = rm.AutoComplete.dataSources;

      if (dataSources[entity]) {
        return dataSources[entity];
      } else {
        return false;
      }
    }

    const remoteSearch = function(url, cb) {
      const xhr = new XMLHttpRequest();
      xhr.onreadystatechange = function ()
      {
        if (xhr.readyState === 4) {
          if (xhr.status === 200) {
            var data = JSON.parse(xhr.responseText);
            cb(data);
          } else if (xhr.status === 403) {
            cb([]);
          }
        }
      };
      xhr.open("GET", url, true);
      xhr.send();
    };

    const tribute = new Tribute({
      collection: [
        {
          trigger: '#',
          values: function (text, cb) {
            if (event.target.type === 'text' && element.getAttribute('autocomplete') != 'off') {
              element.setAttribute('autocomplete', 'off');
            }
            // When triggered with text starting with "##", like "##a", the search term will become "#a",
            // causing the SQL query to fail in finding issues with "a" in the subject.
            // To avoid this, remove the first "#" from the search term.
            if (text) {
              text = text.replace(/^#/, '');
            }
            remoteSearch(getDataSource('issues') + encodeURIComponent(text), function (issues) {
              return cb(issues);
            });
          },
          lookup: 'label',
          fillAttr: 'label',
          requireLeadingSpace: true,
          selectTemplate: function (issue) {
            let leadingHash = "#"
            // keep ## syntax which is a valid issue syntax to show issue with title.
            if (this.currentMentionTextSnapshot.charAt(0) === "#") {
              leadingHash = "##"
            }
            return leadingHash + issue.original.id;
          },
          menuItemTemplate: function (issue) {
            return sanitizeHTML(issue.original.label);
          }
        },
        {
          trigger: '[[',
          values: function (text, cb) {
            remoteSearch(getDataSource('wiki_pages') + encodeURIComponent(text), function (wikiPages) {
              return cb(wikiPages);
            });
          },
          lookup: 'label',
          fillAttr: 'label',
          requireLeadingSpace: true,
          selectTemplate: function (wikiPage) {
            return '[[' + wikiPage.original.value + ']]';
          },
          menuItemTemplate: function (wikiPage) {
            return sanitizeHTML(wikiPage.original.label);
          }
        },
        {
          trigger: '@',
          lookup: function (user, mentionText) {
            return user.name + user.firstname + user.lastname + user.login;
          },
          values: function (text, cb) {
            const url = getDataSource('users');
            if (url) {
              remoteSearch(url + encodeURIComponent(text), function (users) {
                return cb(users);
              });
            }
          },
          menuItemTemplate: function (user) {
            return user.original.name;
          },
          selectTemplate: function (user) {
            return '@' + user.original.login;
          }
        }
      ],
      noMatchTemplate: ""
    });

    tribute.attach(element);
}

// collapsible sidebar jQuery plugin
(function($) {
  // main container this is applied to
  var main;
  // triggers show/hide
  var button;
  // the key to use in local storage
  // this will later be expanded using the current controller and action to
  // allow for different sidebar states for different pages
  var localStorageKey = 'redmine-sidebar-state';
  // true if local storage is available
  var canUseLocalStorage = function(){
    try {
      if('localStorage' in window){
        localStorage.setItem('redmine.test.storage', 'ok');
        var item = localStorage.getItem('redmine.test.storage');
        localStorage.removeItem('redmine.test.storage');
        if(item === 'ok') return true;
      }
    } catch (err) {}
    return false;
  }();
  // function to set current sidebar state
  var setState = function(state){
    if(canUseLocalStorage){
      localStorage.setItem(localStorageKey, state);
    }
  };
  var applyState = function(){
    if(main.hasClass('collapsedsidebar')){
      updateSVGIcon(document.getElementById('sidebar-switch-button'), 'chevrons-left')
      setState('hidden');
    } else {
      updateSVGIcon(document.getElementById('sidebar-switch-button'), 'chevrons-right')
      setState('visible');
    }
  };
  var setupToggleButton = function(){
    button = $('#sidebar-switch-button');
    button.click(function(e){
      main.addClass("animate");
      main.toggleClass('collapsedsidebar');
      applyState();
      e.preventDefault();
      return false;
    });
    applyState();
  };
  $.fn.collapsibleSidebar = function() {
    main = this;
    // determine previously stored sidebar state for this page
    if(canUseLocalStorage) {
      // determine current controller/action pair and use them as storage key
      var bodyClass = $('body').attr('class');
      if(bodyClass){
        try {
          localStorageKey += '-' + bodyClass.split(/\s+/).filter(function(s){
            return s.match(/(action|controller)-.*/);
          }).sort().join('-');
        } catch(e) {
          // in case of error (probably IE8), continue with the unmodified key
        }
      }
      var storedState = localStorage.getItem(localStorageKey);
      main.toggleClass('collapsedsidebar', storedState === 'hidden');
    }
    // draw the toggle button once the DOM is complete
    $(document).ready(setupToggleButton);
  };
}(jQuery));

$(document).ready(setupAjaxIndicator);
$(document).ready(hideOnLoad);
$(document).ready(addFormObserversForDoubleSubmit);
$(document).ready(defaultFocus);
$(document).ready(setupAttachmentDetail);
$(document).ready(setupTabs);
$(document).ready(setupFilePreviewNavigation);
$(document).ready(setupWikiTableSortableHeader);
$(document).on('focus', '[data-auto-complete=true]', function(event) {
  inlineAutoComplete(event.target);
});
