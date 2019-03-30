# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class RepositoriesControllerTest < Redmine::RepositoryControllerTest
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules,
           :repositories, :issues, :issue_statuses, :changesets, :changes,
           :issue_categories, :enumerations, :custom_fields, :custom_values, :trackers

  def setup
    super
    User.current = nil
  end

  def test_new
    @request.session[:user_id] = 1
    get :new, :params => {
        :project_id => 'subproject1'
      }
    assert_response :success
    assert_select 'select[name=?]', 'repository_scm' do
      assert_select 'option[value=?][selected=selected]', 'Subversion'
    end
    assert_select 'input[name=?]:not([disabled])', 'repository[url]'
  end

  def test_new_should_propose_enabled_scm_only
    @request.session[:user_id] = 1
    with_settings :enabled_scm => ['Mercurial', 'Git'] do
      get :new, :params => {
          :project_id => 'subproject1'
        }
    end
    assert_response :success

    assert_select 'select[name=repository_scm]' do
      assert_select 'option', 3
      assert_select 'option[value=Mercurial][selected=selected]'
      assert_select 'option[value=Git]:not([selected])'
    end
  end
 
  def test_get_new_with_type
    @request.session[:user_id] = 1
    get :new, :params => {
        :project_id => 'subproject1',
        :repository_scm => 'Git'
      }
    assert_response :success

    assert_select 'select[name=?]', 'repository_scm' do
      assert_select 'option[value=?][selected=selected]', 'Git'
    end
  end

  def test_create
    @request.session[:user_id] = 1
    assert_difference 'Repository.count' do
      post :create, :params => {
          :project_id => 'subproject1',
          :repository_scm => 'Subversion',
          :repository => {
            :url => 'file:///test',
            :is_default => '1',
            :identifier => ''
          }
        }
    end
    assert_response 302
    repository = Repository.order('id DESC').first
    assert_kind_of Repository::Subversion, repository
    assert_equal 'file:///test', repository.url
  end

  def test_create_with_failure
    @request.session[:user_id] = 1
    assert_no_difference 'Repository.count' do
      post :create, :params => {
          :project_id => 'subproject1',
          :repository_scm => 'Subversion',
          :repository => {
            :url => 'invalid'
          }
        }
    end
    assert_response :success
    assert_select_error /URL is invalid/
    assert_select 'select[name=?]', 'repository_scm' do
      assert_select 'option[value=?][selected=selected]', 'Subversion'
    end
  end

  def test_edit
    @request.session[:user_id] = 1
    get :edit, :params => {
        :id => 11
      }
    assert_response :success
    assert_select 'input[name=?][value=?][disabled=disabled]', 'repository[url]', 'svn://localhost/test'
  end

  def test_update
    @request.session[:user_id] = 1
    put :update, :params => {
        :id => 11,
        :repository => {
          :password => 'test_update'
        }
      }
    assert_response 302
    assert_equal 'test_update', Repository.find(11).password
  end

  def test_update_with_failure
    @request.session[:user_id] = 1
    put :update, :params => {
        :id => 11,
        :repository => {
          :password => 'x'*260
        }
      }
    assert_response :success
    assert_select_error /Password is too long/
  end

  def test_destroy
    @request.session[:user_id] = 1
    assert_difference 'Repository.count', -1 do
      delete :destroy, :params => {
          :id => 11
        }
    end
    assert_response 302
    assert_nil Repository.find_by_id(11)
  end

  def test_show_with_autofetch_changesets_enabled_should_fetch_changesets
    Repository::Subversion.any_instance.expects(:fetch_changesets).once

    with_settings :autofetch_changesets => '1' do
      get :show, :params => {
          :id => 1
        }
    end
  end

  def test_show_with_autofetch_changesets_disabled_should_not_fetch_changesets
    Repository::Subversion.any_instance.expects(:fetch_changesets).never

    with_settings :autofetch_changesets => '0' do
      get :show, :params => {
          :id => 1
        }
    end
  end

  def test_show_with_closed_project_should_not_fetch_changesets
    Repository::Subversion.any_instance.expects(:fetch_changesets).never
    Project.find(1).close

    with_settings :autofetch_changesets => '1' do
      get :show, :params => {
          :id => 1
        }
    end
  end

  def test_show_should_show_diff_button_depending_on_browse_repository_permission
    @request.session[:user_id] = 2
    role = Role.find(1)

    role.add_permission! :browse_repository
    get :show, :params => {
      :id => 1
    }
    assert_response :success
    assert_select 'input[value="View differences"]'

    role.remove_permission! :browse_repository
    get :show, :params => {
      :id => 1
    }
    assert_response :success
    assert_select 'input[value="View differences"]', :count => 0
  end

  def test_revisions
    get :revisions, :params => {
        :id => 1,
        :repository_id => 10
      }
    assert_response :success
    assert_select 'table.changesets'
  end

  def test_revisions_for_other_repository
    repository = Repository::Subversion.create!(:project_id => 1, :identifier => 'foo', :url => 'file:///foo')

    get :revisions, :params => {
        :id => 1,
        :repository_id => 'foo'
      }
    assert_response :success
    assert_select 'table.changesets'
  end

  def test_revisions_for_invalid_repository
    get :revisions, :params => {
        :id => 1,
        :repository_id => 'foo'
      }
    assert_response 404
  end

  def test_revision
    get :revision, :params => {
        :id => 1,
        :repository_id => 10,
        :rev => 1
      }
    assert_response :success
    assert_select 'h2', :text => 'Revision 1'
  end

  def test_revision_should_not_format_comments_when_disabled
    Changeset.where(:id => 100).update_all(:comments => 'Simple *text*')

    with_settings :commit_logs_formatting => '0' do
      get :revision, :params => {
          :id => 1,
          :repository_id => 10,
          :rev => 1
        }
      assert_response :success
      assert_select '.changeset-comments', :text => 'Simple *text*'
    end
  end

  def test_revision_should_show_add_related_issue_form
    Role.find(1).add_permission! :manage_related_issues
    @request.session[:user_id] = 2

    get :revision, :params => {
        :id => 1,
        :repository_id => 10,
        :rev => 1
      }
    assert_response :success

    assert_select 'form[action=?]', '/projects/ecookbook/repository/10/revisions/1/issues' do
      assert_select 'input[name=?]', 'issue_id'
    end
  end

  def test_revision_should_not_change_the_project_menu_link
    get :revision, :params => {
        :id => 1,
        :repository_id => 10,
        :rev => 1
      }
    assert_response :success

    assert_select '#main-menu a.repository[href=?]', '/projects/ecookbook/repository'
  end

  def test_revision_with_before_nil_and_afer_normal
    get :revision, :params => {
        :id => 1,
        :repository_id => 10,
        :rev => 1
      }
    assert_response :success

    assert_select 'div.contextual' do
      assert_select 'a[href=?]', '/projects/ecookbook/repository/10/revisions/0', 0
      assert_select 'a[href=?]', '/projects/ecookbook/repository/10/revisions/2'
    end
  end

  def test_add_related_issue
    @request.session[:user_id] = 2
    assert_difference 'Changeset.find(103).issues.size' do
      post :add_related_issue, :params => {
          :id => 1,
          :repository_id => 10,
          :rev => 4,
          :issue_id => 2,
          :format => 'js'
        },
        :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end
    assert_equal [2], Changeset.find(103).issue_ids
    assert_include 'related-issues', response.body
    assert_include 'Feature request #2', response.body
  end

  def test_add_related_issue_should_accept_issue_id_with_sharp
    @request.session[:user_id] = 2
    assert_difference 'Changeset.find(103).issues.size' do
      post :add_related_issue, :params => {
          :id => 1,
          :repository_id => 10,
          :rev => 4,
          :issue_id => "#2",
          :format => 'js'
        },
        :xhr => true
    end
    assert_equal [2], Changeset.find(103).issue_ids
  end

  def test_add_related_issue_with_invalid_issue_id
    @request.session[:user_id] = 2
    assert_no_difference 'Changeset.find(103).issues.size' do
      post :add_related_issue, :params => {
          :id => 1,
          :repository_id => 10,
          :rev => 4,
          :issue_id => 9999,
          :format => 'js'
        },
        :xhr => true
      assert_response :success
      assert_equal 'text/javascript', response.content_type
    end
    assert_include 'alert("Issue is invalid")', response.body
  end

  def test_remove_related_issue
    Changeset.find(103).issues << Issue.find(1)
    Changeset.find(103).issues << Issue.find(2)

    @request.session[:user_id] = 2
    assert_difference 'Changeset.find(103).issues.size', -1 do
      delete :remove_related_issue, :params => {
          :id => 1,
          :repository_id => 10,
          :rev => 4,
          :issue_id => 2,
          :format => 'js'
        },
        :xhr => true
      assert_response :success
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

    get :graph, :params => {
        :id => 1,
        :repository_id => 10,
        :graph => 'commits_per_month'
      }
    assert_response :success
    assert_equal 'application/json', response.content_type
    data = ActiveSupport::JSON.decode(response.body)
    assert_not_nil data['labels']
    assert_not_nil data['commits']
    assert_not_nil data['changes']
  end

  def test_graph_commits_per_author
    get :graph, :params => {
        :id => 1,
        :repository_id => 10,
        :graph => 'commits_per_author'
      }
    assert_response :success
    assert_equal 'application/json', response.content_type
    data = ActiveSupport::JSON.decode(response.body)
    assert_not_nil data['labels']
    assert_not_nil data['commits']
    assert_not_nil data['changes']
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

    get :committers, :params => {
        :id => 10
      }
    assert_response :success

    assert_select 'input[value=dlopper] + select option[value="3"][selected=selected]', :text => 'Dave Lopper'
    assert_select 'input[value=foo] + select option[selected=selected]', 0 # no option selected
  end

  def test_get_committers_without_changesets
    Changeset.delete_all
    @request.session[:user_id] = 2

    get :committers, :params => {
        :id => 10
      }
    assert_response :success
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
      post :committers, :params => {
          :id => 10,
          :committers => {
            '0' => ['foo', '2'], '1' => ['dlopper', '3']
          }
        }
      assert_response 302
      assert_equal User.find(2), c.reload.user
    end
  end
end
