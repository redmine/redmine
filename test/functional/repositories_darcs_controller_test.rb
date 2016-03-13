# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class RepositoriesDarcsControllerTest < ActionController::TestCase
  tests RepositoriesController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH = Rails.root.join('tmp/test/darcs_repository').to_s
  PRJ_ID = 3
  NUM_REV = 6

  def setup
    User.current = nil
    @project = Project.find(PRJ_ID)
    @repository = Repository::Darcs.create(
                        :project      => @project,
                        :url          => REPOSITORY_PATH,
                        :log_encoding => 'UTF-8'
                        )
    assert @repository
  end

  if File.directory?(REPOSITORY_PATH)
    def test_get_new
      @request.session[:user_id] = 1
      @project.repository.destroy
      get :new, :project_id => 'subproject1', :repository_scm => 'Darcs'
      assert_response :success
      assert_template 'new'
      assert_kind_of Repository::Darcs, assigns(:repository)
      assert assigns(:repository).new_record?
    end

    def test_browse_root
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :show, :id => PRJ_ID
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal 3, assigns(:entries).size
      assert assigns(:entries).detect {|e| e.name == 'images' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'sources' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'README' && e.kind == 'file'}
    end

    def test_browse_directory
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :show, :id => PRJ_ID, :path => repository_path_hash(['images'])[:param]
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ['delete.png', 'edit.png'], assigns(:entries).collect(&:name)
      entry = assigns(:entries).detect {|e| e.name == 'edit.png'}
      assert_not_nil entry
      assert_equal 'file', entry.kind
      assert_equal 'images/edit.png', entry.path
    end

    def test_browse_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :show, :id => PRJ_ID, :path => repository_path_hash(['images'])[:param],
          :rev => 1
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ['delete.png'], assigns(:entries).collect(&:name)
    end

    def test_changes
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :changes, :id => PRJ_ID,
          :path => repository_path_hash(['images', 'edit.png'])[:param]
      assert_response :success
      assert_template 'changes'
      assert_select 'h2', :text => /edit.png/
    end

    def test_diff
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      # Full diff of changeset 5
      ['inline', 'sbs'].each do |dt|
        get :diff, :id => PRJ_ID, :rev => 5, :type => dt
        assert_response :success
        assert_template 'diff'
        # Line 22 removed
        assert_select 'th.line-num:contains(22) ~ td.diff_out', :text => /def remove/
      end
    end

    def test_destroy_valid_repository
      @request.session[:user_id] = 1 # admin
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      assert_difference 'Repository.count', -1 do
        delete :destroy, :id => @repository.id
      end
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end

    def test_destroy_invalid_repository
      @request.session[:user_id] = 1 # admin
      @project.repository.destroy
      @repository = Repository::Darcs.create!(
                        :project      => @project,
                        :url          => "/invalid",
                        :log_encoding => 'UTF-8'
                        )
      @repository.fetch_changesets
      @project.reload
      assert_equal 0, @repository.changesets.count

      assert_difference 'Repository.count', -1 do
        delete :destroy, :id => @repository.id
      end
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end
  else
    puts "Darcs test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
