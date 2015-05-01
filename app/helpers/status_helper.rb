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
  def render_status_table(projects, showosb, showuser)
    s = ''
    if projects.any?
      ancestors = []
      original_project = @project

      status_types = ["", "Curation", "NeuroML v1.x", "NeuroML v2.x", "PyNN", "NEURON", "GENESIS 2", "MOOSE", "PSICS", "NEST", "Brian", "OSB Model Validation"]

      #s << "Show OSB: #{showosb}, show user: #{showuser} "

      s << "<table  class='list'>\n"
      s << "<thead>\n"

      status_types.each do |status_type|
        link = ""
        case status_type
        when "Curation", "NeuroML v1.x", "NeuroML v2.x", "PyNN", "OSB Model Validation"
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
        endorsement = ""

        project.visible_custom_field_values.each do |custom_value|
          if (custom_value.custom_field.name == 'Category')
            if (custom_value.value == 'Project' || custom_value.value == 'Showcase')
              show_this = 1
            end
          end
        end

        if (show_this == 1)
            project.visible_custom_field_values.each do |custom_value|
              if (custom_value.custom_field.name == 'Endorsement')
                if (custom_value.value == '2')
                  endorsement = "<span class='label label-success tooltiplink' data-toggle='tooltip' data-placement='right' title='This project is endorsed by OSB and has been identified as fulfilling OSB best practices for projects.'>OSB+</span>"
                  if (show_this && (showosb == '1' || showosb == 'true'))
                    show_this = 1
                  else 
                    show_this = 0
                  end
                elsif (custom_value.value == '1')
                  endorsement = "<span class='label label-info tooltiplink' data-toggle='tooltip' data-placement='right' title='This project is endorsed by OSB and is officially supported.'>OSB</span>"
                  if (show_this && (showosb == '1' || showosb == 'true'))
                    show_this = 1
                  else 
                    show_this = 0
                  end
                else
                  endorsement = "<span class='label label-warning tooltiplink' data-toggle='tooltip' data-placement='right' title='This is a personal user project and has not yet been endorsed by OSB. Please get in contact (info@opensourcebrain.org) to have this project endorsed!'>User</span>"
                  if (show_this && (showuser == '1' || showuser == 'true'))
                    show_this = 1
                  else 
                    show_this = 0
                  end
                end
              end
              if (custom_value.custom_field.name == 'Status info')
                alt_text = " title='#{custom_value.value}'"  
              end
            end
        end

        if (show_this == 1)
          # set the project environment to please macros.
          @project = project

          s << "<tr>\n"
          status_types.each do |status_type|

            if status_type == ""
              s << "<td>#{endorsement} <a href='/projects/#{project.identifier}'#{alt_text}=>#{project.identifier}</a></td>"
            elsif status_type == "OSB Model Validation"
              if isFileInRepo(project.repository, ".travis.yml") and project.repository.scm_name != 'Mercurial'
                value = getCustomField(project, 'GitHub repository')
                urlBase = "https://travis-ci.org/"+ getGitRepoOwner(value) + '/'+ getGitRepoName(value)
                s << "<td><a alt='Click here for more information (Travis)' title='Click here for more information (Travis)' target='_blank' href='" + urlBase + "'><img src='" + urlBase + ".svg'/></a></td>"
              else
                s << "<td></td>"
              end
            else
              project.visible_custom_field_values.each do |custom_value|
                if (custom_value.custom_field.name == status_type+' support')
              
                  
                  value=getCustomField(project, custom_value.custom_field.name)
                  badges = getTooltipedBadgeAlign(project, custom_value.custom_field.name, '', 'How well can the curated NeuroML/PyNN version of the model be run in this simulator? '+getSupport(value), 'pull-left')
                  
                  s << "<td>  "+badges+"</td>"
                end
                if (custom_value.custom_field.name == status_type+' level')
                  s << "<td><img src='images/curation_sm#{custom_value.value}.png' alt=' '/></td>"
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
