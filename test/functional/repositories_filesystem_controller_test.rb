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

class RepositoriesFilesystemControllerTest < Redmine::RepositoryControllerTest
  tests RepositoriesController

  REPOSITORY_PATH = Rails.root.join('tmp/test/filesystem_repository').to_s
  PRJ_ID = 3

  def setup
    super
    @ruby19_non_utf8_pass = Encoding.default_external.to_s != 'UTF-8'
    User.current = nil
    Setting.enabled_scm << 'Filesystem' unless Setting.enabled_scm.include?('Filesystem')
    @project = Project.find(PRJ_ID)
    @repository =
      Repository::Filesystem.create(
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
      get(
        :new,
        :params => {
          :project_id => 'subproject1',
          :repository_scm => 'Filesystem'
        }
      )
      assert_response :success
      assert_select 'select[name=?]', 'repository_scm' do
        assert_select 'option[value=?][selected=selected]', 'Filesystem'
      end
    end

    def test_browse_root
      @repository.fetch_changesets
      @repository.reload
      get(
        :show,
        :params => {
          :id => PRJ_ID
        }
      )
      assert_response :success

      assert_select 'table.entries tbody' do
        assert_select 'tr', 3
        assert_select 'tr.dir td.filename a', :text => 'dir'
        assert_select 'tr.dir td.filename a', :text => 'japanese'
        assert_select 'tr.file td.filename a', :text => 'test'
      end

      assert_select 'table.changesets tbody', 0

      assert_select 'input[name=rev]', 0
      assert_select 'a', :text => 'Statistics', :count => 0
      assert_select 'a', :text => 'Atom', :count => 0
    end

    def test_show_no_extension
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['test'])[:param]
        }
      )
      assert_response :success
      assert_select 'tr#L1 td.line-code', :text => /TEST CAT/
    end

    def test_entry_download_no_extension
      get(
        :raw,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['test'])[:param]
        }
      )
      assert_response :success
      assert_equal 'application/octet-stream', @response.media_type
    end

    def test_show_non_ascii_contents
      with_settings :repositories_encodings => 'UTF-8,EUC-JP' do
        get(
          :entry,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['japanese', 'euc-jp.txt'])[:param]
          }
        )
        assert_response :success
        assert_select 'tr#L2 td.line-code', :text => /japanese/
        if @ruby19_non_utf8_pass
          puts "TODO: show repository file contents test fails " \
               "when Encoding.default_external is not UTF-8. " \
               "Current value is '#{Encoding.default_external}'"
        else
          assert_select 'tr#L3 td.line-code', :text => /日本語/
        end
      end
    end

    def test_show_utf16
      enc = 'UTF-16'
      with_settings :repositories_encodings => enc do
        get(
          :entry,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['japanese', 'utf-16.txt'])[:param]
          }
        )
        assert_response :success
        assert_select 'tr#L2 td.line-code', :text => /japanese/
      end
    end

    def test_show_text_file_should_show_other_if_too_big
      with_settings :file_max_size_displayed => 1 do
        get(
          :entry,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['japanese', 'big-file.txt'])[:param]
          }
        )
        assert_response :success
        assert_equal 'text/html', @response.media_type
        assert_select 'p.nodata'
      end
    end

    def test_destroy_valid_repository
      @request.session[:user_id] = 1 # admin

      assert_difference 'Repository.count', -1 do
        delete(
          :destroy,
          :params => {
            :id => @repository.id
          }
        )
      end
      assert_response :found
      @project.reload
      assert_nil @project.repository
    end

    def test_destroy_invalid_repository
      @request.session[:user_id] = 1 # admin
      @project.repository.destroy
      @repository =
        Repository::Filesystem.create!(
          :project       => @project,
          :url           => "/invalid",
          :path_encoding => ''
        )
      assert_difference 'Repository.count', -1 do
        delete(
          :destroy,
          :params => {
            :id => @repository.id
          }
        )
      end
      assert_response :found
      @project.reload
      assert_nil @project.repository
    end

    def test_show_should_only_show_view_tab
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['test'])[:param]
        }
      )
      assert_response :success
      assert @repository.supports_cat?
      assert_select 'a#tab-entry', :text => /View/
      assert_not @repository.supports_history?
      assert_select 'a#tab-changes', 0
      assert_not @repository.supports_annotate?
      assert_select 'a#tab-annotate', 0
    end
  else
    puts "Filesystem test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
