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

class RepositoriesCvsControllerTest < ActionController::TestCase
  tests RepositoriesController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH = Rails.root.join('tmp/test/cvs_repository').to_s
  REPOSITORY_PATH.gsub!(/\//, "\\") if Redmine::Platform.mswin?
  # CVS module
  MODULE_NAME = 'test'
  PRJ_ID = 3
  NUM_REV = 7

  def setup
    Setting.default_language = 'en'
    User.current = nil

    @project = Project.find(PRJ_ID)
    @repository  = Repository::Cvs.create(:project      => Project.find(PRJ_ID),
                                          :root_url     => REPOSITORY_PATH,
                                          :url          => MODULE_NAME,
                                          :log_encoding => 'UTF-8')
    assert @repository
  end

  if File.directory?(REPOSITORY_PATH)
    def test_get_new
      @request.session[:user_id] = 1
      @project.repository.destroy
      get :new, :project_id => 'subproject1', :repository_scm => 'Cvs'
      assert_response :success
      assert_template 'new'
      assert_kind_of Repository::Cvs, assigns(:repository)
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

      entry = assigns(:entries).detect {|e| e.name == 'images'}
      assert_equal 'dir', entry.kind

      entry = assigns(:entries).detect {|e| e.name == 'README'}
      assert_equal 'file', entry.kind

      assert_not_nil assigns(:changesets)
      assert assigns(:changesets).size > 0
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
      assert_equal ['add.png', 'delete.png', 'edit.png'], assigns(:entries).collect(&:name)
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
      assert_equal ['delete.png', 'edit.png'], assigns(:entries).collect(&:name)
    end

    def test_entry
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
      assert_response :success
      assert_template 'entry'
      assert_select 'td.line-code', :text => /before_filter/, :count => 0
    end

    def test_entry_at_given_revision
      # changesets must be loaded
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param],
          :rev => 2
      assert_response :success
      assert_template 'entry'
      # this line was removed in r3
      assert_select 'td.line-code', :text => /before_filter/
    end

    def test_entry_not_found
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'zzz.c'])[:param]
      assert_select 'p#errorExplanation', :text => /The entry or revision was not found in the repository/
    end

    def test_entry_download
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param],
          :format => 'raw'
      assert_response :success
    end

    def test_directory_entry
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources'])[:param]
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entry)
      assert_equal 'sources', assigns(:entry).name
    end

    def test_diff
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['inline', 'sbs'].each do |dt|
        get :diff, :id => PRJ_ID, :rev => 3, :type => dt
        assert_response :success
        assert_template 'diff'
        assert_select 'td.line-code.diff_out', :text => /before_filter :require_login/
        assert_select 'td.line-code.diff_in', :text => /with one change/
      end
    end

    def test_diff_new_files
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['inline', 'sbs'].each do |dt|
        get :diff, :id => PRJ_ID, :rev => 1, :type => dt
        assert_response :success
        assert_template 'diff'
        assert_select 'td.line-code.diff_in', :text => /watched.remove_watcher/
        assert_select 'th.filename', :text => /test\/README/
        assert_select 'th.filename', :text => /test\/images\/delete.png/
        assert_select 'th.filename', :text => /test\/images\/edit.png/
        assert_select 'th.filename', :text => /test\/sources\/watchers_controller.rb/
      end
    end

    def test_annotate
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :annotate, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
      assert_response :success
      assert_template 'annotate'

      # 1.1 line
      assert_select 'tr' do
        assert_select 'th.line-num', :text => '21'
        assert_select 'td.revision', :text => /1.1/
        assert_select 'td.author', :text => /LANG/
      end
      # 1.2 line
      assert_select 'tr' do
        assert_select 'th.line-num', :text => '32'
        assert_select 'td.revision', :text => /1.2/
        assert_select 'td.author', :text => /LANG/
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
      @repository  = Repository::Cvs.create!(
                              :project      => Project.find(PRJ_ID),
                              :root_url     => "/invalid",
                              :url          => MODULE_NAME,
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
    puts "CVS test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
