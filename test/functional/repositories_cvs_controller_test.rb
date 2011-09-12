# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
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
require 'repositories_controller'

# Re-raise errors caught by the controller.
class RepositoriesController; def rescue_action(e) raise e end; end

class RepositoriesCvsControllerTest < ActionController::TestCase
  fixtures :projects, :users, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH = Rails.root.join('tmp/test/cvs_repository').to_s
  REPOSITORY_PATH.gsub!(/\//, "\\") if Redmine::Platform.mswin?
  # CVS module
  MODULE_NAME = 'test'
  PRJ_ID = 3
  NUM_REV = 7

  def setup
    @controller = RepositoriesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
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
      get :show, :id => PRJ_ID, :path => ['images']
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
      get :show, :id => PRJ_ID, :path => ['images'], :rev => 1
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
      get :entry, :id => PRJ_ID, :path => ['sources', 'watchers_controller.rb']
      assert_response :success
      assert_template 'entry'
      assert_no_tag :tag => 'td',
                    :attributes => { :class => /line-code/},
                    :content => /before_filter/
    end

    def test_entry_at_given_revision
      # changesets must be loaded
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID, :path => ['sources', 'watchers_controller.rb'], :rev => 2
      assert_response :success
      assert_template 'entry'
      # this line was removed in r3
      assert_tag :tag => 'td',
                 :attributes => { :class => /line-code/},
                 :content => /before_filter/
    end

    def test_entry_not_found
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID, :path => ['sources', 'zzz.c']
      assert_tag :tag => 'p',
                 :attributes => { :id => /errorExplanation/ },
                 :content => /The entry or revision was not found in the repository/
    end

    def test_entry_download
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID, :path => ['sources', 'watchers_controller.rb'],
          :format => 'raw'
      assert_response :success
    end

    def test_directory_entry
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID, :path => ['sources']
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
        assert_tag :tag => 'td', :attributes => { :class => 'line-code diff_out' },
                                 :content => /before_filter :require_login/
        assert_tag :tag => 'td', :attributes => { :class => 'line-code diff_in' },
                                 :content => /with one change/
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
        assert_tag :tag => 'td', :attributes => { :class => 'line-code diff_in' },
                                 :content => /watched.remove_watcher/
        assert_tag :tag => 'th', :attributes => { :class => 'filename' },
                                 :content => /test\/README/
        assert_tag :tag => 'th', :attributes => { :class => 'filename' },
                                 :content => /test\/images\/delete.png	/
        assert_tag :tag => 'th', :attributes => { :class => 'filename' },
                                 :content => /test\/images\/edit.png/
        assert_tag :tag => 'th', :attributes => { :class => 'filename' },
                                 :content => /test\/sources\/watchers_controller.rb/
      end
    end

    def test_annotate
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :annotate, :id => PRJ_ID, :path => ['sources', 'watchers_controller.rb']
      assert_response :success
      assert_template 'annotate'
      # 1.1 line
      assert_tag :tag => 'th',
                 :attributes => { :class => 'line-num' },
                 :content => '18',
                 :sibling => {
                   :tag => 'td',
                   :attributes => { :class => 'revision' },
                   :content => /1.1/,
                   :sibling => {
                      :tag => 'td',
                      :attributes => { :class => 'author' },
                      :content => /LANG/
                        }
                   }
      # 1.2 line
      assert_tag :tag => 'th',
                 :attributes => { :class => 'line-num' },
                 :content => '32',
                 :sibling => {
                     :tag => 'td',
                     :attributes => { :class => 'revision' },
                     :content => /1.2/,
                     :sibling => {
                        :tag => 'td',
                        :attributes => { :class => 'author' },
                        :content => /LANG/
                        }
                   }
    end

    def test_destroy_valid_repository
      @request.session[:user_id] = 1 # admin
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      get :destroy, :id => PRJ_ID
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end

    def test_destroy_invalid_repository
      @request.session[:user_id] = 1 # admin
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      get :destroy, :id => PRJ_ID
      assert_response 302
      @project.reload
      assert_nil @project.repository

      @repository  = Repository::Cvs.create(
                              :project      => Project.find(PRJ_ID),
                              :root_url     => "/invalid",
                              :url          => MODULE_NAME,
                              :log_encoding => 'UTF-8'
                              )
      assert @repository
      @repository.fetch_changesets
      @project.reload
      assert_equal 0, @repository.changesets.count

      get :destroy, :id => PRJ_ID
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end
  else
    puts "CVS test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
