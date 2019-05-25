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

class CalendarsControllerTest < Redmine::ControllerTest
  fixtures :projects,
           :trackers,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :issues,
           :issue_statuses,
           :issue_relations,
           :issue_categories,
           :enumerations,
           :queries,
           :users, :email_addresses

  def test_show
    # Ensure that an issue to which a user is assigned is in the current
    # month's calendar in order to test Gravatar
    travel_to issues(:issues_002).start_date

    with_settings :gravatar_enabled => '1' do
      get :show, :params => {
          :project_id => 1
        }
    end
    assert_response :success

    # query form
    assert_select 'form#query_form' do
      assert_select 'div#query_form_with_buttons.hide-when-print' do
        assert_select 'div#query_form_content' do
          assert_select 'fieldset#filters.collapsible'
        end
        assert_select 'p.contextual'
        assert_select 'p.buttons'
      end
    end

    # Assert context menu on issues
    assert_select 'form[data-cm-url=?]', '/issues/context_menu'
    assert_select 'div.issue.hascontextmenu.tooltip' do
      assert_select 'input[name=?][type=?]', 'ids[]', 'checkbox'
      assert_select 'img[class="gravatar"]'
    end
  end

  def test_show_should_run_custom_queries
    @query = IssueQuery.create!(:name => 'Calendar Query', :visibility => IssueQuery::VISIBILITY_PUBLIC)

    get :show, :params => {
        :query_id => @query.id
      }
    assert_response :success
    assert_select 'h2', :text => 'Calendar Query'
  end

  def test_cross_project_calendar
    get :show
    assert_response :success
  end

  def test_week_number_calculation
    with_settings :start_of_week => 7 do
      get :show, :params => {
          :month => '1',
          :year => '2010'
        }
      assert_response :success
    end

    assert_select 'tr' do
      assert_select 'td.week-number', :text => '53'
      assert_select 'td.odd', :text => '27'
      assert_select 'td.even', :text => '2'
    end

    assert_select 'tr' do
      assert_select 'td.week-number', :text => '1'
      assert_select 'td.odd', :text => '3'
      assert_select 'td.even', :text => '9'
    end

    with_settings :start_of_week => 1 do
      get :show, :params => {
          :month => '1',
          :year => '2010'
        }
      assert_response :success
    end

    assert_select 'tr' do
      assert_select 'td.week-number', :text => '53'
      assert_select 'td.even', :text => '28'
      assert_select 'td.even', :text => '3'
    end

    assert_select 'tr' do
      assert_select 'td.week-number', :text => '1'
      assert_select 'td.even', :text => '4'
      assert_select 'td.even', :text => '10'
    end
  end

  def test_show_custom_query_with_multiple_sort_criteria
    get :show, :params => {
        :query_id => 5
      }

    assert_response :success
    assert_select 'h2', :text => 'Open issues by priority and tracker'
  end

  def test_show_custom_query_with_group_by_option
    get :show, :params => {
        :query_id => 6
      }

    assert_response :success
    assert_select 'h2', :text => 'Open issues grouped by tracker'
  end

  def test_show_calendar_day_css_classes
    get :show, :params => {
        :month => '12',
        :year => '2016'
      }
    assert_response :success

    assert_select 'tr:nth-child(2)' do
      assert_select 'td.week-number', :text => '49'
      # non working days should have "nwday" CSS class
      assert_select 'td.nwday', 2
      assert_select 'td.nwday', :text => '4'
      assert_select 'td.nwday', :text => '10'
    end
  end
end
