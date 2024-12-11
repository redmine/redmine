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

class RepositoriesBazaarControllerTest < Redmine::RepositoryControllerTest
  tests RepositoriesController

  REPOSITORY_PATH = Rails.root.join('tmp/test/bazaar_repository').to_s
  REPOSITORY_PATH_TRUNK = File.join(REPOSITORY_PATH, "trunk")
  PRJ_ID = 3

  def setup
    super
    User.current = nil
    @project = Project.find(PRJ_ID)
    @repository =
      Repository::Bazaar.create(
        :project      => @project,
        :url          => REPOSITORY_PATH_TRUNK,
        :log_encoding => 'UTF-8'
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
          :repository_scm => 'Bazaar'
        }
      )
      assert_response :success
      assert_select 'select[name=?]', 'repository_scm' do
        assert_select 'option[value=?][selected=selected]', 'Bazaar'
      end
    end

    def test_browse_root
      get(
        :show,
        :params => {
          :id => PRJ_ID
        }
      )
      assert_response :success
      assert_select 'table.entries tbody' do
        assert_select 'tr', 2
        assert_select 'tr.dir td.filename a', :text => 'directory'
        assert_select 'tr.file td.filename a', :text => 'doc-mkdir.txt'
      end
    end

    def test_browse_directory
      get(
        :show,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['directory'])[:param]
        }
      )
      assert_response :success
      assert_select 'table.entries tbody' do
        assert_select 'tr', 3
        assert_select 'tr.file td.filename a', :text => 'doc-ls.txt'
        assert_select 'tr.file td.filename a', :text => 'document.txt'
        assert_select 'tr.file td.filename a', :text => 'edit.png'
      end
    end

    def test_browse_at_given_revision
      get(
        :show,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash([])[:param],
          :rev => 3
        }
      )
      assert_response :success
      assert_select 'table.entries tbody' do
        assert_select 'tr', 4
        assert_select 'tr.dir td.filename a', :text => 'directory'
        assert_select 'tr.file td.filename a', :text => 'doc-deleted.txt'
        assert_select 'tr.file td.filename a', :text => 'doc-ls.txt'
        assert_select 'tr.file td.filename a', :text => 'doc-mkdir.txt'
      end
    end

    def test_changes
      get(
        :changes,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['doc-mkdir.txt'])[:param]
        }
      )
      assert_response :success
      assert_select 'h2', :text => /doc-mkdir.txt/
    end

    def test_entry_show
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['directory', 'doc-ls.txt'])[:param]
        }
      )
      assert_response :success
      # Line 19
      assert_select 'tr#L29 td.line-code', :text => /Show help message/
    end

    def test_entry_download
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['directory', 'doc-ls.txt'])[:param],
          :format => 'raw'
        }
      )
      assert_response :success
      # File content
      assert @response.body.include?('Show help message')
    end

    def test_directory_entry
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['directory'])[:param]
        }
      )
      assert_response :success
      assert_select 'table.entries tbody'
    end

    def test_diff
      # Full diff of changeset 3
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
        # Line 11 removed
        assert_select 'th.line-num[data-txt=11] ~ td.diff_out', :text => /Display more information/
      end
    end

    def test_annotate
      get(
        :annotate,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['doc-mkdir.txt'])[:param]
        }
      )
      assert_response :success

      assert_select "th.line-num" do
        assert_select 'a[data-txt=?]', '2'
        assert_select "+ td.revision" do
          assert_select "a", :text => '3'
          assert_select "+ td.author", :text => "jsmith@" do
            assert_select "+ td",
                          :text => "Main purpose:"
          end
        end
      end
    end

    def test_annotate_author_escaping
      repository =
        Repository::Bazaar.create(
          :project      => @project,
          :url          => File.join(REPOSITORY_PATH, "author_escaping"),
          :identifier => 'author_escaping',
          :log_encoding => 'UTF-8'
        )
      assert repository
      get(
        :annotate,
        :params => {
          :id => PRJ_ID,
          :repository_id => 'author_escaping',
          :path => repository_path_hash(['author-escaping-test.txt'])[:param]
        }
      )
      assert_response :success

      assert_select "th.line-num" do
        assert_select "a[data-txt=?]", '1'
        assert_select "+ td.revision" do
          assert_select "a", :text => '2'
          assert_select "+ td.author", :text => "test &" do
            assert_select "+ td",
                          :text => "author escaping test"
          end
        end
      end
    end

    def test_annotate_author_non_ascii
      log_encoding = nil
      if Encoding.locale_charmap == "UTF-8" ||
           Encoding.locale_charmap == "ISO-8859-1"
        log_encoding = Encoding.locale_charmap
      end
      unless log_encoding.nil?
        repository =
          Repository::Bazaar.create(
            :project      => @project,
            :url          => File.join(REPOSITORY_PATH, "author_non_ascii"),
            :identifier => 'author_non_ascii',
            :log_encoding => log_encoding
          )
        assert repository
        get(
          :annotate,
          :params => {
            :id => PRJ_ID,
            :repository_id => 'author_non_ascii',
            :path => repository_path_hash(['author-non-ascii-test.txt'])[:param]
          }
        )
        assert_response :success

        assert_select "th.line-num" do
          assert_select 'a[data-txt=?]', '1'
          assert_select "+ td.revision" do
            assert_select "a", :text => '2'
            assert_select "+ td.author", :text => "test Ü" do
              assert_select "+ td",
                            :text => "author non ASCII test"
            end
          end
        end
      end
    end

    def test_destroy_valid_repository
      @request.session[:user_id] = 1 # admin
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      assert @repository.changesets.count > 0

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
        Repository::Bazaar.create!(
          :project      => @project,
          :url          => "/invalid",
          :log_encoding => 'UTF-8'
        )
      @repository.fetch_changesets
      @repository.reload
      assert_equal 0, @repository.changesets.count

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
  else
    puts "Bazaar test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
