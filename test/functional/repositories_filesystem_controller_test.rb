# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class RepositoriesFilesystemControllerTest < ActionController::TestCase
  tests RepositoriesController

  fixtures :projects, :users, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH = Rails.root.join('tmp/test/filesystem_repository').to_s
  PRJ_ID = 3

  def setup
    @ruby19_non_utf8_pass =
        (RUBY_VERSION >= '1.9' && Encoding.default_external.to_s != 'UTF-8')
    User.current = nil
    Setting.enabled_scm << 'Filesystem' unless Setting.enabled_scm.include?('Filesystem')
    @project = Project.find(PRJ_ID)
    @repository = Repository::Filesystem.create(
                      :project       => @project,
                      :url           => REPOSITORY_PATH,
                      :path_encoding => ''
                      )
    assert @repository
  end

  if File.directory?(REPOSITORY_PATH)
    def test_get_new
      @request.session[:user_id] = 1
      @project.repository.destroy
      get :new, :project_id => 'subproject1', :repository_scm => 'Filesystem'
      assert_response :success
      assert_template 'new'
      assert_kind_of Repository::Filesystem, assigns(:repository)
      assert assigns(:repository).new_record?
    end

    def test_browse_root
      @repository.fetch_changesets
      @repository.reload
      get :show, :id => PRJ_ID
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert assigns(:entries).size > 0
      assert_not_nil assigns(:changesets)
      assert assigns(:changesets).size == 0

      assert_no_tag 'input', :attributes => {:name => 'rev'}
      assert_no_tag 'a', :content => 'Statistics'
      assert_no_tag 'a', :content => 'Atom'
    end

    def test_show_no_extension
      get :entry, :id => PRJ_ID, :path => repository_path_hash(['test'])[:param]
      assert_response :success
      assert_template 'entry'
      assert_tag :tag => 'th',
                 :content => '1',
                 :attributes => { :class => 'line-num' },
                 :sibling => { :tag => 'td', :content => /TEST CAT/ }
    end

    def test_entry_download_no_extension
      get :raw, :id => PRJ_ID, :path => repository_path_hash(['test'])[:param]
      assert_response :success
      assert_equal 'application/octet-stream', @response.content_type
    end

    def test_show_non_ascii_contents
      with_settings :repositories_encodings => 'UTF-8,EUC-JP' do
        get :entry, :id => PRJ_ID,
            :path => repository_path_hash(['japanese', 'euc-jp.txt'])[:param]
        assert_response :success
        assert_template 'entry'
        assert_tag :tag => 'th',
                   :content => '2',
                   :attributes => { :class => 'line-num' },
                   :sibling => { :tag => 'td', :content => /japanese/ }
        if @ruby19_non_utf8_pass
          puts "TODO: show repository file contents test fails in Ruby 1.9 " +
               "and Encoding.default_external is not UTF-8. " +
               "Current value is '#{Encoding.default_external.to_s}'"
        else
          str_japanese = "\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e"
          str_japanese.force_encoding('UTF-8') if str_japanese.respond_to?(:force_encoding)
          assert_tag :tag => 'th',
                     :content => '3',
                     :attributes => { :class => 'line-num' },
                     :sibling => { :tag => 'td', :content => /#{str_japanese}/ }
        end
      end
    end

    def test_show_utf16
      enc = (RUBY_VERSION == "1.9.2" ? 'UTF-16LE' : 'UTF-16')
      with_settings :repositories_encodings => enc do
        get :entry, :id => PRJ_ID,
            :path => repository_path_hash(['japanese', 'utf-16.txt'])[:param]
        assert_response :success
        assert_tag :tag => 'th',
                   :content => '2',
                   :attributes => { :class => 'line-num' },
                   :sibling => { :tag => 'td', :content => /japanese/ }
      end
    end

    def test_show_text_file_should_send_if_too_big
      with_settings :file_max_size_displayed => 1 do
        get :entry, :id => PRJ_ID,
            :path => repository_path_hash(['japanese', 'big-file.txt'])[:param]
        assert_response :success
        assert_equal 'text/plain', @response.content_type
      end
    end

    def test_destroy_valid_repository
      @request.session[:user_id] = 1 # admin

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
      @repository = Repository::Filesystem.create!(
                      :project       => @project,
                      :url           => "/invalid",
                      :path_encoding => ''
                      )

      assert_difference 'Repository.count', -1 do
        delete :destroy, :id => @repository.id
      end
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end
  else
    puts "Filesystem test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
