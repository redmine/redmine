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

class RepositoriesSubversionControllerTest < ActionController::TestCase
  tests RepositoriesController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles, :enabled_modules,
           :repositories, :issues, :issue_statuses, :changesets, :changes,
           :issue_categories, :enumerations, :custom_fields, :custom_values, :trackers

  PRJ_ID = 3
  NUM_REV = 11

  def setup
    Setting.default_language = 'en'
    User.current = nil

    @project = Project.find(PRJ_ID)
    @repository = Repository::Subversion.create(:project => @project,
               :url => self.class.subversion_repository_url)
    assert @repository
  end

  if repository_configured?('subversion')
    def test_new
      @request.session[:user_id] = 1
      @project.repository.destroy
      get :new, :project_id => 'subproject1', :repository_scm => 'Subversion'
      assert_response :success
      assert_template 'new'
      assert_kind_of Repository::Subversion, assigns(:repository)
      assert assigns(:repository).new_record?
    end

    def test_show
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :show, :id => PRJ_ID
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_not_nil assigns(:changesets)

      entry = assigns(:entries).detect {|e| e.name == 'subversion_test'}
      assert_not_nil entry
      assert_equal 'dir', entry.kind
      assert_select 'tr.dir a[href="/projects/subproject1/repository/show/subversion_test"]'

      assert_select 'input[name=rev]'
      assert_select 'a', :text => 'Statistics'
      assert_select 'a', :text => 'Atom'
      assert_select 'a[href=?]', '/projects/subproject1/repository', :text => 'root'
    end

    def test_show_non_default
      Repository::Subversion.create(:project => @project,
        :url => self.class.subversion_repository_url,
        :is_default => false, :identifier => 'svn')

      get :show, :id => PRJ_ID, :repository_id => 'svn'
      assert_response :success
      assert_template 'show'
      assert_select 'tr.dir a[href="/projects/subproject1/repository/svn/show/subversion_test"]'
      # Repository menu should link to the main repo
      assert_select '#main-menu a[href="/projects/subproject1/repository"]'
    end

    def test_browse_directory
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :show, :id => PRJ_ID, :path => repository_path_hash(['subversion_test'])[:param]
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal [
           '[folder_with_brackets]', 'folder', '.project',
           'helloworld.c', 'textfile.txt'
         ],
        assigns(:entries).collect(&:name)
      entry = assigns(:entries).detect {|e| e.name == 'helloworld.c'}
      assert_equal 'file', entry.kind
      assert_equal 'subversion_test/helloworld.c', entry.path
      assert_select 'a.text-x-c', :text => 'helloworld.c'
    end

    def test_browse_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :show, :id => PRJ_ID, :path => repository_path_hash(['subversion_test'])[:param],
          :rev => 4
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ['folder', '.project', 'helloworld.c', 'helloworld.rb', 'textfile.txt'],
                   assigns(:entries).collect(&:name)
    end

    def test_file_changes
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :changes, :id => PRJ_ID,
          :path => repository_path_hash(['subversion_test', 'folder', 'helloworld.rb'])[:param]
      assert_response :success
      assert_template 'changes'

      changesets = assigns(:changesets)
      assert_not_nil changesets
      assert_equal %w(6 3 2), changesets.collect(&:revision)

      # svn properties displayed with svn >= 1.5 only
      if Redmine::Scm::Adapters::SubversionAdapter.client_version_above?([1, 5, 0])
        assert_not_nil assigns(:properties)
        assert_equal 'native', assigns(:properties)['svn:eol-style']
        assert_select 'ul li' do
          assert_select 'b', :text => 'svn:eol-style'
          assert_select 'span', :text => 'native'
        end
      end
    end

    def test_directory_changes
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :changes, :id => PRJ_ID,
          :path => repository_path_hash(['subversion_test', 'folder'])[:param]
      assert_response :success
      assert_template 'changes'

      changesets = assigns(:changesets)
      assert_not_nil changesets
      assert_equal %w(10 9 7 6 5 2), changesets.collect(&:revision)
    end

    def test_entry
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['subversion_test', 'helloworld.c'])[:param]
      assert_response :success
      assert_template 'entry'
    end

    def test_entry_should_send_if_too_big
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      # no files in the test repo is larger than 1KB...
      with_settings :file_max_size_displayed => 0 do
        get :entry, :id => PRJ_ID,
            :path => repository_path_hash(['subversion_test', 'helloworld.c'])[:param]
        assert_response :success
        assert_equal 'attachment; filename="helloworld.c"',
                     @response.headers['Content-Disposition']
      end
    end

    def test_entry_should_send_images_inline
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['subversion_test', 'folder', 'subfolder', 'rubylogo.gif'])[:param]
      assert_response :success
      assert_equal 'inline; filename="rubylogo.gif"', response.headers['Content-Disposition']
    end

    def test_entry_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['subversion_test', 'helloworld.rb'])[:param],
          :rev => 2
      assert_response :success
      assert_template 'entry'
      # this line was removed in r3 and file was moved in r6
      assert_select 'td.line-code', :text => /Here's the code/
    end

    def test_entry_not_found
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['subversion_test', 'zzz.c'])[:param]
      assert_select 'p#errorExplanation', :text => /The entry or revision was not found in the repository/
    end

    def test_entry_download
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :raw, :id => PRJ_ID,
          :path => repository_path_hash(['subversion_test', 'helloworld.c'])[:param]
      assert_response :success
      assert_equal 'attachment; filename="helloworld.c"', @response.headers['Content-Disposition']
    end

    def test_directory_entry
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['subversion_test', 'folder'])[:param]
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entry)
      assert_equal 'folder', assigns(:entry).name
    end

    # TODO: this test needs fixtures.
    def test_revision
      get :revision, :id => 1, :rev => 2
      assert_response :success
      assert_template 'revision'

      assert_select 'ul' do
        assert_select 'li' do
          # link to the entry at rev 2
          assert_select 'a[href=?]', '/projects/ecookbook/repository/revisions/2/entry/test/some/path/in/the/repo', :text => 'repo'
          # link to partial diff
          assert_select 'a[href=?]', '/projects/ecookbook/repository/revisions/2/diff/test/some/path/in/the/repo'
        end
      end
    end

    def test_invalid_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :revision, :id => PRJ_ID, :rev => 'something_weird'
      assert_response 404
      assert_select_error /was not found/
    end

    def test_invalid_revision_diff
      get :diff, :id => PRJ_ID, :rev => '1', :rev_to => 'something_weird'
      assert_response 404
      assert_select_error /was not found/
    end

    def test_empty_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['', ' ', nil].each do |r|
        get :revision, :id => PRJ_ID, :rev => r
        assert_response 404
        assert_select_error /was not found/
      end
    end

    # TODO: this test needs fixtures.
    def test_revision_with_repository_pointing_to_a_subdirectory
      r = Project.find(1).repository
      # Changes repository url to a subdirectory
      r.update_attribute :url, (r.url + '/test/some')

      get :revision, :id => 1, :rev => 2
      assert_response :success
      assert_template 'revision'

      assert_select 'ul' do
        assert_select 'li' do
          # link to the entry at rev 2
          assert_select 'a[href=?]', '/projects/ecookbook/repository/revisions/2/entry/path/in/the/repo', :text => 'repo'
          # link to partial diff
          assert_select 'a[href=?]', '/projects/ecookbook/repository/revisions/2/diff/path/in/the/repo'
        end
      end
    end

    def test_revision_diff
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['inline', 'sbs'].each do |dt|
        get :diff, :id => PRJ_ID, :rev => 3, :type => dt
        assert_response :success
        assert_template 'diff'
        assert_select 'h2', :text => /Revision 3/
        assert_select 'th.filename', :text => 'subversion_test/textfile.txt'
      end
    end

    def test_revision_diff_raw_format
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      get :diff, :id => PRJ_ID, :rev => 5, :format => 'diff'
      assert_response :success
      assert_equal 'text/x-patch', @response.content_type
      assert_equal 'Index: subversion_test/folder/greeter.rb', @response.body.split(/\r?\n/).first
    end

    def test_directory_diff
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['inline', 'sbs'].each do |dt|
        get :diff, :id => PRJ_ID, :rev => 6, :rev_to => 2,
            :path => repository_path_hash(['subversion_test', 'folder'])[:param],
            :type => dt
        assert_response :success
        assert_template 'diff'

        diff = assigns(:diff)
        assert_not_nil diff
        # 2 files modified
        assert_equal 2, Redmine::UnifiedDiff.new(diff).size
        assert_select 'h2', :text => /2:6/
      end
    end

    def test_annotate
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :annotate, :id => PRJ_ID,
          :path => repository_path_hash(['subversion_test', 'helloworld.c'])[:param]
      assert_response :success
      assert_template 'annotate'

      assert_select 'tr' do
        assert_select 'th.line-num', :text => '1'
        assert_select 'td.revision', :text => '4'
        assert_select 'td.author', :text => 'jp'
        assert_select 'td', :text => /stdio.h/
      end
      # Same revision
      assert_select 'tr' do
        assert_select 'th.line-num', :text => '2'
        assert_select 'td.revision', :text => ''
        assert_select 'td.author', :text => ''
      end
    end

    def test_annotate_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :annotate, :id => PRJ_ID, :rev => 8,
          :path => repository_path_hash(['subversion_test', 'helloworld.c'])[:param]
      assert_response :success
      assert_template 'annotate'
      assert_select 'h2', :text => /@ 8/
    end

    def test_destroy_valid_repository
      @request.session[:user_id] = 1 # admin
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
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
      @repository = Repository::Subversion.create!(
                       :project => @project,
                       :url     => "file:///invalid")
      @repository.fetch_changesets
      assert_equal 0, @repository.changesets.count

      assert_difference 'Repository.count', -1 do
        delete :destroy, :id => @repository.id
      end
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end
  else
    puts "Subversion test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
