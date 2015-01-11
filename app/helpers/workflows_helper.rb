# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module WorkflowsHelper
  def options_for_workflow_select(name, objects, selected, options={})
    option_tags = ''.html_safe
    multiple = false
    if selected 
      if selected.size == objects.size
        selected = 'all'
      else
        selected = selected.map(&:id)
        if selected.size > 1
          multiple = true
        end
      end
    else
      selected = objects.first.try(:id)
    end
    all_tag_options = {:value => 'all', :selected => (selected == 'all')}
    if multiple
      all_tag_options.merge!(:style => "display:none;")
    end
    option_tags << content_tag('option', l(:label_all), all_tag_options)
    option_tags << options_from_collection_for_select(objects, "id", "name", selected)
    select_tag name, option_tags, {:multiple => multiple}.merge(options)
  end

  def field_required?(field)
    field.is_a?(CustomField) ? field.is_required? : %w(project_id tracker_id subject priority_id is_private).include?(field)
  end

  def field_permission_tag(permissions, status, field, roles)
    name = field.is_a?(CustomField) ? field.id.to_s : field
    options = [["", ""], [l(:label_readonly), "readonly"]]
    options << [l(:label_required), "required"] unless field_required?(field)
    html_options = {}
    
    if perm = permissions[status.id][name]
      if perm.uniq.size > 1 || perm.size < @roles.size * @trackers.size
        options << [l(:label_no_change_option), "no_change"]
        selected = 'no_change'
      else
        selected = perm.first
      end
    end

    hidden = field.is_a?(CustomField) &&
      !field.visible? &&
      !roles.detect {|role| role.custom_fields.to_a.include?(field)}

    if hidden
      options[0][0] = l(:label_hidden)
      selected = ''
      html_options[:disabled] = true
    end

    select_tag("permissions[#{status.id}][#{name}]", options_for_select(options, selected), html_options)
  end

  def transition_tag(workflows, old_status, new_status, name)
    w = workflows.select {|w| w.old_status_id == old_status.id && w.new_status_id == new_status.id}.size
    
    tag_name = "transitions[#{ old_status.id }][#{new_status.id}][#{name}]"
    if w == 0 || w == @roles.size * @trackers.size
      
      hidden_field_tag(tag_name, "0", :id => nil) +
      check_box_tag(tag_name, "1", w != 0,
            :class => "old-status-#{old_status.id} new-status-#{new_status.id}")
    else
      select_tag tag_name,
        options_for_select([
            [l(:general_text_Yes), "1"],
            [l(:general_text_No), "0"],
            [l(:label_no_change_option), "no_change"]
          ], "no_change")
    end
  end
end
