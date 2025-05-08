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

class GanttsControllerTest < Redmine::ControllerTest
  def test_gantt_should_work
    i2 = Issue.find(2)
    i2.update_attribute(:due_date, 1.month.from_now)
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
          assert_select 'fieldset#options'
        end
        assert_select 'p.contextual' do
          prev_month, next_month = User.current.today.prev_month, User.current.today.next_month
          assert_select(
            'a[accesskey="p"][href=?]',
            project_gantt_path(:project_id => 1, :month => prev_month.month, :year => prev_month.year)
          )
          assert_select(
            'a[accesskey="n"][href=?]',
            project_gantt_path(:project_id => 1, :month => next_month.month, :year => next_month.year)
          )
        end
        assert_select 'p.buttons'
      end
    end

    # Assert context menu on issues subject and gantt bar
    assert_select 'div[class=?]', 'issue-subject hascontextmenu'
    assert_select 'div.tooltip.hascontextmenu' do
      assert_select 'img[class="gravatar"]'
    end
    assert_select "form[data-cm-url=?]", '/issues/context_menu'

    # Issue with start and due dates
    i = Issue.find(1)
    assert_not_nil i.due_date
    assert_select "div a.issue", /##{i.id}/
    # Issue with on a targeted version should not be in the events but loaded in the html
    i = Issue.find(2)
    assert_select "div a.issue", /##{i.id}/
  end

  def test_gantt_at_minimal_zoom
    get(
      :show,
      :params => {
        :project_id => 1,
        :zoom => 1
      }
    )
    assert_response :success
    assert_select 'input[type=hidden][name=zoom][value=?]', '1'
  end

  def test_gantt_at_maximal_zoom
    get(
      :show,
      :params => {
        :project_id => 1,
        :zoom => 4
      }
    )
    assert_response :success
    assert_select 'input[type=hidden][name=zoom][value=?]', '4'
  end

  def test_gantt_should_work_without_issue_due_dates
    Issue.update_all("due_date = NULL")
    get(:show, :params => {:project_id => 1})
    assert_response :success
  end

  def test_gantt_should_work_without_issue_and_version_due_dates
    Issue.update_all("due_date = NULL")
    Version.update_all("effective_date = NULL")
    get(:show, :params => {:project_id => 1})
    assert_response :success
  end

  def test_show_should_run_custom_query
    query = IssueQuery.create!(:name => 'Gantt Query', :description => 'Description for Gantt Query', :visibility => IssueQuery::VISIBILITY_PUBLIC)
    get(
      :show,
      :params => {
        :query_id => query.id
      }
    )
    assert_response :success
    assert_select 'h2', :text => query.name
    assert_select '#sidebar a.query.selected[title=?]', query.description, :text => query.name
  end

  def test_gantt_should_work_cross_project
    get :show
    assert_response :success
  end

  def test_gantt_should_not_disclose_private_projects
    get :show
    assert_response :success

    assert_select 'a', :text => /eCookbook/
    # Root private project
    assert_select 'a', :text => /OnlineStore/, :count => 0
    # Private children of a public project
    assert_select 'a', :text => /Private child of eCookbook/, :count => 0
  end

  def test_gantt_should_display_relations
    IssueRelation.delete_all
    issue1 = Issue.generate!(:start_date => 1.day.from_now.to_date, :due_date => 3.day.from_now.to_date)
    issue2 = Issue.generate!(:start_date => 1.day.from_now.to_date, :due_date => 3.day.from_now.to_date)
    IssueRelation.create!(:issue_from => issue1, :issue_to => issue2, :relation_type => 'precedes')

    get :show
    assert_response :success

    assert_select 'div.task_todo[id=?][data-rels*=?]', "task-todo-issue-#{issue1.id}", issue2.id.to_s
    assert_select 'div.task_todo[id=?]:not([data-rels])', "task-todo-issue-#{issue2.id}"
  end

  def test_gantt_should_export_to_pdf
    get(
      :show,
      :params => {
        :project_id => 1,
        :months => 1,
        :format => 'pdf'
      }
    )
    assert_response :success
    assert_equal 'application/pdf', @response.media_type
    assert @response.body.starts_with?('%PDF')
  end

  def test_gantt_should_export_to_pdf_cross_project
    get(:show, :params => {:format => 'pdf'})
    assert_response :success
    assert_equal 'application/pdf', @response.media_type
    assert @response.body.starts_with?('%PDF')
  end

  if Object.const_defined?(:MiniMagick) && convert_installed?
    def test_gantt_should_export_to_png
      get(
        :show,
        :params => {
          :project_id => 1,
          :zoom => 4,
          :format => 'png'
        }
      )
      assert_response :success
      assert_equal 'image/png', @response.media_type
    end
  end

  def test_gantt_should_respect_gantt_months_limit_setting
    with_settings :gantt_months_limit => '40' do
      # `months` parameter can be less than or equal to
      # `Setting.gantt_months_limit`
      get(
        :show,
        :params => {
          :project_id => 1,
          :zoom => 4,
          :months => 40
        }
      )
      assert_response :success
      assert_select 'div.gantt_hdr>a', :text => /^[\d-]+$/, :count => 40

      # Displays 6 months (the default value for `months`) if `months` exceeds
      # gant_months_limit
      get(
        :show,
        :params => {
          :project_id => 1,
          :zoom => 4,
          :months => 41
        }
      )
      assert_response :success
      assert_select 'div.gantt_hdr>a', :text => /^[\d-]+$/, :count => 6
    end
  end
end
