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

class RepositoriesControllerTest < ActionController::TestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules,
           :repositories, :issues, :issue_statuses, :changesets, :changes,
           :issue_categories, :enumerations, :custom_fields, :custom_values, :trackers

  def setup
    User.current = nil
  end

  def test_new
    @request.session[:user_id] = 1
    get :new, :project_id => 'subproject1'
    assert_response :success
    assert_template 'new'
    assert_kind_of Repository::Subversion, assigns(:repository)
    assert assigns(:repository).new_record?
    assert_select 'input[name=?]:not([disabled])', 'repository[url]'
  end

  def test_new_should_propose_enabled_scm_only
    @request.session[:user_id] = 1
    with_settings :enabled_scm => ['Mercurial', 'Git'] do
      get :new, :project_id => 'subproject1'
    end
    assert_response :success
    assert_template 'new'
    assert_kind_of Repository::Mercurial, assigns(:repository)

    assert_select 'select[name=repository_scm]' do
      assert_select 'option', 3
      assert_select 'option[value=Mercurial][selected=selected]'
      assert_select 'option[value=Git]:not([selected])'
    end
  end

  def test_create
    @request.session[:user_id] = 1
    assert_difference 'Repository.count' do
      post :create, :project_id => 'subproject1',
           :repository_scm => 'Subversion',
           :repository => {:url => 'file:///test', :is_default => '1', :identifier => ''}
    end
    assert_response 302
    repository = Repository.order('id DESC').first
    assert_kind_of Repository::Subversion, repository
    assert_equal 'file:///test', repository.url
  end

  def test_create_with_failure
    @request.session[:user_id] = 1
    assert_no_difference 'Repository.count' do
      post :create, :project_id => 'subproject1',
           :repository_scm => 'Subversion',
           :repository => {:url => 'invalid'}
    end
    assert_response :success
    assert_template 'new'
    assert_kind_of Repository::Subversion, assigns(:repository)
    assert assigns(:repository).new_record?
  end

  def test_edit
    @request.session[:user_id] = 1
    get :edit, :id => 11
    assert_response :success
    assert_template 'edit'
    assert_equal Repository.find(11), assigns(:repository)
    assert_select 'input[name=?][value=?][disabled=disabled]', 'repository[url]', 'svn://localhost/test'
  end

  def test_update
    @request.session[:user_id] = 1
    put :update, :id => 11, :repository => {:password => 'test_update'}
    assert_response 302
    assert_equal 'test_update', Repository.find(11).password
  end

  def test_update_with_failure
    @request.session[:user_id] = 1
    put :update, :id => 11, :repository => {:password => 'x'*260}
    assert_response :success
    assert_template 'edit'
    assert_equal Repository.find(11), assigns(:repository)
  end

  def test_destroy
    @request.session[:user_id] = 1
    assert_difference 'Repository.count', -1 do
      delete :destroy, :id => 11
    end
    assert_response 302
    assert_nil Repository.find_by_id(11)
  end

  def test_show_with_autofetch_changesets_enabled_should_fetch_changesets
    Repository::Subversion.any_instance.expects(:fetch_changesets).once

    with_settings :autofetch_changesets => '1' do
      get :show, :id => 1
    end
  end

  def test_show_with_autofetch_changesets_disabled_should_not_fetch_changesets
    Repository::Subversion.any_instance.expects(:fetch_changesets).never

    with_settings :autofetch_changesets => '0' do
      get :show, :id => 1
    end
  end

  def test_show_with_closed_project_should_not_fetch_changesets
    Repository::Subversion.any_instance.expects(:fetch_changesets).never
    Project.find(1).close

    with_settings :autofetch_changesets => '1' do
      get :show, :id => 1
    end
  end

  def test_revisions
    get :revisions, :id => 1
    assert_response :success
    assert_template 'revisions'
    assert_equal Repository.find(10), assigns(:repository)
    assert_not_nil assigns(:changesets)
  end

  def test_revisions_for_other_repository
    repository = Repository::Subversion.create!(:project_id => 1, :identifier => 'foo', :url => 'file:///foo')

    get :revisions, :id => 1, :repository_id => 'foo'
    assert_response :success
    assert_template 'revisions'
    assert_equal repository, assigns(:repository)
    assert_not_nil assigns(:changesets)
  end

  def test_revisions_for_invalid_repository
    get :revisions, :id => 1, :repository_id => 'foo'
    assert_response 404
  end

  def test_revision
    get :revision, :id => 1, :rev => 1
    assert_response :success
    assert_not_nil assigns(:changeset)
    assert_equal "1", assigns(:changeset).revision
  end

  def test_revision_should_show_add_related_issue_form
    Role.find(1).add_permission! :manage_related_issues
    @request.session[:user_id] = 2

    get :revision, :id => 1, :rev => 1
    assert_response :success

    assert_select 'form[action=?]', '/projects/ecookbook/repository/revisions/1/issues' do
      assert_select 'input[name=?]', 'issue_id'
    end
  end

  def test_revision_should_not_change_the_project_menu_link
    get :revision, :id => 1, :rev => 1
    assert_response :success

    assert_select '#main-menu a.repository[href=?]', '/projects/ecookbook/repository'
  end

  def test_revision_with_before_nil_and_afer_normal
    get :revision, {:id => 1, :rev => 1}
    assert_response :success
    assert_template 'revision'

    assert_select 'div.contextual' do
      assert_select 'a[href=?]', '/projects/ecookbook/repository/revisions/0', 0
      assert_select 'a[href=?]', '/projects/ecookbook/repository/revisions/2'
    end
  end

  def test_add_related_issue
    @request.session[:user_id] = 2
    assert_difference 'Changeset.find(103).issues.size' do
      xhr :post, :add_related_issue, :id => 1, :rev => 4, :issue_id => 2, :format => 'js'
      assert_response :success
      assert_template 'add_related_issue'
      assert_equal 'text/javascript', response.content_type
    end
    assert_equal [2], Changeset.find(103).issue_ids
    assert_include 'related-issues', response.body
    assert_include 'Feature request #2', response.body
  end

  def test_add_related_issue_should_accept_issue_id_with_sharp
    @request.session[:user_id] = 2
    assert_difference 'Changeset.find(103).issues.size' do
      xhr :post, :add_related_issue, :id => 1, :rev => 4, :issue_id => "#2", :format => 'js'
    end
    assert_equal [2], Changeset.find(103).issue_ids
  end

  def test_add_related_issue_with_invalid_issue_id
    @request.session[:user_id] = 2
    assert_no_difference 'Changeset.find(103).issues.size' do
      xhr :post, :add_related_issue, :id => 1, :rev => 4, :issue_id => 9999, :format => 'js'
      assert_response :success
      assert_template 'add_related_issue'
      assert_equal 'text/javascript', response.content_type
    end
    assert_include 'alert("Issue is invalid")', response.body
  end

  def test_remove_related_issue
    Changeset.find(103).issues << Issue.find(1)
    Changeset.find(103).issues << Issue.find(2)

    @request.session[:user_id] = 2
    assert_difference 'Changeset.find(103).issues.size', -1 do
      xhr :delete, :remove_related_issue, :id => 1, :rev => 4, :issue_id => 2, :format => 'js'
      assert_response :success
      assert_template 'remove_related_issue'
      assert_equal 'text/javascript', response.content_type
    end
    assert_equal [1], Changeset.find(103).issue_ids
    assert_include 'related-issue-2', response.body
  end

  def test_graph_commits_per_month
    # Make sure there's some data to display
    latest = Project.find(1).repository.changesets.maximum(:commit_date)
    assert_not_nil latest
    Date.stubs(:today).returns(latest.to_date + 10)

    get :graph, :id => 1, :graph => 'commits_per_month'
    assert_response :success
    assert_equal 'image/svg+xml', @response.content_type
  end

  def test_graph_commits_per_author
    get :graph, :id => 1, :graph => 'commits_per_author'
    assert_response :success
    assert_equal 'image/svg+xml', @response.content_type
  end

  def test_get_committers
    @request.session[:user_id] = 2
    # add a commit with an unknown user
    Changeset.create!(
        :repository => Project.find(1).repository,
        :committer  => 'foo',
        :committed_on => Time.now,
        :revision => 100,
        :comments => 'Committed by foo.'
     )

    get :committers, :id => 10
    assert_response :success
    assert_template 'committers'

    assert_select 'input[value=dlopper] + select option[value="3"][selected=selected]', :text => 'Dave Lopper'
    assert_select 'input[value=foo] + select option[selected=selected]', 0 # no option selected
  end

  def test_get_committers_without_changesets
    Changeset.delete_all
    @request.session[:user_id] = 2

    get :committers, :id => 10
    assert_response :success
    assert_template 'committers'
  end

  def test_post_committers
    @request.session[:user_id] = 2
    # add a commit with an unknown user
    c = Changeset.create!(
            :repository => Project.find(1).repository,
            :committer  => 'foo',
            :committed_on => Time.now,
            :revision => 100,
            :comments => 'Committed by foo.'
          )
    assert_no_difference "Changeset.where(:user_id => 3).count" do
      post :committers, :id => 10, :committers => { '0' => ['foo', '2'], '1' => ['dlopper', '3']}
      assert_response 302
      assert_equal User.find(2), c.reload.user
    end
  end
end
