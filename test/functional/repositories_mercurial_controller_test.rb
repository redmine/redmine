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

class RepositoriesMercurialControllerTest < Redmine::RepositoryControllerTest
  tests RepositoriesController

  REPOSITORY_PATH = Rails.root.join('tmp/test/mercurial_repository').to_s
  PRJ_ID     = 3
  NUM_REV    = 43

  def setup
    super
    User.current = nil
    @project    = Project.find(PRJ_ID)
    @repository =
      Repository::Mercurial.create(
        :project => @project,
        :url     => REPOSITORY_PATH,
        :path_encoding => 'ISO-8859-1'
      )
    assert @repository
    @diff_c_support = true
  end

  if Encoding.default_external.to_s != 'UTF-8'
    puts "TODO: Mercurial functional test fails " \
         "when Encoding.default_external is not UTF-8. " \
         "Current value is '#{Encoding.default_external}'"
    def test_fake; assert true end
  elsif File.directory?(REPOSITORY_PATH)

    def test_get_new
      @request.session[:user_id] = 1
      @project.repository.destroy
      get(
        :new,
        :params => {
          :project_id => 'subproject1',
          :repository_scm => 'Mercurial'
        }
      )
      assert_response :success
      assert_select 'select[name=?]', 'repository_scm' do
        assert_select 'option[value=?][selected=selected]', 'Mercurial'
      end
    end

    def test_show_root
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
        assert_select 'tr', 4
        assert_select 'tr.dir td.filename a', :text => 'images'
        assert_select 'tr.dir td.filename a', :text => 'sources'
        assert_select 'tr.file td.filename a', :text => '.hgtags'
        assert_select 'tr.file td.filename a', :text => 'README'
      end

      assert_select 'table.changesets tbody' do
        assert_select 'tr'
      end
    end

    def test_show_directory
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :show,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['images'])[:param]
        }
      )
      assert_response :success

      assert_select 'table.entries tbody' do
        assert_select 'tr', 2
        assert_select 'tr.file td.filename a', :text => 'delete.png'
        assert_select 'tr.file td.filename a', :text => 'edit.png'
      end

      assert_select 'table.changesets tbody' do
        assert_select 'tr'
      end
    end

    def test_show_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [0, '0', '0885933ad4f6'].each do |r1|
        get(
          :show,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['images'])[:param],
            :rev => r1
          }
        )
        assert_response :success

        assert_select 'table.entries tbody' do
          assert_select 'tr', 1
          assert_select 'tr.file td.filename a', :text => 'delete.png'
        end

        assert_select 'table.changesets tbody' do
          assert_select 'tr'
        end
      end
    end

    def test_show_directory_sql_escape_percent
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [13, '13', '3a330eb32958'].each do |r1|
        get(
          :show,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['sql_escape', 'percent%dir'])[:param],
            :rev => r1
          }
        )
        assert_response :success

        assert_select 'table.entries tbody' do
          assert_select 'tr', 2
          assert_select 'tr.file td.filename a', :text => 'percent%file1.txt'
          assert_select 'tr.file td.filename a', :text => 'percentfile1.txt'
        end

        assert_select 'table.changesets tbody' do
          assert_select 'tr td.id a', :text => /^13:/
          assert_select 'tr td.id a', :text => /^11:/
          assert_select 'tr td.id a', :text => /^10:/
          assert_select 'tr td.id a', :text => /^9:/
        end
      end
    end

    def test_show_directory_latin_1_path
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [21, '21', 'adf805632193'].each do |r1|
        get(
          :show,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['latin-1-dir'])[:param],
            :rev => r1
          }
        )
        assert_response :success

        assert_select 'table.entries tbody' do
          assert_select 'tr', 4
          assert_select 'tr.file td.filename a', :text => "make-latin-1-file.rb"
          assert_select 'tr.file td.filename a', :text => "test-Ü-1.txt"
          assert_select 'tr.file td.filename a', :text => "test-Ü-2.txt"
          assert_select 'tr.file td.filename a', :text => "test-Ü.txt"
        end

        assert_select 'table.changesets tbody' do
          assert_select 'tr td.id a', :text => /^21:/
          assert_select 'tr td.id a', :text => /^20:/
          assert_select 'tr td.id a', :text => /^19:/
          assert_select 'tr td.id a', :text => /^18:/
          assert_select 'tr td.id a', :text => /^17:/
        end
      end
    end

    def show_should_show_branch_selection_form
      @repository.fetch_changesets
      @project.reload
      get(
        :show,
        :params => {
          :id => PRJ_ID
        }
      )
      assert_select 'form#revision_selector[action=?]', '/projects/subproject1/repository/show' do
        assert_select 'select[name=branch]' do
          assert_select 'option[value=?]', 'test-branch-01'
        end
      end
    end

    def test_show_branch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [
        'default',
        'branch-Ü-01',
        'branch (1)[2]&,%.-3_4',
        'branch-Ü-00',
        'test_branch.latin-1',
        'test-branch-00',
      ].each do |bra|
        get(
          :show,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :rev => bra
          }
        )
        assert_response :success

        assert_select 'table.entries tbody tr'
        assert_select 'table.changesets tbody tr'
      end
    end

    def test_show_tag
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [
        'tag-Ü-00',
        'tag_test.00',
        'tag-init-revision'
      ].each do |tag|
        get(
          :show,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :rev => tag
          }
        )
        assert_response :success

        assert_select 'table.entries tbody tr'
        assert_select 'table.changesets tbody tr'
      end
    end

    def test_changes
      get(
        :changes,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['images', 'edit.png'])[:param]
        }
      )
      assert_response :success
      assert_select 'h2', :text => /edit.png/
    end

    def test_entry_show
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
        }
      )
      assert_response :success
      # Line 10
      assert_select 'tr#L10 td.line-code', :text => /WITHOUT ANY WARRANTY/
    end

    def test_entry_show_latin_1_path
      [21, '21', 'adf805632193'].each do |r1|
        get(
          :entry,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['latin-1-dir', "test-Ü-2.txt"])[:param],
            :rev => r1
          }
        )
        assert_response :success
        assert_select 'tr#L1 td.line-code', :text => /Mercurial is a distributed version control system/
      end
    end

    def test_entry_show_latin_1_contents
      with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
        [27, '27', '7bbf4c738e71'].each do |r1|
          get(
            :entry,
            :params => {
              :id => PRJ_ID,
              :repository_id => @repository.id,
              :path => repository_path_hash(['latin-1-dir', "test-Ü.txt"])[:param],
              :rev => r1
            }
          )
          assert_response :success
          assert_select 'tr#L1 td.line-code', :text => /test-Ü.txt/
        end
      end
    end

    def test_entry_download
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param],
          :format => 'raw'
        }
      )
      assert_response :success
      # File content
      assert @response.body.include?('WITHOUT ANY WARRANTY')
    end

    def test_entry_binary_force_download
      # TODO: add a binary file which is not an image to the test repo
    end

    def test_directory_entry
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['sources'])[:param]
        }
      )
      assert_response :success
      assert_select 'h2 a', :text => 'sources'
      assert_select 'table.entries tbody'
    end

    def test_diff
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [4, '4', 'def6d2f1254a'].each do |r1|
        # Full diff of changeset 4
        ['inline', 'sbs'].each do |dt|
          get(
            :diff,
            :params => {
              :id => PRJ_ID,
              :repository_id => @repository.id,
              :rev => r1,
              :type => dt
            }
          )
          assert_response :success
          if @diff_c_support
            # Line 22 removed
            assert_select 'th.line-num[data-txt=22] ~ td.diff_out', :text => /def remove/
            assert_select 'h2', :text => /4:def6d2f1254a/
          end
        end
      end
    end

    def test_diff_two_revs
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [2, '400bb8672109', '400', 400].each do |r1|
        [4, 'def6d2f1254a'].each do |r2|
          ['inline', 'sbs'].each do |dt|
            get(
              :diff,
              :params => {
                :id     => PRJ_ID,
                :repository_id => @repository.id,
                :rev    => r1,
                :rev_to => r2,
                :type => dt
              }
            )
            assert_response :success
            assert_select 'h2', :text => /4:def6d2f1254a 2:400bb8672109/
          end
        end
      end
    end

    def test_diff_latin_1_path
      with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
        [21, 'adf805632193'].each do |r1|
          ['inline', 'sbs'].each do |dt|
            get(
              :diff,
              :params => {
                :id => PRJ_ID,
                :repository_id => @repository.id,
                :rev => r1,
                :type => dt
              }
            )
            assert_response :success
            assert_select 'table' do
              assert_select 'thead th.filename', :text => /latin-1-dir\/test-Ü-2.txt/
              assert_select 'tbody td.diff_in', :text => /It is written in Python/
            end
          end
        end
      end
    end

    def test_diff_should_show_modified_filenames
      get(
        :diff,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :rev => '400bb8672109',
          :type => 'inline'
        }
      )
      assert_response :success
      assert_select 'th.filename', :text => 'sources/watchers_controller.rb'
    end

    def test_diff_should_show_deleted_filenames
      get(
        :diff,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :rev => 'b3a615152df8',
          :type => 'inline'
        }
      )
      assert_response :success
      assert_select 'th.filename', :text => 'sources/welcome_controller.rb'
    end

    def test_annotate
      get(
        :annotate,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
        }
      )
      assert_response :success

      # Line 22, revision 4:def6d2f1254a
      assert_select 'tr' do
        assert_select 'th.line-num a[data-txt=?]', '22'
        assert_select 'td.revision', :text => '4:def6d2f1254a'
        assert_select 'td.author', :text => 'jsmith'
        assert_select 'td', :text => /remove_watcher/
      end
    end

    def test_annotate_not_in_tip
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :annotate,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['sources', 'welcome_controller.rb'])[:param]
        }
      )
      assert_response :not_found
      assert_select_error /was not found/
    end

    def test_annotate_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [2, '400bb8672109', '400', 400].each do |r1|
        get(
          :annotate,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :rev => r1,
            :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
          }
        )
        assert_response :success
        assert_select 'h2', :text => /@ 2:400bb8672109/
      end
    end

    def test_annotate_latin_1_path
      [21, '21', 'adf805632193'].each do |r1|
        get(
          :annotate,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['latin-1-dir', "test-Ü-2.txt"])[:param],
            :rev => r1
          }
        )
        assert_response :success
        assert_select "th.line-num" do
          assert_select "a[data-txt=?]", '1'
          assert_select "+ td.revision" do
            assert_select "a", :text => '20:709858aafd1b'
            assert_select "+ td.author", :text => "jsmith" do
              assert_select "+ td",
                            :text => "Mercurial is a distributed version control system."
            end
          end
        end
      end
    end

    def test_annotate_latin_1_contents
      with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
        [27, '7bbf4c738e71'].each do |r1|
          get(
            :annotate,
            :params => {
              :id => PRJ_ID,
              :repository_id => @repository.id,
              :path => repository_path_hash(['latin-1-dir', "test-Ü.txt"])[:param],
              :rev => r1
            }
          )
          assert_select 'tr#L1 td.line-code', :text => /test-Ü.txt/
        end
      end
    end

    def test_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['1', '9d5b5b', '9d5b5b004199'].each do |r|
        with_settings :default_language => "en" do
          get(
            :revision,
            :params => {
              :id => PRJ_ID,
              :repository_id => @repository.id,
              :rev => r
            }
          )
          assert_response :success
          assert_select 'title',
                        :text => 'Revision 1:9d5b5b004199 - Added 2 files and modified one. - eCookbook Subproject 1 - Redmine'
        end
      end
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

    def test_destroy_valid_repository
      @request.session[:user_id] = 1 # admin
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      assert_equal NUM_REV, @repository.changesets.count

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
        Repository::Mercurial.create!(
          :project => Project.find(PRJ_ID),
          :url     => "/invalid",
          :path_encoding => 'ISO-8859-1'
        )
      @repository.fetch_changesets
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
    puts "Mercurial test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
