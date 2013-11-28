# -*- coding: utf-8 -*-
# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

require File.expand_path('../../test_helper', __FILE__)

class TimeEntryReportsControllerTest < ActionController::TestCase
  tests TimelogController

  fixtures :projects, :enabled_modules, :roles, :members, :member_roles,
           :issues, :time_entries, :users, :trackers, :enumerations,
           :issue_statuses, :custom_fields, :custom_values

  include Redmine::I18n

  def setup
    Setting.default_language = "en"
  end

  def test_report_at_project_level
    get :report, :project_id => 'ecookbook'
    assert_response :success
    assert_template 'report'
    assert_tag :form,
      :attributes => {:action => "/projects/ecookbook/time_entries/report", :id => 'query_form'}
  end

  def test_report_all_projects
    get :report
    assert_response :success
    assert_template 'report'
    assert_tag :form,
      :attributes => {:action => "/time_entries/report", :id => 'query_form'}
  end

  def test_report_all_projects_denied
    r = Role.anonymous
    r.permissions.delete(:view_time_entries)
    r.permissions_will_change!
    r.save
    get :report
    assert_redirected_to '/login?back_url=http%3A%2F%2Ftest.host%2Ftime_entries%2Freport'
  end

  def test_report_all_projects_one_criteria
    get :report, :columns => 'week', :from => "2007-04-01", :to => "2007-04-30", :criteria => ['project']
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:report)
    assert_equal "8.65", "%.2f" % assigns(:report).total_hours
  end

  def test_report_all_time
    get :report, :project_id => 1, :criteria => ['project', 'issue']
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:report)
    assert_equal "162.90", "%.2f" % assigns(:report).total_hours
  end

  def test_report_all_time_by_day
    get :report, :project_id => 1, :criteria => ['project', 'issue'], :columns => 'day'
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:report)
    assert_equal "162.90", "%.2f" % assigns(:report).total_hours
    assert_tag :tag => 'th', :content => '2007-03-12'
  end

  def test_report_one_criteria
    get :report, :project_id => 1, :columns => 'week', :from => "2007-04-01", :to => "2007-04-30", :criteria => ['project']
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:report)
    assert_equal "8.65", "%.2f" % assigns(:report).total_hours
  end

  def test_report_two_criteria
    get :report, :project_id => 1, :columns => 'month', :from => "2007-01-01", :to => "2007-12-31", :criteria => ["user", "activity"]
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:report)
    assert_equal "162.90", "%.2f" % assigns(:report).total_hours
  end

  def test_report_custom_field_criteria_with_multiple_values
    field = TimeEntryCustomField.create!(:name => 'multi', :field_format => 'list', :possible_values => ['value1', 'value2'])
    entry = TimeEntry.create!(:project => Project.find(1), :hours => 1, :activity_id => 10, :user => User.find(2), :spent_on => Date.today)
    CustomValue.create!(:customized => entry, :custom_field => field, :value => 'value1')
    CustomValue.create!(:customized => entry, :custom_field => field, :value => 'value2')

    get :report, :project_id => 1, :columns => 'day', :criteria => ["cf_#{field.id}"]
    assert_response :success
  end

  def test_report_one_day
    get :report, :project_id => 1, :columns => 'day', :from => "2007-03-23", :to => "2007-03-23", :criteria => ["user", "activity"]
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:report)
    assert_equal "4.25", "%.2f" % assigns(:report).total_hours
  end

  def test_report_at_issue_level
    get :report, :project_id => 1, :issue_id => 1, :columns => 'month', :from => "2007-01-01", :to => "2007-12-31", :criteria => ["user", "activity"]
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:report)
    assert_equal "154.25", "%.2f" % assigns(:report).total_hours
    assert_tag :form,
      :attributes => {:action => "/projects/ecookbook/issues/1/time_entries/report", :id => 'query_form'}
  end

  def test_report_by_week_should_use_commercial_year
    TimeEntry.delete_all
    TimeEntry.generate!(:hours => '2', :spent_on => '2009-12-25') # 2009-52
    TimeEntry.generate!(:hours => '4', :spent_on => '2009-12-31') # 2009-53
    TimeEntry.generate!(:hours => '8', :spent_on => '2010-01-01') # 2009-53
    TimeEntry.generate!(:hours => '16', :spent_on => '2010-01-05') # 2010-1

    get :report, :columns => 'week', :from => "2009-12-25", :to => "2010-01-05", :criteria => ["project"]
    assert_response :success

    assert_select '#time-report thead tr' do
      assert_select 'th:nth-child(1)', :text => 'Project'
      assert_select 'th:nth-child(2)', :text => '2009-52'
      assert_select 'th:nth-child(3)', :text => '2009-53'
      assert_select 'th:nth-child(4)', :text => '2010-1'
      assert_select 'th:nth-child(5)', :text => 'Total time'
    end
    assert_select '#time-report tbody tr' do
      assert_select 'td:nth-child(1)', :text => 'eCookbook'
      assert_select 'td:nth-child(2)', :text => '2.00'
      assert_select 'td:nth-child(3)', :text => '12.00'
      assert_select 'td:nth-child(4)', :text => '16.00'
      assert_select 'td:nth-child(5)', :text => '30.00' # Total
    end
  end

  def test_report_should_propose_association_custom_fields
    get :report
    assert_response :success
    assert_template 'report'

    assert_select 'select[name=?]', 'criteria[]' do
      assert_select 'option[value=cf_1]', {:text => 'Database'}, 'Issue custom field not found'
      assert_select 'option[value=cf_3]', {:text => 'Development status'}, 'Project custom field not found'
      assert_select 'option[value=cf_7]', {:text => 'Billable'}, 'TimeEntryActivity custom field not found'
    end
  end

  def test_report_with_association_custom_fields
    get :report, :criteria => ['cf_1', 'cf_3', 'cf_7']
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:report)
    assert_equal 3, assigns(:report).criteria.size
    assert_equal "162.90", "%.2f" % assigns(:report).total_hours

    # Custom fields columns
    assert_select 'th', :text => 'Database'
    assert_select 'th', :text => 'Development status'
    assert_select 'th', :text => 'Billable'

    # Custom field row
    assert_select 'tr' do
      assert_select 'td', :text => 'MySQL'
      assert_select 'td.hours', :text => '1.00'
    end
  end

  def test_report_one_criteria_no_result
    get :report, :project_id => 1, :columns => 'week', :from => "1998-04-01", :to => "1998-04-30", :criteria => ['project']
    assert_response :success
    assert_template 'report'
    assert_not_nil assigns(:report)
    assert_equal "0.00", "%.2f" % assigns(:report).total_hours
  end

  def test_report_status_criterion
    get :report, :project_id => 1, :criteria => ['status']
    assert_response :success
    assert_template 'report'
    assert_tag :tag => 'th', :content => 'Status'
    assert_tag :tag => 'td', :content => 'New'
  end

  def test_report_all_projects_csv_export
    get :report, :columns => 'month', :from => "2007-01-01", :to => "2007-06-30",
        :criteria => ["project", "user", "activity"], :format => "csv"
    assert_response :success
    assert_equal 'text/csv; header=present', @response.content_type
    lines = @response.body.chomp.split("\n")
    # Headers
    assert_equal 'Project,User,Activity,2007-3,2007-4,Total time', lines.first
    # Total row
    assert_equal 'Total time,"","",154.25,8.65,162.90', lines.last
  end

  def test_report_csv_export
    get :report, :project_id => 1, :columns => 'month',
        :from => "2007-01-01", :to => "2007-06-30",
        :criteria => ["project", "user", "activity"], :format => "csv"
    assert_response :success
    assert_equal 'text/csv; header=present', @response.content_type
    lines = @response.body.chomp.split("\n")
    # Headers
    assert_equal 'Project,User,Activity,2007-3,2007-4,Total time', lines.first
    # Total row
    assert_equal 'Total time,"","",154.25,8.65,162.90', lines.last
  end

  def test_csv_big_5
    Setting.default_language = "zh-TW"
    str_utf8  = "\xe4\xb8\x80\xe6\x9c\x88"
    str_big5  = "\xa4@\xa4\xeb"
    if str_utf8.respond_to?(:force_encoding)
      str_utf8.force_encoding('UTF-8')
      str_big5.force_encoding('Big5')
    end
    user = User.find_by_id(3)
    user.firstname = str_utf8
    user.lastname  = "test-lastname"
    assert user.save
    comments = "test_csv_big_5"
    te1 = TimeEntry.create(:spent_on => '2011-11-11',
                           :hours    => 7.3,
                           :project  => Project.find(1),
                           :user     => user,
                           :activity => TimeEntryActivity.find_by_name('Design'),
                           :comments => comments)

    te2 = TimeEntry.find_by_comments(comments)
    assert_not_nil te2
    assert_equal 7.3, te2.hours
    assert_equal 3, te2.user_id

    get :report, :project_id => 1, :columns => 'day',
        :from => "2011-11-11", :to => "2011-11-11",
        :criteria => ["user"], :format => "csv"
    assert_response :success
    assert_equal 'text/csv; header=present', @response.content_type
    lines = @response.body.chomp.split("\n")    
    # Headers
    s1 = "\xa5\xce\xa4\xe1,2011-11-11,\xa4u\xae\xc9\xc1`\xadp"
    s2 = "\xa4u\xae\xc9\xc1`\xadp"
    if s1.respond_to?(:force_encoding)
      s1.force_encoding('Big5')
      s2.force_encoding('Big5')
    end
    assert_equal s1, lines.first
    # Total row
    assert_equal "#{str_big5} #{user.lastname},7.30,7.30", lines[1]
    assert_equal "#{s2},7.30,7.30", lines[2]

    str_tw = "Traditional Chinese (\xe7\xb9\x81\xe9\xab\x94\xe4\xb8\xad\xe6\x96\x87)"
    if str_tw.respond_to?(:force_encoding)
      str_tw.force_encoding('UTF-8')
    end
    assert_equal str_tw, l(:general_lang_name)
    assert_equal 'Big5', l(:general_csv_encoding)
    assert_equal ',', l(:general_csv_separator)
    assert_equal '.', l(:general_csv_decimal_separator)
  end

  def test_csv_cannot_convert_should_be_replaced_big_5
    Setting.default_language = "zh-TW"
    str_utf8  = "\xe4\xbb\xa5\xe5\x86\x85"
    if str_utf8.respond_to?(:force_encoding)
      str_utf8.force_encoding('UTF-8')
    end
    user = User.find_by_id(3)
    user.firstname = str_utf8
    user.lastname  = "test-lastname"
    assert user.save
    comments = "test_replaced"
    te1 = TimeEntry.create(:spent_on => '2011-11-11',
                           :hours    => 7.3,
                           :project  => Project.find(1),
                           :user     => user,
                           :activity => TimeEntryActivity.find_by_name('Design'),
                           :comments => comments)

    te2 = TimeEntry.find_by_comments(comments)
    assert_not_nil te2
    assert_equal 7.3, te2.hours
    assert_equal 3, te2.user_id

    get :report, :project_id => 1, :columns => 'day',
        :from => "2011-11-11", :to => "2011-11-11",
        :criteria => ["user"], :format => "csv"
    assert_response :success
    assert_equal 'text/csv; header=present', @response.content_type
    lines = @response.body.chomp.split("\n")    
    # Headers
    s1 = "\xa5\xce\xa4\xe1,2011-11-11,\xa4u\xae\xc9\xc1`\xadp"
    if s1.respond_to?(:force_encoding)
      s1.force_encoding('Big5')
    end
    assert_equal s1, lines.first
    # Total row
    s2 = ""
    if s2.respond_to?(:force_encoding)
      s2 = "\xa5H?"
      s2.force_encoding('Big5')
    elsif RUBY_PLATFORM == 'java'
      s2 = "??"
    else
      s2 = "\xa5H???"
    end
    assert_equal "#{s2} #{user.lastname},7.30,7.30", lines[1]
  end

  def test_csv_fr
    with_settings :default_language => "fr" do
      str1  = "test_csv_fr"
      user = User.find_by_id(3)
      te1 = TimeEntry.create(:spent_on => '2011-11-11',
                             :hours    => 7.3,
                             :project  => Project.find(1),
                             :user     => user,
                             :activity => TimeEntryActivity.find_by_name('Design'),
                             :comments => str1)

      te2 = TimeEntry.find_by_comments(str1)
      assert_not_nil te2
      assert_equal 7.3, te2.hours
      assert_equal 3, te2.user_id

      get :report, :project_id => 1, :columns => 'day',
          :from => "2011-11-11", :to => "2011-11-11",
          :criteria => ["user"], :format => "csv"
      assert_response :success
      assert_equal 'text/csv; header=present', @response.content_type
      lines = @response.body.chomp.split("\n")    
      # Headers
      s1 = "Utilisateur;2011-11-11;Temps total"
      s2 = "Temps total"
      if s1.respond_to?(:force_encoding)
        s1.force_encoding('ISO-8859-1')
        s2.force_encoding('ISO-8859-1')
      end
      assert_equal s1, lines.first
      # Total row
      assert_equal "#{user.firstname} #{user.lastname};7,30;7,30", lines[1]
      assert_equal "#{s2};7,30;7,30", lines[2]

      str_fr = "Fran\xc3\xa7ais"
      if str_fr.respond_to?(:force_encoding)
        str_fr.force_encoding('UTF-8')
      end
      assert_equal str_fr, l(:general_lang_name)
      assert_equal 'ISO-8859-1', l(:general_csv_encoding)
      assert_equal ';', l(:general_csv_separator)
      assert_equal ',', l(:general_csv_decimal_separator)
    end
  end
end
