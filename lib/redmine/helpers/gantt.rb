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

module Redmine
  module Helpers
    # Simple class to handle gantt chart data
    class Gantt
      class MaxLinesLimitReached < StandardError
      end

      include ERB::Util
      include Redmine::I18n
      include Redmine::Utils::DateCalculation

      # Relation types that are rendered
      DRAW_TYPES = {
        IssueRelation::TYPE_BLOCKS   => {:landscape_margin => 16, :color => '#F34F4F'},
        IssueRelation::TYPE_PRECEDES => {:landscape_margin => 20, :color => '#628FEA'}
      }.freeze

      UNAVAILABLE_COLUMNS = [:tracker, :id, :subject]

      # Some utility methods for the PDF export
      # @private
      class PDF
        MaxCharactorsForSubject = 45
        TotalWidth = 280
        LeftPaneWidth = 100

        def self.right_pane_width
          TotalWidth - LeftPaneWidth
        end
      end

      attr_reader :year_from, :month_from, :date_from, :date_to, :zoom, :months, :truncated, :max_rows
      attr_accessor :query
      attr_accessor :project
      attr_accessor :view

      def initialize(options={})
        options = options.dup
        if options[:year] && options[:year].to_i >0
          @year_from = options[:year].to_i
          if options[:month] && options[:month].to_i >=1 && options[:month].to_i <= 12
            @month_from = options[:month].to_i
          else
            @month_from = 1
          end
        else
          @month_from ||= User.current.today.month
          @year_from ||= User.current.today.year
        end
        zoom = (options[:zoom] || User.current.pref[:gantt_zoom]).to_i
        @zoom = (zoom > 0 && zoom < 5) ? zoom : 2
        months = (options[:months] || User.current.pref[:gantt_months]).to_i
        @months = (months > 0 && months < Setting.gantt_months_limit.to_i + 1) ? months : 6
        # Save gantt parameters as user preference (zoom and months count)
        if User.current.logged? &&
             (@zoom   != User.current.pref[:gantt_zoom] ||
              @months != User.current.pref[:gantt_months])
          User.current.pref[:gantt_zoom], User.current.pref[:gantt_months] = @zoom, @months
          User.current.preference.save
        end
        @date_from = Date.civil(@year_from, @month_from, 1)
        @date_to = (@date_from >> @months) - 1
        @subjects = +''
        @lines = +''
        @columns ||= {}
        @number_of_rows = nil
        @truncated = false
        if options.has_key?(:max_rows)
          @max_rows = options[:max_rows]
        else
          @max_rows = Setting.gantt_items_limit.blank? ? nil : Setting.gantt_items_limit.to_i
        end
      end

      def common_params
        {:controller => 'gantts', :action => 'show', :project_id => @project}
      end

      def params
        common_params.merge({:zoom => zoom, :year => year_from,
                             :month => month_from, :months => months})
      end

      def params_previous
        common_params.merge({:year => (date_from << months).year,
                             :month => (date_from << months).month,
                             :zoom => zoom, :months => months})
      end

      def params_next
        common_params.merge({:year => (date_from >> months).year,
                             :month => (date_from >> months).month,
                             :zoom => zoom, :months => months})
      end

      # Returns the number of rows that will be rendered on the Gantt chart
      def number_of_rows
        return @number_of_rows if @number_of_rows

        rows = projects.inject(0) {|total, p| total += number_of_rows_on_project(p)}
        rows > @max_rows ? @max_rows : rows
      end

      # Returns the number of rows that will be used to list a project on
      # the Gantt chart.  This will recurse for each subproject.
      def number_of_rows_on_project(project)
        return 0 unless projects.include?(project)

        count = 1
        count += project_issues(project).size
        count += project_versions(project).size
        count
      end

      # Renders the subjects of the Gantt chart, the left side.
      def subjects(options={})
        render(options.merge(:only => :subjects)) unless @subjects_rendered
        @subjects
      end

      # Renders the lines of the Gantt chart, the right side
      def lines(options={})
        render(options.merge(:only => :lines)) unless @lines_rendered
        @lines
      end

      # Renders the selected column of the Gantt chart, the right side of subjects.
      def selected_column_content(options={})
        render(options.merge(:only => :selected_columns)) unless @columns.has_key?(options[:column].name)
        @columns[options[:column].name]
      end

      # Returns issues that will be rendered
      def issues
        @issues ||= @query.issues(
          :order => ["#{Project.table_name}.lft ASC", "#{Issue.table_name}.id ASC"],
          :limit => @max_rows
        )
      end

      # Returns a hash of the relations between the issues that are present on the gantt
      # and that should be displayed, grouped by issue ids.
      def relations
        return @relations if @relations

        if issues.any?
          issue_ids = issues.map(&:id)
          @relations = IssueRelation.
            where(:issue_from_id => issue_ids, :issue_to_id => issue_ids, :relation_type => DRAW_TYPES.keys).
            group_by(&:issue_from_id)
        else
          @relations = {}
        end
      end

      # Return all the project nodes that will be displayed
      def projects
        return @projects if @projects

        ids = issues.collect(&:project).uniq.collect(&:id)
        if ids.any?
          # All issues projects and their visible ancestors
          @projects = Project.visible.
            joins("LEFT JOIN #{Project.table_name} child ON #{Project.table_name}.lft <= child.lft AND #{Project.table_name}.rgt >= child.rgt").
            where("child.id IN (?)", ids).
            order("#{Project.table_name}.lft ASC").
            distinct.
            to_a
        else
          @projects = []
        end
      end

      # Returns the issues that belong to +project+
      def project_issues(project)
        @issues_by_project ||= issues.group_by(&:project)
        @issues_by_project[project] || []
      end

      # Returns the distinct versions of the issues that belong to +project+
      def project_versions(project)
        project_issues(project).collect(&:fixed_version).compact.uniq
      end

      # Returns the issues that belong to +project+ and are assigned to +version+
      def version_issues(project, version)
        project_issues(project).select {|issue| issue.fixed_version == version}
      end

      def render(options={})
        options = {:top => 0, :top_increment => 20,
                   :indent_increment => 20, :render => :subject,
                   :format => :html}.merge(options)
        indent = options[:indent] || 4
        @subjects = +'' unless options[:only] == :lines || options[:only] == :selected_columns
        @lines = +'' unless options[:only] == :subjects || options[:only] == :selected_columns
        @columns[options[:column].name] = +'' if options[:only] == :selected_columns && @columns.has_key?(options[:column]) == false
        @number_of_rows = 0
        begin
          Project.project_tree(projects) do |project, level|
            options[:indent] = indent + level * options[:indent_increment]
            render_project(project, options)
          end
        rescue MaxLinesLimitReached
          @truncated = true
        end
        @subjects_rendered = true unless options[:only] == :lines || options[:only] == :selected_columns
        @lines_rendered = true unless options[:only] == :subjects || options[:only] == :selected_columns
        render_end(options)
      end

      def render_project(project, options={})
        render_object_row(project, options)
        increment_indent(options) do
          # render issue that are not assigned to a version
          issues = project_issues(project).select {|i| i.fixed_version.nil?}
          render_issues(issues, options)
          # then render project versions and their issues
          versions = project_versions(project)
          self.class.sort_versions!(versions)
          versions.each do |version|
            render_version(project, version, options)
          end
        end
      end

      def render_version(project, version, options={})
        render_object_row(version, options)
        increment_indent(options) do
          issues = version_issues(project, version)
          render_issues(issues, options)
        end
      end

      def render_issues(issues, options={})
        self.class.sort_issues!(issues)
        ancestors = []
        issues.each do |issue|
          while ancestors.any? && !issue.is_descendant_of?(ancestors.last)
            ancestors.pop
            decrement_indent(options)
          end
          render_object_row(issue, options)
          unless issue.leaf?
            ancestors << issue
            increment_indent(options)
          end
        end
        decrement_indent(options, ancestors.size)
      end

      def render_object_row(object, options)
        class_name = object.class.name.downcase
        send("subject_for_#{class_name}", object, options) unless options[:only] == :lines || options[:only] == :selected_columns
        send("line_for_#{class_name}", object, options) unless options[:only] == :subjects || options[:only] == :selected_columns
        column_content_for_issue(object, options) if options[:only] == :selected_columns && options[:column].present? && object.is_a?(Issue)
        options[:top] += options[:top_increment]
        @number_of_rows += 1
        if @max_rows && @number_of_rows >= @max_rows
          raise MaxLinesLimitReached
        end
      end

      def render_end(options={})
        case options[:format]
        when :pdf
          options[:pdf].Line(15, options[:top], PDF::TotalWidth, options[:top])
        end
      end

      def increment_indent(options, factor=1)
        options[:indent] += options[:indent_increment] * factor
        if block_given?
          yield
          decrement_indent(options, factor)
        end
      end

      def decrement_indent(options, factor=1)
        increment_indent(options, -factor)
      end

      def subject_for_project(project, options)
        subject(project.name, options, project)
      end

      def line_for_project(project, options)
        # Skip projects that don't have a start_date or due date
        if project.is_a?(Project) && project.start_date && project.due_date
          label = project.name
          line(project.start_date, project.due_date, nil, true, label, options, project)
        end
      end

      def subject_for_version(version, options)
        subject(version.to_s_with_project, options, version)
      end

      def line_for_version(version, options)
        # Skip versions that don't have a start_date
        if version.is_a?(Version) && version.due_date && version.start_date
          label = "#{h(version)} #{h(version.visible_fixed_issues.completed_percent.to_f.round)}%"
          label = h("#{version.project} -") + label unless @project && @project == version.project
          line(version.start_date, version.due_date,
               version.visible_fixed_issues.completed_percent,
               true, label, options, version)
        end
      end

      def subject_for_issue(issue, options)
        subject(issue.subject, options, issue)
      end

      def line_for_issue(issue, options)
        # Skip issues that don't have a due_before (due_date or version's due_date)
        if issue.is_a?(Issue) && issue.due_before
          label = issue.status.name.dup
          unless issue.disabled_core_fields.include?('done_ratio')
            label << " #{issue.done_ratio}%"
          end
          markers = !issue.leaf?
          line(issue.start_date, issue.due_before, issue.done_ratio, markers, label, options, issue)
        end
      end

      def column_content_for_issue(issue, options)
        if options[:format] == :html
          data_options = {}
          data_options[:collapse_expand] = "issue-#{issue.id}"
          data_options[:number_of_rows] = number_of_rows
          style = "position: absolute;top: #{options[:top]}px; font-size: 0.8em;"
          content =
            view.content_tag(
              :div, view.column_content(options[:column], issue),
              :style => style, :class => "issue_#{options[:column].name}",
              :id => "#{options[:column].name}_issue_#{issue.id}",
              :data => data_options
            )
          @columns[options[:column].name] << content if @columns.has_key?(options[:column].name)
          content
        end
      end

      def subject(label, options, object=nil)
        send "#{options[:format]}_subject", options, label, object
      end

      def line(start_date, end_date, done_ratio, markers, label, options, object=nil)
        options[:zoom] ||= 1
        options[:g_width] ||= (self.date_to - self.date_from + 1) * options[:zoom]
        coords = coordinates(start_date, end_date, done_ratio, options[:zoom])
        send "#{options[:format]}_task", options, coords, markers, label, object
      end

      # Generates a gantt image
      # Only defined if MiniMagick is avalaible
      def to_image(format='PNG')
        date_to = (@date_from >> @months) - 1
        show_weeks = @zoom > 1
        show_days = @zoom > 2
        subject_width = 400
        header_height = 18
        # width of one day in pixels
        zoom = @zoom * 2
        g_width = (@date_to - @date_from + 1) * zoom
        g_height = 20 * number_of_rows + 30
        headers_height = (show_weeks ? 2 * header_height : header_height)
        height = g_height + headers_height
        # TODO: Remove rmagick_font_path in a later version
        unless Redmine::Configuration['rmagick_font_path'].nil?
          Rails.logger.warn(
            'rmagick_font_path option is deprecated. Use minimagick_font_path instead.'
          )
        end
        font_path =
          Redmine::Configuration['minimagick_font_path'].presence ||
            Redmine::Configuration['rmagick_font_path'].presence
        img = MiniMagick::Image.create(".#{format}", false)
        if Redmine::Configuration['imagemagick_convert_command'].present?
          MiniMagick.cli_path = File.dirname(Redmine::Configuration['imagemagick_convert_command'])
        end
        MiniMagick::Tool::Convert.new do |gc|
          gc.size('%dx%d' % [subject_width + g_width + 1, height])
          gc.xc('white')
          gc.font(font_path) if font_path.present?
          # Subjects
          gc.stroke('transparent')
          subjects(:image => gc, :top => (headers_height + 20), :indent => 4, :format => :image)
          # Months headers
          month_f = @date_from
          left = subject_width
          @months.times do
            width = ((month_f >> 1) - month_f) * zoom
            gc.fill('white')
            gc.stroke('grey')
            gc.strokewidth(1)
            gc.draw('rectangle %d,%d %d,%d' % [
              left, 0, left + width, height
            ])
            gc.fill('black')
            gc.stroke('transparent')
            gc.strokewidth(1)
            gc.draw('text %d,%d %s' % [
              left.round + 8, 14, magick_text("#{month_f.year}-#{month_f.month}")
            ])
            left = left + width
            month_f = month_f >> 1
          end
          # Weeks headers
          if show_weeks
            left = subject_width
            height = header_height
            if @date_from.cwday == 1
              # date_from is monday
              week_f = date_from
            else
              # find next monday after date_from
              week_f = @date_from + (7 - @date_from.cwday + 1)
              width = (7 - @date_from.cwday + 1) * zoom
              gc.fill('white')
              gc.stroke('grey')
              gc.strokewidth(1)
              gc.draw('rectangle %d,%d %d,%d' % [
                left, header_height, left + width, 2 * header_height + g_height - 1
              ])
              left = left + width
            end
            while week_f <= date_to
              width = (week_f + 6 <= date_to) ? 7 * zoom : (date_to - week_f + 1) * zoom
              gc.fill('white')
              gc.stroke('grey')
              gc.strokewidth(1)
              gc.draw('rectangle %d,%d %d,%d' % [
                left.round, header_height, left.round + width, 2 * header_height + g_height - 1
              ])
              gc.fill('black')
              gc.stroke('transparent')
              gc.strokewidth(1)
              gc.draw('text %d,%d %s' % [
                left.round + 2, header_height + 14, magick_text(week_f.cweek.to_s)
              ])
              left = left + width
              week_f = week_f + 7
            end
          end
          # Days details (week-end in grey)
          if show_days
            left = subject_width
            height = g_height + header_height - 1
            (@date_from..date_to).each do |g_date|
              width =  zoom
              gc.fill(non_working_week_days.include?(g_date.cwday) ? '#eee' : 'white')
              gc.stroke('#ddd')
              gc.strokewidth(1)
              gc.draw('rectangle %d,%d %d,%d' % [
                left, 2 * header_height, left + width, 2 * header_height + g_height - 1
              ])
              left = left + width
            end
          end
          # border
          gc.fill('transparent')
          gc.stroke('grey')
          gc.strokewidth(1)
          gc.draw('rectangle %d,%d %d,%d' % [
            0, 0, subject_width + g_width, headers_height
          ])
          gc.stroke('black')
          gc.draw('rectangle %d,%d %d,%d' % [
            0, 0, subject_width + g_width, g_height + headers_height - 1
          ])
          # content
          top = headers_height + 20
          gc.stroke('transparent')
          lines(:image => gc, :top => top, :zoom => zoom,
                :subject_width => subject_width, :format => :image)
          # today red line
          if User.current.today >= @date_from and User.current.today <= date_to
            gc.stroke('red')
            x = (User.current.today - @date_from + 1) * zoom + subject_width
            gc.draw('line %g,%g %g,%g' % [
              x, headers_height, x, headers_height + g_height - 1
            ])
          end
          gc << img.path
        end
        img.to_blob
      ensure
        img.destroy! if img
      end if Object.const_defined?(:MiniMagick)

      def to_pdf
        pdf = ::Redmine::Export::PDF::ITCPDF.new(current_language)
        pdf.SetTitle("#{l(:label_gantt)} #{project}")
        pdf.alias_nb_pages
        pdf.footer_date = format_date(User.current.today)
        pdf.AddPage("L")
        pdf.SetFontStyle('B', 12)
        pdf.SetX(15)
        pdf.RDMCell(PDF::LeftPaneWidth, 20, project.to_s)
        pdf.Ln
        pdf.SetFontStyle('B', 9)
        subject_width = PDF::LeftPaneWidth
        header_height = 5
        headers_height = header_height
        show_weeks = false
        show_days = false
        if self.months < 7
          show_weeks = true
          headers_height = 2 * header_height
          if self.months < 3
            show_days = true
            headers_height = 3 * header_height
            if self.months < 2
              show_day_num = true
              headers_height = 4 * header_height
            end
          end
        end
        g_width = PDF.right_pane_width
        zoom = g_width / (self.date_to - self.date_from + 1)
        g_height = 120
        t_height = g_height + headers_height
        y_start = pdf.GetY
        # Months headers
        month_f = self.date_from
        left = subject_width
        height = header_height
        self.months.times do
          width = ((month_f >> 1) - month_f) * zoom
          pdf.SetY(y_start)
          pdf.SetX(left)
          pdf.RDMCell(width, height, "#{month_f.year}-#{month_f.month}", "LTR", 0, "C")
          left = left + width
          month_f = month_f >> 1
        end
        # Weeks headers
        if show_weeks
          left = subject_width
          height = header_height
          if self.date_from.cwday == 1
            # self.date_from is monday
            week_f = self.date_from
          else
            # find next monday after self.date_from
            week_f = self.date_from + (7 - self.date_from.cwday + 1)
            width = (7 - self.date_from.cwday + 1) * zoom-1
            pdf.SetY(y_start + header_height)
            pdf.SetX(left)
            pdf.RDMCell(width + 1, height, "", "LTR")
            left = left + width + 1
          end
          while week_f <= self.date_to
            width = (week_f + 6 <= self.date_to) ? 7 * zoom : (self.date_to - week_f + 1) * zoom
            pdf.SetY(y_start + header_height)
            pdf.SetX(left)
            pdf.RDMCell(width, height, (width >= 5 ? week_f.cweek.to_s : ""), "LTR", 0, "C")
            left = left + width
            week_f = week_f + 7
          end
        end
        # Day numbers headers
        if show_day_num
          left = subject_width
          height = header_height
          day_num = self.date_from
          pdf.SetFontStyle('B', 7)
          (self.date_from..self.date_to).each do |g_date|
            width = zoom
            pdf.SetY(y_start + header_height * 2)
            pdf.SetX(left)
            pdf.SetTextColor(non_working_week_days.include?(g_date.cwday) ? 150 : 0)
            pdf.RDMCell(width, height, day_num.day.to_s, "LTR", 0, "C")
            left = left + width
            day_num = day_num + 1
          end
        end
        # Days headers
        if show_days
          left = subject_width
          height = header_height
          pdf.SetFontStyle('B', 7)
          (self.date_from..self.date_to).each do |g_date|
            width = zoom
            pdf.SetY(y_start + header_height * (show_day_num ? 3 : 2))
            pdf.SetX(left)
            pdf.SetTextColor(non_working_week_days.include?(g_date.cwday) ? 150 : 0)
            pdf.RDMCell(width, height, day_name(g_date.cwday).first, "LTR", 0, "C")
            left = left + width
          end
        end
        pdf.SetY(y_start)
        pdf.SetX(15)
        pdf.SetTextColor(0)
        pdf.RDMCell(subject_width + g_width - 15, headers_height, "", 1)
        # Tasks
        top = headers_height + y_start
        options = {
          :top => top,
          :zoom => zoom,
          :subject_width => subject_width,
          :g_width => g_width,
          :indent => 0,
          :indent_increment => 5,
          :top_increment => 5,
          :format => :pdf,
          :pdf => pdf
        }
        render(options)
        pdf.Output
      end

      private

      def coordinates(start_date, end_date, progress, zoom=nil)
        zoom ||= @zoom
        coords = {}
        if start_date && end_date && start_date <= self.date_to && end_date >= self.date_from
          if start_date >= self.date_from
            coords[:start] = start_date - self.date_from
            coords[:bar_start] = start_date - self.date_from
          else
            coords[:bar_start] = 0
          end
          if end_date <= self.date_to
            coords[:end] = end_date - self.date_from + 1
            coords[:bar_end] = end_date - self.date_from + 1
          else
            coords[:bar_end] = self.date_to - self.date_from + 1
          end
          if progress
            progress_date = calc_progress_date(start_date, end_date, progress)
            if progress_date > self.date_from && progress_date > start_date
              if progress_date < self.date_to
                coords[:bar_progress_end] = progress_date - self.date_from
              else
                coords[:bar_progress_end] = self.date_to - self.date_from + 1
              end
            end
            if progress_date <= User.current.today
              late_date = [User.current.today, end_date].min + 1
              if late_date > self.date_from && late_date > start_date
                if late_date < self.date_to
                  coords[:bar_late_end] = late_date - self.date_from
                else
                  coords[:bar_late_end] = self.date_to - self.date_from + 1
                end
              end
            end
          end
        end
        # Transforms dates into pixels witdh
        coords.each_key do |key|
          coords[key] = (coords[key] * zoom).floor
        end
        coords
      end

      def calc_progress_date(start_date, end_date, progress)
        start_date + (end_date - start_date + 1) * (progress / 100.0)
      end

      # Singleton class method is public
      class << self
        def sort_issues!(issues)
          issues.sort_by! {|issue| sort_issue_logic(issue)}
        end

        def sort_issue_logic(issue)
          julian_date = Date.new
          ancesters_start_date = []
          current_issue = issue
          begin
            ancesters_start_date.unshift([current_issue.start_date || julian_date, current_issue.id])
            current_issue = current_issue.parent
          end while (current_issue)
          ancesters_start_date
        end

        def sort_versions!(versions)
          versions.sort!
        end
      end

      def pdf_new_page?(options)
        if options[:top] > 180
          options[:pdf].Line(15, options[:top], PDF::TotalWidth, options[:top])
          options[:pdf].AddPage("L")
          options[:top] = 15
          options[:pdf].Line(15, options[:top] - 0.1, PDF::TotalWidth, options[:top] - 0.1)
        end
      end

      def html_subject_content(object)
        case object
        when Issue
          issue = object
          css_classes = +''
          css_classes << ' issue-overdue' if issue.overdue?
          css_classes << ' issue-behind-schedule' if issue.behind_schedule?
          css_classes << ' icon icon-issue' unless Setting.gravatar_enabled? && issue.assigned_to
          css_classes << ' issue-closed' if issue.closed?
          if issue.start_date && issue.due_before && issue.done_ratio
            progress_date = calc_progress_date(issue.start_date,
                                               issue.due_before, issue.done_ratio)
            css_classes << ' behind-start-date' if progress_date < self.date_from
            css_classes << ' over-end-date' if progress_date > self.date_to && issue.done_ratio > 0
          end
          s = (+"").html_safe
          s << view.assignee_avatar(issue.assigned_to, :size => 13, :class => 'icon-gravatar')
          s << view.link_to_issue(issue).html_safe
          s << view.content_tag(:input, nil, :type => 'checkbox', :name => 'ids[]',
                                :value => issue.id, :style => 'display:none;',
                                :class => 'toggle-selection')
          view.content_tag(:span, s, :class => css_classes).html_safe
        when Version
          version = object
          html_class = +""
          html_class << 'icon icon-package '
          html_class << (version.behind_schedule? ? 'version-behind-schedule' : '') << " "
          html_class << (version.overdue? ? 'version-overdue' : '')
          html_class << ' version-closed' unless version.open?
          if version.start_date && version.due_date && version.visible_fixed_issues.completed_percent
            progress_date = calc_progress_date(version.start_date,
                                               version.due_date, version.visible_fixed_issues.completed_percent)
            html_class << ' behind-start-date' if progress_date < self.date_from
            html_class << ' over-end-date' if progress_date > self.date_to && version.visible_fixed_issues.completed_percent > 0
          end
          s = view.link_to_version(version).html_safe
          view.content_tag(:span, s, :class => html_class).html_safe
        when Project
          project = object
          html_class = +""
          html_class << 'icon icon-projects '
          html_class << (project.overdue? ? 'project-overdue' : '')
          s = view.link_to_project(project).html_safe
          view.content_tag(:span, s, :class => html_class).html_safe
        end
      end

      def html_subject(params, subject, object)
        content = html_subject_content(object) || subject
        tag_options = {}
        case object
        when Issue
          tag_options[:id] = "issue-#{object.id}"
          tag_options[:class] = "issue-subject hascontextmenu"
          tag_options[:title] = object.subject
          children = object.children & project_issues(object.project)
          has_children =
            children.present? &&
              (children.collect(&:fixed_version).uniq & [object.fixed_version]).present?
        when Version
          tag_options[:id] = "version-#{object.id}"
          tag_options[:class] = "version-name"
          has_children = object.fixed_issues.exists?
        when Project
          tag_options[:class] = "project-name"
          has_children = object.issues.exists? || object.versions.exists?
        end
        if object
          tag_options[:data] = {
            :collapse_expand => {
              :top_increment => params[:top_increment],
              :obj_id => "#{object.class}-#{object.id}".downcase,
            },
            :number_of_rows => number_of_rows,
          }
        end
        if has_children
          content = view.content_tag(:span, nil, :class => 'icon icon-expanded expander') + content
          tag_options[:class] += ' open'
        else
          if params[:indent]
            params = params.dup
            params[:indent] += 12
          end
        end
        style = "position: absolute;top:#{params[:top]}px;left:#{params[:indent]}px;"
        style += "width:#{params[:subject_width] - params[:indent]}px;" if params[:subject_width]
        tag_options[:style] = style
        output = view.content_tag(:div, content, tag_options)
        @subjects << output
        output
      end

      def pdf_subject(params, subject, options={})
        pdf_new_page?(params)
        params[:pdf].SetY(params[:top])
        params[:pdf].SetX(15)
        char_limit = PDF::MaxCharactorsForSubject - params[:indent]
        params[:pdf].RDMCell(params[:subject_width] - 15, 5,
                             (" " * params[:indent]) +
                               subject.to_s.sub(/^(.{#{char_limit}}[^\s]*\s).*$/, '\1 (...)'),
                             "LR")
        params[:pdf].SetY(params[:top])
        params[:pdf].SetX(params[:subject_width])
        params[:pdf].RDMCell(params[:g_width], 5, "", "LR")
      end

      def image_subject(params, subject, options={})
        params[:image].fill('black')
        params[:image].stroke('transparent')
        params[:image].strokewidth(1)
        params[:image].draw('text %d,%d %s' % [
          params[:indent], params[:top] + 2, magick_text(subject)
        ])
      end

      def issue_relations(issue)
        rels = {}
        if relations[issue.id]
          relations[issue.id].each do |relation|
            (rels[relation.relation_type] ||= []) << relation.issue_to_id
          end
        end
        rels
      end

      def html_task(params, coords, markers, label, object)
        output = +''
        data_options = {}
        if object
          data_options[:collapse_expand] = "#{object.class}-#{object.id}".downcase
          data_options[:number_of_rows] = number_of_rows
        end
        css = "task " +
          case object
          when Project
            "project"
          when Version
            "version"
          when Issue
            object.leaf? ? 'leaf' : 'parent'
          else
            ""
          end
        # Renders the task bar, with progress and late
        if coords[:bar_start] && coords[:bar_end]
          width = coords[:bar_end] - coords[:bar_start] - 2
          style = +""
          style << "top:#{params[:top]}px;"
          style << "left:#{coords[:bar_start]}px;"
          style << "width:#{width}px;"
          html_id = "task-todo-issue-#{object.id}" if object.is_a?(Issue)
          html_id = "task-todo-version-#{object.id}" if object.is_a?(Version)
          content_opt = {:style => style,
                         :class => "#{css} task_todo",
                         :id => html_id,
                         :data => {}}
          if object.is_a?(Issue)
            rels = issue_relations(object)
            if rels.present?
              content_opt[:data] = {"rels" => rels.to_json}
            end
          end
          content_opt[:data].merge!(data_options)
          output << view.content_tag(:div, '&nbsp;'.html_safe, content_opt)
          if coords[:bar_late_end]
            width = coords[:bar_late_end] - coords[:bar_start] - 2
            style = +""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:bar_start]}px;"
            style << "width:#{width}px;"
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{css} task_late",
                                       :data => data_options)
          end
          if coords[:bar_progress_end]
            width = coords[:bar_progress_end] - coords[:bar_start] - 2
            style = +""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:bar_start]}px;"
            style << "width:#{width}px;"
            html_id = "task-done-issue-#{object.id}" if object.is_a?(Issue)
            html_id = "task-done-version-#{object.id}" if object.is_a?(Version)
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{css} task_done",
                                       :id => html_id,
                                       :data => data_options)
          end
        end
        # Renders the markers
        if markers
          if coords[:start]
            style = +""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:start]}px;"
            style << "width:15px;"
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{css} marker starting",
                                       :data => data_options)
          end
          if coords[:end]
            style = +""
            style << "top:#{params[:top]}px;"
            style << "left:#{coords[:end]}px;"
            style << "width:15px;"
            output << view.content_tag(:div, '&nbsp;'.html_safe,
                                       :style => style,
                                       :class => "#{css} marker ending",
                                       :data => data_options)
          end
        end
        # Renders the label on the right
        if label
          style = +""
          style << "top:#{params[:top]}px;"
          style << "left:#{(coords[:bar_end] || 0) + 8}px;"
          style << "width:15px;"
          output << view.content_tag(:div, label,
                                     :style => style,
                                     :class => "#{css} label",
                                     :data => data_options)
        end
        # Renders the tooltip
        if object.is_a?(Issue) && coords[:bar_start] && coords[:bar_end]
          s = view.content_tag(:span,
                               view.render_issue_tooltip(object).html_safe,
                               :class => "tip")
          s += view.content_tag(:input, nil, :type => 'checkbox', :name => 'ids[]',
                                :value => object.id, :style => 'display:none;',
                                :class => 'toggle-selection')
          style = +""
          style << "position: absolute;"
          style << "top:#{params[:top]}px;"
          style << "left:#{coords[:bar_start]}px;"
          style << "width:#{coords[:bar_end] - coords[:bar_start]}px;"
          style << "height:12px;"
          output << view.content_tag(:div, s.html_safe,
                                     :style => style,
                                     :class => "tooltip hascontextmenu",
                                     :data => data_options)
        end
        @lines << output
        output
      end

      def pdf_task(params, coords, markers, label, object)
        cell_height_ratio = params[:pdf].get_cell_height_ratio
        params[:pdf].set_cell_height_ratio(0.1)

        height = 2
        height /= 2 if markers
        # Renders the task bar, with progress and late
        if coords[:bar_start] && coords[:bar_end]
          width = [1, coords[:bar_end] - coords[:bar_start]].max
          params[:pdf].SetY(params[:top] + 1.5)
          params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
          params[:pdf].SetFillColor(200, 200, 200)
          params[:pdf].RDMCell(width, height, "", 0, 0, "", 1)
          if coords[:bar_late_end]
            width = [1, coords[:bar_late_end] - coords[:bar_start]].max
            params[:pdf].SetY(params[:top] + 1.5)
            params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
            params[:pdf].SetFillColor(255, 100, 100)
            params[:pdf].RDMCell(width, height, "", 0, 0, "", 1)
          end
          if coords[:bar_progress_end]
            width = [1, coords[:bar_progress_end] - coords[:bar_start]].max
            params[:pdf].SetY(params[:top] + 1.5)
            params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
            params[:pdf].SetFillColor(90, 200, 90)
            params[:pdf].RDMCell(width, height, "", 0, 0, "", 1)
          end
        end
        # Renders the markers
        if markers
          if coords[:start]
            params[:pdf].SetY(params[:top] + 1)
            params[:pdf].SetX(params[:subject_width] + coords[:start] - 1)
            params[:pdf].SetFillColor(50, 50, 200)
            params[:pdf].RDMCell(2, 2, "", 0, 0, "", 1)
          end
          if coords[:end]
            params[:pdf].SetY(params[:top] + 1)
            params[:pdf].SetX(params[:subject_width] + coords[:end] - 1)
            params[:pdf].SetFillColor(50, 50, 200)
            params[:pdf].RDMCell(2, 2, "", 0, 0, "", 1)
          end
        end
        # Renders the label on the right
        if label
          params[:pdf].SetX(params[:subject_width] + (coords[:bar_end] || 0) + 5)
          params[:pdf].RDMCell(30, 2, label)
        end

        params[:pdf].set_cell_height_ratio(cell_height_ratio)
      end

      def image_task(params, coords, markers, label, object)
        height = 6
        height /= 2 if markers
        # Renders the task bar, with progress and late
        if coords[:bar_start] && coords[:bar_end]
          params[:image].fill('#aaa')
          params[:image].draw('rectangle %d,%d %d,%d' % [
            params[:subject_width] + coords[:bar_start],
            params[:top],
            params[:subject_width] + coords[:bar_end],
            params[:top] - height
          ])
          if coords[:bar_late_end]
            params[:image].fill('#f66')
            params[:image].draw('rectangle %d,%d %d,%d' % [
              params[:subject_width] + coords[:bar_start],
              params[:top],
              params[:subject_width] + coords[:bar_late_end],
              params[:top] - height
            ])
          end
          if coords[:bar_progress_end]
            params[:image].fill('#00c600')
            params[:image].draw('rectangle %d,%d %d,%d' % [
              params[:subject_width] + coords[:bar_start],
              params[:top],
              params[:subject_width] + coords[:bar_progress_end],
              params[:top] - height
            ])
          end
        end
        # Renders the markers
        if markers
          if coords[:start]
            x = params[:subject_width] + coords[:start]
            y = params[:top] - height / 2
            params[:image].fill('blue')
            params[:image].draw('polygon %d,%d %d,%d %d,%d %d,%d' % [
              x - 4, y,
              x, y - 4,
              x + 4, y,
              x, y + 4
            ])
          end
          if coords[:end]
            x = params[:subject_width] + coords[:end]
            y = params[:top] - height / 2
            params[:image].fill('blue')
            params[:image].draw('polygon %d,%d %d,%d %d,%d %d,%d' % [
              x - 4, y,
              x, y - 4,
              x + 4, y,
              x, y + 4
            ])
          end
        end
        # Renders the label on the right
        if label
          params[:image].fill('black')
          params[:image].draw('text %d,%d %s' % [
            params[:subject_width] + (coords[:bar_end] || 0) + 5,
            params[:top] + 1,
            magick_text(label)
          ])
        end
      end

      # Escape the passed string as a text argument in a draw rule for
      # mini_magick. Note that the returned string is not shell-safe on its own.
      def magick_text(str)
        "'#{str.to_s.gsub(/['\\]/, '\\\\\0')}'"
      end
    end
  end
end
