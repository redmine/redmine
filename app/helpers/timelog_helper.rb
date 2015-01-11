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

module TimelogHelper
  include ApplicationHelper

  def render_timelog_breadcrumb
    links = []
    links << link_to(l(:label_project_all), {:project_id => nil, :issue_id => nil})
    links << link_to(h(@project), {:project_id => @project, :issue_id => nil}) if @project
    if @issue
      if @issue.visible?
        links << link_to_issue(@issue, :subject => false)
      else
        links << "##{@issue.id}"
      end
    end
    breadcrumb links
  end

  # Returns a collection of activities for a select field.  time_entry
  # is optional and will be used to check if the selected TimeEntryActivity
  # is active.
  def activity_collection_for_select_options(time_entry=nil, project=nil)
    project ||= @project
    if project.nil?
      activities = TimeEntryActivity.shared.active
    else
      activities = project.activities
    end

    collection = []
    if time_entry && time_entry.activity && !time_entry.activity.active?
      collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ]
    else
      collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ] unless activities.detect(&:is_default)
    end
    activities.each { |a| collection << [a.name, a.id] }
    collection
  end

  def select_hours(data, criteria, value)
    if value.to_s.empty?
      data.select {|row| row[criteria].blank? }
    else
      data.select {|row| row[criteria].to_s == value.to_s}
    end
  end

  def sum_hours(data)
    sum = 0
    data.each do |row|
      sum += row['hours'].to_f
    end
    sum
  end

  def format_criteria_value(criteria_options, value)
    if value.blank?
      "[#{l(:label_none)}]"
    elsif k = criteria_options[:klass]
      obj = k.find_by_id(value.to_i)
      if obj.is_a?(Issue)
        obj.visible? ? "#{obj.tracker} ##{obj.id}: #{obj.subject}" : "##{obj.id}"
      else
        obj
      end
    elsif cf = criteria_options[:custom_field]
      format_value(value, cf)
    else
      value.to_s
    end
  end

  def report_to_csv(report)
    decimal_separator = l(:general_csv_decimal_separator)
    export = CSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # Column headers
      headers = report.criteria.collect {|criteria| l(report.available_criteria[criteria][:label]) }
      headers += report.periods
      headers << l(:label_total_time)
      csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(
                                    c.to_s,
                                    l(:general_csv_encoding) ) }
      # Content
      report_criteria_to_csv(csv, report.available_criteria, report.columns, report.criteria, report.periods, report.hours)
      # Total row
      str_total = Redmine::CodesetUtil.from_utf8(l(:label_total_time), l(:general_csv_encoding))
      row = [ str_total ] + [''] * (report.criteria.size - 1)
      total = 0
      report.periods.each do |period|
        sum = sum_hours(select_hours(report.hours, report.columns, period.to_s))
        total += sum
        row << (sum > 0 ? ("%.2f" % sum).gsub('.',decimal_separator) : '')
      end
      row << ("%.2f" % total).gsub('.',decimal_separator)
      csv << row
    end
    export
  end

  def report_criteria_to_csv(csv, available_criteria, columns, criteria, periods, hours, level=0)
    decimal_separator = l(:general_csv_decimal_separator)
    hours.collect {|h| h[criteria[level]].to_s}.uniq.each do |value|
      hours_for_value = select_hours(hours, criteria[level], value)
      next if hours_for_value.empty?
      row = [''] * level
      row << Redmine::CodesetUtil.from_utf8(
                        format_criteria_value(available_criteria[criteria[level]], value).to_s,
                        l(:general_csv_encoding) )
      row += [''] * (criteria.length - level - 1)
      total = 0
      periods.each do |period|
        sum = sum_hours(select_hours(hours_for_value, columns, period.to_s))
        total += sum
        row << (sum > 0 ? ("%.2f" % sum).gsub('.',decimal_separator) : '')
      end
      row << ("%.2f" % total).gsub('.',decimal_separator)
      csv << row
      if criteria.length > level + 1
        report_criteria_to_csv(csv, available_criteria, columns, criteria, periods, hours_for_value, level + 1)
      end
    end
  end
end
