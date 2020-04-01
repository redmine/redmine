# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class IssuesControllerTest < Redmine::ControllerTest
  fixtures :projects,
           :users, :email_addresses, :user_preferences,
           :roles,
           :members,
           :member_roles,
           :issues,
           :issue_statuses,
           :issue_relations,
           :versions,
           :trackers,
           :projects_trackers,
           :issue_categories,
           :enabled_modules,
           :enumerations,
           :attachments,
           :workflows,
           :custom_fields,
           :custom_values,
           :custom_fields_projects,
           :custom_fields_trackers,
           :time_entries,
           :journals,
           :journal_details,
           :queries,
           :repositories,
           :changesets,
           :watchers

  include Redmine::I18n

  def setup
    User.current = nil
  end

  def test_index
    with_settings :default_language => "en" do
      get :index
      assert_response :success

      # links to visible issues
      assert_select 'a[href="/issues/1"]', :text => /Cannot print recipes/
      assert_select 'a[href="/issues/5"]', :text => /Subproject issue/
      # private projects hidden
      assert_select 'a[href="/issues/6"]', 0
      assert_select 'a[href="/issues/4"]', 0
      # project column
      assert_select 'th', :text => /Project/
    end
  end

  def test_index_should_not_list_issues_when_module_disabled
    EnabledModule.where("name = 'issue_tracking' AND project_id = 1").delete_all
    get :index
    assert_response :success

    assert_select 'a[href="/issues/1"]', 0
    assert_select 'a[href="/issues/5"]', :text => /Subproject issue/
  end

  def test_index_should_list_visible_issues_only
    get :index, :params => {
        :per_page => 100
      }
    assert_response :success

    Issue.open.each do |issue|
      assert_select "tr#issue-#{issue.id}", issue.visible? ? 1 : 0
    end
  end

  def test_index_with_project
    Setting.display_subprojects_issues = 0
    get :index, :params => {
        :project_id => 1
      }
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

    assert_select 'a[href="/issues/1"]', :text => /Cannot print recipes/
    assert_select 'a[href="/issues/5"]', 0
  end

  def test_index_with_project_and_subprojects
    Setting.display_subprojects_issues = 1
    get :index, :params => {
        :project_id => 1
      }
    assert_response :success

    assert_select 'a[href="/issues/1"]', :text => /Cannot print recipes/
    assert_select 'a[href="/issues/5"]', :text => /Subproject issue/
    assert_select 'a[href="/issues/6"]', 0
  end

  def test_index_with_project_and_subprojects_should_show_private_subprojects_with_permission
    @request.session[:user_id] = 2
    Setting.display_subprojects_issues = 1
    get :index, :params => {
        :project_id => 1
      }
    assert_response :success

    assert_select 'a[href="/issues/1"]', :text => /Cannot print recipes/
    assert_select 'a[href="/issues/5"]', :text => /Subproject issue/
    assert_select 'a[href="/issues/6"]', :text => /Issue of a private subproject/
  end

  def test_index_with_project_and_default_filter
    get :index, :params => {
        :project_id => 1,
        :set_filter => 1
      }
    assert_response :success

    # default filter
    assert_query_filters [['status_id', 'o', '']]
  end

  def test_index_with_project_and_filter
    get :index, :params => {
        :project_id => 1,
        :set_filter => 1,
        :f => ['tracker_id'],
        :op => {
          'tracker_id' => '='
        },
        :v => {
          'tracker_id' => ['1']
        }
      }
    assert_response :success

    assert_query_filters [['tracker_id', '=', '1']]
  end

  def test_index_with_short_filters
    to_test = {
      'status_id' => {
        'o' => { :op => 'o', :values => [''] },
        'c' => { :op => 'c', :values => [''] },
        '7' => { :op => '=', :values => ['7'] },
        '7|3|4' => { :op => '=', :values => ['7', '3', '4'] },
        '=7' => { :op => '=', :values => ['7'] },
        '!3' => { :op => '!', :values => ['3'] },
        '!7|3|4' => { :op => '!', :values => ['7', '3', '4'] }},
      'subject' => {
        'This is a subject' => { :op => '=', :values => ['This is a subject'] },
        'o' => { :op => '=', :values => ['o'] },
        '~This is part of a subject' => { :op => '~', :values => ['This is part of a subject'] },
        '!~This is part of a subject' => { :op => '!~', :values => ['This is part of a subject'] }},
      'tracker_id' => {
        '3' => { :op => '=', :values => ['3'] },
        '=3' => { :op => '=', :values => ['3'] }},
      'start_date' => {
        '2011-10-12' => { :op => '=', :values => ['2011-10-12'] },
        '=2011-10-12' => { :op => '=', :values => ['2011-10-12'] },
        '>=2011-10-12' => { :op => '>=', :values => ['2011-10-12'] },
        '<=2011-10-12' => { :op => '<=', :values => ['2011-10-12'] },
        '><2011-10-01|2011-10-30' => { :op => '><', :values => ['2011-10-01', '2011-10-30'] },
        '<t+2' => { :op => '<t+', :values => ['2'] },
        '>t+2' => { :op => '>t+', :values => ['2'] },
        't+2' => { :op => 't+', :values => ['2'] },
        't' => { :op => 't', :values => [''] },
        'w' => { :op => 'w', :values => [''] },
        '>t-2' => { :op => '>t-', :values => ['2'] },
        '<t-2' => { :op => '<t-', :values => ['2'] },
        't-2' => { :op => 't-', :values => ['2'] }},
      'created_on' => {
        '>=2011-10-12' => { :op => '>=', :values => ['2011-10-12'] },
        '<t-2' => { :op => '<t-', :values => ['2'] },
        '>t-2' => { :op => '>t-', :values => ['2'] },
        't-2' => { :op => 't-', :values => ['2'] }},
      'cf_1' => {
        'c' => { :op => '=', :values => ['c'] },
        '!c' => { :op => '!', :values => ['c'] },
        '!*' => { :op => '!*', :values => [''] },
        '*' => { :op => '*', :values => [''] }},
      'estimated_hours' => {
        '=13.4' => { :op => '=', :values => ['13.4'] },
        '>=45' => { :op => '>=', :values => ['45'] },
        '<=125' => { :op => '<=', :values => ['125'] },
        '><10.5|20.5' => { :op => '><', :values => ['10.5', '20.5'] },
        '!*' => { :op => '!*', :values => [''] },
        '*' => { :op => '*', :values => [''] }}
    }
    default_filter = { 'status_id' => {:operator => 'o', :values => [''] }}
    to_test.each do |field, expression_and_expected|
      expression_and_expected.each do |filter_expression, expected|
        get :index, :params => {
            :set_filter => 1, field => filter_expression
          }
        assert_response :success
        expected_with_default = default_filter.merge({field => {:operator => expected[:op], :values => expected[:values]}})
        assert_query_filters expected_with_default.map {|f, v| [f, v[:operator], v[:values]]}
      end
    end
  end

  def test_index_with_project_and_empty_filters
    get :index, :params => {
        :project_id => 1,
        :set_filter => 1,
        :fields => ['']
      }
    assert_response :success

    # no filter
    assert_query_filters []
  end

  def test_index_with_project_custom_field_filter
    field = ProjectCustomField.create!(:name => 'Client', :is_filter => true, :field_format => 'string')
    CustomValue.create!(:custom_field => field, :customized => Project.find(3), :value => 'Foo')
    CustomValue.create!(:custom_field => field, :customized => Project.find(5), :value => 'Foo')
    filter_name = "project.cf_#{field.id}"
    @request.session[:user_id] = 1

    get :index, :params => {
        :set_filter => 1,
        :f => [filter_name],
        :op => {
          filter_name => '='
        },
        :v => {
          filter_name => ['Foo']
        },
        :c => ['project']
      }
    assert_response :success

    assert_equal [3, 5], issues_in_list.map(&:project_id).uniq.sort
  end

  def test_index_with_project_status_filter
    project = Project.find(2)
    project.close
    project.save

    get :index, :params => {
        :set_filter => 1,
        :f => ['project.status'],
        :op => {'project.status' => '='},
        :v => {'project.status' => ['1']}
      }

    assert_response :success

    issues = issues_in_list.map(&:id).uniq.sort
    assert_include 1, issues
    assert_not_include 4, issues
  end

  def test_index_with_query
    get :index, :params => {
        :project_id => 1,
        :query_id => 5
      }
    assert_response :success

    assert_select '#sidebar .queries' do
      # assert only query is selected in sidebar
      assert_select 'a.query.selected', 1
      # assert link properties
      assert_select 'a.query.selected[href=?]', '/projects/ecookbook/issues?query_id=5', :text => "Open issues by priority and tracker"
      # assert only one clear link exists
      assert_select 'a.icon-clear-query', 1
      # assert clear link properties
      assert_select 'a.icon-clear-query[title=?][href=?]', 'Clear', '/projects/ecookbook/issues?set_filter=1&sort=', 1
    end
  end

  def test_index_with_query_grouped_by_tracker
    get :index, :params => {
        :project_id => 1,
        :query_id => 6
      }
    assert_response :success
    assert_select 'tr.group span.count'
  end

  def test_index_with_query_grouped_and_sorted_by_category
    get :index, :params => {
        :project_id => 1,
        :set_filter => 1,
        :group_by => "category",
        :sort => "category"
      }
    assert_response :success
    assert_select 'tr.group span.count'
  end

  def test_index_with_query_grouped_and_sorted_by_fixed_version
    get :index, :params => {
        :project_id => 1,
        :set_filter => 1,
        :group_by => "fixed_version",
        :sort => "fixed_version"
      }
    assert_response :success
    assert_select 'tr.group span.count'
  end

  def test_index_with_query_grouped_and_sorted_by_fixed_version_in_reverse_order
    get :index, :params => {
        :project_id => 1,
        :set_filter => 1,
        :group_by => "fixed_version",
        :sort => "fixed_version:desc"
      }
    assert_response :success
    assert_select 'tr.group span.count'
  end

  def test_index_grouped_by_due_date
    set_tmp_attachments_directory
    Issue.destroy_all
    Issue.generate!(:due_date => '2018-08-10')
    Issue.generate!(:due_date => '2018-08-10')
    Issue.generate!

    get :index, :params => {
        :set_filter => 1,
        :group_by => "due_date"
      }
    assert_response :success
    assert_select 'tr.group span.name', :value => '2018-08-10' do
      assert_select '~ span.count', :value => '2'
    end
    assert_select 'tr.group span.name', :value => '(blank)' do
      assert_select '~ span.count', :value => '1'
    end
  end

  def test_index_grouped_by_created_on_if_time_zone_is_utc
    # TODO: test fails with mysql
    skip if mysql?
    skip unless IssueQuery.new.groupable_columns.detect {|c| c.name == :created_on}

    @request.session[:user_id] = 2
    User.find(2).pref.update(time_zone: 'UTC')

    get :index, :params => {
        :set_filter => 1,
        :group_by => 'created_on'
      }
    assert_response :success

    assert_select 'tr.group span.name', :text => '07/19/2006' do
      assert_select '+ span.count', :text => '2'
    end
  end

  def test_index_grouped_by_created_on_if_time_zone_is_nil
    skip unless IssueQuery.new.groupable_columns.detect {|c| c.name == :created_on}
    current_user = User.find(2)
    @request.session[:user_id] = current_user.id
    current_user.pref.update(time_zone: nil)

    get :index, :params => {
        :set_filter => 1,
        :group_by => 'created_on'
      }
    assert_response :success

    # group_name depends on localtime
    group_name = format_date(Issue.second.created_on.localtime)
    assert_select 'tr.group span.name', :text => group_name do
      assert_select '+ span.count', :text => '2'
    end
  end

  def test_index_grouped_by_created_on_as_pdf
    skip unless IssueQuery.new.groupable_columns.detect {|c| c.name == :created_on}

    get :index, :params => {
        :set_filter => 1,
        :group_by => 'created_on',
        :format => 'pdf'
      }
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  def test_index_with_query_grouped_by_list_custom_field
    get :index, :params => {
        :project_id => 1,
        :query_id => 9
      }
    assert_response :success
    assert_select 'tr.group span.count'
  end

  def test_index_with_query_grouped_by_key_value_custom_field
    cf = IssueCustomField.create!(:name => 'Key', :is_for_all => true, :tracker_ids => [1,2,3], :field_format => 'enumeration')
    cf.enumerations << valueb = CustomFieldEnumeration.new(:name => 'Value B', :position => 1)
    cf.enumerations << valuea = CustomFieldEnumeration.new(:name => 'Value A', :position => 2)
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(1), :value => valueb.id)
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(2), :value => valueb.id)
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(3), :value => valuea.id)
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(5), :value => '')

    get :index, :params => {
        :project_id => 1,
        :set_filter => 1,
      :group_by => "cf_#{cf.id}"
      }
    assert_response :success

    assert_select 'tr.group', 3
    assert_select 'tr.group' do
      assert_select 'span.name', :text => 'Value B'
      assert_select 'span.count', :text => '2'
    end
    assert_select 'tr.group' do
      assert_select 'span.name', :text => 'Value A'
      assert_select 'span.count', :text => '1'
    end
  end

  def test_index_with_query_grouped_by_user_custom_field
    cf = IssueCustomField.create!(:name => 'User', :is_for_all => true, :tracker_ids => [1,2,3], :field_format => 'user')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(1), :value => '2')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(2), :value => '3')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(3), :value => '3')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(5), :value => '')

    get :index, :params => {
        :project_id => 1,
        :set_filter => 1,
      :group_by => "cf_#{cf.id}"
      }
    assert_response :success

    assert_select 'tr.group', 3
    assert_select 'tr.group' do
      assert_select 'a', :text => 'John Smith'
      assert_select 'span.count', :text => '1'
    end
    assert_select 'tr.group' do
      assert_select 'a', :text => 'Dave Lopper'
      assert_select 'span.count', :text => '2'
    end
  end

  def test_index_grouped_by_boolean_custom_field_should_distinguish_blank_and_false_values
    cf = IssueCustomField.create!(:name => 'Bool', :is_for_all => true, :tracker_ids => [1,2,3], :field_format => 'bool')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(1), :value => '1')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(2), :value => '0')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(3), :value => '')

    with_settings :default_language => 'en' do
      get :index, :params => {
          :project_id => 1,
          :set_filter => 1,
        :group_by => "cf_#{cf.id}"
        }
      assert_response :success
    end

    assert_select 'tr.group', 3
    assert_select 'tr.group', :text => /Yes/
    assert_select 'tr.group', :text => /No/
    assert_select 'tr.group', :text => /blank/
  end

  def test_index_grouped_by_boolean_custom_field_with_false_group_in_first_position_should_show_the_group
    cf = IssueCustomField.create!(:name => 'Bool', :is_for_all => true, :tracker_ids => [1,2,3], :field_format => 'bool', :is_filter => true)
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(1), :value => '0')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(2), :value => '0')

    with_settings :default_language => 'en' do
      get :index, :params => {
          :project_id => 1,
        :set_filter => 1, "cf_#{cf.id}" => "*",
        :group_by => "cf_#{cf.id}"
        }
      assert_response :success
    end

    assert_equal [1, 2], issues_in_list.map(&:id).sort
    assert_select 'tr.group', 1
    assert_select 'tr.group', :text => /No/
  end

  def test_index_with_query_grouped_by_tracker_in_normal_order
    3.times {|i| Issue.generate!(:tracker_id => (i + 1))}
    get :index, :params => {
        :set_filter => 1,
        :group_by => 'tracker',
        :sort => 'id:desc'
      }
    assert_response :success
    assert_equal ["Bug", "Feature request", "Support request"],
                 css_select("tr.issue td.tracker").map(&:text).uniq
  end

  def test_index_with_query_grouped_by_tracker_in_reverse_order
    3.times {|i| Issue.generate!(:tracker_id => (i + 1))}
    get :index, :params => {
        :set_filter => 1,
        :group_by => 'tracker',
        :c => ['tracker', 'subject'],
        :sort => 'id:desc,tracker:desc'
      }
    assert_response :success
    assert_equal ["Bug", "Feature request", "Support request"].reverse,
                 css_select("tr.issue td.tracker").map(&:text).uniq
  end

  def test_index_with_query_id_and_project_id_should_set_session_query
    get :index, :params => {
        :project_id => 1,
        :query_id => 4
      }
    assert_response :success
    assert_kind_of Hash, session[:issue_query]
    assert_equal 4, session[:issue_query][:id]
    assert_equal 1, session[:issue_query][:project_id]
  end

  def test_index_with_invalid_query_id_should_respond_404
    get :index, :params => {
        :project_id => 1,
        :query_id => 999
      }
    assert_response 404
  end

  def test_index_with_cross_project_query_in_session_should_show_project_issues
    q = IssueQuery.create!(:name => "cross_project_query", :user_id => 2, :project => nil, :column_names => ['project'])
    @request.session[:issue_query] = {:id => q.id, :project_id => 1}

    with_settings :display_subprojects_issues => '0' do
      get :index, :params => {
          :project_id => 1
        }
    end
    assert_response :success

    assert_select 'h2', :text => q.name
    assert_equal ["eCookbook"], css_select("tr.issue td.project").map(&:text).uniq
  end

  def test_private_query_should_not_be_available_to_other_users
    q = IssueQuery.create!(:name => "private", :user => User.find(2), :visibility => IssueQuery::VISIBILITY_PRIVATE, :project => nil)
    @request.session[:user_id] = 3

    get :index, :params => {
        :query_id => q.id
      }
    assert_response 403
  end

  def test_private_query_should_be_available_to_its_user
    q = IssueQuery.create!(:name => "private", :user => User.find(2), :visibility => IssueQuery::VISIBILITY_PRIVATE, :project => nil)
    @request.session[:user_id] = 2

    get :index, :params => {
        :query_id => q.id
      }
    assert_response :success
  end

  def test_public_query_should_be_available_to_other_users
    q = IssueQuery.create!(:name => "public", :user => User.find(2), :visibility => IssueQuery::VISIBILITY_PUBLIC, :project => nil)
    @request.session[:user_id] = 3

    get :index, :params => {
        :query_id => q.id
      }
    assert_response :success
  end

  def test_index_should_omit_page_param_in_export_links
    get :index, :params => {
        :page => 2
      }
    assert_response :success
    assert_select 'a.atom[href="/issues.atom"]'
    assert_select 'a.csv[href="/issues.csv"]'
    assert_select 'a.pdf[href="/issues.pdf"]'
    assert_select 'form#csv-export-form[action="/issues.csv"]'
  end

  def test_index_should_not_warn_when_not_exceeding_export_limit
    with_settings :issues_export_limit => 200 do
      get :index
      assert_select '#csv-export-options p.icon-warning', 0
    end
  end

  def test_index_should_warn_when_exceeding_export_limit
    with_settings :issues_export_limit => 2 do
      get :index
      assert_select '#csv-export-options p.icon-warning', :text => %r{limit: 2}
    end
  end

  def test_index_should_include_query_params_as_hidden_fields_in_csv_export_form
    get :index, :params => {
        :project_id => 1,
        :set_filter => "1",
        :tracker_id => "2",
        :sort => 'status',
        :c => ["status", "priority"]
      }

    assert_select '#csv-export-form[action=?]', '/projects/ecookbook/issues.csv'
    assert_select '#csv-export-form[method=?]', 'get'

    assert_select '#csv-export-form' do
      assert_select 'input[name=?][value=?]', 'set_filter', '1'

      assert_select 'input[name=?][value=?]', 'f[]', 'tracker_id'
      assert_select 'input[name=?][value=?]', 'op[tracker_id]', '='
      assert_select 'input[name=?][value=?]', 'v[tracker_id][]', '2'

      assert_select 'input[name=?][value=?]', 'c[]', 'status'
      assert_select 'input[name=?][value=?]', 'c[]', 'priority'

      assert_select 'input[name=?][value=?]', 'sort', 'status'
    end

    get :index, :params => {
        :project_id => 1,
        :set_filter => "1",
        :f => ['']
      }
    assert_select '#csv-export-form input[name=?][value=?]', 'f[]', ''
  end

  def test_index_should_show_block_columns_in_csv_export_form
    field = IssueCustomField.
              create!(
                :name => 'Long text', :field_format => 'text',
                :full_width_layout => '1',
                :tracker_ids => [1], :is_for_all => true
              )
    get :index

    assert_response :success
    assert_select '#csv-export-form' do
      assert_select 'input[value=?]', 'description'
      assert_select 'input[value=?]', 'last_notes'
      assert_select 'input[value=?]', "cf_#{field.id}"
    end
  end

  def test_index_csv
    get :index, :params => {
        :format => 'csv'
      }
    assert_response :success

    assert_equal 'text/csv', @response.media_type
    assert response.body.starts_with?("#,")
    lines = response.body.chomp.split("\n")
    # default columns + id and project
    assert_equal Setting.issue_list_default_columns.size + 2, lines[0].split(',').size
  end

  def test_index_csv_with_project
    get :index, :params => {
        :project_id => 1,
        :format => 'csv'
      }
    assert_response :success
    assert_equal 'text/csv', @response.media_type
  end

  def test_index_csv_without_any_filters
    @request.session[:user_id] = 1
    Issue.create!(:project_id => 1, :tracker_id => 1, :status_id => 5, :subject => 'Closed issue', :author_id => 1)
    get :index, :params => {
        :set_filter => 1,
        :f => [''],
        :format => 'csv'
      }
    assert_response :success
    # -1 for headers
    assert_equal Issue.count, response.body.chomp.split("\n").size - 1
  end

  def test_index_csv_with_description
    Issue.generate!(:description => 'test_index_csv_with_description')
    with_settings :default_language => 'en' do
      get :index, :params => {
          :format => 'csv',
          :c => [:tracker, :description]
        }
      assert_response :success
    end
    assert_equal 'text/csv', response.media_type
    headers = response.body.chomp.split("\n").first.split(',')
    assert_include 'Description', headers
    assert_include 'test_index_csv_with_description', response.body
  end

  def test_index_csv_with_spent_time_column
    issue = Issue.create!(:project_id => 1, :tracker_id => 1, :subject => 'test_index_csv_with_spent_time_column', :author_id => 2)
    TimeEntry.create!(:project => issue.project, :issue => issue, :hours => 7.33, :user => User.find(2), :spent_on => Date.today)

    get :index, :params => {
        :format => 'csv',
        :set_filter => '1',
        :c => %w(subject spent_hours)
      }
    assert_response :success
    assert_equal 'text/csv', @response.media_type
    lines = @response.body.chomp.split("\n")
    assert_include "#{issue.id},#{issue.subject},7.33", lines
  end

  def test_index_csv_with_all_columns
    get :index, :params => {
        :format => 'csv',
        :c => ['all_inline']
      }
    assert_response :success

    assert_equal 'text/csv', @response.media_type
    assert_match /\A#,/, response.body
    lines = response.body.chomp.split("\n")
    assert_equal IssueQuery.new.available_inline_columns.size, lines[0].split(',').size
  end

  def test_index_csv_with_multi_column_field
    CustomField.find(1).update_attribute :multiple, true
    issue = Issue.find(1)
    issue.custom_field_values = {1 => ['MySQL', 'Oracle']}
    issue.save!

    get :index, :params => {
        :format => 'csv',
        :c => ['tracker', "cf_1"]
      }
    assert_response :success
    lines = @response.body.chomp.split("\n")
    assert lines.detect {|line| line.include?('"MySQL, Oracle"')}
  end

  def test_index_csv_should_format_float_custom_fields_with_csv_decimal_separator
    field = IssueCustomField.create!(:name => 'Float', :is_for_all => true, :tracker_ids => [1], :field_format => 'float')
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :custom_field_values => {field.id => '185.6'})

    with_settings :default_language => 'fr' do
      get :index, :params => {
          :format => 'csv',
        :c => ['id', 'tracker', "cf_#{field.id}"]
        }
      assert_response :success
      issue_line = response.body.chomp.split("\n").map {|line| line.split(';')}.detect {|line| line[0]==issue.id.to_s}
      assert_include '185,60', issue_line
    end

    with_settings :default_language => 'en' do
      get :index, :params => {
          :format => 'csv',
        :c => ['id', 'tracker', "cf_#{field.id}"]
        }
      assert_response :success
      issue_line = response.body.chomp.split("\n").map {|line| line.split(',')}.detect {|line| line[0]==issue.id.to_s}
      assert_include '185.60', issue_line
    end
  end

  def test_index_csv_should_fill_parent_column_with_parent_id
    Issue.delete_all
    parent = Issue.generate!
    child = Issue.generate!(:parent_issue_id => parent.id)

    with_settings :default_language => 'en' do
      get :index, :params => {
          :format => 'csv',
          :c => %w(parent)
        }
    end
    lines = response.body.split("\n")
    assert_include "#{child.id},#{parent.id}", lines
  end

  def test_index_csv_big_5
    with_settings :default_language => "zh-TW" do
      str_utf8  = '一月'
      str_big5  = (+"\xa4@\xa4\xeb").force_encoding('Big5')
      issue = Issue.generate!(:subject => str_utf8)

      get :index, :params => {
          :project_id => 1,
          :subject => str_utf8,
          :format => 'csv'
        }
      assert_equal 'text/csv', @response.media_type
      lines = @response.body.chomp.split("\n")
      header = lines[0]
      status = (+"\xaa\xac\xbaA").force_encoding('Big5')
      assert_include status, header
      issue_line = lines.find {|l| l =~ /^#{issue.id},/}
      assert_include str_big5, issue_line
    end
  end

  def test_index_csv_cannot_convert_should_be_replaced_big_5
    with_settings :default_language => "zh-TW" do
      str_utf8  = '以内'
      issue = Issue.generate!(:subject => str_utf8)

      get :index, :params => {
          :project_id => 1,
          :subject => str_utf8,
          :c => ['status', 'subject'],
          :format => 'csv',
          :set_filter => 1
        }
      assert_equal 'text/csv', @response.media_type
      lines = @response.body.chomp.split("\n")
      header = lines[0]
      issue_line = lines.find {|l| l =~ /^#{issue.id},/}
      s1 = (+"\xaa\xac\xbaA").force_encoding('Big5') # status
      assert header.include?(s1)
      s2 = issue_line.split(",")[2]
      s3 = (+"\xa5H?").force_encoding('Big5') # subject
      assert_equal s3, s2
    end
  end

  def test_index_csv_tw
    with_settings :default_language => "zh-TW" do
      str1  = "test_index_csv_tw"
      issue = Issue.generate!(:subject => str1, :estimated_hours => '1234.5')

      get :index, :params => {
          :project_id => 1,
          :subject => str1,
          :c => ['estimated_hours', 'subject'],
          :format => 'csv',
          :set_filter => 1
        }
      assert_equal 'text/csv', @response.media_type
      lines = @response.body.chomp.split("\n")
      assert_include "#{issue.id},1234.50,#{str1}", lines
    end
  end

  def test_index_csv_fr
    with_settings :default_language => "fr" do
      str1  = "test_index_csv_fr"
      issue = Issue.generate!(:subject => str1, :estimated_hours => '1234.5')

      get :index, :params => {
          :project_id => 1,
          :subject => str1,
          :c => ['estimated_hours', 'subject'],
          :format => 'csv',
          :set_filter => 1
        }
      assert_equal 'text/csv', @response.media_type
      lines = @response.body.chomp.split("\n")
      assert_include "#{issue.id};1234,50;#{str1}", lines
    end
  end

  def test_index_csv_should_not_change_selected_columns
    get :index, :params => {
        :set_filter => 1,
        :c => ["subject", "due_date"],
        :project_id => "ecookbook"
      }
    assert_response :success
    assert_equal [:subject, :due_date], session[:issue_query][:column_names]

    get :index, :params => {
        :set_filter => 1,
        :c =>["all_inline"],
        :project_id => "ecookbook",
        :format => 'csv'
      }
    assert_response :success
    assert_equal [:subject, :due_date], session[:issue_query][:column_names]
  end

  def test_index_pdf
    ["en", "zh", "zh-TW", "ja", "ko", "ar"].each do |lang|
      with_settings :default_language => lang do
        get :index
        assert_response :success

        get :index, :params => {
            :format => 'pdf'
          }
        assert_response :success
        assert_equal 'application/pdf', @response.content_type

        get :index, :params => {
            :project_id => 1,
            :format => 'pdf'
          }
        assert_response :success
        assert_equal 'application/pdf', @response.content_type

        get :index, :params => {
            :project_id => 1,
            :query_id => 6,
            :format => 'pdf'
          }
        assert_response :success
        assert_equal 'application/pdf', @response.content_type
      end
    end
  end

  def test_index_pdf_with_query_grouped_by_list_custom_field
    get :index, :params => {
        :project_id => 1,
        :query_id => 9,
        :format => 'pdf'
      }
    assert_response :success
    assert_equal 'application/pdf', @response.content_type
  end

  def test_index_atom
    get :index, :params => {
        :project_id => 'ecookbook',
        :format => 'atom'
      }
    assert_response :success
    assert_equal 'application/atom+xml', response.content_type

    assert_select 'feed' do
      assert_select 'link[rel=self][href=?]', 'http://test.host/projects/ecookbook/issues.atom'
      assert_select 'link[rel=alternate][href=?]', 'http://test.host/projects/ecookbook/issues'
      assert_select 'entry link[href=?]', 'http://test.host/issues/1'
    end
  end

  def test_index_should_include_back_url_input
    get :index, :params => {
        :project_id => 'ecookbook',
        :foo => 'bar'
      }
    assert_response :success
    assert_select 'input[name=back_url][value=?]', '/projects/ecookbook/issues?foo=bar'
  end

  def test_index_sort
    get :index, :params => {
        :sort => 'tracker,id:desc'
      }
    assert_response :success

    assert_equal issues_in_list.sort_by {|issue| [issue.tracker.position, -issue.id]}, issues_in_list
    assert_select 'table.issues.sort-by-tracker.sort-asc'
  end

  def test_index_sort_by_field_not_included_in_columns
    with_settings :issue_list_default_columns => %w(subject author) do
      get :index, :params => {
          :sort => 'tracker'
        }
      assert_response :success
    end
  end

  def test_index_sort_by_assigned_to
    get :index, :params => {
        :sort => 'assigned_to'
      }
    assert_response :success

    assignees = issues_in_list.map(&:assigned_to).compact
    assert_equal assignees.sort, assignees
    assert_select 'table.issues.sort-by-assigned-to.sort-asc'
  end

  def test_index_sort_by_assigned_to_desc
    get :index, :params => {
        :sort => 'assigned_to:desc'
      }
    assert_response :success

    assignees = issues_in_list.map(&:assigned_to).compact
    assert_equal assignees.sort.reverse, assignees
    assert_select 'table.issues.sort-by-assigned-to.sort-desc'
  end

  def test_index_group_by_assigned_to
    get :index, :params => {
        :group_by => 'assigned_to',
        :sort => 'priority'
      }
    assert_response :success
  end

  def test_index_sort_by_author
    get :index, :params => {
        :sort => 'author',
        :c => ['author']
      }
    assert_response :success

    authors = issues_in_list.map(&:author)
    assert_equal authors.sort, authors
  end

  def test_index_sort_by_author_desc
    get :index, :params => {
        :sort => 'author:desc'
      }
    assert_response :success

    authors = issues_in_list.map(&:author)
    assert_equal authors.sort.reverse, authors
  end

  def test_index_group_by_author
    get :index, :params => {
        :group_by => 'author',
        :sort => 'priority'
      }
    assert_response :success
  end

  def test_index_sort_by_last_updated_by
    get :index, :params => {
        :sort => 'last_updated_by'
      }
    assert_response :success
    assert_select 'table.issues.sort-by-last-updated-by.sort-asc'
  end

  def test_index_sort_by_last_updated_by_desc
    get :index, :params => {
        :sort => 'last_updated_by:desc'
      }
    assert_response :success
    assert_select 'table.issues.sort-by-last-updated-by.sort-desc'
  end

  def test_index_sort_by_spent_hours
    get :index, :params => {
        :sort => 'spent_hours:desc'
      }
    assert_response :success
    hours = issues_in_list.map(&:spent_hours)
    assert_equal hours.sort.reverse, hours
  end

  def test_index_sort_by_spent_hours_should_sort_by_visible_spent_hours
    TimeEntry.delete_all
    TimeEntry.generate!(:issue => Issue.generate!(:project_id => 1), :hours => 3)
    TimeEntry.generate!(:issue => Issue.generate!(:project_id => 3), :hours => 4)

    get :index, :params => {:sort => "spent_hours:desc", :c => ['subject','spent_hours']}
    assert_response :success
    assert_equal ['4.00', '3.00', '0.00'], columns_values_in_list('spent_hours')[0..2]

    Project.find(3).disable_module!(:time_tracking)

    get :index, :params => {:sort => "spent_hours:desc", :c => ['subject','spent_hours']}
    assert_response :success
    assert_equal ['3.00', '0.00', '0.00'], columns_values_in_list('spent_hours')[0..2]
  end

  def test_index_sort_by_total_spent_hours
    get :index, :params => {
        :sort => 'total_spent_hours:desc'
      }
    assert_response :success
    hours = issues_in_list.map(&:total_spent_hours)
    assert_equal hours.sort.reverse, hours
  end

  def test_index_sort_by_total_estimated_hours
    get :index, :params => {
        :sort => 'total_estimated_hours:desc'
      }
    assert_response :success
    hours = issues_in_list.map(&:total_estimated_hours)
    # Removes nil because the position of NULL is database dependent
    hours.compact!
    assert_equal hours.sort.reverse, hours
  end

  def test_index_sort_by_user_custom_field
    cf = IssueCustomField.create!(:name => 'User', :is_for_all => true, :tracker_ids => [1,2,3], :field_format => 'user')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(1), :value => '2')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(2), :value => '3')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(3), :value => '3')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(5), :value => '')

    get :index, :params => {
        :project_id => 1,
        :set_filter => 1,
      :sort => "cf_#{cf.id},id"
      }
    assert_response :success

    assert_equal [2, 3, 1], issues_in_list.select {|issue| issue.custom_field_value(cf).present?}.map(&:id)
  end

  def test_index_with_columns
    columns = ['tracker', 'subject', 'assigned_to', 'buttons']
    get :index, :params => {
        :set_filter => 1,
        :c => columns
      }
    assert_response :success

    # query should use specified columns + id and checkbox
    assert_select 'table.issues thead' do
      assert_select 'th', columns.size + 2
      assert_select 'th.tracker'
      assert_select 'th.subject'
      assert_select 'th.assigned_to'
      assert_select 'th.buttons'
    end

    # columns should be stored in session
    assert_kind_of Hash, session[:issue_query]
    assert_kind_of Array, session[:issue_query][:column_names]
    assert_equal columns, session[:issue_query][:column_names].map(&:to_s)

    # ensure only these columns are kept in the selected columns list
    assert_select 'select[name=?] option', 'c[]' do
      assert_select 'option', 3
      assert_select 'option[value=tracker]'
      assert_select 'option[value=project]', 0
    end
  end

  def test_index_without_project_should_implicitly_add_project_column_to_default_columns
    with_settings :issue_list_default_columns => ['tracker', 'subject', 'assigned_to'] do
      get :index, :params => {
          :set_filter => 1
        }
    end

    # query should use specified columns
    assert_equal ["#", "Project", "Tracker", "Subject", "Assignee"], columns_in_issues_list
  end

  def test_index_without_project_and_explicit_default_columns_should_not_add_project_column
    with_settings :issue_list_default_columns => ['tracker', 'subject', 'assigned_to'] do
      columns = ['id', 'tracker', 'subject', 'assigned_to']
      get :index, :params => {
          :set_filter => 1,
          :c => columns
        }
    end

    # query should use specified columns
    assert_equal ["#", "Tracker", "Subject", "Assignee"], columns_in_issues_list
  end

  def test_index_with_default_columns_should_respect_default_columns_order
    columns = ['assigned_to', 'subject', 'status', 'tracker']
    with_settings :issue_list_default_columns => columns do
      get :index, :params => {
          :project_id => 1,
          :set_filter => 1
        }

      assert_equal ["#", "Assignee", "Subject", "Status", "Tracker"], columns_in_issues_list
    end
  end

  def test_index_with_custom_field_column
    columns = %w(tracker subject cf_2)
    get :index, :params => {
        :set_filter => 1,
        :c => columns
      }
    assert_response :success

    # query should use specified columns
    assert_equal ["#", "Tracker", "Subject", "Searchable field"], columns_in_issues_list
    assert_select 'table.issues' do
      assert_select 'th.cf_2.string'
      assert_select 'td.cf_2.string'
    end
  end

  def test_index_with_multi_custom_field_column
    field = CustomField.find(1)
    field.update_attribute :multiple, true
    issue = Issue.find(1)
    issue.custom_field_values = {1 => ['MySQL', 'Oracle']}
    issue.save!

    get :index, :params => {
        :set_filter => 1,
        :c => %w(tracker subject cf_1)
      }
    assert_response :success

    assert_select 'table.issues td.cf_1', :text => 'MySQL, Oracle'
  end

  def test_index_with_multi_user_custom_field_column
    field = IssueCustomField.create!(:name => 'Multi user', :field_format => 'user', :multiple => true,
      :tracker_ids => [1], :is_for_all => true)
    issue = Issue.find(1)
    issue.custom_field_values = {field.id => ['2', '3']}
    issue.save!

    get :index, :params => {
        :set_filter => 1,
      :c => ['tracker', 'subject', "cf_#{field.id}"]
      }
    assert_response :success

    assert_select "table.issues td.cf_#{field.id}" do
      assert_select 'a', 2
      assert_select 'a[href=?]', '/users/2', :text => 'John Smith'
      assert_select 'a[href=?]', '/users/3', :text => 'Dave Lopper'
    end
  end

  def test_index_with_date_column
    with_settings :date_format => '%d/%m/%Y' do
      Issue.find(1).update_attribute :start_date, '1987-08-24'
      get :index, :params => {
          :set_filter => 1,
          :c => %w(start_date)
        }
      assert_select 'table.issues' do
        assert_select 'th.start_date'
        assert_select 'td.start_date', :text => '24/08/1987'
      end
    end
  end

  def test_index_with_done_ratio_column
    Issue.find(1).update_attribute :done_ratio, 40
    get :index, :params => {
        :set_filter => 1,
        :c => %w(done_ratio)
      }
    assert_select 'table.issues td.done_ratio' do
      assert_select 'table.progress' do
        assert_select 'td.closed[style=?]', 'width: 40%;'
      end
    end
  end

  def test_index_with_spent_hours_column
    Issue.expects(:load_visible_spent_hours).once
    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject spent_hours)
      }
    assert_select 'table.issues tr#issue-3 td.spent_hours', :text => '1.00'
  end

  def test_index_with_total_spent_hours_column
    Issue.expects(:load_visible_total_spent_hours).once
    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject total_spent_hours)
      }
    assert_select 'table.issues tr#issue-3 td.total_spent_hours', :text => '1.00'
  end

  def test_index_with_total_estimated_hours_column
    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject total_estimated_hours)
      }
    assert_select 'table.issues td.total_estimated_hours'
  end

  def test_index_should_not_show_spent_hours_column_without_permission
    Role.anonymous.remove_permission! :view_time_entries
    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject spent_hours)
      }
    assert_select 'td.spent_hours', 0
  end

  def test_index_with_fixed_version_column
    get :index, :params => {
        :set_filter => 1,
        :c => %w(fixed_version)
      }
    assert_select 'table.issues td.fixed_version' do
      assert_select 'a[href=?]', '/versions/2', :text => 'eCookbook - 1.0'
    end
  end

  def test_index_with_relations_column
    IssueRelation.delete_all
    IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(1), :issue_to => Issue.find(7))
    IssueRelation.create!(:relation_type => "relates", :issue_from => Issue.find(8), :issue_to => Issue.find(1))
    IssueRelation.create!(:relation_type => "blocks", :issue_from => Issue.find(1), :issue_to => Issue.find(11))
    IssueRelation.create!(:relation_type => "blocks", :issue_from => Issue.find(12), :issue_to => Issue.find(2))

    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject relations)
      }
    assert_response :success
    assert_select "tr#issue-1 td.relations" do
      assert_select "span", 3
      assert_select "span", :text => "Related to #7"
      assert_select "span", :text => "Related to #8"
      assert_select "span", :text => "Blocks #11"
    end
    assert_select "tr#issue-2 td.relations" do
      assert_select "span", 1
      assert_select "span", :text => "Blocked by #12"
    end
    assert_select "tr#issue-3 td.relations" do
      assert_select "span", 0
    end

    get :index, :params => {
        :set_filter => 1,
        :c => %w(relations),
        :format => 'csv'
      }
    assert_response :success
    assert_equal 'text/csv', response.media_type
    lines = response.body.chomp.split("\n")
    assert_include '1,"Related to #7, Related to #8, Blocks #11"', lines
    assert_include '2,Blocked by #12', lines
    assert_include '3,""', lines

    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject relations),
        :format => 'pdf'
      }
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  def test_index_with_description_column
    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject description)
      }

    assert_select 'table.issues thead th', 4 # columns: chekbox + id + subject
    assert_select 'td.description[colspan="4"]', :text => 'Unable to print recipes'

    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject description),
        :format => 'pdf'
      }
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  def test_index_with_last_notes_column
    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject last_notes)
      }

    assert_response :success
    assert_select 'table.issues thead th', 4 # columns: chekbox + id + subject

    assert_select 'td.last_notes[colspan="4"]', :text => 'Some notes with Redmine links: #2, r2.'
    assert_select 'td.last_notes[colspan="4"]', :text => 'A comment with inline image:  and a reference to #1 and r2.'

    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject last_notes),
        :format => 'pdf'
      }
    assert_response :success
    assert_equal 'application/pdf', response.content_type
  end

  def test_index_with_last_notes_column_should_display_private_notes_with_permission_only
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Public notes', :user_id => 1)
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Privates notes', :private_notes => true, :user_id => 1)
    @request.session[:user_id] = 2

    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject last_notes)
      }
    assert_response :success
    assert_select 'td.last_notes[colspan="4"]', :text => 'Privates notes'

    Role.find(1).remove_permission! :view_private_notes

    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject last_notes)
      }
    assert_response :success
    assert_select 'td.last_notes[colspan="4"]', :text => 'Public notes'
  end

  def test_index_with_description_and_last_notes_columns_should_display_column_name
    get :index, :params => {
        :set_filter => 1,
        :c => %w(subject last_notes description)
      }
    assert_response :success

    assert_select 'td.last_notes[colspan="4"] span', :text => 'Last notes'
    assert_select 'td.description[colspan="4"] span', :text => 'Description'
  end

  def test_index_with_full_width_layout_custom_field_column_should_show_column_as_block_column
    field = IssueCustomField.create!(:name => 'Long text', :field_format => 'text', :full_width_layout => '1',
      :tracker_ids => [1], :is_for_all => true)
    issue = Issue.find(1)
    issue.custom_field_values = {field.id => 'This is a long text'}
    issue.save!

    get :index, :params => {
        :set_filter => 1,
        :c => ['subject', 'description', "cf_#{field.id}"]
      }
    assert_response :success

    assert_select 'td.description[colspan="4"] span', :text => 'Description'
    assert_select "td.cf_#{field.id} span", :text => 'Long text'
  end

  def test_index_with_parent_column
    Issue.delete_all
    parent = Issue.generate!
    child = Issue.generate!(:parent_issue_id => parent.id)

    get :index, :params => {
        :c => %w(parent)
      }

    assert_select 'td.parent', :text => "#{parent.tracker} ##{parent.id}"
    assert_select 'td.parent a[title=?]', parent.subject
  end

  def test_index_with_parent_subject_column
    Issue.delete_all
    parent = Issue.generate!
    child = Issue.generate!(:parent_issue_id => parent.id)

    get :index, :params => {
        :c => %w(parent.subject)
      }

    assert_select 'table.issues' do
      assert_select 'th.parent-subject', :text => l(:field_parent_issue_subject)
      assert_select "tr#issue-#{child.id}" do
        assert_select 'td.parent-subject', :text => parent.subject
      end
    end
  end

  def test_index_with_last_updated_by_column
    get :index, :params => {
        :c => %w(subject last_updated_by),
        :issue_id => '1,2,3',
        :sort => 'id',
        :set_filter => '1'
      }

    assert_select 'td.last_updated_by'
    assert_equal ["John Smith", "John Smith", ""], css_select('td.last_updated_by').map(&:text)
  end

  def test_index_with_attachments_column
    get :index, :params => {
        :c => %w(subject attachments),
        :set_filter => '1',
        :sort => 'id'
      }
    assert_response :success

    assert_select 'td.attachments'
    assert_select 'tr#issue-2' do
      assert_select 'td.attachments' do
        assert_select 'a', :text => 'source.rb'
        assert_select 'a', :text => 'picture.jpg'
      end
    end
  end

  def test_index_with_attachments_column_as_csv
    get :index, :params => {
        :c => %w(subject attachments),
        :set_filter => '1',
        :sort => 'id',
        :format => 'csv'
      }
    assert_response :success

    assert_include "\"source.rb\npicture.jpg\"", response.body
  end

  def test_index_with_estimated_hours_total
    Issue.delete_all
    Issue.generate!(:estimated_hours => 5.5)
    Issue.generate!(:estimated_hours => 1.1)

    get :index, :params => {
        :t => %w(estimated_hours)
      }
    assert_response :success
    assert_select '.query-totals'
    assert_select '.total-for-estimated-hours span.value', :text => '6.60'
    assert_select 'input[type=checkbox][name=?][value=estimated_hours][checked=checked]', 't[]'
  end

  def test_index_with_grouped_query_and_estimated_hours_total
    Issue.delete_all
    Issue.generate!(:estimated_hours => 5.5, :category_id => 1)
    Issue.generate!(:estimated_hours => 2.3, :category_id => 1)
    Issue.generate!(:estimated_hours => 1.1, :category_id => 2)
    Issue.generate!(:estimated_hours => 4.6)

    get :index, :params => {
        :t => %w(estimated_hours),
        :group_by => 'category'
      }
    assert_response :success
    assert_select '.query-totals'
    assert_select '.query-totals .total-for-estimated-hours span.value', :text => '13.50'
    assert_select 'tr.group', :text => /Printing/ do
      assert_select '.total-for-estimated-hours span.value', :text => '7.80'
    end
    assert_select 'tr.group', :text => /Recipes/ do
      assert_select '.total-for-estimated-hours span.value', :text => '1.10'
    end
    assert_select 'tr.group', :text => /blank/ do
      assert_select '.total-for-estimated-hours span.value', :text => '4.60'
    end
  end

  def test_index_with_int_custom_field_total
    field = IssueCustomField.generate!(:field_format => 'int', :is_for_all => true)
    CustomValue.create!(:customized => Issue.find(1), :custom_field => field, :value => '2')
    CustomValue.create!(:customized => Issue.find(2), :custom_field => field, :value => '7')

    get :index, :params => {
      :t => ["cf_#{field.id}"]
      }
    assert_response :success
    assert_select '.query-totals'
    assert_select ".total-for-cf-#{field.id} span.value", :text => '9'
  end

  def test_index_with_spent_time_total_should_sum_visible_spent_time_only
    TimeEntry.delete_all
    TimeEntry.generate!(:issue => Issue.generate!(:project_id => 1), :hours => 3)
    TimeEntry.generate!(:issue => Issue.generate!(:project_id => 3), :hours => 4)

    get :index, :params => {:t => ["spent_hours"]}
    assert_response :success
    assert_select ".total-for-spent-hours span.value", :text => '7.00'

    Project.find(3).disable_module!(:time_tracking)

    get :index, :params => {:t => ["spent_hours"]}
    assert_response :success
    assert_select ".total-for-spent-hours span.value", :text => '3.00'
  end

  def test_index_totals_should_default_to_settings
    with_settings :issue_list_default_totals => ['estimated_hours'] do
      get :index
      assert_response :success
      assert_select '.total-for-estimated-hours span.value'
      assert_select '.query-totals>span', 1
    end
  end

  def test_index_send_html_if_query_is_invalid
    get :index, :params => {
        :f => ['start_date'],
        :op => {
          :start_date => '='
        }
      }
    assert_equal 'text/html', @response.content_type
    assert_select_error /Start date cannot be blank/i
  end

  def test_index_send_nothing_if_query_is_invalid
    get :index, :params => {
        :f => ['start_date'],
        :op => {
          :start_date => '='
        },
        :format => 'csv'
      }
    assert_equal 'text/csv', @response.content_type
    assert @response.body.blank?
  end

  def test_index_should_include_new_issue_link
    @request.session[:user_id] = 2
    get :index, :params => {
        :project_id => 1
      }
    assert_select '#content a.new-issue[href="/projects/ecookbook/issues/new"]', :text => 'New issue'
  end

  def test_index_should_not_include_new_issue_link_for_project_without_trackers
    Project.find(1).trackers.clear

    @request.session[:user_id] = 2
    get :index, :params => {
        :project_id => 1
      }
    assert_select '#content a.new-issue', 0
  end

  def test_index_should_not_include_new_issue_link_for_users_with_copy_issues_permission_only
    role = Role.find(1)
    role.remove_permission! :add_issues
    role.add_permission! :copy_issues

    @request.session[:user_id] = 2
    get :index, :params => {
        :project_id => 1
      }
    assert_select '#content a.new-issue', 0
  end

  def test_index_without_project_should_include_new_issue_link
    @request.session[:user_id] = 2
    get :index
    assert_select '#content a.new-issue[href="/issues/new"]', :text => 'New issue'
  end

  def test_index_should_not_include_new_issue_tab_when_disabled
    with_settings :new_item_menu_tab => '0' do
      @request.session[:user_id] = 2
      get :index, :params => {
          :project_id => 1
        }
      assert_select '#main-menu a.new-issue', 0
    end
  end

  def test_index_should_include_new_issue_tab_when_enabled
    with_settings :new_item_menu_tab => '1' do
      @request.session[:user_id] = 2
      get :index, :params => {
          :project_id => 1
        }
      assert_select '#main-menu a.new-issue[href="/projects/ecookbook/issues/new"]', :text => 'New issue'
    end
  end

  def test_new_should_have_new_issue_tab_as_current_menu_item
    with_settings :new_item_menu_tab => '1' do
      @request.session[:user_id] = 2
      get :new, :params => {
          :project_id => 1
        }
      assert_select '#main-menu a.new-issue.selected'
    end
  end

  def test_index_should_not_include_new_issue_tab_for_project_without_trackers
    with_settings :new_item_menu_tab => '1' do
      Project.find(1).trackers.clear

      @request.session[:user_id] = 2
      get :index, :params => {
          :project_id => 1
        }
      assert_select '#main-menu a.new-issue', 0
    end
  end

  def test_index_should_not_include_new_issue_tab_for_users_with_copy_issues_permission_only
    with_settings :new_item_menu_tab => '1' do
      role = Role.find(1)
      role.remove_permission! :add_issues
      role.add_permission! :copy_issues

      @request.session[:user_id] = 2
      get :index, :params => {
          :project_id => 1
        }
      assert_select '#main-menu a.new-issue', 0
    end
  end

  def test_show_by_anonymous
    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'div.issue div.description', :text => /Unable to print recipes/
    # anonymous role is allowed to add a note
    assert_select 'form#issue-form' do
      assert_select 'fieldset' do
        assert_select 'legend', :text => 'Notes'
        assert_select 'textarea[name=?]', 'issue[notes]'
      end
    end
    assert_select 'title', :text => "Bug #1: Cannot print recipes - eCookbook - Redmine"
  end

  def test_show_by_manager
    @request.session[:user_id] = 2
    get :show, :params => {
        :id => 1
      }

    assert_select 'a', :text => /Quote/
    assert_select 'form#issue-form' do
      assert_select 'fieldset' do
        assert_select 'legend', :text => 'Change properties'
        assert_select 'input[name=?]', 'issue[subject]'
      end
      assert_select 'fieldset' do
        assert_select 'legend', :text => 'Log time'
        assert_select 'input[name=?]', 'time_entry[hours]'
      end
      assert_select 'fieldset' do
        assert_select 'legend', :text => 'Notes'
        assert_select 'textarea[name=?]', 'issue[notes]'
      end
    end
  end

  def test_show_should_display_update_form
    @request.session[:user_id] = 2
    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'form#issue-form' do
      assert_select 'input[name=?]', 'issue[is_private]'
      assert_select 'select[name=?]', 'issue[project_id]'
      assert_select 'select[name=?]', 'issue[tracker_id]'
      assert_select 'input[name=?]', 'issue[subject]'
      assert_select 'textarea[name=?]', 'issue[description]'
      assert_select 'select[name=?]', 'issue[status_id]'
      assert_select 'select[name=?]', 'issue[priority_id]'
      assert_select 'select[name=?]', 'issue[assigned_to_id]'
      assert_select 'select[name=?]', 'issue[category_id]'
      assert_select 'select[name=?]', 'issue[fixed_version_id]'
      assert_select 'input[name=?]', 'issue[parent_issue_id]'
      assert_select 'input[name=?]', 'issue[start_date]'
      assert_select 'input[name=?]', 'issue[due_date]'
      assert_select 'select[name=?]', 'issue[done_ratio]'
      assert_select 'input[name=?]', 'issue[custom_field_values][2]'
      assert_select 'input[name=?]', 'issue[watcher_user_ids][]', 0
      assert_select 'textarea[name=?]', 'issue[notes]'
    end
  end

  def test_show_should_display_update_form_with_minimal_permissions
    Role.find(1).update_attribute :permissions, [:view_issues, :add_issue_notes]
    WorkflowTransition.where(:role_id => 1).delete_all

    @request.session[:user_id] = 2
    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'form#issue-form' do
      assert_select 'input[name=?]', 'issue[is_private]', 0
      assert_select 'select[name=?]', 'issue[project_id]', 0
      assert_select 'select[name=?]', 'issue[tracker_id]', 0
      assert_select 'input[name=?]', 'issue[subject]', 0
      assert_select 'textarea[name=?]', 'issue[description]', 0
      assert_select 'select[name=?]', 'issue[status_id]', 0
      assert_select 'select[name=?]', 'issue[priority_id]', 0
      assert_select 'select[name=?]', 'issue[assigned_to_id]', 0
      assert_select 'select[name=?]', 'issue[category_id]', 0
      assert_select 'select[name=?]', 'issue[fixed_version_id]', 0
      assert_select 'input[name=?]', 'issue[parent_issue_id]', 0
      assert_select 'input[name=?]', 'issue[start_date]', 0
      assert_select 'input[name=?]', 'issue[due_date]', 0
      assert_select 'select[name=?]', 'issue[done_ratio]', 0
      assert_select 'input[name=?]', 'issue[custom_field_values][2]', 0
      assert_select 'input[name=?]', 'issue[watcher_user_ids][]', 0
      assert_select 'textarea[name=?]', 'issue[notes]'
    end
  end

  def test_show_should_not_display_update_form_without_permissions
    Role.find(1).update_attribute :permissions, [:view_issues]

    @request.session[:user_id] = 2
    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'form#issue-form', 0
  end

  def test_update_form_should_not_display_inactive_enumerations
    assert !IssuePriority.find(15).active?

    @request.session[:user_id] = 2
    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'form#issue-form' do
      assert_select 'select[name=?]', 'issue[priority_id]' do
        assert_select 'option[value="4"]'
        assert_select 'option[value="15"]', 0
      end
    end
  end

  def test_update_form_should_allow_attachment_upload
    @request.session[:user_id] = 2
    get :show, :params => {
        :id => 1
      }

    assert_select 'form#issue-form[method=post][enctype="multipart/form-data"]' do
      assert_select 'input[type=file][name=?]', 'attachments[dummy][file]'
    end
  end

  def test_show_should_deny_anonymous_access_without_permission
    Role.anonymous.remove_permission!(:view_issues)
    get :show, :params => {
        :id => 1
      }
    assert_response :redirect
  end

  def test_show_should_deny_anonymous_access_to_private_issue
    Issue.where(:id => 1).update_all(["is_private = ?", true])
    get :show, :params => {
        :id => 1
      }
    assert_response :redirect
  end

  def test_show_should_deny_non_member_access_without_permission
    Role.non_member.remove_permission!(:view_issues)
    @request.session[:user_id] = 9
    get :show, :params => {
        :id => 1
      }
    assert_response 403
  end

  def test_show_should_deny_non_member_access_to_private_issue
    Issue.where(:id => 1).update_all(["is_private = ?", true])
    @request.session[:user_id] = 9
    get :show, :params => {
        :id => 1
      }
    assert_response 403
  end

  def test_show_should_deny_member_access_without_permission
    Role.find(1).remove_permission!(:view_issues)
    @request.session[:user_id] = 2
    get :show, :params => {
        :id => 1
      }
    assert_response 403
  end

  def test_show_should_deny_member_access_to_private_issue_without_permission
    Issue.where(:id => 1).update_all(["is_private = ?", true])
    @request.session[:user_id] = 3
    get :show, :params => {
        :id => 1
      }
    assert_response 403
  end

  def test_show_should_allow_author_access_to_private_issue
    Issue.where(:id => 1).update_all(["is_private = ?, author_id = 3", true])
    @request.session[:user_id] = 3
    get :show, :params => {
        :id => 1
      }
    assert_response :success
  end

  def test_show_should_allow_assignee_access_to_private_issue
    Issue.where(:id => 1).update_all(["is_private = ?, assigned_to_id = 3", true])
    @request.session[:user_id] = 3
    get :show, :params => {
        :id => 1
      }
    assert_response :success
  end

  def test_show_should_allow_member_access_to_private_issue_with_permission
    Issue.where(:id => 1).update_all(["is_private = ?", true])
    User.find(3).roles_for_project(Project.find(1)).first.update_attribute :issues_visibility, 'all'
    @request.session[:user_id] = 3
    get :show, :params => {
        :id => 1
      }
    assert_response :success
  end

  def test_show_should_format_related_issues_dates
    with_settings :date_format => '%d/%m/%Y' do
      issue = Issue.generate!(:start_date => '2018-11-29', :due_date => '2018-12-01')
      IssueRelation.create!(:issue_from => Issue.find(1), :issue_to => issue, :relation_type => 'relates')

      get :show, :params => {
          :id => 1
        }
      assert_response :success

      assert_select '#relations td.start_date', :text => '29/11/2018'
      assert_select '#relations td.due_date', :text => '01/12/2018'
    end
  end

  def test_show_should_not_disclose_relations_to_invisible_issues
    Setting.cross_project_issue_relations = '1'
    IssueRelation.create!(:issue_from => Issue.find(1), :issue_to => Issue.find(2), :relation_type => 'relates')
    # Relation to a private project issue
    IssueRelation.create!(:issue_from => Issue.find(1), :issue_to => Issue.find(4), :relation_type => 'relates')

    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'div#relations' do
      assert_select 'a', :text => /#2$/
      assert_select 'a', :text => /#4$/, :count => 0
    end
  end

  def test_show_should_list_subtasks
    Issue.create!(:project_id => 1, :author_id => 1, :tracker_id => 1, :parent_issue_id => 1, :subject => 'Child Issue')

    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'div#issue_tree' do
      assert_select 'td.subject', :text => /Child Issue/
    end
  end

  def test_show_should_list_parents
    issue = Issue.create!(:project_id => 1, :author_id => 1, :tracker_id => 1, :parent_issue_id => 1, :subject => 'Child Issue')

    get :show, :params => {
        :id => issue.id
      }
    assert_response :success

    assert_select 'div.subject' do
      assert_select 'h3', 'Child Issue'
      assert_select 'a[href="/issues/1"]'
    end
  end

  def test_show_should_not_display_prev_next_links_without_query_in_session
    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'div.next-prev-links', 0
  end

  def test_show_should_display_prev_next_links_with_query_in_session
    @request.session[:issue_query] = {:filters => {'status_id' => {:values => [''], :operator => 'o'}}, :project_id => nil, :sort => [['id', 'asc']]}

    with_settings :display_subprojects_issues => '0' do
      get :show, :params => {
          :id => 3
        }
    end
    assert_response :success

    count = Issue.open.visible.count

    # Previous and next issues for all projects
    assert_select 'div.next-prev-links' do
      assert_select 'a[href="/issues/2"]', :text => /Previous/
      assert_select 'a[href="/issues/5"]', :text => /Next/
      assert_select 'span.position', :text => "3 of #{count}"
    end
  end

  def test_show_should_display_prev_next_links_with_saved_query_in_session
    query = IssueQuery.create!(:name => 'test', :visibility => IssueQuery::VISIBILITY_PUBLIC,  :user_id => 1,
      :filters => {'status_id' => {:values => ['5'], :operator => '='}},
      :sort_criteria => [['id', 'asc']])
    @request.session[:issue_query] = {:id => query.id, :project_id => nil}

    get :show, :params => {
        :id => 11
      }
    assert_response :success

    # Previous and next issues for all projects
    assert_select 'div.next-prev-links' do
      assert_select 'a[href="/issues/8"]', :text => /Previous/
      assert_select 'a[href="/issues/12"]', :text => /Next/
    end
  end

  def test_show_should_display_prev_next_links_with_query_and_sort_on_association
    @request.session[:issue_query] = {:filters => {'status_id' => {:values => [''], :operator => 'o'}}, :project_id => nil}

    %w(project tracker status priority author assigned_to category fixed_version).each do |assoc_sort|
      @request.session[:issue_query][:sort] = [[assoc_sort, 'asc']]

      get :show, :params => {
          :id => 3
        }
      assert_response :success, "Wrong response status for #{assoc_sort} sort"

      assert_select 'div.next-prev-links' do
        assert_select 'a', :text => /(Previous|Next)/
      end
    end
  end

  def test_show_should_display_prev_next_links_with_project_query_in_session
    @request.session[:issue_query] = {:filters => {'status_id' => {:values => [''], :operator => 'o'}}, :project_id => 1, :sort => [['id','asc']]}

    with_settings :display_subprojects_issues => '0' do
      get :show, :params => {
          :id => 3
        }
    end
    assert_response :success

    # Previous and next issues inside project
    assert_select 'div.next-prev-links' do
      assert_select 'a[href="/issues/2"]', :text => /Previous/
      assert_select 'a[href="/issues/7"]', :text => /Next/
    end
  end

  def test_show_should_not_display_prev_link_for_first_issue
    @request.session[:issue_query] = {:filters => {'status_id' => {:values => [''], :operator => 'o'}}, :project_id => 1, :sort => [['id', 'asc']]}

    with_settings :display_subprojects_issues => '0' do
      get :show, :params => {
          :id => 1
        }
    end
    assert_response :success

    assert_select 'div.next-prev-links' do
      assert_select 'a', :text => /Previous/, :count => 0
      assert_select 'a[href="/issues/2"]', :text => /Next/
    end
  end

  def test_show_should_not_display_prev_next_links_for_issue_not_in_query_results
    @request.session[:issue_query] = {:filters => {'status_id' => {:values => [''], :operator => 'c'}}, :project_id => 1, :sort => [['id', 'asc']]}

    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'a', :text => /Previous/, :count => 0
    assert_select 'a', :text => /Next/, :count => 0
  end

  def test_show_show_should_display_prev_next_links_with_query_sort_by_user_custom_field
    cf = IssueCustomField.create!(:name => 'User', :is_for_all => true, :tracker_ids => [1,2,3], :field_format => 'user')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(1), :value => '2')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(2), :value => '3')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(3), :value => '3')
    CustomValue.create!(:custom_field => cf, :customized => Issue.find(5), :value => '')

    query = IssueQuery.create!(:name => 'test', :visibility => IssueQuery::VISIBILITY_PUBLIC,  :user_id => 1, :filters => {},
      :sort_criteria => [["cf_#{cf.id}", 'asc'], ['id', 'asc']])
    @request.session[:issue_query] = {:id => query.id, :project_id => nil}

    get :show, :params => {
        :id => 3
      }
    assert_response :success

    assert_select 'div.next-prev-links' do
      assert_select 'a[href="/issues/2"]', :text => /Previous/
      assert_select 'a[href="/issues/1"]', :text => /Next/
    end
  end

  def test_show_should_display_prev_next_links_when_request_has_previous_and_next_issue_ids_params
    get :show, :params => {
        :id => 1,
        :prev_issue_id => 1,
        :next_issue_id => 3,
        :issue_position => 2,
        :issue_count => 4
      }
    assert_response :success

    assert_select 'div.next-prev-links' do
      assert_select 'a[href="/issues/1"]', :text => /Previous/
      assert_select 'a[href="/issues/3"]', :text => /Next/
      assert_select 'span.position', :text => "2 of 4"
    end
  end

  def test_show_should_display_category_field_if_categories_are_defined
    Issue.update_all :category_id => nil

    get :show, :params => {
        :id => 1
      }
    assert_response :success
    assert_select '.attributes .category'
  end

  def test_show_should_not_display_category_field_if_no_categories_are_defined
    Project.find(1).issue_categories.delete_all

    get :show, :params => {
        :id => 1
      }
    assert_response :success
    assert_select 'table.attributes .category', 0
  end

  def test_show_should_display_link_to_the_assignee
    get :show, :params => {
        :id => 2
      }
    assert_response :success
    assert_select '.assigned-to' do
      assert_select 'a[href="/users/3"]'
    end
  end

  def test_show_should_display_visible_changesets_from_other_projects
    project = Project.find(2)
    issue = project.issues.first
    issue.changeset_ids = [102]
    issue.save!
    # changesets from other projects should be displayed even if repository
    # is disabled on issue's project
    project.disable_module! :repository

    @request.session[:user_id] = 2
    get :issue_tab, :params => {
        :id => issue.id,
        :name => 'changesets'
      },
      :xhr => true

    assert_select 'a[href=?]', '/projects/ecookbook/repository/10/revisions/3'
  end

  def test_show_should_display_watchers
    @request.session[:user_id] = 2
    Issue.find(1).add_watcher User.find(2)

    get :show, :params => {
        :id => 1
      }
    assert_select 'div#watchers ul' do
      assert_select 'li' do
        assert_select 'a[href="/users/2"]'
        assert_select 'a[class*=delete]'
      end
    end
  end

  def test_show_should_display_watchers_with_gravatars
    @request.session[:user_id] = 2
    Issue.find(1).add_watcher User.find(2)

    with_settings :gravatar_enabled => '1' do
      get :show, :params => {
          :id => 1
        }
    end

    assert_select 'div#watchers ul' do
      assert_select 'li' do
        assert_select 'img.gravatar'
        assert_select 'a[href="/users/2"]'
        assert_select 'a[class*=delete]'
      end
    end
  end

  def test_show_with_thumbnails_enabled_should_display_thumbnails
    @request.session[:user_id] = 2

    with_settings :thumbnails_enabled => '1' do
      get :show, :params => {
          :id => 14
        }
      assert_response :success
    end

    assert_select 'div.thumbnails' do
      assert_select 'a[href="/attachments/16"]' do
        assert_select 'img[src="/attachments/thumbnail/16"]'
      end
    end
  end

  def test_show_with_thumbnails_disabled_should_not_display_thumbnails
    @request.session[:user_id] = 2

    with_settings :thumbnails_enabled => '0' do
      get :show, :params => {
          :id => 14
        }
      assert_response :success
    end

    assert_select 'div.thumbnails', 0
  end

  def test_show_with_multi_custom_field
    field = CustomField.find(1)
    field.update_attribute :multiple, true
    issue = Issue.find(1)
    issue.custom_field_values = {1 => ['MySQL', 'Oracle']}
    issue.save!

    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select ".cf_1 .value", :text => 'MySQL, Oracle'
  end

  def test_show_with_full_width_layout_custom_field_should_show_field_under_description
    field = IssueCustomField.create!(:name => 'Long text', :field_format => 'text', :full_width_layout => '1',
      :tracker_ids => [1], :is_for_all => true)
    issue = Issue.find(1)
    issue.custom_field_values = {field.id => 'This is a long text'}
    issue.save!

    get :show, :params => {
        :id => 1
      }
    assert_response :success

    # long text custom field should not be render in the attributes div
    assert_select "div.attributes div.attribute.cf_#{field.id} p strong", 0, :text => 'Long text'
    assert_select "div.attributes div.attribute.cf_#{field.id} div.value", 0, :text => 'This is a long text'

    # long text custom field should be render under description field
    assert_select "div.description ~ div.attribute.cf_#{field.id} p strong", :text => 'Long text'
    assert_select "div.description ~ div.attribute.cf_#{field.id} div.value", :text => 'This is a long text'
  end

  def test_show_custom_fields_with_full_text_formatting_should_be_rendered_using_wiki_class
    half_field = IssueCustomField.create!(:name => 'Half width field', :field_format => 'text', :tracker_ids => [1],
      :is_for_all => true, :text_formatting => 'full')
    full_field = IssueCustomField.create!(:name => 'Full width field', :field_format => 'text', :full_width_layout => '1',
      :tracker_ids => [1], :is_for_all => true, :text_formatting => 'full')

    issue = Issue.find(1)
    issue.custom_field_values = {full_field.id => 'This is a long text', half_field.id => 'This is a short text'}
    issue.save!

    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select "div.attribute.cf_#{half_field.id} div.value div.wiki", 1
    assert_select "div.attribute.cf_#{full_field.id} div.value div.wiki", 1
  end

  def test_show_with_multi_user_custom_field
    field = IssueCustomField.create!(:name => 'Multi user', :field_format => 'user', :multiple => true,
      :tracker_ids => [1], :is_for_all => true)
    issue = Issue.find(1)
    issue.custom_field_values = {field.id => ['2', '3']}
    issue.save!

    get :show, :params => {
        :id => 1
      }
    assert_response :success

    assert_select ".cf_#{field.id} .value", :text => 'Dave Lopper, John Smith' do
      assert_select 'a', :text => 'Dave Lopper'
      assert_select 'a', :text => 'John Smith'
    end
  end

  def test_show_should_not_display_default_value_for_new_custom_field
    prior = Issue.generate!
    field = IssueCustomField.generate!(:name => 'WithDefault', :field_format => 'string', :default_value => 'DEFAULT')
    after = Issue.generate!

    get :show, :params => {:id => prior.id}
    assert_response :success
    assert_select ".cf_#{field.id} .value", :text => ''

    get :show, :params => {:id => after.id}
    assert_response :success
    assert_select ".cf_#{field.id} .value", :text => 'DEFAULT'
  end

  def test_show_should_display_private_notes_with_permission_only
    journal = Journal.create!(:journalized => Issue.find(2), :notes => 'Privates notes', :private_notes => true, :user_id => 1)
    @request.session[:user_id] = 2

    get :show, :params => {
        :id => 2
      }
    assert_response :success
    assert_select "#change-#{journal.id}", 1

    Role.find(1).remove_permission! :view_private_notes
    get :show, :params => {
        :id => 2
      }
    assert_response :success
    assert_select "#change-#{journal.id}", 0
  end

  def test_show_should_display_private_notes_created_by_current_user
    User.find(3).roles_for_project(Project.find(1)).each do |role|
      role.remove_permission! :view_private_notes
    end
    visible = Journal.create!(:journalized => Issue.find(2), :notes => 'Private notes', :private_notes => true, :user_id => 3)
    not_visible = Journal.create!(:journalized => Issue.find(2), :notes => 'Private notes', :private_notes => true, :user_id => 1)
    @request.session[:user_id] = 3

    get :show, :params => {
        :id => 2
      }
    assert_response :success
    assert_select "#change-#{visible.id}", 1
    assert_select "#change-#{not_visible.id}", 0
  end

  def test_show_atom
    get :show, :params => {
        :id => 2,
        :format => 'atom'
      }
    assert_response :success
    assert_equal 'application/atom+xml', response.content_type
    # Inline image
    assert_select 'content', :text => Regexp.new(Regexp.quote('http://test.host/attachments/download/10'))
  end

  def test_show_export_to_pdf
    issue = Issue.find(3)
    assert issue.relations.select{|r| r.other_issue(issue).visible?}.present?
    get :show, :params => {
        :id => 3,
        :format => 'pdf'
      }
    assert_response :success
    assert_equal 'application/pdf', @response.content_type
    assert @response.body.starts_with?('%PDF')
  end

  def test_export_to_pdf_with_utf8_u_fffd
    issue = Issue.generate!(:subject => "�")
    ["en", "zh", "zh-TW", "ja", "ko", "ar"].each do |lang|
      with_settings :default_language => lang do
        get :show, :params => {
            :id => issue.id,
            :format => 'pdf'
          }
        assert_response :success
        assert_equal 'application/pdf', @response.content_type
        assert @response.body.starts_with?('%PDF')
      end
    end
  end

  def test_show_export_to_pdf_with_ancestors
    issue = Issue.generate!(:project_id => 1, :author_id => 2, :tracker_id => 1, :subject => 'child', :parent_issue_id => 1)

    get :show, :params => {
        :id => issue.id,
        :format => 'pdf'
      }
    assert_response :success
    assert_equal 'application/pdf', @response.content_type
    assert @response.body.starts_with?('%PDF')
  end

  def test_show_export_to_pdf_with_descendants
    c1 = Issue.generate!(:project_id => 1, :author_id => 2, :tracker_id => 1, :subject => 'child', :parent_issue_id => 1)
    c2 = Issue.generate!(:project_id => 1, :author_id => 2, :tracker_id => 1, :subject => 'child', :parent_issue_id => 1)
    c3 = Issue.generate!(:project_id => 1, :author_id => 2, :tracker_id => 1, :subject => 'child', :parent_issue_id => c1.id)

    get :show, :params => {
        :id => 1,
        :format => 'pdf'
      }
    assert_response :success
    assert_equal 'application/pdf', @response.content_type
    assert @response.body.starts_with?('%PDF')
  end

  def test_show_export_to_pdf_with_journals
    get :show, :params => {
        :id => 1,
        :format => 'pdf'
      }
    assert_response :success
    assert_equal 'application/pdf', @response.content_type
    assert @response.body.starts_with?('%PDF')
  end

  def test_show_export_to_pdf_with_private_journal
    Journal.create!(
      :journalized => Issue.find(1),
      :notes => 'Private notes',
      :private_notes => true,
      :user_id => 3
    )
    @request.session[:user_id] = 3
    get(
      :show,
      :params => {
        :id => 1,
        :format => 'pdf'
      }
    )
    assert_response :success
    assert_equal 'application/pdf', @response.content_type
    assert @response.body.starts_with?('%PDF')
  end

  def test_show_export_to_pdf_with_changesets
    [[100], [100, 101], [100, 101, 102]].each do |cs|
      issue1 = Issue.find(3)
      issue1.changesets = Changeset.find(cs)
      issue1.save!
      issue = Issue.find(3)
      assert_equal issue.changesets.count, cs.size
      get :show, :params => {
          :id => 3,
          :format => 'pdf'
        }
      assert_response :success
      assert_equal 'application/pdf', @response.content_type
      assert @response.body.starts_with?('%PDF')
    end
  end

  def test_show_invalid_should_respond_with_404
    get :show, :params => {
        :id => 999
      }
    assert_response 404
  end

  def test_show_on_active_project_should_display_edit_links
    @request.session[:user_id] = 1

    get :show, :params => {
        :id => 1
      }
    assert_response :success
    assert_select 'a', :text => 'Edit'
    assert_select 'a', :text => 'Delete'
  end

  def test_show_on_closed_project_should_not_display_edit_links
    Issue.find(1).project.close
    @request.session[:user_id] = 1

    get :show, :params => {
        :id => 1
      }
    assert_response :success
    assert_select 'a', :text => 'Edit', :count => 0
    assert_select 'a', :text => 'Delete', :count => 0
  end

  def test_show_should_not_display_history_tabs_for_issue_without_journals
    @request.session[:user_id] = 1

    get :show, :params => {:id => 5}
    assert_response :success
    assert_select '#history div.tabs', 0
    assert_select '#history p.nodata', :text => 'No data to display'
  end

  def test_show_display_only_all_and_notes_tabs_for_issue_with_notes_only
    @request.session[:user_id] = 1

    get :show, :params => {:id => 6}
    assert_response :success
    assert_select '#history' do
      assert_select 'div.tabs ul a', 2
      assert_select 'div.tabs a[id=?]', 'tab-history', :text => 'History'
      assert_select 'div.tabs a[id=?]', 'tab-notes', :text => 'Notes'
    end
  end

  def test_show_display_only_all_and_history_tabs_for_issue_with_history_changes_only
    journal = Journal.create!(:journalized => Issue.find(5), :user_id => 1)
    detail = JournalDetail.create!(:journal => journal, :property => 'attr', :prop_key => 'description',
      :old_value => 'Foo', :value => 'Bar')

    @request.session[:user_id] = 1

    get :show, :params => {:id => 5}
    assert_response :success
    assert_select '#history' do
      assert_select 'div.tabs ul a', 2
      assert_select 'div.tabs a[id=?]', 'tab-history', :text => 'History'
      assert_select 'div.tabs a[id=?]', 'tab-properties', :text => 'Property changes'
    end
  end

  def test_show_display_all_notes_and_history_tabs_for_issue_with_notes_and_history_changes
    journal = Journal.create!(:journalized => Issue.find(6), :user_id => 1)
    detail = JournalDetail.create!(:journal => journal, :property => 'attr', :prop_key => 'description',
      :old_value => 'Foo', :value => 'Bar')

    @request.session[:user_id] = 1

    get :show, :params => {:id => 6}
    assert_response :success
    assert_select '#history' do
      assert_select 'div.tabs ul a', 3
      assert_select 'div.tabs a[id=?]', 'tab-history', :text => 'History'
      assert_select 'div.tabs a[id=?]', 'tab-notes', :text => 'Notes'
      assert_select 'div.tabs a[id=?]', 'tab-properties', :text => 'Property changes'
    end
  end

  def test_show_display_changesets_tab_for_issue_with_changesets
    project = Project.find(2)
    issue = Issue.find(9)
    issue.changeset_ids = [102]
    issue.save!

    @request.session[:user_id] = 2
    get :show, :params => {:id => issue.id}

    assert_select '#history' do
      assert_select 'div.tabs ul a', 1
      assert_select 'div.tabs a[id=?]', 'tab-changesets', :text => 'Associated revisions'
    end
  end

  def test_show_should_display_spent_time_tab_for_issue_with_time_entries
    @request.session[:user_id] = 1
    get :show, :params => {:id => 3}
    assert_response :success

    assert_select '#history' do
      assert_select 'div.tabs ul a', 1
      assert_select 'div.tabs a[id=?]', 'tab-time_entries', :text => 'Spent time'
    end

    get :issue_tab, :params => {
        :id => 3,
        :name => 'time_entries'
      },
      :xhr => true
    assert_response :success

    assert_select 'div[id=?]', 'time-entry-3' do
      assert_select 'a[title=?][href=?]', 'Edit', '/time_entries/3/edit'
      assert_select 'a[title=?][href=?]', 'Delete', '/time_entries/3'

      assert_select 'ul[class=?]', 'details', :text => /1.00 h/
    end
  end

  def test_get_new
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :tracker_id => 1
      }
    assert_response :success

    assert_select 'form#issue-form[action=?]', '/projects/ecookbook/issues'
    assert_select 'form#issue-form' do
      assert_select 'input[name=?]', 'issue[is_private]'
      assert_select 'select[name=?]', 'issue[project_id]'
      assert_select 'select[name=?]', 'issue[tracker_id]'
      assert_select 'input[name=?]', 'issue[subject]'
      assert_select 'textarea[name=?]', 'issue[description]'
      assert_select 'select[name=?]', 'issue[status_id]'
      assert_select 'select[name=?]', 'issue[priority_id]'
      assert_select 'select[name=?]', 'issue[assigned_to_id]'
      assert_select 'select[name=?]', 'issue[category_id]'
      assert_select 'select[name=?]', 'issue[fixed_version_id]'
      assert_select 'input[name=?]', 'issue[parent_issue_id]'
      assert_select 'input[name=?]', 'issue[start_date]'
      assert_select 'input[name=?]', 'issue[due_date]'
      assert_select 'select[name=?]', 'issue[done_ratio]'
      assert_select 'input[name=?][value=?]', 'issue[custom_field_values][2]', 'Default string'
      assert_select 'input[name=?]', 'issue[watcher_user_ids][]'
    end

    # Be sure we don't display inactive IssuePriorities
    assert ! IssuePriority.find(15).active?
    assert_select 'select[name=?]', 'issue[priority_id]' do
      assert_select 'option[value="15"]', 0
    end
  end

  def test_get_new_should_show_project_selector_for_project_with_subprojects
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :tracker_id => 1
      }
    assert_response :success

    assert_select 'select[name="issue[project_id]"]' do
      assert_select 'option', 3
      assert_select 'option[selected=selected]', :text => 'eCookbook'
      assert_select 'option[value=?]', '5', :text => '  » Private child of eCookbook'
      assert_select 'option[value=?]', '3', :text => '  » eCookbook Subproject 1'

      # user_id 2 is not allowed to add issues on project_id 4 (it's not a member)
      assert_select 'option[value=?]', '4', 0
    end
  end

  def test_get_new_should_not_show_project_selector_for_project_without_subprojects
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 2,
        :tracker_id => 1
      }
    assert_response :success

    assert_select 'select[name="issue[project_id]"]', 0
  end

  def test_get_new_with_minimal_permissions
    Role.find(1).update_attribute :permissions, [:add_issues]
    WorkflowTransition.where(:role_id => 1).delete_all

    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :tracker_id => 1
      }
    assert_response :success

    assert_select 'form#issue-form' do
      assert_select 'input[name=?]', 'issue[is_private]', 0
      assert_select 'select[name=?]', 'issue[project_id]'
      assert_select 'select[name=?]', 'issue[tracker_id]'
      assert_select 'input[name=?]', 'issue[subject]'
      assert_select 'textarea[name=?]', 'issue[description]'
      assert_select 'select[name=?]', 'issue[status_id]'
      assert_select 'select[name=?]', 'issue[priority_id]'
      assert_select 'select[name=?]', 'issue[assigned_to_id]'
      assert_select 'select[name=?]', 'issue[category_id]'
      assert_select 'select[name=?]', 'issue[fixed_version_id]'
      assert_select 'input[name=?]', 'issue[parent_issue_id]', 0
      assert_select 'input[name=?]', 'issue[start_date]'
      assert_select 'input[name=?]', 'issue[due_date]'
      assert_select 'select[name=?]', 'issue[done_ratio]'
      assert_select 'input[name=?][value=?]', 'issue[custom_field_values][2]', 'Default string'
      assert_select 'input[name=?]', 'issue[watcher_user_ids][]', 0
    end
  end

  def test_new_without_project_id
    @request.session[:user_id] = 2
    get :new
    assert_response :success

    assert_select 'form#issue-form[action=?]', '/issues'
    assert_select 'form#issue-form' do
      assert_select 'select[name=?]', 'issue[project_id]'
    end
  end

  def test_new_with_me_assigned_to_id
    @request.session[:user_id] = 2
    get :new, :params => {
      :issue => { :assigned_to_id => 'me' }
    }
    assert_response :success
    assert_select 'select[name=?]', 'issue[assigned_to_id]' do
      assert_select 'option[value="2"][selected=selected]'
    end
  end

  def test_new_should_select_default_status
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option[value="1"][selected=selected]'
    end
    assert_select 'input[name=was_default_status][value="1"]'
  end

  def test_new_should_propose_allowed_statuses
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:tracker_id => 1, :role_id => 1, :old_status_id => 0, :new_status_id => 1)
    WorkflowTransition.create!(:tracker_id => 1, :role_id => 1, :old_status_id => 0, :new_status_id => 3)
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option[value="1"]'
      assert_select 'option[value="3"]'
      assert_select 'option', 2
      assert_select 'option[value="1"][selected=selected]'
    end
  end

  def test_new_should_propose_allowed_statuses_without_default_status_allowed
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:tracker_id => 1, :role_id => 1, :old_status_id => 0, :new_status_id => 2)
    assert_equal 1, Tracker.find(1).default_status_id
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option[value="2"]'
      assert_select 'option', 1
      assert_select 'option[value="2"][selected=selected]'
    end
  end

  def test_new_should_propose_allowed_trackers
    role = Role.find(1)
    role.set_permission_trackers 'add_issues', [1, 3]
    role.save!
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[tracker_id]' do
      assert_select 'option', 2
      assert_select 'option[value="1"]'
      assert_select 'option[value="3"]'
    end
  end

  def test_new_should_default_to_first_tracker
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[tracker_id]' do
      assert_select 'option', 3
      assert_select 'option[value="1"][selected=selected]'
    end
  end

  def test_new_with_parent_issue_id_should_default_to_first_tracker_without_disabled_parent_field
    tracker = Tracker.find(1)
    tracker.core_fields -= ['parent_issue_id']
    tracker.save!
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1,
        :issue => {
          :parent_issue_id => 1
        }
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[tracker_id]' do
      assert_select 'option', 2
      assert_select 'option[value="2"][selected=selected]'
      assert_select 'option[value="1"]', 0
    end
  end

  def test_new_without_allowed_trackers_should_respond_with_403
    role = Role.find(1)
    role.set_permission_trackers 'add_issues', []
    role.save!
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1
      }
    assert_response 403
  end

  def test_new_without_projects_should_respond_with_403
    Project.delete_all
    @request.session[:user_id] = 2

    get :new
    assert_response 403
    assert_select_error /no projects/
  end

  def test_new_without_enabled_trackers_on_projects_should_respond_with_403
    Project.all.each {|p| p.trackers.clear }
    @request.session[:user_id] = 2

    get :new
    assert_response 403
    assert_select_error /no projects/
  end

  def test_new_should_preselect_default_version
    version = Version.generate!(:project_id => 1)
    Project.find(1).update_attribute :default_version_id, version.id
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[fixed_version_id]' do
      assert_select 'option[value=?][selected=selected]', version.id.to_s
    end
  end

  def test_get_new_with_list_custom_field
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :tracker_id => 1
      }
    assert_response :success

    assert_select 'select.list_cf[name=?]', 'issue[custom_field_values][1]' do
      assert_select 'option', 4
      assert_select 'option[value=MySQL]', :text => 'MySQL'
    end
  end

  def test_get_new_with_multi_custom_field
    field = IssueCustomField.find(1)
    field.update_attribute :multiple, true

    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :tracker_id => 1
      }
    assert_response :success

    assert_select 'select[name=?][multiple=multiple]', 'issue[custom_field_values][1][]' do
      assert_select 'option', 3
      assert_select 'option[value=MySQL]', :text => 'MySQL'
    end
    assert_select 'input[name=?][type=hidden][value=?]', 'issue[custom_field_values][1][]', ''
  end

  def test_get_new_with_multi_user_custom_field
    field = IssueCustomField.create!(:name => 'Multi user', :field_format => 'user', :multiple => true,
      :tracker_ids => [1], :is_for_all => true)

    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :tracker_id => 1
      }
    assert_response :success

    assert_select 'select[name=?][multiple=multiple]', "issue[custom_field_values][#{field.id}][]" do
      assert_select 'option', Project.find(1).users.count + 1 # users + 'me'
      assert_select 'option[value="2"]', :text => 'John Smith'
    end
    assert_select 'input[name=?][type=hidden][value=?]', "issue[custom_field_values][#{field.id}][]", ''
  end

  def test_get_new_with_date_custom_field
    field = IssueCustomField.create!(:name => 'Date', :field_format => 'date', :tracker_ids => [1], :is_for_all => true)

    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :tracker_id => 1
      }
    assert_response :success

    assert_select 'input[name=?]', "issue[custom_field_values][#{field.id}]"
  end

  def test_get_new_with_text_custom_field
    field = IssueCustomField.create!(:name => 'Text', :field_format => 'text', :tracker_ids => [1], :is_for_all => true)

    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :tracker_id => 1
      }
    assert_response :success

    assert_select 'textarea[name=?]', "issue[custom_field_values][#{field.id}]"
  end

  def test_get_new_without_default_start_date_is_creation_date
    with_settings :default_issue_start_date_to_creation_date  => 0 do
      @request.session[:user_id] = 2
      get :new, :params => {
          :project_id => 1,
          :tracker_id => 1
        }
      assert_response :success
      assert_select 'input[name=?]', 'issue[start_date]'
      assert_select 'input[name=?][value]', 'issue[start_date]', 0
    end
  end

  def test_get_new_with_default_start_date_is_creation_date
    with_settings :default_issue_start_date_to_creation_date  => 1 do
      @request.session[:user_id] = 2
      get :new, :params => {
          :project_id => 1,
          :tracker_id => 1
        }
      assert_response :success
      assert_select 'input[name=?][value=?]', 'issue[start_date]',
                    Date.today.to_s
    end
  end

  def test_get_new_form_should_allow_attachment_upload
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :tracker_id => 1
      }
    assert_response :success

    assert_select 'form[id=issue-form][method=post][enctype="multipart/form-data"]' do
      assert_select 'input[name=?][type=file]', 'attachments[dummy][file]'
    end
  end

  def test_get_new_should_prefill_the_form_from_params
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :issue => {
          :tracker_id => 3,
          :description => 'Prefilled',
          :custom_field_values => {
          '2' => 'Custom field value'}
        }
      }

    assert_select 'select[name=?]', 'issue[tracker_id]' do
      assert_select 'option[value="3"][selected=selected]'
    end
    assert_select 'textarea[name=?]', 'issue[description]', :text => /Prefilled/
    assert_select 'input[name=?][value=?]', 'issue[custom_field_values][2]', 'Custom field value'
  end

  def test_get_new_should_mark_required_fields
    cf1 = IssueCustomField.create!(:name => 'Foo', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])
    cf2 = IssueCustomField.create!(:name => 'Bar', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'due_date', :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => cf2.id.to_s, :rule => 'required')
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1
      }
    assert_response :success

    assert_select 'label[for=issue_start_date]' do
      assert_select 'span[class=required]', 0
    end
    assert_select 'label[for=issue_due_date]' do
      assert_select 'span[class=required]'
    end
    assert_select 'label[for=?]', "issue_custom_field_values_#{cf1.id}" do
      assert_select 'span[class=required]', 0
    end
    assert_select 'label[for=?]', "issue_custom_field_values_#{cf2.id}" do
      assert_select 'span[class=required]'
    end
  end

  def test_get_new_should_not_display_readonly_fields
    cf1 = IssueCustomField.create!(:name => 'Foo', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])
    cf2 = IssueCustomField.create!(:name => 'Bar', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => 'due_date', :rule => 'readonly')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 1, :role_id => 1, :field_name => cf2.id.to_s, :rule => 'readonly')
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1
      }
    assert_response :success

    assert_select 'input[name=?]', 'issue[start_date]'
    assert_select 'input[name=?]', 'issue[due_date]', 0
    assert_select 'input[name=?]', "issue[custom_field_values][#{cf1.id}]"
    assert_select 'input[name=?]', "issue[custom_field_values][#{cf2.id}]", 0
  end

  def test_new_with_tracker_set_as_readonly_should_accept_status
    WorkflowPermission.delete_all
    [1, 2].each do |status_id|
      WorkflowPermission.create!(:tracker_id => 1, :old_status_id => status_id, :role_id => 1, :field_name => 'tracker_id', :rule => 'readonly')
    end
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1,
        :issue => {
          :status_id => 2
        }
      }
    assert_select 'select[name=?]', 'issue[tracker_id]', 0
    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option[value=?][selected=selected]', '2'
    end
  end

  def test_get_new_without_tracker_id
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[tracker_id]' do
      assert_select 'option[value=?][selected=selected]', Project.find(1).trackers.first.id.to_s
    end
  end

  def test_get_new_with_no_default_status_should_display_an_error
    @request.session[:user_id] = 2
    IssueStatus.delete_all

    get :new, :params => {
        :project_id => 1
      }
    assert_response 500
    assert_select_error /No default issue/
  end

  def test_get_new_with_no_tracker_should_display_an_error
    @request.session[:user_id] = 2
    Tracker.delete_all

    get :new, :params => {
        :project_id => 1
      }
    assert_response 500
    assert_select_error /No tracker/
  end

  def test_new_with_invalid_project_id
    @request.session[:user_id] = 1
    get :new, :params => {
        :project_id => 'invalid'
      }
    assert_response 404
  end

  def test_new_with_parent_id_should_only_propose_valid_trackers
    @request.session[:user_id] = 2
    t = Tracker.find(3)
    assert !t.disabled_core_fields.include?('parent_issue_id')
    get :new, :params => {
        :project_id => 1, :issue => { parent_issue_id: 1 }
      }
    assert_response :success
    assert_select 'option', text: /#{t.name}/, count: 1

    t.core_fields = Tracker::CORE_FIELDS - ['parent_issue_id']
    t.save!
    assert t.disabled_core_fields.include?('parent_issue_id')
    get :new, :params => {
        :project_id => 1, :issue => { parent_issue_id: 1 }
      }
    assert_response :success
    assert_select 'option', text: /#{t.name}/, count: 0
  end

  def test_get_new_should_show_trackers_description
    @request.session[:user_id] = 2
    get :new, :params => {
      :project_id => 1,
      :issue => {
        :tracker_id => 1
      }
    }
    assert_response :success

    assert_select 'form#issue-form' do
      assert_select 'a[title=?]', 'View all trackers description', :text => 'View all trackers description'
      assert_select 'select[name=?][title=?]', 'issue[tracker_id]', 'Description for Bug tracker'
    end

    assert_select 'div#trackers_description' do
      assert_select 'h3', 1, :text => 'Trackers description'
      # only Bug and Feature have descriptions
      assert_select 'dt', 2, :text => 'Bug'
      assert_select 'dd', 2, :text => 'Description for Bug tracker'
    end
  end

  def test_get_new_should_not_show_trackers_description_for_trackers_without_description
    Tracker.update_all(:description => '')

    @request.session[:user_id] = 2
    get :new, :params => {
      :project_id => 1,
      :issue => {
        :tracker_id => 1
      }
    }
    assert_response :success

    assert_select 'form#issue-form' do
      assert_select 'a[title=?]', 'View all trackers description', 0
      assert_select 'select[name=?][title=?]', 'issue[tracker_id]', ''
    end

    assert_select 'div#trackers_description', 0
  end

  def test_update_form_for_new_issue
    @request.session[:user_id] = 2
    post :new, :params => {
        :project_id => 1,
        :issue => {
          :tracker_id => 2,
          :subject => 'This is the test_new issue',
          :description => 'This is the description',
          :priority_id => 5
        }
      },
      :xhr => true
    assert_response :success
    assert_equal 'text/javascript', response.content_type
    assert_include 'This is the test_new issue', response.body
  end

  def test_update_form_for_new_issue_should_propose_transitions_based_on_initial_status
    @request.session[:user_id] = 2
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 0, :new_status_id => 2)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 0, :new_status_id => 5)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 5, :new_status_id => 4)

    post :new, :params => {
        :project_id => 1,
        :issue => {
          :tracker_id => 1,
          :status_id => 5,
          :subject => 'This is an issue'
        }
      }

    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option[value=?][selected=selected]', '5'
      assert_select 'option[value=?]', '2'
      assert_select 'option', :count => 2
    end
  end

  def test_update_form_with_default_status_should_ignore_submitted_status_id_if_equals
    @request.session[:user_id] = 2
    tracker = Tracker.find(2)
    tracker.update! :default_status_id => 2
    tracker.generate_transitions! 2 => 1, :clear => true

    post :new, :params => {
        :project_id => 1,
        :issue => {
          :tracker_id => 2,
          :status_id => 1
        },
        :was_default_status => 1
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option[value=?][selected=selected]', '2'
    end
  end

  def test_update_form_for_new_issue_should_ignore_version_when_changing_project
    version = Version.generate!(:project_id => 1)
    Project.find(1).update_attribute :default_version_id, version.id
    @request.session[:user_id] = 2

    post :new, :params => {
        :issue => {
          :project_id => 1,
          :fixed_version_id => ''
        },
        :form_update_triggered_by => 'issue_project_id'
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[project_id]' do
      assert_select 'option[value=?][selected=selected]', '1'
    end
    assert_select 'select[name=?]', 'issue[fixed_version_id]' do
      assert_select 'option[value=?][selected=selected]', version.id.to_s
    end
  end

  def test_post_create
    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      assert_no_difference 'Journal.count' do
        post :create, :params => {
            :project_id => 1,
            :issue => {
              :tracker_id => 3,
              :status_id => 2,
              :subject => 'This is the test_new issue',
              :description => 'This is the description',
              :priority_id => 5,
              :start_date => '2010-11-07',
              :estimated_hours => '',
              :custom_field_values => {
              '2' => 'Value for field 2'}
            }
          }
      end
    end
    assert_redirected_to :controller => 'issues', :action => 'show', :id => Issue.last.id

    issue = Issue.find_by_subject('This is the test_new issue')
    assert_not_nil issue
    assert_equal 2, issue.author_id
    assert_equal 3, issue.tracker_id
    assert_equal 2, issue.status_id
    assert_equal Date.parse('2010-11-07'), issue.start_date
    assert_nil issue.estimated_hours
    v = issue.custom_values.where(:custom_field_id => 2).first
    assert_not_nil v
    assert_equal 'Value for field 2', v.value
  end

  def test_post_new_with_group_assignment
    group = Group.find(11)
    project = Project.find(1)
    project.members << Member.new(:principal => group, :roles => [Role.givable.first])

    with_settings :issue_group_assignment => '1' do
      @request.session[:user_id] = 2
      assert_difference 'Issue.count' do
        post :create, :params => {
            :project_id => project.id,
            :issue => {
              :tracker_id => 3,
              :status_id => 1,
              :subject => 'This is the test_new_with_group_assignment issue',
              :assigned_to_id => group.id
            }
          }
      end
    end
    assert_redirected_to :controller => 'issues', :action => 'show', :id => Issue.last.id

    issue = Issue.find_by_subject('This is the test_new_with_group_assignment issue')
    assert_not_nil issue
    assert_equal group, issue.assigned_to
  end

  def test_post_create_without_start_date_and_default_start_date_is_not_creation_date
    with_settings :default_issue_start_date_to_creation_date  => 0 do
      @request.session[:user_id] = 2
      assert_difference 'Issue.count' do
        post :create, :params => {
            :project_id => 1,
            :issue => {
              :tracker_id => 3,
              :status_id => 2,
              :subject => 'This is the test_new issue',
              :description => 'This is the description',
              :priority_id => 5,
              :estimated_hours => '',
              :custom_field_values => {
              '2' => 'Value for field 2'}
            }
          }
      end
      assert_redirected_to :controller => 'issues', :action => 'show',
                           :id => Issue.last.id
      issue = Issue.find_by_subject('This is the test_new issue')
      assert_not_nil issue
      assert_nil issue.start_date
    end
  end

  def test_post_create_without_start_date_and_default_start_date_is_creation_date
    with_settings :default_issue_start_date_to_creation_date  => 1 do
      @request.session[:user_id] = 2
      assert_difference 'Issue.count' do
        post :create, :params => {
            :project_id => 1,
            :issue => {
              :tracker_id => 3,
              :status_id => 2,
              :subject => 'This is the test_new issue',
              :description => 'This is the description',
              :priority_id => 5,
              :estimated_hours => '',
              :custom_field_values => {
              '2' => 'Value for field 2'}
            }
          }
      end
      assert_redirected_to :controller => 'issues', :action => 'show',
                           :id => Issue.last.id
      issue = Issue.find_by_subject('This is the test_new issue')
      assert_not_nil issue
      assert_equal Date.today, issue.start_date
    end
  end

  def test_post_create_and_continue
    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 3,
            :subject => 'This is first issue',
            :priority_id => 5
          },
          :continue => ''
        }
    end

    issue = Issue.order('id DESC').first
    assert_redirected_to :controller => 'issues',
                         :action => 'new', :project_id => 'ecookbook',
                         :issue => {:tracker_id => 3}
    assert_not_nil flash[:notice], "flash was not set"
    assert_select_in flash[:notice],
                     'a[href=?][title=?]', "/issues/#{issue.id}",
                     "This is first issue", :text => "##{issue.id}"
  end

  def test_post_create_without_custom_fields_param
    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is the test_new issue',
            :description => 'This is the description',
            :priority_id => 5
          }
        }
    end
    assert_redirected_to :controller => 'issues', :action => 'show', :id => Issue.last.id
  end

  def test_post_create_with_multi_custom_field
    field = IssueCustomField.find_by_name('Database')
    field.update_attribute(:multiple, true)

    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is the test_new issue',
            :description => 'This is the description',
            :priority_id => 5,
            :custom_field_values => {
            '1' => ['', 'MySQL', 'Oracle']}
          }
        }
    end
    assert_response 302
    issue = Issue.order('id DESC').first
    assert_equal ['MySQL', 'Oracle'], issue.custom_field_value(1).sort
  end

  def test_post_create_with_empty_multi_custom_field
    field = IssueCustomField.find_by_name('Database')
    field.update_attribute(:multiple, true)

    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is the test_new issue',
            :description => 'This is the description',
            :priority_id => 5,
            :custom_field_values => {
            '1' => ['']}
          }
        }
    end
    assert_response 302
    issue = Issue.order('id DESC').first
    assert_equal [''], issue.custom_field_value(1).sort
  end

  def test_post_create_with_multi_user_custom_field
    field = IssueCustomField.create!(:name => 'Multi user', :field_format => 'user', :multiple => true,
      :tracker_ids => [1], :is_for_all => true)

    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is the test_new issue',
            :description => 'This is the description',
            :priority_id => 5,
            :custom_field_values => {
            field.id.to_s => ['', '2', '3']}
          }
        }
    end
    assert_response 302
    issue = Issue.order('id DESC').first
    assert_equal ['2', '3'], issue.custom_field_value(field).sort
  end

  def test_post_create_with_required_custom_field_and_without_custom_fields_param
    field = IssueCustomField.find_by_name('Database')
    field.update_attribute(:is_required, true)

    @request.session[:user_id] = 2
    assert_no_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is the test_new issue',
            :description => 'This is the description',
            :priority_id => 5
          }
        }
    end
    assert_response :success
    assert_select_error /Database cannot be blank/
  end

  def test_create_should_validate_required_fields
    cf1 = IssueCustomField.create!(:name => 'Foo', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])
    cf2 = IssueCustomField.create!(:name => 'Bar', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2, :role_id => 1, :field_name => 'due_date', :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2, :role_id => 1, :field_name => cf2.id.to_s, :rule => 'required')
    @request.session[:user_id] = 2

    assert_no_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 2,
            :status_id => 1,
            :subject => 'Test',
            :start_date => '',
            :due_date => '',
            :custom_field_values => {
              cf1.id.to_s => '', cf2.id.to_s => ''
            }

          }
        }
      assert_response :success
    end

    assert_select_error /Due date cannot be blank/i
    assert_select_error /Bar cannot be blank/i
  end

  def test_create_should_validate_required_list_fields
    cf1 = IssueCustomField.create!(:name => 'Foo', :field_format => 'list', :is_for_all => true, :tracker_ids => [1, 2], :multiple => false, :possible_values => ['a', 'b'])
    cf2 = IssueCustomField.create!(:name => 'Bar', :field_format => 'list', :is_for_all => true, :tracker_ids => [1, 2], :multiple => true, :possible_values => ['a', 'b'])
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2, :role_id => 1, :field_name => cf1.id.to_s, :rule => 'required')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2, :role_id => 1, :field_name => cf2.id.to_s, :rule => 'required')
    @request.session[:user_id] = 2

    assert_no_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 2,
            :status_id => 1,
            :subject => 'Test',
            :start_date => '',
            :due_date => '',
            :custom_field_values => {
              cf1.id.to_s => '', cf2.id.to_s => ['']
            }

          }
        }
      assert_response :success
    end

    assert_select_error /Foo cannot be blank/i
    assert_select_error /Bar cannot be blank/i
  end

  def test_create_should_ignore_readonly_fields
    cf1 = IssueCustomField.create!(:name => 'Foo', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])
    cf2 = IssueCustomField.create!(:name => 'Bar', :field_format => 'string', :is_for_all => true, :tracker_ids => [1, 2])
    WorkflowPermission.delete_all
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2, :role_id => 1, :field_name => 'due_date', :rule => 'readonly')
    WorkflowPermission.create!(:old_status_id => 1, :tracker_id => 2, :role_id => 1, :field_name => cf2.id.to_s, :rule => 'readonly')
    @request.session[:user_id] = 2

    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 2,
            :status_id => 1,
            :subject => 'Test',
            :start_date => '2012-07-14',
            :due_date => '2012-07-16',
            :custom_field_values => {
              cf1.id.to_s => 'value1', cf2.id.to_s => 'value2'
            }

          }
        }
      assert_response 302
    end

    issue = Issue.order('id DESC').first
    assert_equal Date.parse('2012-07-14'), issue.start_date
    assert_nil issue.due_date
    assert_equal 'value1', issue.custom_field_value(cf1)
    assert_nil issue.custom_field_value(cf2)
  end

  def test_create_should_ignore_unallowed_trackers
    role = Role.find(1)
    role.set_permission_trackers :add_issues, [3]
    role.save!
    @request.session[:user_id] = 2

    issue = new_record(Issue) do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :status_id => 1,
            :subject => 'Test'

          }
        }
      assert_response 302
    end
    assert_equal 3, issue.tracker_id
  end

  def test_post_create_with_watchers
    @request.session[:user_id] = 2
    ActionMailer::Base.deliveries.clear

    with_settings :notified_events => %w(issue_added) do
      assert_difference 'Watcher.count', 2 do
        post :create, :params => {
            :project_id => 1,
            :issue => {
              :tracker_id => 1,
              :subject => 'This is a new issue with watchers',
              :description => 'This is the description',
              :priority_id => 5,
              :watcher_user_ids => ['2', '3']
            }
          }
      end
    end
    issue = Issue.find_by_subject('This is a new issue with watchers')
    assert_not_nil issue
    assert_redirected_to :controller => 'issues', :action => 'show', :id => issue

    # Watchers added
    assert_equal [2, 3], issue.watcher_user_ids.sort
    assert issue.watched_by?(User.find(3))
    # Watchers notified
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert [mail.bcc, mail.cc].flatten.include?(User.find(3).mail)
  end

  def test_post_create_subissue
    @request.session[:user_id] = 2

    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is a child issue',
            :parent_issue_id => '2'
          }
        }
      assert_response 302
    end
    issue = Issue.order('id DESC').first
    assert_equal Issue.find(2), issue.parent
  end

  def test_post_create_subissue_with_sharp_parent_id
    @request.session[:user_id] = 2

    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is a child issue',
            :parent_issue_id => '#2'
          }
        }
      assert_response 302
    end
    issue = Issue.order('id DESC').first
    assert_equal Issue.find(2), issue.parent
  end

  def test_post_create_subissue_with_non_visible_parent_id_should_not_validate
    @request.session[:user_id] = 2

    assert_no_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is a child issue',
            :parent_issue_id => '4'
          }
        }

      assert_response :success
      assert_select 'input[name=?][value=?]', 'issue[parent_issue_id]', '4'
      assert_select_error /Parent task is invalid/i
    end
  end

  def test_post_create_subissue_with_non_numeric_parent_id_should_not_validate
    @request.session[:user_id] = 2

    assert_no_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is a child issue',
            :parent_issue_id => '01ABC'
          }
        }

      assert_response :success
      assert_select 'input[name=?][value=?]', 'issue[parent_issue_id]', '01ABC'
      assert_select_error /Parent task is invalid/i
    end
  end

  def test_post_create_private
    @request.session[:user_id] = 2

    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is a private issue',
            :is_private => '1'
          }
        }
    end
    issue = Issue.order('id DESC').first
    assert issue.is_private?
  end

  def test_post_create_private_with_set_own_issues_private_permission
    role = Role.find(1)
    role.remove_permission! :set_issues_private
    role.add_permission! :set_own_issues_private

    @request.session[:user_id] = 2

    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is a private issue',
            :is_private => '1'
          }
        }
    end
    issue = Issue.order('id DESC').first
    assert issue.is_private?
  end

  def test_create_without_project_id
    @request.session[:user_id] = 2

    assert_difference 'Issue.count' do
      post :create, :params => {
          :issue => {
            :project_id => 3,
            :tracker_id => 2,
            :subject => 'Foo'
          }
        }
      assert_response 302
    end
    issue = Issue.order('id DESC').first
    assert_equal 3, issue.project_id
    assert_equal 2, issue.tracker_id
  end

  def test_create_without_project_id_and_continue_should_redirect_without_project_id
    @request.session[:user_id] = 2

    assert_difference 'Issue.count' do
      post :create, :params => {
          :issue => {
            :project_id => 3,
            :tracker_id => 2,
            :subject => 'Foo'
          },
          :continue => '1'
        }
      assert_redirected_to '/issues/new?issue%5Bproject_id%5D=3&issue%5Btracker_id%5D=2'
    end
  end

  def test_create_without_project_id_should_be_denied_without_permission
    Role.non_member.remove_permission! :add_issues
    Role.anonymous.remove_permission! :add_issues
    @request.session[:user_id] = 2

    assert_no_difference 'Issue.count' do
      post :create, :params => {
          :issue => {
            :project_id => 3,
            :tracker_id => 2,
            :subject => 'Foo'
          }
        }
      assert_response 422
    end
  end

  def test_create_without_project_id_with_failure_should_not_set_project
    @request.session[:user_id] = 2

    post :create, :params => {
        :issue => {
          :project_id => 3,
          :tracker_id => 2,
          :subject => ''
        }
      }
    assert_response :success
    # no project menu
    assert_select '#main-menu a.overview', 0
  end

  def test_post_create_should_send_a_notification
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 2
    with_settings :notified_events => %w(issue_added) do
      assert_difference 'Issue.count' do
        post :create, :params => {
            :project_id => 1,
            :issue => {
              :tracker_id => 3,
              :subject => 'This is the test_new issue',
              :description => 'This is the description',
              :priority_id => 5,
              :estimated_hours => '',
              :custom_field_values => {
              '2' => 'Value for field 2'}
            }
          }
      end
      assert_redirected_to :controller => 'issues', :action => 'show', :id => Issue.last.id

      assert_equal 2, ActionMailer::Base.deliveries.size
    end
  end

  def test_post_create_should_preserve_fields_values_on_validation_failure
    @request.session[:user_id] = 2
    post :create, :params => {
        :project_id => 1,
        :issue => {
          :tracker_id => 1,
          :subject => '', # empty subject
          :description => 'This is a description',
          :priority_id => 6,
          :custom_field_values => {'1' => 'Oracle', '2' => 'Value for field 2'}
        }
      }
    assert_response :success

    assert_select 'textarea[name=?]', 'issue[description]', :text => 'This is a description'
    assert_select 'select[name=?]', 'issue[priority_id]' do
      assert_select 'option[value="6"][selected=selected]', :text => 'High'
    end
    # Custom fields
    assert_select 'select[name=?]', 'issue[custom_field_values][1]' do
      assert_select 'option[value=Oracle][selected=selected]', :text => 'Oracle'
    end
    assert_select 'input[name=?][value=?]', 'issue[custom_field_values][2]', 'Value for field 2'
  end

  def test_post_create_with_failure_should_preserve_watchers
    assert !User.find(8).member_of?(Project.find(1))

    @request.session[:user_id] = 2
    post :create, :params => {
        :project_id => 1,
        :issue => {
          :tracker_id => 1,
          :watcher_user_ids => ['3', '8']
        }
      }
    assert_response :success

    assert_select 'input[name=?][value="2"]:not(checked)', 'issue[watcher_user_ids][]'
    assert_select 'input[name=?][value="3"][checked=checked]', 'issue[watcher_user_ids][]'
    assert_select 'input[name=?][value="8"][checked=checked]', 'issue[watcher_user_ids][]'
  end

  def test_post_create_should_ignore_non_safe_attributes
    @request.session[:user_id] = 2
    assert_nothing_raised do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker => "A param can not be a Tracker"
          }
        }
    end
  end

  def test_post_create_with_attachment
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    assert_difference 'Issue.count' do
      assert_difference 'Attachment.count' do
        assert_no_difference 'Journal.count' do
          post :create, :params => {
              :project_id => 1,
              :issue => {
                :tracker_id => '1',
                :subject => 'With attachment'
              },
              :attachments => {
                '1' => {
                'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'test file'}
              }
            }
        end
      end
    end

    issue = Issue.order('id DESC').first
    attachment = Attachment.order('id DESC').first

    assert_equal issue, attachment.container
    assert_equal 2, attachment.author_id
    assert_equal 'testfile.txt', attachment.filename
    assert_equal 'text/plain', attachment.content_type
    assert_equal 'test file', attachment.description
    assert_equal 59, attachment.filesize
    assert File.exists?(attachment.diskfile)
    assert_equal 59, File.size(attachment.diskfile)
  end

  def test_post_create_with_attachment_should_notify_with_attachments
    ActionMailer::Base.deliveries.clear
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    with_settings :notified_events => %w(issue_added) do
      assert_difference 'Issue.count' do
        post :create, :params => {
            :project_id => 1,
            :issue => {
              :tracker_id => '1',
              :subject => 'With attachment'
            },
            :attachments => {
              '1' => {
              'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'test file'}
            }
          }
      end
    end

    assert_not_nil ActionMailer::Base.deliveries.last
    assert_select_email do
      assert_select 'a[href^=?]', 'http://localhost:3000/attachments/download', 'testfile.txt'
    end
  end

  def test_post_create_with_failure_should_save_attachments
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    assert_no_difference 'Issue.count' do
      assert_difference 'Attachment.count' do
        post :create, :params => {
            :project_id => 1,
            :issue => {
              :tracker_id => '1',
              :subject => ''
            },
            :attachments => {
              '1' => {
              'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'test file'}
            }
          }
        assert_response :success
      end
    end

    attachment = Attachment.order('id DESC').first
    assert_equal 'testfile.txt', attachment.filename
    assert File.exists?(attachment.diskfile)
    assert_nil attachment.container

    assert_select 'input[name=?][value=?]', 'attachments[p0][token]', attachment.token
    assert_select 'input[name=?][value=?]', 'attachments[p0][filename]', 'testfile.txt'
  end

  def test_post_create_with_failure_should_keep_saved_attachments
    set_tmp_attachments_directory
    attachment = Attachment.create!(:file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 2)
    @request.session[:user_id] = 2

    assert_no_difference 'Issue.count' do
      assert_no_difference 'Attachment.count' do
        post :create, :params => {
            :project_id => 1,
            :issue => {
              :tracker_id => '1',
              :subject => ''
            },
            :attachments => {
              'p0' => {
              'token' => attachment.token}
            }
          }
        assert_response :success
      end
    end

    assert_select 'input[name=?][value=?]', 'attachments[p0][token]', attachment.token
    assert_select 'input[name=?][value=?]', 'attachments[p0][filename]', 'testfile.txt'
  end

  def test_post_create_should_attach_saved_attachments
    set_tmp_attachments_directory
    attachment = Attachment.create!(:file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 2)
    @request.session[:user_id] = 2

    assert_difference 'Issue.count' do
      assert_no_difference 'Attachment.count' do
        post :create, :params => {
            :project_id => 1,
            :issue => {
              :tracker_id => '1',
              :subject => 'Saved attachments'
            },
            :attachments => {
              'p0' => {
              'token' => attachment.token}
            }
          }
        assert_response 302
      end
    end

    issue = Issue.order('id DESC').first
    assert_equal 1, issue.attachments.count

    attachment.reload
    assert_equal issue, attachment.container
  end

  def setup_without_workflow_privilege
    WorkflowTransition.where(["role_id = ?", Role.anonymous.id]).delete_all
    Role.anonymous.add_permission! :add_issues, :add_issue_notes
  end
  private :setup_without_workflow_privilege

  test "without workflow privilege #new should propose default status only" do
    setup_without_workflow_privilege
    get :new, :params => {
        :project_id => 1
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option', 1
      assert_select 'option[value=?][selected=selected]', '1'
    end
  end

  test "without workflow privilege #create should accept default status" do
    setup_without_workflow_privilege
    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is an issue',
            :status_id => 1
          }
        }
    end
    issue = Issue.order('id').last
    assert_not_nil issue.default_status
    assert_equal issue.default_status, issue.status
  end

  test "without workflow privilege #create should ignore unauthorized status" do
    setup_without_workflow_privilege
    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :subject => 'This is an issue',
            :status_id => 3
          }
        }
    end
    issue = Issue.order('id').last
    assert_not_nil issue.default_status
    assert_equal issue.default_status, issue.status
  end

  test "without workflow privilege #update should ignore status change" do
    setup_without_workflow_privilege
    assert_difference 'Journal.count' do
      put :update, :params => {
          :id => 1,
          :issue => {
            :status_id => 3,
            :notes => 'just trying'
          }
        }
    end
    assert_equal 1, Issue.find(1).status_id
  end

  test "without workflow privilege #update ignore attributes changes" do
    setup_without_workflow_privilege
    assert_difference 'Journal.count' do
      put :update, :params => {
          :id => 1,
          :issue => {
            :subject => 'changed',
            :assigned_to_id => 2,
            :notes => 'just trying'
          }
        }
    end
    issue = Issue.find(1)
    assert_equal "Cannot print recipes", issue.subject
    assert_nil issue.assigned_to
  end

  def setup_with_workflow_privilege
    WorkflowTransition.where(["role_id = ?", Role.anonymous.id]).delete_all
    WorkflowTransition.create!(:role => Role.anonymous, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 3)
    WorkflowTransition.create!(:role => Role.anonymous, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 4)
    Role.anonymous.add_permission! :add_issues, :add_issue_notes
  end
  private :setup_with_workflow_privilege

  def setup_with_workflow_privilege_and_edit_issues_permission
    setup_with_workflow_privilege
    Role.anonymous.add_permission! :add_issues, :edit_issues
  end
  private :setup_with_workflow_privilege_and_edit_issues_permission

  test "with workflow privilege and :edit_issues permission should accept authorized status" do
    setup_with_workflow_privilege_and_edit_issues_permission
    assert_difference 'Journal.count' do
      put :update, :params => {
          :id => 1,
          :issue => {
            :status_id => 3,
            :notes => 'just trying'
          }
        }
    end
    assert_equal 3, Issue.find(1).status_id
  end

  test "with workflow privilege and :edit_issues permission should ignore unauthorized status" do
    setup_with_workflow_privilege_and_edit_issues_permission
    assert_difference 'Journal.count' do
      put :update, :params => {
          :id => 1,
          :issue => {
            :status_id => 2,
            :notes => 'just trying'
          }
        }
    end
    assert_equal 1, Issue.find(1).status_id
  end

  test "with workflow privilege and :edit_issues permission should accept authorized attributes changes" do
    setup_with_workflow_privilege_and_edit_issues_permission
    assert_difference 'Journal.count' do
      put :update, :params => {
          :id => 1,
          :issue => {
            :subject => 'changed',
            :assigned_to_id => 2,
            :notes => 'just trying'
          }
        }
    end
    issue = Issue.find(1)
    assert_equal "changed", issue.subject
    assert_equal 2, issue.assigned_to_id
  end

  def test_new_as_copy
    orig = Issue.find(1)
    @request.session[:user_id] = 2

    get :new, :params => {
        :project_id => 1,
        :copy_from => orig.id
      }
    assert_response :success

    assert_select 'form[id=issue-form][action="/projects/ecookbook/issues"]' do
      assert_select 'select[name=?]', 'issue[project_id]' do
        assert_select 'option[value="1"][selected=selected]', :text => 'eCookbook'
        assert_select 'option[value="2"]:not([selected])', :text => 'OnlineStore'
      end
      assert_select 'input[name=?][value=?]', 'issue[subject]', orig.subject
      assert_select 'input[name=copy_from][value="1"]'
    end
  end

  def test_new_as_copy_without_add_issues_permission_should_not_propose_current_project_as_target
    user = setup_user_with_copy_but_not_add_permission

    @request.session[:user_id] = user.id
    get :new, :params => {
        :project_id => 1,
        :copy_from => 1
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[project_id]' do
      assert_select 'option[value="1"]', 0
      assert_select 'option[value="2"]', :text => 'OnlineStore'
    end
  end

  def test_new_as_copy_with_attachments_should_show_copy_attachments_checkbox
    @request.session[:user_id] = 2
    issue = Issue.find(3)
    assert issue.attachments.count > 0
    get :new, :params => {
        :project_id => 1,
        :copy_from => 3
      }

    assert_select 'input[name=copy_attachments][type=checkbox][checked=checked][value="1"]'
  end

  def test_new_as_copy_without_attachments_should_not_show_copy_attachments_checkbox
    @request.session[:user_id] = 2
    issue = Issue.find(3)
    issue.attachments.delete_all
    get :new, :params => {
        :project_id => 1,
        :copy_from => 3
      }

    assert_select 'input[name=copy_attachments]', 0
  end

  def test_new_as_copy_should_preserve_parent_id
    @request.session[:user_id] = 2
    issue = Issue.generate!(:parent_issue_id => 2)
    get :new, :params => {
        :project_id => 1,
        :copy_from => issue.id
      }

    assert_select 'input[name=?][value="2"]', 'issue[parent_issue_id]'
  end

  def test_new_as_copy_with_subtasks_should_show_copy_subtasks_checkbox
    @request.session[:user_id] = 2
    issue = Issue.generate_with_descendants!
    get :new, :params => {
        :project_id => 1,
        :copy_from => issue.id
      }

    assert_select 'input[type=checkbox][name=copy_subtasks][checked=checked][value="1"]'
  end

  def test_new_as_copy_should_preserve_watchers
    @request.session[:user_id] = 2
    user = User.generate!
    Watcher.create!(:watchable => Issue.find(1), :user => user)
    get :new, :params => {
        :project_id => 1,
        :copy_from => 1
      }

    assert_select 'input[type=checkbox][name=?][checked=checked]', 'issue[watcher_user_ids][]', 1
    assert_select 'input[type=checkbox][name=?][checked=checked][value=?]', 'issue[watcher_user_ids][]', user.id.to_s
    assert_select 'input[type=hidden][name=?][value=?]', 'issue[watcher_user_ids][]', '', 1
  end

  def test_new_as_copy_should_not_propose_locked_watchers
    @request.session[:user_id] = 2

    issue = Issue.find(1)
    user = User.generate!
    user2 = User.generate!

    Watcher.create!(:watchable => issue, :user => user)
    Watcher.create!(:watchable => issue, :user => user2)

    user2.status = User::STATUS_LOCKED
    user2.save!
    get :new, :params => {
        :project_id => 1,
        :copy_from => 1
      }

    assert_select 'input[type=checkbox][name=?][checked=checked]', 'issue[watcher_user_ids][]', 1
    assert_select 'input[type=checkbox][name=?][checked=checked][value=?]', 'issue[watcher_user_ids][]', user.id.to_s
    assert_select 'input[type=checkbox][name=?][checked=checked][value=?]', 'issue[watcher_user_ids][]', user2.id.to_s, 0
    assert_select 'input[type=hidden][name=?][value=?]', 'issue[watcher_user_ids][]', '', 1
  end

  def test_new_as_copy_with_invalid_issue_should_respond_with_404
    @request.session[:user_id] = 2
    get :new, :params => {
        :project_id => 1,
        :copy_from => 99999
      }
    assert_response 404
  end

  def test_create_as_copy_on_different_project
    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :copy_from => 1,
          :issue => {
            :project_id => '2',
            :tracker_id => '3',
            :status_id => '1',
            :subject => 'Copy'
          }
        }
    end
    issue = Issue.order('id DESC').first
    assert_redirected_to "/issues/#{issue.id}"

    assert_equal 2, issue.project_id
    assert_equal 3, issue.tracker_id
    assert_equal 'Copy', issue.subject
  end

  def test_create_as_copy_should_allow_status_to_be_set_to_default
    copied = Issue.generate! :status_id => 2
    assert_equal 2, copied.reload.status_id

    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :copy_from => copied.id,
          :issue => {
            :project_id => '1',
            :tracker_id => '1',
            :status_id => '1'
          },
          :was_default_status => '1'
        }
    end
    issue = Issue.order('id DESC').first
    assert_equal 1, issue.status_id
  end

  def test_create_as_copy_should_fail_without_add_issue_permission_on_original_tracker
    role = Role.find(2)
    role.set_permission_trackers :add_issues, [1, 3]
    role.save!
    Role.non_member.remove_permission! :add_issues

    issue = Issue.generate!(:project_id => 1, :tracker_id => 2)
    @request.session[:user_id] = 3

    assert_no_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :copy_from => issue.id,
          :issue => {
            :project_id => '1'
          }
        }
    end
    assert_select_error 'Tracker is invalid'
  end

  def test_create_as_copy_should_copy_attachments
    @request.session[:user_id] = 2
    issue = Issue.find(3)
    count = issue.attachments.count
    assert count > 0
    assert_difference 'Issue.count' do
      assert_difference 'Attachment.count', count do
        post :create, :params => {
            :project_id => 1,
            :copy_from => 3,
            :issue => {
              :project_id => '1',
              :tracker_id => '3',
              :status_id => '1',
              :subject => 'Copy with attachments'
            },
            :copy_attachments => '1'
          }
      end
    end
    copy = Issue.order('id DESC').first
    assert_equal count, copy.attachments.count
    assert_equal issue.attachments.map(&:filename).sort, copy.attachments.map(&:filename).sort
  end

  def test_create_as_copy_without_copy_attachments_option_should_not_copy_attachments
    @request.session[:user_id] = 2
    issue = Issue.find(3)
    count = issue.attachments.count
    assert count > 0
    assert_difference 'Issue.count' do
      assert_no_difference 'Attachment.count' do
        post :create, :params => {
            :project_id => 1,
            :copy_from => 3,
            :issue => {
              :project_id => '1',
              :tracker_id => '3',
              :status_id => '1',
              :subject => 'Copy with attachments'
            }
          }
      end
    end
    copy = Issue.order('id DESC').first
    assert_equal 0, copy.attachments.count
  end

  def test_create_as_copy_with_attachments_should_also_add_new_files
    set_tmp_attachments_directory
    @request.session[:user_id] = 2
    issue = Issue.find(3)
    count = issue.attachments.count
    assert count > 0
    assert_difference 'Issue.count' do
      assert_difference 'Attachment.count', count + 1 do
        post :create, :params => {
            :project_id => 1,
            :copy_from => 3,
            :issue => {
              :project_id => '1',
              :tracker_id => '3',
              :status_id => '1',
              :subject => 'Copy with attachments'
            },
            :copy_attachments => '1',
            :attachments => {
              '1' => {
                'file' => uploaded_test_file('testfile.txt', 'text/plain'),
                'description' => 'test file'
              }
          }
        }
      end
    end
    copy = Issue.order('id DESC').first
    assert_equal count + 1, copy.attachments.count
  end

  def test_create_as_copy_should_add_relation_with_copied_issue
    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      assert_difference 'IssueRelation.count' do
        post :create, :params => {
            :project_id => 1,
            :copy_from => 1,
            :link_copy => '1',
            :issue => {
              :project_id => '1',
              :tracker_id => '3',
              :status_id => '1',
              :subject => 'Copy'
            }
          }
      end
    end
    copy = Issue.order('id DESC').first
    assert_equal 1, copy.relations.size
  end

  def test_create_as_copy_should_allow_not_to_add_relation_with_copied_issue
    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      assert_no_difference 'IssueRelation.count' do
        post :create, :params => {
            :project_id => 1,
            :copy_from => 1,
            :issue => {
              :subject => 'Copy'
            }
          }
      end
    end
  end

  def test_create_as_copy_should_always_add_relation_with_copied_issue_by_setting
    with_settings :link_copied_issue => 'yes' do
      @request.session[:user_id] = 2
      assert_difference 'Issue.count' do
        assert_difference 'IssueRelation.count' do
          post :create, :params => {
              :project_id => 1,
              :copy_from => 1,
              :issue => {
                :subject => 'Copy'
              }
            }
        end
      end
    end
  end

  def test_create_as_copy_should_never_add_relation_with_copied_issue_by_setting
    with_settings :link_copied_issue => 'no' do
      @request.session[:user_id] = 2
      assert_difference 'Issue.count' do
        assert_no_difference 'IssueRelation.count' do
          post :create, :params => {
              :project_id => 1,
              :copy_from => 1,
              :link_copy => '1',
              :issue => {
                :subject => 'Copy'
              }
            }
        end
      end
    end
  end

  def test_create_as_copy_should_copy_subtasks
    @request.session[:user_id] = 2
    issue = Issue.generate_with_descendants!
    count = issue.descendants.count
    assert_difference 'Issue.count', count + 1 do
      post :create, :params => {
          :project_id => 1,
          :copy_from => issue.id,
          :issue => {
            :project_id => '1',
            :tracker_id => '3',
            :status_id => '1',
            :subject => 'Copy with subtasks'
          },
          :copy_subtasks => '1'
        }
    end
    copy = Issue.where(:parent_id => nil).order('id DESC').first
    assert_equal count, copy.descendants.count
    assert_equal issue.descendants.map(&:subject).sort, copy.descendants.map(&:subject).sort
  end

  def test_create_as_copy_to_a_different_project_should_copy_subtask_custom_fields
    issue = Issue.generate! {|i| i.custom_field_values = {'2' => 'Foo'}}
    child = Issue.generate!(:parent_issue_id => issue.id) {|i| i.custom_field_values = {'2' => 'Bar'}}
    @request.session[:user_id] = 1

    assert_difference 'Issue.count', 2 do
      post :create, :params => {
          :project_id => 'ecookbook',
          :copy_from => issue.id,
          :issue => {
            :project_id => '2',
            :tracker_id => 1,
            :status_id => '1',
            :subject => 'Copy with subtasks',
            :custom_field_values => {
            '2' => 'Foo'}
          },
          :copy_subtasks => '1'
        }
    end

    child_copy, issue_copy = Issue.order(:id => :desc).limit(2).to_a
    assert_equal 2, issue_copy.project_id
    assert_equal 'Foo', issue_copy.custom_field_value(2)
    assert_equal 'Bar', child_copy.custom_field_value(2)
  end

  def test_create_as_copy_without_copy_subtasks_option_should_not_copy_subtasks
    @request.session[:user_id] = 2
    issue = Issue.generate_with_descendants!
    assert_difference 'Issue.count', 1 do
      post :create, :params => {
          :project_id => 1,
          :copy_from => 3,
          :issue => {
            :project_id => '1',
            :tracker_id => '3',
            :status_id => '1',
            :subject => 'Copy with subtasks'
          }
        }
    end
    copy = Issue.where(:parent_id => nil).order('id DESC').first
    assert_equal 0, copy.descendants.count
  end

  def test_create_as_copy_with_failure
    @request.session[:user_id] = 2
    post :create, :params => {
        :project_id => 1,
        :copy_from => 1,
        :issue => {
          :project_id => '2',
          :tracker_id => '3',
          :status_id => '1',
          :subject => ''
        }
      }

    assert_response :success

    assert_select 'form#issue-form[action="/projects/ecookbook/issues"]' do
      assert_select 'select[name=?]', 'issue[project_id]' do
        assert_select 'option[value="1"]:not([selected])', :text => 'eCookbook'
        assert_select 'option[value="2"][selected=selected]', :text => 'OnlineStore'
      end
      assert_select 'input[name=copy_from][value="1"]'
    end
  end

  def test_create_as_copy_on_project_without_permission_should_ignore_target_project
    @request.session[:user_id] = 2
    assert !User.find(2).member_of?(Project.find(4))

    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :copy_from => 1,
          :issue => {
            :project_id => '4',
            :tracker_id => '3',
            :status_id => '1',
            :subject => 'Copy'
          }
        }
    end
    issue = Issue.order('id DESC').first
    assert_equal 1, issue.project_id
  end

  def test_create_as_copy_with_watcher_user_ids_should_copy_watchers
    @request.session[:user_id] = 2
    copied = Issue.generate!
    copied.add_watcher User.find(2)
    copied.add_watcher User.find(3)

    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :copy_from => copied.id,
          :issue => {
            :subject => 'Copy cleared watchers',
            :watcher_user_ids => ['', '3']
          }
        }
    end
    issue = Issue.order('id DESC').first
    assert_equal [3], issue.watcher_user_ids
  end

  def test_create_as_copy_without_watcher_user_ids_should_not_copy_watchers
    @request.session[:user_id] = 2
    copied = Issue.generate!
    copied.add_watcher User.find(2)
    copied.add_watcher User.find(3)

    assert_difference 'Issue.count' do
      post :create, :params => {
          :project_id => 1,
          :copy_from => copied.id,
          :issue => {
            :subject => 'Copy cleared watchers',
            :watcher_user_ids => ['']
          }
        }
    end
    issue = Issue.order('id DESC').first
    assert_equal [], issue.watcher_user_ids
  end

  def test_get_edit
    @request.session[:user_id] = 2
    get :edit, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[project_id]'
    # Be sure we don't display inactive IssuePriorities
    assert ! IssuePriority.find(15).active?
    assert_select 'select[name=?]', 'issue[priority_id]' do
      assert_select 'option[value="15"]', 0
    end
  end

  def test_edit_should_hide_project_if_user_is_not_allowed_to_change_project
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :field_name => 'project_id', :rule => 'readonly')

    @request.session[:user_id] = 2
    get :edit, :params => {
        :id => 1
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[project_id]', 0
  end

  def test_edit_should_not_hide_project_when_user_changes_the_project_even_if_project_is_readonly_on_target_project
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :field_name => 'project_id', :rule => 'readonly')
    issue = Issue.generate!(:project_id => 2)

    @request.session[:user_id] = 2
    get :edit, :params => {
        :id => issue.id,
        :issue => {
          :project_id => 1
        }
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[project_id]'
  end

  def test_get_edit_should_display_the_time_entry_form_with_log_time_permission
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').update_attribute :permissions, [:view_issues, :edit_issues, :log_time]

    get :edit, :params => {
        :id => 1
      }
    assert_select 'input[name=?]', 'time_entry[hours]'
  end

  def test_get_edit_should_not_display_the_time_entry_form_without_log_time_permission
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :log_time

    get :edit, :params => {
        :id => 1
      }
    assert_select 'input[name=?]', 'time_entry[hours]', 0
  end

  def test_get_edit_with_params
    @request.session[:user_id] = 2
    get :edit, :params => {
        :id => 1,
        :issue => {
          :status_id => 5,
          :priority_id => 7
        },
        :time_entry => {
          :hours => '2.5',
          :comments => 'test_get_edit_with_params',
          :activity_id => 10
        }
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option[value="5"][selected=selected]', :text => 'Closed'
    end

    assert_select 'select[name=?]', 'issue[priority_id]' do
      assert_select 'option[value="7"][selected=selected]', :text => 'Urgent'
    end

    assert_select 'input[name=?][value="2.50"]', 'time_entry[hours]'
    assert_select 'select[name=?]', 'time_entry[activity_id]' do
      assert_select 'option[value="10"][selected=selected]', :text => 'Development'
    end
    assert_select 'input[name=?][value=test_get_edit_with_params]', 'time_entry[comments]'
  end

  def test_get_edit_with_multi_custom_field
    field = CustomField.find(1)
    field.update_attribute :multiple, true
    issue = Issue.find(1)
    issue.custom_field_values = {1 => ['MySQL', 'Oracle']}
    issue.save!

    @request.session[:user_id] = 2
    get :edit, :params => {
        :id => 1
      }
    assert_response :success

    assert_select 'select[name=?][multiple=multiple]', 'issue[custom_field_values][1][]' do
      assert_select 'option', 3
      assert_select 'option[value=MySQL][selected=selected]'
      assert_select 'option[value=Oracle][selected=selected]'
      assert_select 'option[value=PostgreSQL]:not([selected])'
    end
  end

  def test_get_edit_with_me_assigned_to_id
    @request.session[:user_id] = 2
    get :edit, :params => {
      :id => 1,
      :issue => { :assigned_to_id => 'me' }
    }
    assert_response :success
    assert_select 'select[name=?]', 'issue[assigned_to_id]' do
      assert_select 'option[value="2"][selected=selected]'
    end
  end

  def test_update_form_for_existing_issue
    @request.session[:user_id] = 2
    patch :edit, :params => {
        :id => 1,
        :issue => {
          :tracker_id => 2,
          :subject => 'This is the test_new issue',
          :description => 'This is the description',
          :priority_id => 5
        }
      },
      :xhr => true
    assert_response :success
    assert_equal 'text/javascript', response.content_type

    assert_include 'This is the test_new issue', response.body
  end

  def test_update_form_for_existing_issue_should_keep_issue_author
    @request.session[:user_id] = 3
    patch :edit, :params => {
        :id => 1,
        :issue => {
          :subject => 'Changed'
        }
      }
    assert_response :success

    assert_equal User.find(2), Issue.find(1).author
  end

  def test_update_form_for_existing_issue_should_propose_transitions_based_on_initial_status
    @request.session[:user_id] = 2
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 2, :new_status_id => 1)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 2, :new_status_id => 5)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 5, :new_status_id => 4)

    patch :edit, :params => {
        :id => 2,
        :issue => {
          :tracker_id => 2,
          :status_id => 5,
          :subject => 'This is an issue'
        }
      }

    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option[value="1"]'
      assert_select 'option[value="2"]'
      assert_select 'option[value="5"][selected=selected]'
      assert_select 'option', 3
    end
  end

  def test_update_form_for_existing_issue_with_project_change
    @request.session[:user_id] = 2
    patch :edit, :params => {
        :id => 1,
        :issue => {
          :project_id => 2,
          :tracker_id => 2,
          :subject => 'This is the test_new issue',
          :description => 'This is the description',
          :priority_id => 5
        }
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[project_id]' do
      assert_select 'option[value="2"][selected=selected]'
    end
    assert_select 'select[name=?]', 'issue[tracker_id]' do
      assert_select 'option[value="2"][selected=selected]'
    end
    assert_select 'input[name=?][value=?]', 'issue[subject]', 'This is the test_new issue'
  end

  def test_update_form_should_keep_category_with_same_when_changing_project
    source = Project.generate!
    target = Project.generate!
    source_category = IssueCategory.create!(:name => 'Foo', :project => source)
    target_category = IssueCategory.create!(:name => 'Foo', :project => target)
    issue = Issue.generate!(:project => source, :category => source_category)

    @request.session[:user_id] = 1
    patch :edit, :params => {
        :id => issue.id,
        :issue => {
          :project_id => target.id,
          :category_id => source_category.id
        }
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[category_id]' do
      assert_select 'option[value=?][selected=selected]', target_category.id.to_s
    end
  end

  def test_update_form_should_propose_default_status_for_existing_issue
    @request.session[:user_id] = 2
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 2, :old_status_id => 2, :new_status_id => 3)

    patch :edit, :params => {
        :id => 2
      }
    assert_response :success
    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option[value="2"]'
      assert_select 'option[value="3"]'
      assert_select 'option', 2
    end
  end

  def test_put_update_without_custom_fields_param
    @request.session[:user_id] = 2

    issue = Issue.find(1)
    assert_equal '125', issue.custom_value_for(2).value

    assert_difference('Journal.count') do
      assert_difference('JournalDetail.count') do
        put :update, :params => {
            :id => 1,
            :issue => {
              :subject => 'New subject'
            }
          }
      end
    end
    assert_redirected_to :action => 'show', :id => '1'
    issue.reload
    assert_equal 'New subject', issue.subject
    # Make sure custom fields were not cleared
    assert_equal '125', issue.custom_value_for(2).value
  end

  def test_put_update_with_project_change
    @request.session[:user_id] = 2
    ActionMailer::Base.deliveries.clear

    with_settings :notified_events => %w(issue_updated) do
      assert_difference('Journal.count') do
        assert_difference('JournalDetail.count', 3) do
          put :update, :params => {
              :id => 1,
              :issue => {
                :project_id => '2',
                :tracker_id => '1', # no change
                :priority_id => '6',
                :category_id => '3'
              }
            }
        end
      end
    end
    assert_redirected_to :action => 'show', :id => '1'
    issue = Issue.find(1)
    assert_equal 2, issue.project_id
    assert_equal 1, issue.tracker_id
    assert_equal 6, issue.priority_id
    assert_equal 3, issue.category_id

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert mail.subject.starts_with?("[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}]")
    assert_mail_body_match "Project changed from eCookbook to OnlineStore", mail
  end

  def test_put_update_trying_to_move_issue_to_project_without_tracker_should_not_error
    target = Project.generate!(:tracker_ids => [])
    assert target.trackers.empty?
    issue = Issue.generate!
    @request.session[:user_id] = 1

    put :update, :params => {
        :id => issue.id,
        :issue => {
          :project_id => target.id
        }
      }
    assert_response 302
  end

  def test_put_update_with_tracker_change
    @request.session[:user_id] = 2
    ActionMailer::Base.deliveries.clear

    with_settings :notified_events => %w(issue_updated) do
      assert_difference('Journal.count') do
        assert_difference('JournalDetail.count', 3) do
          put :update, :params => {
              :id => 1,
              :issue => {
                :project_id => '1',
                :tracker_id => '2',
                :priority_id => '6'

              }
            }
        end
      end
    end
    assert_redirected_to :action => 'show', :id => '1'
    issue = Issue.find(1)
    assert_equal 1, issue.project_id
    assert_equal 2, issue.tracker_id
    assert_equal 6, issue.priority_id
    assert_equal 1, issue.category_id

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert mail.subject.starts_with?("[#{issue.project.name} - #{issue.tracker.name} ##{issue.id}]")
    assert_mail_body_match "Tracker changed from Bug to Feature request", mail
  end

  def test_put_update_with_custom_field_change
    @request.session[:user_id] = 2
    issue = Issue.find(1)
    assert_equal '125', issue.custom_value_for(2).value

    with_settings :notified_events => %w(issue_updated) do
      assert_difference('Journal.count') do
        assert_difference('JournalDetail.count', 3) do
          put :update, :params => {
              :id => 1,
              :issue => {
                :subject => 'Custom field change',
                :priority_id => '6',
                :category_id => '1', # no change
                :custom_field_values => { '2' => 'New custom value' }
              }
            }
        end
      end
    end
    assert_redirected_to :action => 'show', :id => '1'
    issue.reload
    assert_equal 'New custom value', issue.custom_value_for(2).value

    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_mail_body_match "Searchable field changed from 125 to New custom value", mail
  end

  def test_put_update_with_multi_custom_field_change
    field = CustomField.find(1)
    field.update_attribute :multiple, true
    issue = Issue.find(1)
    issue.custom_field_values = {1 => ['MySQL', 'Oracle']}
    issue.save!

    @request.session[:user_id] = 2
    assert_difference('Journal.count') do
      assert_difference('JournalDetail.count', 3) do
        put :update, :params => {
            :id => 1,
            :issue => {
              :subject => 'Custom field change',
              :custom_field_values => {
                '1' => ['', 'Oracle', 'PostgreSQL']
              }

            }
          }
      end
    end
    assert_redirected_to :action => 'show', :id => '1'
    assert_equal ['Oracle', 'PostgreSQL'], Issue.find(1).custom_field_value(1).sort
  end

  def test_put_update_with_status_and_assignee_change
    issue = Issue.find(1)
    assert_equal 1, issue.status_id
    @request.session[:user_id] = 2

    with_settings :notified_events => %w(issue_updated) do
      assert_difference('TimeEntry.count', 0) do
        put :update, :params => {
            :id => 1,
            :issue => {
              :status_id => 2,
              :assigned_to_id => 3,
              :notes => 'Assigned to dlopper'
            },
            :time_entry => {
              :hours => '',
              :comments => '',
              :activity_id => TimeEntryActivity.first
            }
          }
      end
    end
    assert_redirected_to :action => 'show', :id => '1'
    issue.reload
    assert_equal 2, issue.status_id
    j = Journal.order('id DESC').first
    assert_equal 'Assigned to dlopper', j.notes
    assert_equal 2, j.details.size

    mail = ActionMailer::Base.deliveries.last
    assert_mail_body_match "Status changed from New to Assigned", mail
    # subject should contain the new status
    assert mail.subject.include?("(#{IssueStatus.find(2).name})")
  end

  def test_put_update_with_note_only
    notes = 'Note added by IssuesControllerTest#test_update_with_note_only'

    with_settings :notified_events => %w(issue_updated) do
      # anonymous user
      put :update, :params => {
          :id => 1,
          :issue => {
            :notes => notes
          }
        }
    end
    assert_redirected_to :action => 'show', :id => '1'
    j = Journal.order('id DESC').first
    assert_equal notes, j.notes
    assert_equal 0, j.details.size
    assert_equal User.anonymous, j.user

    mail = ActionMailer::Base.deliveries.last
    assert_mail_body_match notes, mail
  end

  def test_put_update_with_private_note_only
    notes = 'Private note'
    @request.session[:user_id] = 2

    assert_difference 'Journal.count' do
      put :update, :params => {
          :id => 1,
          :issue => {
            :notes => notes,
            :private_notes => '1'
          }
        }
      assert_redirected_to :action => 'show', :id => '1'
    end

    j = Journal.order('id DESC').first
    assert_equal notes, j.notes
    assert_equal true, j.private_notes
  end

  def test_put_update_with_private_note_and_changes
    notes = 'Private note'
    @request.session[:user_id] = 2

    assert_difference 'Journal.count', 2 do
      put :update, :params => {
          :id => 1,
          :issue => {
            :subject => 'New subject',
            :notes => notes,
            :private_notes => '1'
          }
        }
      assert_redirected_to :action => 'show', :id => '1'
    end

    j = Journal.order('id DESC').first
    assert_equal notes, j.notes
    assert_equal true, j.private_notes
    assert_equal 0, j.details.count

    j = Journal.order('id DESC').offset(1).first
    assert_nil j.notes
    assert_equal false, j.private_notes
    assert_equal 1, j.details.count
  end

  def test_put_update_with_note_and_spent_time
    @request.session[:user_id] = 2
    spent_hours_before = Issue.find(1).spent_hours
    assert_difference('TimeEntry.count') do
      put :update, :params => {
          :id => 1,
          :issue => {
            :notes => '2.5 hours added'
          },
          :time_entry => {
            :hours => '2.5',
            :comments => 'test_put_update_with_note_and_spent_time',
            :activity_id => TimeEntryActivity.first.id
          }
        }
    end
    assert_redirected_to :action => 'show', :id => '1'

    issue = Issue.find(1)

    j = Journal.order('id DESC').first
    assert_equal '2.5 hours added', j.notes
    assert_equal 0, j.details.size

    t = issue.time_entries.find_by_comments('test_put_update_with_note_and_spent_time')
    assert_not_nil t
    assert_equal 2.5, t.hours
    assert_equal spent_hours_before + 2.5, issue.spent_hours
  end

  def test_put_update_should_preserve_parent_issue_even_if_not_visible
    parent = Issue.generate!(:project_id => 1, :is_private => true)
    issue = Issue.generate!(:parent_issue_id => parent.id)
    assert !parent.visible?(User.find(3))
    @request.session[:user_id] = 3

    get :edit, :params => {
        :id => issue.id
      }
    assert_select 'input[name=?][value=?]', 'issue[parent_issue_id]', parent.id.to_s

    put :update, :params => {
        :id => issue.id,
        :issue => {
          :subject => 'New subject',
          :parent_issue_id => parent.id.to_s
        }
      }
    assert_response 302
    assert_equal parent, issue.parent
  end

  def test_put_update_with_attachment_only
    set_tmp_attachments_directory

    # Delete all fixtured journals, a race condition can occur causing the wrong
    # journal to get fetched in the next find.
    Journal.delete_all
    JournalDetail.delete_all

    with_settings :notified_events => %w(issue_updated) do
      # anonymous user
      assert_difference 'Attachment.count' do
        put :update, :params => {
            :id => 1,
            :issue => {
              :notes => ''
            },
            :attachments => {
              '1' => {
              'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'test file'}
            }
          }
      end
    end

    assert_redirected_to :action => 'show', :id => '1'
    j = Issue.find(1).journals.reorder('id DESC').first
    assert j.notes.blank?
    assert_equal 1, j.details.size
    assert_equal 'testfile.txt', j.details.first.value
    assert_equal User.anonymous, j.user

    attachment = Attachment.order('id DESC').first
    assert_equal Issue.find(1), attachment.container
    assert_equal User.anonymous, attachment.author
    assert_equal 'testfile.txt', attachment.filename
    assert_equal 'text/plain', attachment.content_type
    assert_equal 'test file', attachment.description
    assert_equal 59, attachment.filesize
    assert File.exists?(attachment.diskfile)
    assert_equal 59, File.size(attachment.diskfile)

    mail = ActionMailer::Base.deliveries.last
    assert_mail_body_match 'testfile.txt', mail
  end

  def test_put_update_with_failure_should_save_attachments
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    assert_no_difference 'Journal.count' do
      assert_difference 'Attachment.count' do
        put :update, :params => {
            :id => 1,
            :issue => {
              :subject => ''
            },
            :attachments => {
              '1' => {
              'file' => uploaded_test_file('testfile.txt', 'text/plain'), 'description' => 'test file'}
            }
          }
        assert_response :success
      end
    end

    attachment = Attachment.order('id DESC').first
    assert_equal 'testfile.txt', attachment.filename
    assert File.exists?(attachment.diskfile)
    assert_nil attachment.container

    assert_select 'input[name=?][value=?]', 'attachments[p0][token]', attachment.token
    assert_select 'input[name=?][value=?]', 'attachments[p0][filename]', 'testfile.txt'
  end

  def test_put_update_with_failure_should_keep_saved_attachments
    set_tmp_attachments_directory
    attachment = Attachment.create!(:file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 2)
    @request.session[:user_id] = 2

    assert_no_difference 'Journal.count' do
      assert_no_difference 'Attachment.count' do
        put :update, :params => {
            :id => 1,
            :issue => {
              :subject => ''
            },
            :attachments => {
              'p0' => {
              'token' => attachment.token}
            }
          }
        assert_response :success
      end
    end

    assert_select 'input[name=?][value=?]', 'attachments[p0][token]', attachment.token
    assert_select 'input[name=?][value=?]', 'attachments[p0][filename]', 'testfile.txt'
  end

  def test_put_update_should_attach_saved_attachments
    set_tmp_attachments_directory
    attachment = Attachment.create!(:file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 2)
    @request.session[:user_id] = 2

    assert_difference 'Journal.count' do
      assert_difference 'JournalDetail.count' do
        assert_no_difference 'Attachment.count' do
          put :update, :params => {
              :id => 1,
              :issue => {
                :notes => 'Attachment added'
              },
              :attachments => {
                'p0' => {
                'token' => attachment.token}
              }
            }
          assert_redirected_to '/issues/1'
        end
      end
    end

    attachment.reload
    assert_equal Issue.find(1), attachment.container

    journal = Journal.order('id DESC').first
    assert_equal 1, journal.details.size
    assert_equal 'testfile.txt', journal.details.first.value
  end

  def test_put_update_with_attachment_that_fails_to_save
    set_tmp_attachments_directory

    # anonymous user
    with_settings :attachment_max_size => 0 do
      put :update, :params => {
          :id => 1,
          :issue => {
            :notes => ''
          },
          :attachments => {
            '1' => {
            'file' => uploaded_test_file('testfile.txt', 'text/plain')}
          }
        }
      assert_redirected_to :action => 'show', :id => '1'
      assert_equal '1 file(s) could not be saved.', flash[:warning]
    end
  end

  def test_put_update_with_attachment_deletion_should_create_a_single_journal
    set_tmp_attachments_directory
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 2

    journal = new_record(Journal) do
      assert_difference 'Attachment.count', -2 do
        put :update, :params => {
            :id => 3,
            :issue => {
              :notes => 'Removing attachments',
              :deleted_attachment_ids => ['1', '5']

            }
          }
      end
    end
    assert_equal 'Removing attachments', journal.notes
    assert_equal 2, journal.details.count

    assert_select_email do
      assert_select 'ul.journal.details li', 2
      assert_select 'del', :text => 'error281.txt'
      assert_select 'del', :text => 'changeset_iso8859-1.diff'
    end
  end

  def test_put_update_with_attachment_deletion_and_failure_should_preserve_selected_attachments
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    assert_no_difference 'Journal.count' do
      assert_no_difference 'Attachment.count' do
        put :update, :params => {
            :id => 3,
            :issue => {
              :subject => '',
              :notes => 'Removing attachments',
              :deleted_attachment_ids => ['1', '5']

            }
          }
      end
    end
    assert_select 'input[name=?][value="1"][checked=checked]', 'issue[deleted_attachment_ids][]'
    assert_select 'input[name=?][value="5"][checked=checked]', 'issue[deleted_attachment_ids][]'
    assert_select 'input[name=?][value="6"]:not([checked])', 'issue[deleted_attachment_ids][]'
  end

  def test_put_update_with_no_change
    issue = Issue.find(1)
    issue.journals.clear
    ActionMailer::Base.deliveries.clear

    put :update, :params => {
        :id => 1,
        :issue => {
          :notes => ''
        }
      }
    assert_redirected_to :action => 'show', :id => '1'

    issue.reload
    assert issue.journals.empty?
    # No email should be sent
    assert ActionMailer::Base.deliveries.empty?
  end

  def test_put_update_should_send_a_notification
    @request.session[:user_id] = 2
    ActionMailer::Base.deliveries.clear
    issue = Issue.find(1)
    old_subject = issue.subject
    new_subject = 'Subject modified by IssuesControllerTest#test_post_edit'

    with_settings :notified_events => %w(issue_updated) do
      put :update, :params => {
          :id => 1,
          :issue => {
            :subject => new_subject,
            :priority_id => '6',
            :category_id => '1' # no change

          }
        }
      assert_equal 2, ActionMailer::Base.deliveries.size
    end
  end

  def test_put_update_with_invalid_spent_time_hours_only
    @request.session[:user_id] = 2
    notes = 'Note added by IssuesControllerTest#test_post_edit_with_invalid_spent_time'

    assert_no_difference('Journal.count') do
      put :update, :params => {
          :id => 1,
          :issue => {
            :notes => notes
          },
          :time_entry => {
            "comments"=>"", "activity_id"=>"", "hours"=>"2z"
          }
        }
    end
    assert_response :success

    assert_select_error /Activity cannot be blank/
    assert_select 'textarea[name=?]', 'issue[notes]', :text => notes
    assert_select 'input[name=?][value=?]', 'time_entry[hours]', '2z'
  end

  def test_put_update_with_invalid_spent_time_comments_only
    @request.session[:user_id] = 2
    notes = 'Note added by IssuesControllerTest#test_post_edit_with_invalid_spent_time'

    assert_no_difference('Journal.count') do
      put :update, :params => {
          :id => 1,
          :issue => {
            :notes => notes
          },
          :time_entry => {
            "comments"=>"this is my comment", "activity_id"=>"", "hours"=>""
          }
        }
    end
    assert_response :success

    assert_select_error /Activity cannot be blank/
    assert_select_error /Hours cannot be blank/
    assert_select 'textarea[name=?]', 'issue[notes]', :text => notes
    assert_select 'input[name=?][value=?]', 'time_entry[comments]', 'this is my comment'
  end

  def test_put_update_should_allow_fixed_version_to_be_set_to_a_subproject
    issue = Issue.find(2)
    @request.session[:user_id] = 2

    put :update, :params => {
        :id => issue.id,
        :issue => {
          :fixed_version_id => 4

        }
      }

    assert_response :redirect
    issue.reload
    assert_equal 4, issue.fixed_version_id
    assert_not_equal issue.project_id, issue.fixed_version.project_id
  end

  def test_put_update_should_redirect_back_using_the_back_url_parameter
    issue = Issue.find(2)
    @request.session[:user_id] = 2

    put :update, :params => {
        :id => issue.id,
        :issue => {
          :fixed_version_id => 4

        },
        :back_url => '/issues'
      }

    assert_response :redirect
    assert_redirected_to '/issues'
  end

  def test_put_update_should_not_redirect_back_using_the_back_url_parameter_off_the_host
    issue = Issue.find(2)
    @request.session[:user_id] = 2

    put :update, :params => {
        :id => issue.id,
        :issue => {
          :fixed_version_id => 4

        },
        :back_url => 'http://google.com'
      }

    assert_response :redirect
    assert_redirected_to :controller => 'issues', :action => 'show', :id => issue.id
  end

  def test_put_update_should_redirect_with_previous_and_next_issue_ids_params
    @request.session[:user_id] = 2

    put :update, :params => {
        :id => 11,
        :issue => {
          :status_id => 6,
          :notes => 'Notes'
        },
        :prev_issue_id => 8,
        :next_issue_id => 12,
        :issue_position => 2,
        :issue_count => 3
      }

    assert_redirected_to '/issues/11?issue_count=3&issue_position=2&next_issue_id=12&prev_issue_id=8'
  end

  def test_update_with_permission_on_tracker_should_be_allowed
    role = Role.find(1)
    role.set_permission_trackers :edit_issues, [1]
    role.save!
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1, :subject => 'Original subject')

    @request.session[:user_id] = 2
    put :update, :params => {
        :id => issue.id,
        :issue => {
          :subject => 'Changed subject'
        }
      }
    assert_response 302
    assert_equal 'Changed subject', issue.reload.subject
  end

  def test_update_without_permission_on_tracker_should_be_denied
    role = Role.find(1)
    role.set_permission_trackers :edit_issues, [1]
    role.save!
    issue = Issue.generate!(:project_id => 1, :tracker_id => 2, :subject => 'Original subject')

    @request.session[:user_id] = 2
    put :update, :params => {
        :id => issue.id,
        :issue => {
          :subject => 'Changed subject'
        }
      }
    assert_response 302
    assert_equal 'Original subject', issue.reload.subject
  end

  def test_update_with_me_assigned_to_id
    @request.session[:user_id] = 2
    issue = Issue.find(1)
    assert_not_equal 2, issue.assigned_to_id
    put :update, :params => {
        :id => issue.id,
        :issue => {
          :assigned_to_id => 'me'
        }
      }
    assert_response 302
    assert_equal 2, issue.reload.assigned_to_id
  end

  def test_get_bulk_edit
    @request.session[:user_id] = 2
    get :bulk_edit, :params => {
        :ids => [1, 3]
      }
    assert_response :success

    assert_select 'ul#bulk-selection' do
      assert_select 'li', 2
      assert_select 'li a', :text => 'Bug #1'
    end

    assert_select 'form#bulk_edit_form[action=?]', '/issues/bulk_update' do
      assert_select 'input[name=?]', 'ids[]', 2
      assert_select 'input[name=?][value="1"][type=hidden]', 'ids[]'

      assert_select 'select[name=?]', 'issue[project_id]'
      assert_select 'input[name=?]', 'issue[parent_issue_id]'

      # Project specific custom field, date type
      field = CustomField.find(9)
      assert !field.is_for_all?
      assert_equal 'date', field.field_format
      assert_select 'input[name=?]', 'issue[custom_field_values][9]'

      # System wide custom field
      assert CustomField.find(1).is_for_all?
      assert_select 'select[name=?]', 'issue[custom_field_values][1]'

      # Be sure we don't display inactive IssuePriorities
      assert ! IssuePriority.find(15).active?
      assert_select 'select[name=?]', 'issue[priority_id]' do
        assert_select 'option[value="15"]', 0
      end
    end
  end

  def test_get_bulk_edit_on_different_projects
    @request.session[:user_id] = 2
    get :bulk_edit, :params => {
        :ids => [1, 2, 6]
      }
    assert_response :success

    # Can not set issues from different projects as children of an issue
    assert_select 'input[name=?]', 'issue[parent_issue_id]', 0

    # Project specific custom field, date type
    field = CustomField.find(9)
    assert !field.is_for_all?
    assert !field.project_ids.include?(Issue.find(6).project_id)
    assert_select 'input[name=?]', 'issue[custom_field_values][9]', 0
  end

  def test_get_bulk_edit_with_user_custom_field
    field = IssueCustomField.create!(:name => 'Tester', :field_format => 'user', :is_for_all => true, :tracker_ids => [1,2,3])

    @request.session[:user_id] = 2
    get :bulk_edit, :params => {
        :ids => [1, 2]
      }
    assert_response :success

    assert_select 'select.user_cf[name=?]', "issue[custom_field_values][#{field.id}]" do
      assert_select 'option', Project.find(1).users.count + 3 # "no change" + "none" + "me" options
    end
  end

  def test_get_bulk_edit_with_version_custom_field
    field = IssueCustomField.create!(:name => 'Affected version', :field_format => 'version', :is_for_all => true, :tracker_ids => [1,2,3])

    @request.session[:user_id] = 2
    get :bulk_edit, :params => {
        :ids => [1, 2]
      }
    assert_response :success

    assert_select 'select.version_cf[name=?]', "issue[custom_field_values][#{field.id}]" do
      assert_select 'option', Project.find(1).shared_versions.count + 2 # "no change" + "none" options
    end
  end

  def test_get_bulk_edit_with_multi_custom_field
    field = CustomField.find(1)
    field.update_attribute :multiple, true

    @request.session[:user_id] = 2
    get :bulk_edit, :params => {
        :ids => [1, 3]
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[custom_field_values][1][]' do
      assert_select 'option', field.possible_values.size + 1 # "none" options
    end
  end

  def test_bulk_edit_should_propose_to_clear_text_custom_fields
    @request.session[:user_id] = 2
    get :bulk_edit, :params => {
        :ids => [1, 3]
      }
    assert_response :success

    assert_select 'input[name=?][value=?]', 'issue[custom_field_values][2]', '__none__'
  end

  def test_bulk_edit_should_only_propose_statuses_allowed_for_all_issues
    WorkflowTransition.delete_all
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 1)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 3)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 1,
                               :old_status_id => 1, :new_status_id => 4)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 2,
                               :old_status_id => 2, :new_status_id => 1)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 2,
                               :old_status_id => 2, :new_status_id => 3)
    WorkflowTransition.create!(:role_id => 1, :tracker_id => 2,
                               :old_status_id => 2, :new_status_id => 5)
    @request.session[:user_id] = 2
    get :bulk_edit, :params => {
        :ids => [1, 2]
      }

    assert_select 'select[name=?]', 'issue[status_id]' do
      assert_select 'option[value=""]'
      assert_select 'option[value="1"]'
      assert_select 'option[value="3"]'
      assert_select 'option', 3 # 2 statuses + "no change" option
    end
  end

  def test_bulk_edit_should_propose_target_project_open_shared_versions
    @request.session[:user_id] = 2
    post :bulk_edit, :params => {
        :ids => [1, 2, 6],
        :issue => {
          :project_id => 1
        }
      }
    assert_response :success

    expected_versions = Project.find(1).shared_versions.open.to_a.sort

    assert_select 'select[name=?]', 'issue[fixed_version_id]' do
      expected_versions.each do |version|
        assert_select 'option[value=?]', version.id.to_s
      end
      assert_select 'option[value=""]'
      assert_select 'option[value="none"]'
      assert_select 'option', expected_versions.size + 2
    end
  end

  def test_bulk_edit_should_propose_target_project_categories
    @request.session[:user_id] = 2
    post :bulk_edit, :params => {
        :ids => [1, 2, 6],
        :issue => {
          :project_id => 1
        }
      }
    assert_response :success

    expected_categories = Project.find(1).issue_categories.sort

    assert_select 'select[name=?]', 'issue[category_id]' do
      expected_categories.each do |category|
        assert_select 'option[value=?]', category.id.to_s
      end
      assert_select 'option[value=""]'
      assert_select 'option[value="none"]'
      assert_select 'option', expected_categories.size + 2
    end
  end

  def test_bulk_edit_should_only_propose_issues_trackers_custom_fields
    IssueCustomField.delete_all
    field1 = IssueCustomField.generate!(:tracker_ids => [1], :is_for_all => true)
    field2 = IssueCustomField.generate!(:tracker_ids => [2], :is_for_all => true)
    @request.session[:user_id] = 2

    issue_ids = Issue.where(:project_id => 1, :tracker_id => 1).limit(2).ids
    get :bulk_edit, :params => {
        :ids => issue_ids
      }
    assert_response :success

    assert_select 'input[name=?]', "issue[custom_field_values][#{field1.id}]"
    assert_select 'input[name=?]', "issue[custom_field_values][#{field2.id}]", 0
  end

  def test_bulk_edit_should_propose_target_tracker_custom_fields
    IssueCustomField.delete_all
    field1 = IssueCustomField.generate!(:tracker_ids => [1], :is_for_all => true)
    field2 = IssueCustomField.generate!(:tracker_ids => [2], :is_for_all => true)
    @request.session[:user_id] = 2

    issue_ids = Issue.where(:project_id => 1, :tracker_id => 1).limit(2).ids
    get :bulk_edit, :params => {
        :ids => issue_ids,
        :issue => {
          :tracker_id => 2
        }
      }
    assert_response :success

    assert_select 'input[name=?]', "issue[custom_field_values][#{field1.id}]", 0
    assert_select 'input[name=?]', "issue[custom_field_values][#{field2.id}]"
  end

  def test_bulk_edit_should_warn_about_custom_field_values_about_to_be_cleared
    CustomField.destroy_all

    cleared = IssueCustomField.generate!(:name => 'Cleared', :tracker_ids => [2], :is_for_all => true)
    CustomValue.create!(:customized => Issue.find(2), :custom_field => cleared, :value => 'foo')

    not_cleared = IssueCustomField.generate!(:name => 'Not cleared', :tracker_ids => [2, 3], :is_for_all => true)
    CustomValue.create!(:customized => Issue.find(2), :custom_field => not_cleared, :value => 'bar')
    @request.session[:user_id] = 2

    get :bulk_edit, :params => {
        :ids => [1, 2],
        :issue => {
          :tracker_id => 3
        }
      }
    assert_response :success
    assert_select '.warning', :text => /automatic deletion of values/
    assert_select '.warning span', :text => 'Cleared (1)'
    assert_select '.warning span', :text => /Not cleared/, :count => 0
  end

  def test_bulk_update
    @request.session[:user_id] = 2
    # update issues priority
    post :bulk_update, :params => {
        :ids => [1, 2],
        :notes => 'Bulk editing',
        :issue => {
          :priority_id => 7,
          :assigned_to_id => '',
          :custom_field_values => {
          '2' => ''}
        }
      }

    assert_response 302
    # check that the issues were updated
    assert_equal [7, 7], Issue.where(:id =>[1, 2]).collect {|i| i.priority.id}

    issue = Issue.find(1)
    journal = issue.journals.reorder('created_on DESC').first
    assert_equal '125', issue.custom_value_for(2).value
    assert_equal 'Bulk editing', journal.notes
    assert_equal 1, journal.details.size
  end

  def test_bulk_update_with_group_assignee
    group = Group.find(11)
    project = Project.find(1)
    project.members << Member.new(:principal => group, :roles => [Role.givable.first])

    @request.session[:user_id] = 2
    # update issues assignee
    with_settings :issue_group_assignment => '1' do
      post :bulk_update, :params => {
          :ids => [1, 2],
          :notes => 'Bulk editing',
          :issue => {
            :priority_id => '',
            :assigned_to_id => group.id,
            :custom_field_values => {
            '2' => ''}
          }
        }

      assert_response 302
      assert_equal [group, group], Issue.where(:id => [1, 2]).collect {|i| i.assigned_to}
    end
  end

  def test_bulk_update_on_different_projects
    @request.session[:user_id] = 2
    # update issues priority
    post :bulk_update, :params => {
        :ids => [1, 2, 6],
        :notes => 'Bulk editing',
        :issue => {
          :priority_id => 7,
          :assigned_to_id => '',
          :custom_field_values => {
          '2' => ''}
        }
      }

    assert_response 302
    # check that the issues were updated
    assert_equal [7, 7, 7], Issue.find([1,2,6]).map(&:priority_id)

    issue = Issue.find(1)
    journal = issue.journals.reorder('created_on DESC').first
    assert_equal '125', issue.custom_value_for(2).value
    assert_equal 'Bulk editing', journal.notes
    assert_equal 1, journal.details.size
  end

  def test_bulk_update_on_different_projects_without_rights
    @request.session[:user_id] = 3
    user = User.find(3)
    action = { :controller => "issues", :action => "bulk_update" }
    assert user.allowed_to?(action, Issue.find(1).project)
    assert ! user.allowed_to?(action, Issue.find(6).project)
    post :bulk_update, :params => {
        :ids => [1, 6],
        :notes => 'Bulk should fail',
        :issue => {
          :priority_id => 7,
          :assigned_to_id => '',
          :custom_field_values => {
          '2' => ''}
        }
      }
    assert_response 403
    assert_not_equal "Bulk should fail", Journal.last.notes
  end

  def test_bulk_update_should_send_a_notification
    @request.session[:user_id] = 2
    ActionMailer::Base.deliveries.clear
    with_settings :notified_events => %w(issue_updated) do
      post :bulk_update, :params => {
          :ids => [1, 2],
          :notes => 'Bulk editing',
          :issue => {
            :priority_id => 7,
            :assigned_to_id => '',
            :custom_field_values => {'2' => ''}
          }
        }
      assert_response 302
      # 4 emails for 2 members and 2 issues
      # 1 email for a watcher of issue #2
      assert_equal 5, ActionMailer::Base.deliveries.size
    end
  end

  def test_bulk_update_project
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 2],
        :issue => {
          :project_id => '2'
        }
      }
    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => 'ecookbook'
    # Issues moved to project 2
    assert_equal 2, Issue.find(1).project_id
    assert_equal 2, Issue.find(2).project_id
    # No tracker change
    assert_equal 1, Issue.find(1).tracker_id
    assert_equal 2, Issue.find(2).tracker_id
  end

  def test_bulk_update_project_on_single_issue_should_follow_when_needed
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :id => 1,
        :issue => {
          :project_id => '2'
        },
        :follow => '1'
      }
    assert_redirected_to '/issues/1'
  end

  def test_bulk_update_project_on_multiple_issues_should_follow_when_needed
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :id => [1, 2],
        :issue => {
          :project_id => '2'
        },
        :follow => '1'
      }
    assert_redirected_to '/projects/onlinestore/issues'
  end

  def test_bulk_update_tracker
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 2],
        :issue => {
          :tracker_id => '2'
        }
      }
    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => 'ecookbook'
    assert_equal 2, Issue.find(1).tracker_id
    assert_equal 2, Issue.find(2).tracker_id
  end

  def test_bulk_update_status
    @request.session[:user_id] = 2
    # update issues priority
    post :bulk_update, :params => {
        :ids => [1, 2],
        :notes => 'Bulk editing status',
        :issue => {
          :priority_id => '',
          :assigned_to_id => '',
          :status_id => '5'
        }
      }

    assert_response 302
    issue = Issue.find(1)
    assert issue.closed?
  end

  def test_bulk_update_priority
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 2],
        :issue => {
          :priority_id => 6
        }
      }

    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => 'ecookbook'
    assert_equal 6, Issue.find(1).priority_id
    assert_equal 6, Issue.find(2).priority_id
  end

  def test_bulk_update_with_notes
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 2],
        :notes => 'Moving two issues'
      }

    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => 'ecookbook'
    assert_equal 'Moving two issues', Issue.find(1).journals.sort_by(&:id).last.notes
    assert_equal 'Moving two issues', Issue.find(2).journals.sort_by(&:id).last.notes
    assert_equal false, Issue.find(1).journals.sort_by(&:id).last.private_notes
    assert_equal false, Issue.find(2).journals.sort_by(&:id).last.private_notes
  end

  def test_bulk_update_with_private_notes
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 2],
        :notes => 'Moving two issues',
        :issue => {:private_notes => 'true'}
      }

    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => 'ecookbook'
    assert_equal 'Moving two issues', Issue.find(1).journals.sort_by(&:id).last.notes
    assert_equal 'Moving two issues', Issue.find(2).journals.sort_by(&:id).last.notes
    assert_equal true, Issue.find(1).journals.sort_by(&:id).last.private_notes
    assert_equal true, Issue.find(2).journals.sort_by(&:id).last.private_notes
  end

  def test_bulk_update_parent_id
    IssueRelation.delete_all
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 3],
        :notes => 'Bulk editing parent',
        :issue => {
          :priority_id => '',
          :assigned_to_id => '',
          :status_id => '',
          :parent_issue_id => '2'
        }
      }
    assert_response 302
    parent = Issue.find(2)
    assert_equal parent.id, Issue.find(1).parent_id
    assert_equal parent.id, Issue.find(3).parent_id
    assert_equal [1, 3], parent.children.collect(&:id).sort
  end

  def test_bulk_update_estimated_hours
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 2],
        :issue => {
          :estimated_hours => 4.25
        }
      }

    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => 'ecookbook'
    assert_equal 4.25, Issue.find(1).estimated_hours
    assert_equal 4.25, Issue.find(2).estimated_hours
  end

  def test_bulk_update_custom_field
    @request.session[:user_id] = 2
    # update issues priority
    post :bulk_update, :params => {
        :ids => [1, 2],
        :notes => 'Bulk editing custom field',
        :issue => {
          :priority_id => '',
          :assigned_to_id => '',
          :custom_field_values => {
          '2' => '777'}
        }
      }

    assert_response 302

    issue = Issue.find(1)
    journal = issue.journals.reorder('created_on DESC').first
    assert_equal '777', issue.custom_value_for(2).value
    assert_equal 1, journal.details.size
    assert_equal '125', journal.details.first.old_value
    assert_equal '777', journal.details.first.value
  end

  def test_bulk_update_custom_field_to_blank
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 3],
        :notes => 'Bulk editing custom field',
        :issue => {
          :priority_id => '',
          :assigned_to_id => '',
          :custom_field_values => {
          '1' => '__none__'}
        }
      }
    assert_response 302
    assert_equal '', Issue.find(1).custom_field_value(1)
    assert_equal '', Issue.find(3).custom_field_value(1)
  end

  def test_bulk_update_multi_custom_field
    field = CustomField.find(1)
    field.update_attribute :multiple, true

    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 2, 3],
        :notes => 'Bulk editing multi custom field',
        :issue => {
          :priority_id => '',
          :assigned_to_id => '',
          :custom_field_values => {
          '1' => ['MySQL', 'Oracle']}
        }
      }

    assert_response 302

    assert_equal ['MySQL', 'Oracle'], Issue.find(1).custom_field_value(1).sort
    assert_equal ['MySQL', 'Oracle'], Issue.find(3).custom_field_value(1).sort
    # the custom field is not associated with the issue tracker
    assert_nil Issue.find(2).custom_field_value(1)
  end

  def test_bulk_update_multi_custom_field_to_blank
    field = CustomField.find(1)
    field.update_attribute :multiple, true

    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 3],
        :notes => 'Bulk editing multi custom field',
        :issue => {
          :priority_id => '',
          :assigned_to_id => '',
          :custom_field_values => {
          '1' => ['__none__']}
        }
      }
    assert_response 302
    assert_equal [''], Issue.find(1).custom_field_value(1)
    assert_equal [''], Issue.find(3).custom_field_value(1)
  end

  def test_bulk_update_unassign
    assert_not_nil Issue.find(2).assigned_to
    @request.session[:user_id] = 2
    # unassign issues
    post :bulk_update, :params => {
        :ids => [1, 2],
        :notes => 'Bulk unassigning',
        :issue => {
          :assigned_to_id => 'none'
        }
      }
    assert_response 302
    # check that the issues were updated
    assert_nil Issue.find(2).assigned_to
  end

  def test_post_bulk_update_should_allow_fixed_version_to_be_set_to_a_subproject
    @request.session[:user_id] = 2

    post :bulk_update, :params => {
        :ids => [1,2],
        :issue => {
          :fixed_version_id => 4
        }
      }

    assert_response :redirect
    issues = Issue.find([1,2])
    issues.each do |issue|
      assert_equal 4, issue.fixed_version_id
      assert_not_equal issue.project_id, issue.fixed_version.project_id
    end
  end

  def test_post_bulk_update_should_redirect_back_using_the_back_url_parameter
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1,2],
        :back_url => '/issues'
      }

    assert_response :redirect
    assert_redirected_to '/issues'
  end

  def test_post_bulk_update_should_not_redirect_back_using_the_back_url_parameter_off_the_host
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1,2],
        :back_url => 'http://google.com'
      }

    assert_response :redirect
    assert_redirected_to :controller => 'issues', :action => 'index', :project_id => Project.find(1).identifier
  end

  def test_bulk_update_with_all_failures_should_show_errors
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 2],
        :issue => {
          :start_date => 'foo'
        }
      }
    assert_response :success

    assert_select '#errorExplanation span', :text => 'Failed to save 2 issue(s) on 2 selected: #1, #2.'
    assert_select '#errorExplanation ul li', :text => 'Start date is not a valid date: #1, #2'
  end

  def test_bulk_update_with_some_failures_should_show_errors
    issue1 = Issue.generate!(:start_date => '2013-05-12')
    issue2 = Issue.generate!(:start_date => '2013-05-15')
    issue3 = Issue.generate!
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [issue1.id, issue2.id, issue3.id],
        :issue => {
          :due_date => '2013-05-01'
        }
      }
    assert_response :success
    assert_select '#errorExplanation span',
                  :text => "Failed to save 2 issue(s) on 3 selected: ##{issue1.id}, ##{issue2.id}."
    assert_select '#errorExplanation ul li',
                  :text => "Due date must be greater than start date: ##{issue1.id}, ##{issue2.id}"
    assert_select '#bulk-selection li', 2
  end

  def test_bulk_update_with_failure_should_preserved_form_values
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 2],
        :issue => {
          :tracker_id => '2',
          :start_date => 'foo'
        }
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[tracker_id]' do
      assert_select 'option[value="2"][selected=selected]'
    end
    assert_select 'input[name=?][value=?]', 'issue[start_date]', 'foo'
  end

  def test_get_bulk_copy
    @request.session[:user_id] = 2
    get :bulk_edit, :params => {
        :ids => [1, 2, 3],
        :copy => '1'
      }
    assert_response :success

    assert_select '#bulk-selection li', 3

    assert_select 'select[name=?]', 'issue[project_id]' do
      assert_select 'option[value=""]'
    end
    assert_select 'input[name=copy_attachments]'
  end

  def test_get_bulk_copy_without_add_issues_permission_should_not_propose_current_project_as_target
    user = setup_user_with_copy_but_not_add_permission
    @request.session[:user_id] = user.id

    get :bulk_edit, :params => {
        :ids => [1, 2, 3],
        :copy => '1'
      }
    assert_response :success

    assert_select 'select[name=?]', 'issue[project_id]' do
      assert_select 'option[value=""]', 0
      assert_select 'option[value="2"]'
    end
  end

  def test_bulk_copy_to_another_project
    @request.session[:user_id] = 2
    issue_ids = [1, 2]
    assert_difference 'Issue.count', issue_ids.size do
      assert_no_difference 'Project.find(1).issues.count' do
        post :bulk_update, :params => {
            :ids => issue_ids,
            :issue => {
              :project_id => '2'
            },
            :copy => '1'
          }
      end
    end
    assert_redirected_to '/projects/ecookbook/issues'

    copies = Issue.order('id DESC').limit(issue_ids.size)
    copies.each do |copy|
      assert_equal 2, copy.project_id
    end
  end

  def test_bulk_copy_without_add_issues_permission_should_be_allowed_on_project_with_permission
    user = setup_user_with_copy_but_not_add_permission
    @request.session[:user_id] = user.id

    assert_difference 'Issue.count', 3 do
      post :bulk_update, :params => {
          :ids => [1, 2, 3],
          :issue => {
            :project_id => '2'
          },
          :copy => '1'
        }
      assert_response 302
    end
  end

  def test_bulk_copy_on_same_project_without_add_issues_permission_should_be_denied
    user = setup_user_with_copy_but_not_add_permission
    @request.session[:user_id] = user.id

    post :bulk_update, :params => {
        :ids => [1, 2, 3],
        :issue => {
          :project_id => ''
        },
        :copy => '1'
      }
    assert_response 403
  end

  def test_bulk_copy_on_different_project_without_add_issues_permission_should_be_denied
    user = setup_user_with_copy_but_not_add_permission
    @request.session[:user_id] = user.id

    post :bulk_update, :params => {
        :ids => [1, 2, 3],
        :issue => {
          :project_id => '1'
        },
        :copy => '1'
      }
    assert_response 403
  end

  def test_bulk_copy_should_allow_not_changing_the_issue_attributes
    @request.session[:user_id] = 2
    issues = [
      Issue.create!(:project_id => 1, :tracker_id => 1, :status_id => 1,
                    :priority_id => 2, :subject => 'issue 1', :author_id => 1,
                    :assigned_to_id => nil),
      Issue.create!(:project_id => 2, :tracker_id => 3, :status_id => 2,
                    :priority_id => 1, :subject => 'issue 2', :author_id => 2,
                    :assigned_to_id => 2)
    ]
    assert_difference 'Issue.count', issues.size do
      post :bulk_update, :params => {
          :ids => issues.map(&:id),
          :copy => '1',
          :issue => {
            :project_id => '',
            :tracker_id => '',
            :assigned_to_id => '',
            :status_id => '',
            :start_date => '',
            :due_date => ''

          }
        }
    end

    copies = Issue.order('id DESC').limit(issues.size)
    issues.each do |orig|
      copy = copies.detect {|c| c.subject == orig.subject}
      assert_not_nil copy
      assert_equal orig.project_id, copy.project_id
      assert_equal orig.tracker_id, copy.tracker_id
      assert_equal 1, copy.status_id
      if orig.assigned_to_id
        assert_equal orig.assigned_to_id, copy.assigned_to_id
      else
        assert_nil copy.assigned_to_id
      end
      assert_equal orig.priority_id, copy.priority_id
    end
  end

  def test_bulk_copy_should_allow_changing_the_issue_attributes
    # Fixes random test failure with Mysql
    # where Issue.where(:project_id => 2).limit(2).order('id desc')
    # doesn't return the expected results
    Issue.where("project_id=2").delete_all

    @request.session[:user_id] = 2
    assert_difference 'Issue.count', 2 do
      assert_no_difference 'Project.find(1).issues.count' do
        post :bulk_update, :params => {
            :ids => [1, 2],
            :copy => '1',
            :issue => {
              :project_id => '2',
              :tracker_id => '',
              :assigned_to_id => '2',
              :status_id => '1',
              :start_date => '2009-12-01',
              :due_date => '2009-12-31'

            }
          }
      end
    end

    copied_issues = Issue.where(:project_id => 2).limit(2).order('id desc').to_a
    assert_equal 2, copied_issues.size
    copied_issues.each do |issue|
      assert_equal 2, issue.project_id, "Project is incorrect"
      assert_equal 2, issue.assigned_to_id, "Assigned to is incorrect"
      assert_equal 1, issue.status_id, "Status is incorrect"
      assert_equal '2009-12-01', issue.start_date.to_s, "Start date is incorrect"
      assert_equal '2009-12-31', issue.due_date.to_s, "Due date is incorrect"
    end
  end

  def test_bulk_copy_should_allow_adding_a_note
    @request.session[:user_id] = 2
    assert_difference 'Issue.count', 1 do
      post :bulk_update, :params => {
          :ids => [1],
          :copy => '1',
          :notes => 'Copying one issue',
          :issue => {
            :project_id => '',
            :tracker_id => '',
            :status_id => '3',
            :start_date => '2009-12-01',
            :due_date => '2009-12-31'

          }
        }
    end
    issue = Issue.order('id DESC').first
    assert_equal 1, issue.journals.size
    journal = issue.journals.first
    assert_equal 'Copying one issue', journal.notes
  end

  def test_bulk_copy_should_allow_not_copying_the_attachments
    attachment_count = Issue.find(3).attachments.size
    assert attachment_count > 0
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', 1 do
      assert_no_difference 'Attachment.count' do
        post :bulk_update, :params => {
            :ids => [3],
            :copy => '1',
            :copy_attachments => '0',
            :issue => {
              :project_id => ''

            }
          }
      end
    end
  end

  def test_bulk_copy_should_allow_copying_the_attachments
    attachment_count = Issue.find(3).attachments.size
    assert attachment_count > 0
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', 1 do
      assert_difference 'Attachment.count', attachment_count do
        post :bulk_update, :params => {
            :ids => [3],
            :copy => '1',
            :copy_attachments => '1',
            :issue => {
              :project_id => ''

            }
          }
      end
    end
  end

  def test_bulk_copy_should_add_relations_with_copied_issues
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', 2 do
      assert_difference 'IssueRelation.count', 2 do
        post :bulk_update, :params => {
            :ids => [1, 3],
            :copy => '1',
            :link_copy => '1',
            :issue => {
              :project_id => '1'

            }
          }
      end
    end
  end

  def test_bulk_copy_should_allow_not_copying_the_subtasks
    issue = Issue.generate_with_descendants!
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', 1 do
      post :bulk_update, :params => {
          :ids => [issue.id],
          :copy => '1',
          :copy_subtasks => '0',
          :issue => {
            :project_id => ''

          }
        }
    end
  end

  test "bulk copy should allow copying the subtasks" do
    issue = Issue.generate_with_descendants!
    count = issue.descendants.count
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', count+1 do
      post :bulk_update, :params => {
          :ids => [issue.id],
          :copy => '1',
          :copy_subtasks => '1',
          :issue => {
            :project_id => ''

          }
        }
    end
    copy = Issue.where(:parent_id => nil).order("id DESC").first
    assert_equal count, copy.descendants.count
  end

  test "issue bulk copy copy watcher" do
    Watcher.create!(:watchable => Issue.find(1), :user => User.find(3))
    @request.session[:user_id] = 2
    assert_difference 'Issue.count' do
      post :bulk_update, :params => {
          :ids => [1],
          :copy => '1',
          :copy_watchers => '1',
          :issue => {
            :project_id => ''
          }
        }
    end
    copy = Issue.order(:id => :desc).first
    assert_equal 1, copy.watchers.count
  end

  def test_bulk_copy_should_not_copy_selected_subtasks_twice
    issue = Issue.generate_with_descendants!
    count = issue.descendants.count
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', count+1 do
      post :bulk_update, :params => {
          :ids => issue.self_and_descendants.map(&:id),
          :copy => '1',
          :copy_subtasks => '1',
          :issue => {
            :project_id => ''

          }
        }
    end
    copy = Issue.where(:parent_id => nil).order("id DESC").first
    assert_equal count, copy.descendants.count
  end

  def test_bulk_copy_to_another_project_should_follow_when_needed
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1],
        :copy => '1',
        :issue => {
          :project_id => 2
        },
        :follow => '1'
      }
    issue = Issue.order('id DESC').first
    assert_redirected_to :controller => 'issues', :action => 'show', :id => issue
  end

  def test_bulk_copy_with_all_failures_should_display_errors
    @request.session[:user_id] = 2
    post :bulk_update, :params => {
        :ids => [1, 2],
        :copy => '1',
        :issue => {
          :start_date => 'foo'
        }
      }

    assert_response :success
  end

  def test_destroy_issue_with_no_time_entries_should_delete_the_issues
    set_tmp_attachments_directory
    assert_nil TimeEntry.find_by_issue_id(2)
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', -1 do
      delete :destroy, :params => {
          :id => 2
        }
    end
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert_nil Issue.find_by_id(2)
  end

  def test_destroy_issues_with_time_entries_should_show_the_reassign_form
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    with_settings :timelog_required_fields => [] do
      assert_no_difference 'Issue.count' do
        delete :destroy, :params => {
            :ids => [1, 3]
          }
      end
    end
    assert_response :success

    assert_select 'form' do
      assert_select 'input[name=_method][value=delete]'
      assert_select 'input[name=todo][value=destroy]'
      assert_select 'input[name=todo][value=nullify]'
      assert_select 'input[name=todo][value=reassign]'
    end
  end

  def test_destroy_issues_with_time_entries_should_not_show_the_nullify_option_when_issue_is_required_for_time_entries
    set_tmp_attachments_directory
    with_settings :timelog_required_fields => ['issue_id'] do
      @request.session[:user_id] = 2

      assert_no_difference 'Issue.count' do
        delete :destroy, :params => {
            :ids => [1, 3]
          }
      end
      assert_response :success

      assert_select 'form' do
        assert_select 'input[name=_method][value=delete]'
        assert_select 'input[name=todo][value=destroy]'
        assert_select 'input[name=todo][value=nullify]', 0
        assert_select 'input[name=todo][value=reassign]'
      end
    end
  end

  def test_destroy_issues_with_time_entries_should_show_hours_on_issues_and_descendants
    parent = Issue.generate_with_child!
    TimeEntry.generate!(:issue => parent)
    TimeEntry.generate!(:issue => parent.children.first)
    leaf = Issue.generate!
    TimeEntry.generate!(:issue => leaf)
    @request.session[:user_id] = 2

    delete :destroy, :params => {
        :ids => [parent.id, leaf.id]
      }
    assert_response :success

    assert_select 'p', :text => /3\.00 hours were reported/
  end

  def test_destroy_issues_and_destroy_time_entries
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', -2 do
      assert_difference 'TimeEntry.count', -3 do
        delete :destroy, :params => {
            :ids => [1, 3],
            :todo => 'destroy'
          }
      end
    end
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert !(Issue.find_by_id(1) || Issue.find_by_id(3))
    assert_nil TimeEntry.find_by_id([1, 2])
  end

  def test_destroy_issues_and_assign_time_entries_to_project
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    with_settings :timelog_required_fields => [] do
    assert_difference 'Issue.count', -2 do
      assert_no_difference 'TimeEntry.count' do
        delete :destroy, :params => {
            :ids => [1, 3],
            :todo => 'nullify'
          }
      end
    end
    end
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert !(Issue.find_by_id(1) || Issue.find_by_id(3))
    assert_nil TimeEntry.find(1).issue_id
    assert_nil TimeEntry.find(2).issue_id
  end

  def test_destroy_issues_and_reassign_time_entries_to_another_issue
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', -2 do
      assert_no_difference 'TimeEntry.count' do
        delete :destroy, :params => {
            :ids => [1, 3],
            :todo => 'reassign',
            :reassign_to_id => 2
          }
      end
    end
    assert_redirected_to :action => 'index', :project_id => 'ecookbook'
    assert !(Issue.find_by_id(1) || Issue.find_by_id(3))
    assert_equal 2, TimeEntry.find(1).issue_id
    assert_equal 2, TimeEntry.find(2).issue_id
  end

  def test_destroy_issues_with_time_entries_should_reassign_time_entries_of_issues_and_descendants
    parent = Issue.generate_with_child!
    TimeEntry.generate!(:issue => parent)
    TimeEntry.generate!(:issue => parent.children.first)
    leaf = Issue.generate!
    TimeEntry.generate!(:issue => leaf)
    target = Issue.generate!
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', -3 do
      assert_no_difference 'TimeEntry.count' do
        delete :destroy, :params => {
            :ids => [parent.id, leaf.id],
            :todo => 'reassign',
            :reassign_to_id => target.id
          }
        assert_response 302
      end
    end
    assert_equal 3, target.time_entries.count
  end

  def test_destroy_issues_and_reassign_time_entries_to_an_invalid_issue_should_fail
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    assert_no_difference 'Issue.count' do
      assert_no_difference 'TimeEntry.count' do
        # try to reassign time to an issue of another project
        delete :destroy, :params => {
            :ids => [1, 3],
            :todo => 'reassign',
            :reassign_to_id => 4
          }
      end
    end
    assert_response :success
  end

  def test_destroy_issues_and_reassign_time_entries_to_an_issue_to_delete_should_fail
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    assert_no_difference 'Issue.count' do
      assert_no_difference 'TimeEntry.count' do
        delete :destroy, :params => {
            :ids => [1, 3],
            :todo => 'reassign',
            :reassign_to_id => 3
          }
      end
    end
    assert_response :success
    assert_select '#flash_error', :text => I18n.t(:error_cannot_reassign_time_entries_to_an_issue_about_to_be_deleted)
  end

  def test_destroy_issues_and_nullify_time_entries_should_fail_when_issue_is_required_for_time_entries
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    with_settings :timelog_required_fields => ['issue_id'] do
      assert_no_difference 'Issue.count' do
        assert_no_difference 'TimeEntry.count' do
          delete :destroy, :params => {
              :ids => [1, 3],
              :todo => 'nullify'
            }
        end
      end
    end
    assert_response :success
    assert_select '#flash_error', :text => 'Issue cannot be blank'
  end

  def test_destroy_issues_from_different_projects
    set_tmp_attachments_directory
    @request.session[:user_id] = 2

    assert_difference 'Issue.count', -3 do
      delete :destroy, :params => {
          :ids => [1, 2, 6],
          :todo => 'destroy'
        }
    end
    assert_redirected_to :controller => 'issues', :action => 'index'
    assert !(Issue.find_by_id(1) || Issue.find_by_id(2) || Issue.find_by_id(6))
  end

  def test_destroy_parent_and_child_issues
    parent = Issue.create!(:project_id => 1, :author_id => 1, :tracker_id => 1, :subject => 'Parent Issue')
    child = Issue.create!(:project_id => 1, :author_id => 1, :tracker_id => 1, :subject => 'Child Issue', :parent_issue_id => parent.id)
    assert child.is_descendant_of?(parent.reload)

    @request.session[:user_id] = 2
    assert_difference 'Issue.count', -2 do
      delete :destroy, :params => {
          :ids => [parent.id, child.id],
          :todo => 'destroy'
        }
    end
    assert_response 302
  end

  def test_destroy_invalid_should_respond_with_404
    @request.session[:user_id] = 2
    assert_no_difference 'Issue.count' do
      delete :destroy, :params => {
          :id => 999
        }
    end
    assert_response 404
  end

  def test_destroy_with_permission_on_tracker_should_be_allowed
    role = Role.find(1)
    role.set_permission_trackers :delete_issues, [1]
    role.save!
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1)

    @request.session[:user_id] = 2
    assert_difference 'Issue.count', -1 do
      delete :destroy, :params => {
          :id => issue.id
        }
    end
    assert_response 302
  end

  def test_destroy_without_permission_on_tracker_should_be_denied
    role = Role.find(1)
    role.set_permission_trackers :delete_issues, [2]
    role.save!
    issue = Issue.generate!(:project_id => 1, :tracker_id => 1)

    @request.session[:user_id] = 2
    assert_no_difference 'Issue.count' do
      delete :destroy, :params => {
          :id => issue.id
        }
    end
    assert_response 403
  end

  def test_default_search_scope
    get :index

    assert_select 'div#quick-search form' do
      assert_select 'input[name=issues][value="1"][type=hidden]'
    end
  end

  def setup_user_with_copy_but_not_add_permission
    Role.all.each {|r| r.remove_permission! :add_issues}
    Role.find_by_name('Manager').add_permission! :add_issues
    user = User.generate!
    User.add_to_project(user, Project.find(1), Role.find_by_name('Developer'))
    User.add_to_project(user, Project.find(2), Role.find_by_name('Manager'))
    user
  end

  def test_cancel_edit_link_for_issue_show_action_should_have_onclick_action
    @request.session[:user_id] = 1

    get :show, :params => {
        :id => 1
      }
    assert_response :success
    assert_select 'a[href=?][onclick=?]', "/issues/1", "$('#update').hide(); return false;", :text => 'Cancel'
  end

  def test_cancel_edit_link_for_issue_edit_action_should_not_have_onclick_action
    @request.session[:user_id] = 1

    get :edit, :params => {
        :id => 1
      }
    assert_response :success
    assert_select 'a[href=?][onclick=?]', "/issues/1", "", :text => 'Cancel'
  end

  def test_show_should_display_author_gravatar_only_when_not_assigned
    issue = Issue.find(1)
    assert_nil issue.assigned_to_id
    @request.session[:user_id] = 1

    with_settings :gravatar_enabled => '1' do
      get :show, :params => {:id => issue.id}
      assert_select 'div.gravatar-with-child' do
        assert_select 'img.gravatar', 1
      end
    end
  end

  def test_show_should_display_author_and_assignee_gravatars_when_assigned
    issue = Issue.find(1)
    issue.assigned_to_id = 2
    issue.save!
    @request.session[:user_id] = 1

    with_settings :gravatar_enabled => '1' do
      get :show, :params => {:id => issue.id}
      assert_select 'div.gravatar-with-child' do
        assert_select 'img.gravatar', 2
        assert_select 'img.gravatar-child', 1
      end
    end
  end
end
