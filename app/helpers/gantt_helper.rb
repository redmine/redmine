# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

module GanttHelper
  def gantt_zoom_link(gantt, in_or_out)
    case in_or_out
    when :in
      if gantt.zoom < 4
        link_to(
          sprite_icon('zoom-in', l(:text_zoom_in)),
          {:params => request.query_parameters.merge(gantt.params.merge(:zoom => (gantt.zoom + 1)))},
          :class => 'icon icon-zoom-in')
      else
        content_tag(:span, sprite_icon('zoom-in', l(:text_zoom_in)), :class => 'icon icon-zoom-in').html_safe
      end

    when :out
      if gantt.zoom > 1
        link_to(
          sprite_icon('zoom-out', l(:text_zoom_out)),
          {:params => request.query_parameters.merge(gantt.params.merge(:zoom => (gantt.zoom - 1)))},
          :class => 'icon icon-zoom-out')
      else
        content_tag(:span, sprite_icon('zoom-out', l(:text_zoom_out)), :class => 'icon icon-zoom-out').html_safe
      end
    end
  end

  def gantt_chart_tag(query, &)
    data_attributes = {
      controller: 'gantt--chart',
      # Events emitted by child controllers the chart listens to.
      # - `gantt--options` toggles checkboxes under Options.
      # - `gantt--subjects` reports tree expand/collapse.
      # - Window resize triggers a redraw of progress lines and relations.
      action: %w(
        gantt--options:toggle-display@document->gantt--chart#handleOptionsDisplay
        gantt--options:toggle-relations@document->gantt--chart#handleOptionsRelations
        gantt--options:toggle-progress@document->gantt--chart#handleOptionsProgress
        gantt--subjects:toggle-tree->gantt--chart#handleSubjectTreeChanged
        resize@window->gantt--chart#handleWindowResize
      ).join(' '),
      'gantt--chart-issue-relation-types-value': Redmine::Helpers::Gantt::DRAW_TYPES.to_json,
      'gantt--chart-show-selected-columns-value': query.draw_selected_columns ? 'true' : 'false',
      'gantt--chart-show-relations-value': query.draw_relations ? 'true' : 'false',
      'gantt--chart-show-progress-value': query.draw_progress_line ? 'true' : 'false'
    }

    tag.table(class: 'gantt-table', data: data_attributes, &)
  end

  def gantt_column_tag(column_name, min_width: nil, **options, &)
    options[:data] = {
      controller: 'gantt--column',
      action: 'resize@window->gantt--column#handleWindowResize',
      'gantt--column-min-width-value': min_width,
      'gantt--column-column-value': column_name
    }
    options[:class] = ["gantt_#{column_name}_column", options[:class]]

    tag.td(**options, &)
  end

  def gantt_subjects_tag(&)
    data_attributes = {
      controller: 'gantt--subjects',
      action: 'gantt--column:resize-column-subjects@document->gantt--subjects#handleResizeColumn'
    }
    tag.div(class: "gantt_subjects", data: data_attributes, &)
  end
end
