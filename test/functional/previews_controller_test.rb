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

class PreviewsControllerTest < Redmine::ControllerTest
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :journals, :journal_details,
           :news

  def test_preview_new_issue_description
    @request.session[:user_id] = 2
    post(
      :issue,
      :params => {
        :project_id => '1',
        :text => 'Foo'
      }
    )
    assert_response :success
    assert_select 'p', :text => 'Foo'
  end

  def test_preview_issue_description
    @request.session[:user_id] = 2
    post(
      :issue,
      :params => {
        :project_id => '1',
        :issue_id => 1,
        :text => 'Unable to print recipes'
      }
    )
    assert_response :success

    assert_select 'p', :text => 'Unable to print recipes'
  end

  def test_preview_issue_notes
    @request.session[:user_id] = 2
    post(
      :issue,
      :params => {
        :project_id => '1',
        :id => 1,
        :text => 'Foo'
      }
    )
    assert_response :success
    assert_select 'p', :text => 'Foo'
  end

  def test_preview_issue_notes_should_support_links_to_existing_attachments
    Attachment.generate!(:container => Issue.find(1), :filename => 'foo.bar')
    @request.session[:user_id] = 2
    post(
      :issue,
      :params => {
        :project_id => '1',
        :issue_id => 1,
        :field => 'notes',
        :text => 'attachment:foo.bar'
      }
    )
    assert_response :success
    assert_select 'a.attachment', :text => 'foo.bar'
  end

  def test_preview_issue_notes_should_show_thumbnail_of_file_immidiately_after_attachment
    attachment = Attachment.generate!(filename: 'foo.png', digest: Redmine::Utils.random_hex(32))
    attachment.update(container: nil)

    @request.session[:user_id] = 2
    post(
      :issue,
      params: {
        project_id: '1',
        issue_id: 1,
        field: 'notes',
        text: '{{thumbnail(foo.png)}}',
        attachments: {'1': { token: attachment.token }}
      }
    )
    assert_response :success
    assert_select 'a.thumbnail[title=?]', 'foo.png'
  end

  def test_preview_new_news
    get(
      :news,
      :params => {
        :project_id => 1,
        :text => 'News description',
      }
    )
    assert_response :success
    assert_select 'p', :text => /News description/
  end

  def test_preview_existing_news
    get(
      :news,
      :params => {
        :project_id => 1,
        :id => 2,
        :text => 'News description'
      }
    )
    assert_response :success
    assert_select 'p', :text => /News description/
  end
end
