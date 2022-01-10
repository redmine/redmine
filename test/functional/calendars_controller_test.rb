# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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
           :users, :email_addresses,
           :versions

  def test_show
    # Ensure that an issue to which a user is assigned is in the current
    # month's calendar in order to test Gravatar
    travel_to issues(:issues_002).start_date

    with_settings :gravatar_enabled => '1' do
      get(
        :show,
        :params => {
          :project_id => 1
        }
      )
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

    assert_select 'table.cal' do
      assert_select 'tr' do
        assert_select 'td' do
          assert_select(
            'div.issue.hascontextmenu.tooltip.starting',
            :text => /Add ingredients categories/
          ) do
            assert_select 'a.issue[href=?]', '/issues/2', :text => 'Feature request #2'
            assert_select 'span.tip' do
              assert_select 'img[class="gravatar"]'
            end
            assert_select 'input[name=?][type=?][value=?]', 'ids[]', 'checkbox', '2'
          end
        end
      end
    end
  end

  def test_show_issue_due_date
    travel_to issues(:issues_001).due_date

    get(:show, :params => {:project_id => 1})
    assert_response :success

    assert_select 'table.cal' do
      assert_select 'tr' do
        assert_select 'td' do
          assert_select(
            'div.issue.hascontextmenu.tooltip.ending',
            :text => /Cannot print recipes/
          ) do
            assert_select 'a.issue[href=?]', '/issues/1', :text => 'Bug #1'
            assert_select 'input[name=?][type=?][value=?]', 'ids[]', 'checkbox', '1'
          end
        end
      end
    end
  end

  test "show issue of start and due dates are same" do
    subject = 'start and due dates are same'
    issue = Issue.generate!(:start_date => '2012-10-06',
                            :due_date   => '2012-10-06',
                            :project_id => 1, :tracker_id => 1,
                            :subject => subject)
    get(
      :show,
      :params => {
        :project_id => 1,
        :month => '10',
        :year => '2012'
      }
    )
    assert_response :success

    assert_select 'table.cal' do
      assert_select 'tr' do
        assert_select 'td' do
          assert_select(
            'div.issue.hascontextmenu.tooltip.starting.ending',
            :text => /#{subject}/
          ) do
            assert_select(
              'a.issue[href=?]', "/issues/#{issue.id}",
              :text => "Bug ##{issue.id}"
            )
            assert_select(
              'input[name=?][type=?][value=?]',
              'ids[]',
              'checkbox',
              issue.id.to_s
            )
          end
        end
      end
    end
  end

  def test_show_version
    travel_to versions(:versions_002).effective_date

    get(:show, :params => {:project_id => 1})
    assert_response :success

    assert_select 'table.cal' do
      assert_select 'tr' do
        assert_select 'td' do
          assert_select(
            'span.icon.icon-package'
          ) do
            assert_select 'a[href=?]', '/versions/2', :text => '1.0'
          end
        end
      end
    end
  end

  def test_show_should_run_custom_queries
    @query = IssueQuery.create!(:name => 'Calendar Query', :visibility => IssueQuery::VISIBILITY_PUBLIC)
    get(
      :show,
      :params => {
        :query_id => @query.id
      }
    )
    assert_response :success
    assert_select 'h2', :text => 'Calendar Query'
  end

  def test_cross_project_calendar
    travel_to issues(:issues_002).start_date
    get :show
    assert_response :success

    assert_select 'table.cal' do
      assert_select 'tr' do
        assert_select 'td' do
          assert_select(
            'div.issue.hascontextmenu.tooltip.starting',
            :text => /eCookbook.*Add ingredients categories/m
          ) do
            assert_select 'a.issue[href=?]', '/issues/2', :text => 'Feature request #2'
            assert_select 'input[name=?][type=?][value=?]', 'ids[]', 'checkbox', '2'
          end
        end
      end
    end
  end

  def test_cross_project_calendar_version
    travel_to versions(:versions_002).effective_date

    get :show
    assert_response :success

    assert_select 'table.cal' do
      assert_select 'tr' do
        assert_select 'td' do
          assert_select(
            'span.icon.icon-package'
          ) do
            assert_select(
              'a[href=?]', '/versions/2',
              :text => 'eCookbook - 1.0'
            )
          end
        end
      end
    end
  end

  def test_week_number_calculation
    with_settings :start_of_week => 7 do
      get(
        :show,
        :params => {
          :month => '1',
          :year => '2010'
        }
      )
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
      get(
        :show,
        :params => {
          :month => '1',
          :year => '2010'
        }
      )
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
    get(
      :show,
      :params => {
        :query_id => 5
      }
    )
    assert_response :success
    assert_select 'h2', :text => 'Open issues by priority and tracker'
  end

  def test_show_custom_query_with_group_by_option
    get(
      :show,
      :params => {
        :query_id => 6
      }
    )
    assert_response :success
    assert_select 'h2', :text => 'Open issues grouped by tracker'
  end

  def test_show_calendar_day_css_classes
    get(
      :show,
      :params => {
        :month => '12',
        :year => '2016'
      }
    )
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
