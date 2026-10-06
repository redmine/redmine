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
  class ChartLayout
    # A calendar period displayed in the timeline header.
    Period = Struct.new(
      # The first date of the period, or nil for a leading partial week
      :date,
      # The period width in pixels
      :width,
      # Whether the period represents a non-working day
      :non_working,
      # Whether the period's grid line extends through the chart body
      :spans_body,
      # Whether the period is the last one in its header row
      :last,
      keyword_init: true
    )

    # The height of one timeline header row in pixels
    attr_reader :header_height
    # The combined height of all visible header rows in pixels
    attr_reader :headers_height
    # The gap between the header and the first chart row in pixels
    attr_reader :content_top
    # The subject pane width used to render its rows in pixels
    attr_reader :subject_width
    # The number of pixels representing one day
    attr_reader :zoom

    def initialize(gantt)
      @gantt = gantt
      @zoom = 2**gantt.zoom
      @subject_width = 330
      @header_height = 18
      @content_top = 8
      @headers_height = header_rows * header_height
    end

    # The full timeline width in pixels
    def chart_width
      @chart_width ||= begin
        days_in_range = (@gantt.date_to - @gantt.date_from + 1).to_i
        days_in_range * zoom
      end
    end

    def content_height
      @content_height ||= begin
        row_height = 20
        extra_rows = 6
        bottom_padding = 150
        minimum_height = 206

        # Preserve the extra space and minimum height from the original template.
        rows_height = row_height * (@gantt.number_of_rows + extra_rows)
        [rows_height + bottom_padding, minimum_height].max
      end
    end

    def pane_height
      headers_height + content_height
    end

    def months
      date = @gantt.date_from

      Array.new(@gantt.months) do |index|
        next_month = date.next_month
        days_in_month = (next_month - date).to_i
        period = Period.new(
          date: date,
          width: days_in_month * zoom,
          spans_body: !show_weeks?,
          last: index == @gantt.months - 1
        )
        date = next_month
        period
      end
    end

    def weeks
      return [] unless show_weeks?

      date = @gantt.date_from
      periods = []
      unless date.monday?
        week_end = date.end_of_week(:monday)
        remaining_days = (week_end - date + 1).to_i
        # A leading partial week has no week-number label.
        periods << Period.new(
          date: nil,
          width: remaining_days * zoom,
          spans_body: !show_days?,
          last: week_end >= @gantt.date_to
        )
        date = date.next_week(:monday)
      end

      while date <= @gantt.date_to
        week_end = [date.end_of_week(:monday), @gantt.date_to].min
        days_in_week = (week_end - date + 1).to_i
        periods << Period.new(
          date: date,
          width: days_in_week * zoom,
          spans_body: !show_days?,
          last: week_end == @gantt.date_to
        )
        date = date.next_week(:monday)
      end
      periods
    end

    def day_numbers
      return [] unless show_day_numbers?

      day_periods
    end

    def days
      return [] unless show_days?

      day_periods(spans_body: true)
    end

    def today_start
      today = User.current.today
      return unless today.between?(@gantt.date_from, @gantt.date_to)

      days_through_today = (today - @gantt.date_from + 1).to_i
      # Place the line at the last pixel of the current day.
      days_through_today * zoom - 1
    end

    def show_weeks?
      @gantt.zoom > 1
    end

    def show_days?
      @gantt.zoom > 2
    end

    def show_day_numbers?
      @gantt.zoom > 3
    end

    private

    def header_rows
      # The month header is always displayed.
      1 + [show_weeks?, show_days?, show_day_numbers?].count(true)
    end

    def day_periods(spans_body: false)
      (@gantt.date_from..@gantt.date_to).map do |date|
        Period.new(
          date: date,
          width: zoom,
          non_working: @gantt.non_working_week_days.include?(date.cwday),
          spans_body: spans_body,
          last: date == @gantt.date_to
        )
      end
    end
  end

  def gantt_css_variables(variables)
    variables.map {|name, value| "--#{name}:#{value}"}.join(';')
  end

  def gantt_period_style(period)
    gantt_css_variables(
      'gantt-period-width': "#{period.width}px"
    )
  end

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

  def gantt_chart_tag(query, layout, &block)
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

    style = gantt_css_variables(
      'gantt-subject-width': "#{layout.subject_width + 1}px",
      'gantt-header-height': "#{layout.header_height}px",
      'gantt-headers-height': "#{layout.headers_height}px",
      'gantt-chart-width': "#{layout.chart_width}px",
      'gantt-content-top': "#{layout.content_top}px",
      'gantt-content-height': "#{layout.content_height}px",
      'gantt-pane-height': "#{layout.pane_height}px"
    )

    tag.div(class: 'gantt-chart', style: style, data: data_attributes) do
      capture(layout, &block)
    end
  end

  def gantt_column_tag(column_name, min_width: nil, **options, &)
    options[:data] = {
      controller: 'gantt--column',
      action: 'resize@window->gantt--column#handleWindowResize',
      'gantt--column-min-width-value': min_width,
      'gantt--column-column-value': column_name
    }
    options[:class] = ["gantt_#{column_name}_column", options[:class]]

    options[:style] = gantt_css_variables('gantt-column-width': options.delete(:width)) if options[:width]

    tag.div(**options, &)
  end

  def gantt_subjects_tag(&)
    data_attributes = {
      controller: 'gantt--subjects',
      action: 'gantt--column:resize-column-subjects@document->gantt--subjects#handleResizeColumn'
    }
    tag.div(class: "gantt_subjects", data: data_attributes, &)
  end
end
