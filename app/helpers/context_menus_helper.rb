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

module ContextMenusHelper
  def context_menu_link(name, url, options={})
    options[:class] ||= ''
    if options.delete(:selected)
      options[:class] << ' icon-checked disabled'
      options[:disabled] = true
    end
    if options.delete(:disabled)
      options.delete(:method)
      options.delete(:data)
      options[:onclick] = 'return false;'
      options[:class] << ' disabled'
      url = '#'
    end
    link_to h(name), url, options
  end

  def bulk_update_custom_field_context_menu_link(field, text, value)
    context_menu_link h(text),
      bulk_update_issues_path(:ids => @issue_ids, :issue => {'custom_field_values' => {field.id => value}}, :back_url => @back),
      :method => :post,
      :selected => (@issue && @issue.custom_field_value(field) == value)
  end

  def bulk_update_time_entry_custom_field_context_menu_link(field, text, value)
    context_menu_link h(text),
      bulk_update_time_entries_path(:ids => @time_entries.map(&:id).sort, :time_entry => {'custom_field_values' => {field.id => value}}, :back_url => @back),
      :method => :post,
      :selected => (@time_entry && @time_entry.custom_field_value(field) == value)
  end
end
