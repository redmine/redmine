/* Redmine - project management software
 * Copyright (C) 2006-2023  Jean-Philippe Lang
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA. */

$(document).ready(function() {
  /* 
  If we're viewing a tag or branch, don't display it in the
  revision box
  */
  var branch_selected = $('#branch').length > 0 && $('#rev').val() == $('#branch').val();
  var tag_selected = $('#tag').length > 0 && $('#rev').val() == $('#tag').val();
  if (branch_selected || tag_selected) {
    $('#rev').val('');
  }

  /* 
  Copy the branch/tag value into the revision box, then disable
  the dropdowns before submitting the form
  */
  $('#branch,#tag').change(function() {
    $('#rev').val($(this).val());
    $('#branch,#tag').attr('disabled', true);
    $(this).parent().submit();
    $('#branch,#tag').removeAttr('disabled');
  });

  /*
  Disable the branch/tag dropdowns before submitting the revision form
  */
  $('#rev').keydown(function(e) {
    if (e.keyCode == 13) {
      $('#branch,#tag').attr('disabled', true);
      $(this).parent().submit();
      $('#branch,#tag').removeAttr('disabled');
    }
  });
})
