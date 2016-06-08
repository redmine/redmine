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

module Redmine
  module Helpers
    class TimeReport
      attr_reader :criteria, :columns, :hours, :total_hours, :periods

      def initialize(project, issue, criteria, columns, time_entry_scope)
        @project = project
        @issue = issue

        @criteria = criteria || []
        @criteria = @criteria.select{|criteria| available_criteria.has_key? criteria}
        @criteria.uniq!
        @criteria = @criteria[0,3]

        @columns = (columns && %w(year month week day).include?(columns)) ? columns : 'month'
        @scope = time_entry_scope

        run
      end

      def available_criteria
        @available_criteria || load_available_criteria
      end

      private

      def run
        unless @criteria.empty?
          time_columns = %w(tyear tmonth tweek spent_on)
          @hours = []
          @scope.includes(:issue, :activity).
              group(@criteria.collect{|criteria| @available_criteria[criteria][:sql]} + time_columns).
              joins(@criteria.collect{|criteria| @available_criteria[criteria][:joins]}.compact).
              sum(:hours).each do |hash, hours|
            h = {'hours' => hours}
            (@criteria + time_columns).each_with_index do |name, i|
              h[name] = hash[i]
            end
            @hours << h
          end
          
          @hours.each do |row|
            case @columns
            when 'year'
              row['year'] = row['tyear']
            when 'month'
              row['month'] = "#{row['tyear']}-#{row['tmonth']}"
            when 'week'
              row['week'] = "#{row['spent_on'].cwyear}-#{row['tweek']}"
            when 'day'
              row['day'] = "#{row['spent_on']}"
            end
          end
          
          min = @hours.collect {|row| row['spent_on']}.min
          @from = min ? min.to_date : User.current.today

          max = @hours.collect {|row| row['spent_on']}.max
          @to = max ? max.to_date : User.current.today
          
          @total_hours = @hours.inject(0) {|s,k| s = s + k['hours'].to_f}

          @periods = []
          # Date#at_beginning_of_ not supported in Rails 1.2.x
          date_from = @from.to_time
          # 100 columns max
          while date_from <= @to.to_time && @periods.length < 100
            case @columns
            when 'year'
              @periods << "#{date_from.year}"
              date_from = (date_from + 1.year).at_beginning_of_year
            when 'month'
              @periods << "#{date_from.year}-#{date_from.month}"
              date_from = (date_from + 1.month).at_beginning_of_month
            when 'week'
              @periods << "#{date_from.to_date.cwyear}-#{date_from.to_date.cweek}"
              date_from = (date_from + 7.day).at_beginning_of_week
            when 'day'
              @periods << "#{date_from.to_date}"
              date_from = date_from + 1.day
            end
          end
        end
      end

      def load_available_criteria
        @available_criteria = { 'project' => {:sql => "#{TimeEntry.table_name}.project_id",
                                              :klass => Project,
                                              :label => :label_project},
                                 'status' => {:sql => "#{Issue.table_name}.status_id",
                                              :klass => IssueStatus,
                                              :label => :field_status},
                                 'version' => {:sql => "#{Issue.table_name}.fixed_version_id",
                                              :klass => Version,
                                              :label => :label_version},
                                 'category' => {:sql => "#{Issue.table_name}.category_id",
                                                :klass => IssueCategory,
                                                :label => :field_category},
                                 'user' => {:sql => "#{TimeEntry.table_name}.user_id",
                                             :klass => User,
                                             :label => :label_user},
                                 'tracker' => {:sql => "#{Issue.table_name}.tracker_id",
                                              :klass => Tracker,
                                              :label => :label_tracker},
                                 'activity' => {:sql => "#{TimeEntry.table_name}.activity_id",
                                               :klass => TimeEntryActivity,
                                               :label => :label_activity},
                                 'issue' => {:sql => "#{TimeEntry.table_name}.issue_id",
                                             :klass => Issue,
                                             :label => :label_issue}
                               }

        # Add time entry custom fields
        custom_fields = TimeEntryCustomField.all
        # Add project custom fields
        custom_fields += ProjectCustomField.all
        # Add issue custom fields
        custom_fields += (@project.nil? ? IssueCustomField.for_all : @project.all_issue_custom_fields)
        # Add time entry activity custom fields
        custom_fields += TimeEntryActivityCustomField.all

        # Add list and boolean custom fields as available criteria
        custom_fields.select {|cf| %w(list bool).include?(cf.field_format) && !cf.multiple?}.each do |cf|
          @available_criteria["cf_#{cf.id}"] = {:sql => cf.group_statement,
                                                 :joins => cf.join_for_order_statement,
                                                 :format => cf.field_format,
                                                 :custom_field => cf,
                                                 :label => cf.name}
        end

        @available_criteria
      end
    end
  end
end
