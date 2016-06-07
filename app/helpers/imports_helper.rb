# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

module ImportsHelper
  def options_for_mapping_select(import, field, options={})
    tags = "".html_safe
    blank_text = options[:required] ? "-- #{l(:actionview_instancetag_blank_option)} --" : "&nbsp;".html_safe
    tags << content_tag('option', blank_text, :value => '')
    tags << options_for_select(import.columns_options, import.mapping[field])
    if values = options[:values]
      tags << content_tag('option', '--', :disabled => true)
      tags << options_for_select(values.map {|text, value| [text, "value:#{value}"]}, import.mapping[field])
    end
    tags
  end

  def mapping_select_tag(import, field, options={})
    name = "import_settings[mapping][#{field}]"
    select_tag name, options_for_mapping_select(import, field, options), :id => "import_mapping_#{field}"
  end

  # Returns the options for the date_format setting
  def date_format_options
    Import::DATE_FORMATS.map do |f|
      format = f.gsub('%', '').gsub(/[dmY]/) do
        {'d' => 'DD', 'm' => 'MM', 'Y' => 'YYYY'}[$&]
      end
      [format, f]
    end
  end
end
