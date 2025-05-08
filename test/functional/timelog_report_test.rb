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

require_relative '../test_helper'

class TimelogReportTest < Redmine::ControllerTest
  tests TimelogController

  include Redmine::I18n

  def setup
    Setting.default_language = "en"
  end

  def test_report_at_project_level
    get :report, :params => {:project_id => 'ecookbook'}
    assert_response :success

    # query form
    assert_select 'form#query_form' do
      assert_select 'div#query_form_with_buttons.hide-when-print' do
        assert_select 'div#query_form_content' do
          assert_select 'fieldset#filters.collapsible'
          assert_select 'fieldset#options'
        end
        assert_select 'p.buttons'
      end
    end

    assert_select 'form#query_form[action=?]', '/projects/ecookbook/time_entries/report'
  end

  def test_report_all_projects
    get :report
    assert_response :success
    assert_select 'form#query_form[action=?]', '/time_entries/report'
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
    get :report, :params => {:columns => 'week', :from => "2007-04-01", :to => "2007-04-30", :criteria => ['project']}
    assert_response :success
    assert_select 'tr.total td:last', :text => '8:39'
    assert_select 'tr td.name a[href=?]', '/projects/ecookbook', :text => 'eCookbook'
  end

  def test_report_all_time
    get :report, :params => {:project_id => 1, :criteria => ['project', 'issue']}
    assert_response :success
    assert_select 'tr.total td:last', :text => '162:54'
  end

  def test_report_all_time_by_day
    get :report, :params => {:project_id => 1, :criteria => ['project', 'issue'], :columns => 'day'}
    assert_response :success
    assert_select 'tr.total td:last', :text => '162:54'
    assert_select 'th', :text => '2007-03-12'
  end

  def test_report_one_criteria
    get :report, :params => {:project_id => 1, :columns => 'week', :from => "2007-04-01", :to => "2007-04-30", :criteria => ['project']}
    assert_response :success
    assert_select 'tr.total td:last', :text => '8:39'
  end

  def test_report_two_criteria
    get :report, :params => {:project_id => 1, :columns => 'month', :from => "2007-01-01", :to => "2007-12-31", :criteria => ["user", "activity"]}
    assert_response :success
    assert_select 'tr.total td:last', :text => '162:54'
  end

  def test_report_should_show_locked_users
    @request.session[:user_id] = 1

    user = User.find(2)
    user.status = User::STATUS_LOCKED
    user.save

    get :report, :params => {:project_id => 1, :columns => 'month', :criteria => ["user", "activity"]}
    assert_response :success

    assert_select 'td.name a.user.active[href=?]', '/users/1', :text => 'Redmine Admin', :count => 1
    assert_select 'td.name a.user.locked[href=?]', '/users/2', :text => 'John Smith', :count => 1
  end

  def test_report_custom_field_criteria_with_multiple_values_on_single_value_custom_field_should_not_fail
    field = TimeEntryCustomField.create!(:name => 'multi', :field_format => 'list', :possible_values => ['value1', 'value2'])
    entry = TimeEntry.create!(:project => Project.find(1), :hours => 1, :activity_id => 10, :user => User.find(2), :spent_on => Date.today)
    CustomValue.create!(:customized => entry, :custom_field => field, :value => 'value1')
    CustomValue.create!(:customized => entry, :custom_field => field, :value => 'value2')

    get :report, :params => {:project_id => 1, :columns => 'day', :criteria => ["cf_#{field.id}"]}
    assert_response :success
  end

  def test_report_multiple_values_custom_fields_should_not_be_proposed
    TimeEntryCustomField.create!(:name => 'Single', :field_format => 'list', :possible_values => ['value1', 'value2'])
    TimeEntryCustomField.create!(:name => 'Multi', :field_format => 'list', :multiple => true, :possible_values => ['value1', 'value2'])

    get :report, :params => {:project_id => 1}
    assert_response :success
    assert_select 'select[name=?]', 'criteria[]' do
      assert_select 'option', :text => 'Single'
      assert_select 'option', :text => 'Multi', :count => 0
    end
  end

  def test_hidden_custom_fields_should_not_be_proposed
    TimeEntryCustomField.create!(name: 'shown', field_format: 'list', possible_values: ['value1', 'value2'], visible: true)
    TimeEntryCustomField.create!(name: 'Hidden', field_format: 'list', possible_values: ['value1', 'value2'], visible: false, role_ids: [3])

    get :report, :params => {:project_id => 1}
    assert_response :success
    assert_select 'select[name=?]', 'criteria[]' do
      assert_select 'option', :text => 'Shown'
      assert_select 'option', :text => 'Hidden', :count => 0
    end
  end

  def test_report_one_day
    get :report, :params => {:project_id => 1, :columns => 'day', :from => "2007-03-23", :to => "2007-03-23", :criteria => ["user", "activity"]}
    assert_response :success
    assert_select 'tr.total td:last', :text => '4:15'
  end

  def test_report_by_week_should_use_commercial_year
    TimeEntry.delete_all
    TimeEntry.generate!(:hours => '2', :spent_on => '2009-12-25') # 2009-52
    TimeEntry.generate!(:hours => '4', :spent_on => '2009-12-31') # 2009-53
    TimeEntry.generate!(:hours => '8', :spent_on => '2010-01-01') # 2009-53
    TimeEntry.generate!(:hours => '16', :spent_on => '2010-01-05') # 2010-1

    get :report, :params => {:columns => 'week', :from => "2009-12-25", :to => "2010-01-05", :criteria => ["project"]}
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
      assert_select 'td:nth-child(2)', :text => '2:00'
      assert_select 'td:nth-child(3)', :text => '12:00'
      assert_select 'td:nth-child(4)', :text => '16:00'
      assert_select 'td:nth-child(5)', :text => '30:00' # Total
    end
  end

  def test_report_should_propose_association_custom_fields
    get :report
    assert_response :success

    assert_select 'select[name=?]', 'criteria[]' do
      assert_select 'option[value=cf_1]', {:text => 'Database'}, 'Issue custom field not found'
      assert_select 'option[value=cf_3]', {:text => 'Development status'}, 'Project custom field not found'
      assert_select 'option[value=cf_7]', {:text => 'Billable'}, 'TimeEntryActivity custom field not found'
    end
  end

  def test_report_with_association_custom_fields
    get :report, :params => {:criteria => ['cf_1', 'cf_3', 'cf_7']}
    assert_response :success

    assert_select 'tr.total td:last', :text => '162:54'

    # Custom fields columns
    assert_select 'th', :text => 'Database'
    assert_select 'th', :text => 'Development status'
    assert_select 'th', :text => 'Billable'

    # Custom field row
    assert_select 'tr' do
      assert_select 'td', :text => 'MySQL'
      assert_select 'td.hours', :text => '1:00'
    end
  end

  def test_report_one_criteria_no_result
    get :report, :params => {:project_id => 1, :columns => 'week', :from => "1998-04-01", :to => "1998-04-30", :criteria => ['project']}
    assert_response :success

    assert_select '.nodata'
  end

  def test_report_status_criterion
    get :report, :params => {:project_id => 1, :criteria => ['status']}
    assert_response :success

    assert_select 'th', :text => 'Status'
    assert_select 'td', :text => 'New'
  end

  def test_report_activity_criterion_should_aggregate_system_activity_and_project_activity
    activity = TimeEntryActivity.create!(:name => 'Design', :parent_id => 9, :project_id => 3)
    TimeEntry.generate!(:project_id => 3, :issue_id => 5, :activity_id => activity.id, :spent_on => '2007-05-23', :hours => 10.0)

    get :report, :params => {:project_id => 1, :criteria => ['activity']}
    assert_response :success

    assert_select 'tr.last-level' do
      assert_select 'td.name', :text => 'Design'
      assert_select 'td.hours:last', :text => '165:15'
    end
  end

  def test_report_all_projects_csv_export
    get :report, :params => {
      :columns => 'month',
      :from => "2007-01-01",
      :to => "2007-06-30",
      :criteria => ["project", "user", "activity"],
      :format => "csv"
    }
    assert_response :success
    assert_equal 'text/csv; header=present', @response.media_type
    lines = @response.body.chomp.split("\n")
    # Headers
    assert_equal 'Project,User,Activity,2007-3,2007-4,Total time', lines.first
    # Total row
    assert_equal 'Total time,"","",154.25,8.65,162.90', lines.last
  end

  def test_report_csv_export
    get :report, :params => {
      :project_id => 1,
      :columns => 'month',
      :from => "2007-01-01",
      :to => "2007-06-30",
      :criteria => ["project", "user", "cf_10"],
      :format => "csv"
    }
    assert_response :success
    assert_equal 'text/csv; header=present', @response.media_type
    lines = @response.body.chomp.split("\n")
    # Headers
    assert_equal 'Project,User,Overtime,2007-3,2007-4,Total time', lines.first
    # Total row
    assert_equal 'Total time,"","",154.25,8.65,162.90', lines.last
  end

  def test_report_csv_should_fill_issue_criteria_with_tracker_id_and_subject
    get :report, :params => {
      :project_id => 1,
      :columns => 'month',
      :from => "2007-01-01",
      :to => "2007-06-30",
      :criteria => ["issue"],
      :format => "csv"
    }

    assert_response :success
    lines = @response.body.chomp.split("\n")
    assert lines.detect {|line| line.include?('Bug #1: Cannot print recipes')}
  end

  def test_csv_big_5
    str_big5  = (+"\xa4@\xa4\xeb").force_encoding('Big5')
    user = User.find_by_id(3)
    user.firstname = "一月"
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

    with_settings :default_language => "zh-TW" do
      get :report, :params => {
        :project_id => 1,
        :columns => 'day',
        :from => "2011-11-11",
        :to => "2011-11-11",
        :criteria => ["user"],
        :format => "csv"
      }
    end
    assert_response :success
    assert_equal 'text/csv; header=present', @response.media_type
    lines = @response.body.chomp.split("\n")
    # Headers
    s1 = (+"\xa5\xce\xa4\xe1,2011-11-11,\xa4u\xae\xc9\xc1`\xadp").force_encoding('Big5')
    s2 = (+"\xa4u\xae\xc9\xc1`\xadp").force_encoding('Big5')
    assert_equal s1, lines.first
    # Total row
    assert_equal "#{str_big5} #{user.lastname},7.30,7.30", lines[1]
    assert_equal "#{s2},7.30,7.30", lines[2]

    assert_equal 'Chinese/Traditional (繁體中文)', l(:general_lang_name)
    assert_equal 'Big5', l(:general_csv_encoding)
    assert_equal ',', l(:general_csv_separator)
    assert_equal '.', l(:general_csv_decimal_separator)
  end

  def test_csv_cannot_convert_should_be_replaced_big_5
    user = User.find_by_id(3)
    user.firstname = "以内"
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

    with_settings :default_language => "zh-TW" do
      get :report, :params => {
        :project_id => 1,
        :columns => 'day',
        :from => "2011-11-11",
        :to => "2011-11-11",
        :criteria => ["user"],
        :format => "csv"
      }
    end
    assert_response :success
    assert_equal 'text/csv; header=present', @response.media_type
    lines = @response.body.chomp.split("\n")
    # Headers
    s1 = (+"\xa5\xce\xa4\xe1,2011-11-11,\xa4u\xae\xc9\xc1`\xadp").force_encoding('Big5')
    assert_equal s1, lines.first
    # Total row
    s2 = (+"\xa5H?").force_encoding('Big5')
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

      get :report, :params => {
        :project_id => 1,
        :columns => 'day',
        :from => "2011-11-11",
        :to => "2011-11-11",
        :criteria => ["user"],
        :format => "csv"
      }
      assert_response :success
      assert_equal 'text/csv; header=present', @response.media_type
      lines = @response.body.chomp.split("\n")
      # Headers
      s1 = (+"Utilisateur;2011-11-11;Temps total").force_encoding('ISO-8859-1')
      s2 = (+"Temps total").force_encoding('ISO-8859-1')
      assert_equal s1, lines.first
      # Total row
      assert_equal "#{user.firstname} #{user.lastname};7,30;7,30", lines[1]
      assert_equal "#{s2};7,30;7,30", lines[2]

      assert_equal 'French (Français)', l(:general_lang_name)
      assert_equal 'ISO-8859-1', l(:general_csv_encoding)
      assert_equal ';', l(:general_csv_separator)
      assert_equal ',', l(:general_csv_decimal_separator)
    end
  end
end
