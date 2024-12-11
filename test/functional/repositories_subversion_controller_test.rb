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

class RepositoriesSubversionControllerTest < Redmine::RepositoryControllerTest
  tests RepositoriesController

  PRJ_ID = 3
  NUM_REV = 16

  def setup
    super
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
      get(
        :new,
        :params => {
          :project_id => 'subproject1',
          :repository_scm => 'Subversion'
        }
      )
      assert_response :success
      assert_select 'select[name=?]', 'repository_scm' do
        assert_select 'option[value=?][selected=selected]', 'Subversion'
      end
    end

    def test_show
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :show,
        :params => {
          :id => PRJ_ID
        }
      )
      assert_response :success

      assert_select 'table.entries tbody' do
        assert_select 'tr', 1
        assert_select 'tr.dir td.filename a', :text => 'subversion_test'
        assert_select 'tr.dir td.filename a[href=?]', "/projects/subproject1/repository/#{@repository.id}/show/subversion_test"
      end

      assert_select 'table.changesets tbody' do
        assert_select 'tr', 10
        assert_select 'tr td.id a', :text => '12'
      end

      assert_select 'input[name=rev]'
      assert_select 'a', :text => 'Statistics'
      assert_select 'a', :text => 'Atom'
      assert_select 'a[href=?]', "/projects/subproject1/repository/#{@repository.id}", :text => 'root'
    end

    def test_show_non_default
      Repository::Subversion.create(:project => @project,
        :url => self.class.subversion_repository_url,
        :is_default => false, :identifier => 'svn')
      get(
        :show,
        :params => {
          :id => PRJ_ID,
          :repository_id => 'svn'
        }
      )
      assert_response :success

      assert_select 'tr.dir a[href="/projects/subproject1/repository/svn/show/subversion_test"]'
      # Repository menu should link to the main repo
      assert_select '#main-menu a[href="/projects/subproject1/repository"]'
    end

    def test_browse_directory
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :show,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test'])[:param]
        }
      )
      assert_response :success

      assert_select 'table.entries tbody' do
        assert_select 'tr', 7
        assert_select 'tr.dir td.filename a', :text => '[folder_with_brackets]'
        assert_select 'tr.dir td.filename a', :text => 'folder'
        assert_select 'tr.file td.filename a', :text => '+.md'
        assert_select 'tr.file td.filename a', :text => '.project'
        assert_select 'tr.file td.filename a', :text => 'helloworld.c'
        assert_select 'tr.file td.filename a', :text => 'textfile.txt'
        assert_select 'tr.file td.filename a', :text => 'foo.js'
      end

      assert_select 'a.text-x-c', :text => 'helloworld.c'
    end

    def test_browse_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :show,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test'])[:param],
          :rev => 4
        }
      )
      assert_response :success

      assert_select 'table.entries tbody' do
        assert_select 'tr', 5
        assert_select 'tr.dir td.filename a', :text => 'folder'
        assert_select 'tr.file td.filename a', :text => '.project'
        assert_select 'tr.file td.filename a', :text => 'helloworld.c'
        assert_select 'tr.file td.filename a', :text => 'helloworld.rb'
        assert_select 'tr.file td.filename a', :text => 'textfile.txt'
      end
    end

    def test_file_changes
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :changes,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'folder', 'helloworld.rb'])[:param]
        }
      )
      assert_response :success

      assert_select 'table.changesets tbody' do
        assert_select 'tr', 3
        assert_select 'tr td.id a', :text => '6'
        assert_select 'tr td.id a', :text => '3'
        assert_select 'tr td.id a', :text => '2'
      end

      # svn properties displayed with svn >= 1.5 only
      if Redmine::Scm::Adapters::SubversionAdapter.client_version_above?([1, 5, 0])
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
      get(
        :changes,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'folder'])[:param]
        }
      )
      assert_response :success
      assert_select 'table.changesets tbody' do
        assert_select 'tr', 8
        assert_select 'tr td.id a', :text => '13'
        assert_select 'tr td.id a', :text => '12'
        assert_select 'tr td.id a', :text => '10'
        assert_select 'tr td.id a', :text => '9'
        assert_select 'tr td.id a', :text => '7'
        assert_select 'tr td.id a', :text => '6'
        assert_select 'tr td.id a', :text => '5'
        assert_select 'tr td.id a', :text => '2'
      end
    end

    def test_entry
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'helloworld.c'])[:param]
        }
      )
      assert_response :success
      assert_select 'h2 a', :text => 'subversion_test'
      assert_select 'h2 a', :text => 'helloworld.c'
    end

    def test_entry_should_show_other_if_too_big
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      # no files in the test repo is larger than 1KB...
      with_settings :file_max_size_displayed => 0 do
        get(
          :entry,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['subversion_test', 'helloworld.c'])[:param]
          }
        )
        assert_response :success
        assert_equal 'text/html', @response.media_type
        assert_select 'p.nodata'
      end
    end

    def test_entry_should_display_images
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'folder', 'subfolder', 'rubylogo.gif'])[:param]
        }
      )
      assert_response :success
      assert_select 'img[src=?]', "/projects/subproject1/repository/#{@repository.id}/raw/subversion_test/folder/subfolder/rubylogo.gif"
    end

    def test_entry_should_preview_audio
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'folder', 'subfolder', 'chords.mp3'])[:param]
        }
      )
      assert_response :success
      assert_select 'audio[src=?]', "/projects/subproject1/repository/#{@repository.id}/raw/subversion_test/folder/subfolder/chords.mp3"
    end

    def text_entry_should_preview_markdown
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'folder', 'subfolder', 'testfile.md'])[:param]
        }
      )
      assert_response :success
      assert_select 'div.wiki', :html => "<h1>Header 1</h1>\n\n<h2>Header 2</h2>\n\n<h3>Header 3</h3>"
    end

    def text_entry_should_preview_textile
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'folder', 'subfolder', 'testfile.textile'])[:param]
        }
      )
      assert_response :success
      assert_select 'div.wiki', :html => "<h1>Header 1</h1>\n\n\n\t<h2>Header 2</h2>\n\n\n\t<h3>Header 3</h3>"
    end

    def test_entry_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'helloworld.rb'])[:param],
          :rev => 2
        }
      )
      assert_response :success
      # this line was removed in r3 and file was moved in r6
      assert_select 'td.line-code', :text => /Here's the code/
    end

    def test_entry_not_found
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'zzz.c'])[:param]
        }
      )
      assert_select 'p#errorExplanation', :text => /The entry or revision was not found in the repository/
    end

    def test_entry_download
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :raw,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'helloworld.c'])[:param]
        }
      )
      assert_response :success
      assert_equal "attachment; filename=\"helloworld.c\"; filename*=UTF-8''helloworld.c", @response.headers['Content-Disposition']
    end

    def test_directory_entry
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'folder'])[:param]
        }
      )
      assert_response :success
      assert_select 'h2 a', :text => 'subversion_test'
      assert_select 'h2 a', :text => 'folder'
    end

    # TODO: this test needs fixtures.
    def test_revision
      get(
        :revision,
        :params => {
          :id => 1,
          :repository_id => 10,
          :rev => 2
        }
      )
      assert_response :success

      assert_select 'ul' do
        assert_select 'li' do
          # link to the entry at rev 2
          assert_select 'a[href=?]', '/projects/ecookbook/repository/10/revisions/2/entry/test/some/path/in/the/repo', :text => 'repo'
          # link to partial diff
          assert_select 'a[href=?]', '/projects/ecookbook/repository/10/revisions/2/diff/test/some/path/in/the/repo'
        end
      end
    end

    def test_invalid_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :revision,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :rev => 'something_weird'
        }
      )
      assert_response :not_found
      assert_select_error /was not found/
    end

    def test_invalid_revision_diff
      get(
        :diff,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :rev => '1',
          :rev_to => 'something_weird'
        }
      )
      assert_response :not_found
      assert_select_error /was not found/
    end

    def test_empty_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['', ' ', nil].each do |r|
        get(
          :revision,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :rev => r
          }
        )
        assert_response :not_found
        assert_select_error /was not found/
      end
    end

    # TODO: this test needs fixtures.
    def test_revision_with_repository_pointing_to_a_subdirectory
      r = Project.find(1).repository
      # Changes repository url to a subdirectory
      r.update_attribute :url, (r.url + '/test/some')
      get(
        :revision,
        :params => {
          :id => 1,
          :repository_id => 10,
          :rev => 2
        }
      )
      assert_response :success

      assert_select 'ul' do
        assert_select 'li' do
          # link to the entry at rev 2
          assert_select 'a[href=?]', '/projects/ecookbook/repository/10/revisions/2/entry/path/in/the/repo', :text => 'repo'
          # link to partial diff
          assert_select 'a[href=?]', '/projects/ecookbook/repository/10/revisions/2/diff/path/in/the/repo'
        end
      end
    end

    def test_revision_diff
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['inline', 'sbs'].each do |dt|
        get(
          :diff,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :rev => 3,
            :type => dt
          }
        )
        assert_response :success
        assert_select 'h2', :text => /Revision 3/
        assert_select 'th.filename', :text => 'subversion_test/textfile.txt'
      end
    end

    def test_revision_diff_raw_format
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :diff,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :rev => 5,
          :format => 'diff'
        }
      )
      assert_response :success
      assert_equal 'text/x-patch', @response.media_type
      assert_equal 'Index: subversion_test/folder/greeter.rb', @response.body.split(/\r?\n/).first
    end

    def test_directory_diff
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['inline', 'sbs'].each do |dt|
        get(
          :diff,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :rev => 6,
            :rev_to => 2,
            :path => repository_path_hash(['subversion_test', 'folder'])[:param],
            :type => dt
          }
        )
        assert_response :success

        assert_select 'h2', :text => /2:6/
        # 2 files modified
        assert_select 'table.filecontent', 2
        assert_select 'table.filecontent thead th.filename', :text => 'greeter.rb'
        assert_select 'table.filecontent thead th.filename', :text => 'helloworld.rb'
      end
    end

    def test_annotate
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :annotate,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['subversion_test', 'helloworld.c'])[:param]
        }
      )
      assert_response :success

      assert_select 'tr' do
        assert_select 'th.line-num a[data-txt=?]', '1'
        assert_select 'td.revision', :text => '4'
        assert_select 'td.author', :text => 'jp'
        assert_select 'td', :text => /stdio.h/
      end
      # Same revision
      assert_select 'tr' do
        assert_select 'th.line-num a[data-txt=?]', '2'
        assert_select 'td.revision', :text => ''
        assert_select 'td.author', :text => ''
      end
    end

    def test_annotate_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :annotate,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :rev => 8,
          :path => repository_path_hash(['subversion_test', 'helloworld.c'])[:param]
        }
      )
      assert_response :success
      assert_select 'h2', :text => /@ 8/
    end

    def test_destroy_valid_repository
      @request.session[:user_id] = 1 # admin
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      assert_equal NUM_REV, @repository.changesets.count

      assert_difference 'Repository.count', -1 do
        delete(:destroy, :params => {:id => @repository.id})
      end
      assert_response :found
      @project.reload
      assert_nil @project.repository
    end

    def test_destroy_invalid_repository
      @request.session[:user_id] = 1 # admin
      @project.repository.destroy
      @repository =
        Repository::Subversion.
          create!(
            :project => @project,
            :url     => "file:///invalid"
          )
      @repository.fetch_changesets
      assert_equal 0, @repository.changesets.count

      assert_difference 'Repository.count', -1 do
        delete(:destroy, :params => {:id => @repository.id})
      end
      assert_response :found
      @project.reload
      assert_nil @project.repository
    end
  else
    puts "Subversion test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
