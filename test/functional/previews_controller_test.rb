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

require File.expand_path('../../test_helper', __FILE__)

class PreviewsControllerTest < ActionController::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :journals, :journal_details,
           :news

  def test_preview_new_issue
    @request.session[:user_id] = 2
    post :issue, :project_id => '1', :issue => {:description => 'Foo'}
    assert_response :success
    assert_template 'previews/issue'
    assert_not_nil assigns(:description)
  end

  def test_preview_issue_notes
    @request.session[:user_id] = 2
    post :issue, :project_id => '1', :id => 1,
         :issue => {:description => Issue.find(1).description, :notes => 'Foo'}
    assert_response :success
    assert_template 'previews/issue'
    assert_not_nil assigns(:notes)
  end

  def test_preview_journal_notes_for_update
    @request.session[:user_id] = 2
    post :issue, :project_id => '1', :id => 1, :notes => 'Foo'
    assert_response :success
    assert_template 'previews/issue'
    assert_not_nil assigns(:notes)
    assert_select 'p', :text => 'Foo'
  end

  def test_preview_issue_notes_should_support_links_to_existing_attachments
    Attachment.generate!(:container => Issue.find(1), :filename => 'foo.bar')
    @request.session[:user_id] = 2
    post :issue, :project_id => '1', :id => 1, :notes => 'attachment:foo.bar'
    assert_response :success
    assert_select 'a.attachment', :text => 'foo.bar'
  end

  def test_preview_issue_with_project_changed
    @request.session[:user_id] = 2
    post :issue, :project_id => '1', :id => 1, :issue => {:notes => 'notes', :project_id => 2}
    assert_response :success
    assert_not_nil assigns(:issue)
    assert_not_nil assigns(:notes)
  end

  def test_preview_new_news
    get :news, :project_id => 1,
                  :news => {:title => '',
                            :description => 'News description',
                            :summary => ''}
    assert_response :success
    assert_template 'common/_preview'
    assert_select 'fieldset.preview', :text => /News description/
  end

  def test_existing_new_news
    get :news, :project_id => 1, :id => 2,
                  :news => {:title => '',
                            :description => 'News description',
                            :summary => ''}
    assert_response :success
    assert_template 'common/_preview'
    assert_equal News.find(2), assigns(:previewed)
    assert_not_nil assigns(:attachments)

    assert_select 'fieldset.preview', :text => /News description/
  end
end
