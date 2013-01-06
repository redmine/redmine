# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
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

module StatusHelper


  # Renders a table of project statuses
  def render_status_table(projects)
    s = ''
    if projects.any?
      ancestors = []
      original_project = @project

      status_types = ["", "NeuroML v1.x", "NeuroML v2.x", "PyNN", "NEURON", "GENESIS 2", "MOOSE", "PSICS", "NEST", "Brian"]

      s << "<table  class='list'>\n"
      s << "<thead>\n"

      status_types.each do |status_type|
        link = ""
        case status_type
          when "NeuroML v1.x", "NeuroML v2.x", "PyNN"
            link = "#{status_type}"
          else
            link = "<a href='/projects/simulators/wiki/Wiki/##{status_type}'>#{status_type}</a>"
        end
        s << "<td>#{link}</td>\n"
      end

      s << "</thead>\n"


      projects.each do |project|

        show_this = 0
        alt_text = ""
        
        project.visible_custom_field_values.each do |custom_value|
	      if (custom_value.custom_field.name == 'Category')
            if (custom_value.value == 'Project' || custom_value.value == 'Showcase')
              show_this = 1
            end
          end
	      if (custom_value.custom_field.name == 'Status info')
              alt_text = " title='#{custom_value.value}'"
          end
        end
        
        if (show_this == 1)
          # set the project environment to please macros.
          @project = project

          s << "<tr>\n"
          status_types.each do |status_type|

            if status_type == ""
                s << "<td><a href='/projects/#{project.identifier}'#{alt_text}=>#{project.identifier}</a></td>"
            else
              project.visible_custom_field_values.each do |custom_value|
                if (custom_value.custom_field.name == status_type+' support')
                  s << "<td><img src='images/status_sm#{custom_value.value}.png' alt=' '/></td>"
                end
              end
            end
          end
          s << "</tr>\n"

        end

      end

      s << "</table>\n"



      @project = original_project
    end
    s.html_safe
  end


end
