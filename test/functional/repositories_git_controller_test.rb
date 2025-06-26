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

require File.expand_path('../../test_helper', __FILE__)

class RepositoriesGitControllerTest < Redmine::RepositoryControllerTest
  tests RepositoriesController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH = Rails.root.join('tmp/test/git_repository').to_s
  REPOSITORY_PATH.tr!('/', "\\") if Redmine::Platform.mswin?
  PRJ_ID     = 3
  NUM_REV = 29

  def setup
    super
    @not_utf8_external = Encoding.default_external.to_s != 'UTF-8'

    User.current = nil
    @project    = Project.find(PRJ_ID)
    @repository =
      Repository::Git.
        create(
          :project       => @project,
          :url           => REPOSITORY_PATH,
          :path_encoding => 'ISO-8859-1'
        )
    assert @repository
  end

  def test_create_and_update
    @request.session[:user_id] = 1
    assert_difference 'Repository.count' do
      post(
        :create,
        :params => {
          :project_id => 'subproject1',
          :repository_scm => 'Git',
          :repository => {
            :url => '/test',
            :is_default => '0',
            :identifier => 'test-create',
            :report_last_commit => '1',
          }
        }
      )
    end
    assert_response 302
    repository = Repository.order('id DESC').first
    assert_kind_of Repository::Git, repository
    assert_equal '/test', repository.url
    assert_equal true, repository.report_last_commit

    put(
      :update,
      :params => {
        :id => repository.id,
        :repository => {
          :report_last_commit => '0'
        }
      }
    )
    assert_response 302
    repo2 = Repository.find(repository.id)
    assert_equal false, repo2.report_last_commit
  end

  if File.directory?(REPOSITORY_PATH)
    ## Ruby uses ANSI api to fork a process on Windows.
    ## Japanese Shift_JIS and Traditional Chinese Big5 have 0x5c(backslash) problem
    ## and these are incompatible with ASCII.
    ## Git for Windows (msysGit) changed internal API from ANSI to Unicode in 1.7.10
    ## http://code.google.com/p/msysgit/issues/detail?id=80
    ## So, Latin-1 path tests fail on Japanese Windows
    WINDOWS_PASS = (Redmine::Platform.mswin? &&
                         Redmine::Scm::Adapters::GitAdapter.client_version_above?([1, 7, 10]))
    WINDOWS_SKIP_STR = "TODO: This test fails in Git for Windows above 1.7.10"

    def test_get_new
      @request.session[:user_id] = 1
      @project.repository.destroy
      get(
        :new,
        :params => {
          :project_id => 'subproject1',
          :repository_scm => 'Git'
        }
      )
      assert_response :success
      assert_select 'select[name=?]', 'repository_scm' do
        assert_select 'option[value=?][selected=selected]', 'Git'
      end
    end

    def test_browse_root
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      get(:show, :params => {:id => PRJ_ID})
      assert_response :success

      assert_select 'table.entries tbody' do
        assert_select 'tr', 9
        assert_select 'tr.dir td.filename_no_report a', :text => 'images'
        assert_select 'tr.dir td.filename_no_report a', :text => 'this_is_a_really_long_and_verbose_directory_name'
        assert_select 'tr.dir td.filename_no_report a', :text => 'sources'
        assert_select 'tr.file td.filename_no_report a', :text => 'README'
        assert_select 'tr.file td.filename_no_report a', :text => 'copied_README'
        assert_select 'tr.file td.filename_no_report a', :text => 'new_file.txt'
        assert_select 'tr.file td.filename_no_report a', :text => 'renamed_test.txt'
        assert_select 'tr.file td.filename_no_report a', :text => 'filemane with spaces.txt'
        assert_select 'tr.file td.filename_no_report a', :text => 'filename with a leading space.txt'
      end

      assert_select 'table.changesets tbody' do
        assert_select 'tr'
      end
    end

    def test_browse_branch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :show,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :rev => 'test_branch'
        }
      )
      assert_response :success

      assert_select 'table.entries tbody' do
        assert_select 'tr', 4
        assert_select 'tr.dir td.filename_no_report a', :text => 'images'
        assert_select 'tr.dir td.filename_no_report a', :text => 'sources'
        assert_select 'tr.file td.filename_no_report a', :text => 'README'
        assert_select 'tr.file td.filename_no_report a', :text => 'test.txt'
      end

      assert_select 'table.changesets tbody' do
        assert_select 'tr'
      end
    end

    def test_browse_tag
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [
        "tag00.lightweight",
        "tag01.annotated",
      ].each do |t1|
        get(
          :show,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :rev => t1
          }
        )
        assert_response :success

        assert_select 'table.entries tbody tr'
        assert_select 'table.changesets tbody tr'
      end
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
          :path => repository_path_hash(['images'])[:param]
        }
      )
      assert_response :success

      assert_select 'table.entries tbody' do
        assert_select 'tr', 1
        assert_select 'tr.file td.filename_no_report a', :text => 'edit.png'
      end
      assert_select 'table.changesets tbody tr'
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
          :path => repository_path_hash(['images'])[:param],
          :rev => '7234cb2750b63f47bff735edc50a1c0a433c2518'
        }
      )
      assert_response :success

      assert_select 'table.entries tbody' do
        assert_select 'tr', 1
        assert_select 'tr.file td.filename_no_report a', :text => 'delete.png'
      end
    end

    def test_browse_latin_1_dir
      if @not_utf8_external
        puts_pass_on_not_utf8
      elsif WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      else
        assert_equal 0, @repository.changesets.count
        @repository.fetch_changesets
        @project.reload
        assert_equal NUM_REV, @repository.changesets.count
        get(
          :show,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['latin-1-dir', 'test-Ü-subdir'])[:param],
            :rev => '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127'
          }
        )
        assert_response :success

        assert_select 'table.entries tbody' do
          assert_select 'tr', 3
          assert_select 'tr.file td.filename_no_report a', :text => 'test-Ü-1.txt'
          assert_select 'tr.file td.filename_no_report a', :text => 'test-Ü-2.txt'
          assert_select 'tr.file td.filename_no_report a', :text => 'test-Ü.txt'
        end
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
      # Line 11
      assert_select 'tr#L11 td.line-code', :text => /WITHOUT ANY WARRANTY/
    end

    def test_entry_show_should_render_pagination
      get(
        :entry,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :path => repository_path_hash(['README'])[:param]
        }
      )
      assert_response :success
      assert_select 'ul.pages li.next', :text => /next/i
      assert_select 'ul.pages li.previous', :text => /previous/i
    end

    def test_entry_show_latin_1
      if @not_utf8_external
        puts_pass_on_not_utf8
      elsif WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      else
        with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
          ['57ca437c', '57ca437c0acbbcb749821fdf3726a1367056d364'].each do |r1|
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
      assert_select 'div.contextual > a.icon-download', false
    end

    def test_diff
      assert_equal true, @repository.is_default
      assert @repository.identifier.blank?
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      # Full diff of changeset 2f9c0091
      ['inline', 'sbs'].each do |dt|
        get(
          :diff,
          :params => {
            :id   => PRJ_ID,
            :repository_id => @repository.id,
            :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7',
            :type => dt
          }
        )
        assert_response :success
        # Line 22 removed
        assert_select 'th.line-num[data-txt=22] ~ td.diff_out', :text => /def remove/
        assert_select 'h2', :text => /2f9c0091/
      end
    end

    def test_diff_with_rev_and_path
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      with_settings :diff_max_lines_displayed => 1000 do
        # Full diff of changeset 2f9c0091
        ['inline', 'sbs'].each do |dt|
          get(
            :diff,
            :params => {
              :id   => PRJ_ID,
              :repository_id => @repository.id,
              :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7',
              :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param],
              :type => dt
            }
          )
          assert_response :success
          # Line 22 removed
          assert_select 'th.line-num[data-txt=22] ~ td.diff_out', :text => /def remove/
          assert_select 'h2', :text => /2f9c0091/
        end
      end
    end

    def test_diff_truncated
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      with_settings :diff_max_lines_displayed => 5 do
        # Truncated diff of changeset 2f9c0091
        with_cache do
          with_settings :default_language => 'en' do
            get(
              :diff,
              :params => {
                :id   => PRJ_ID,
                :repository_id => @repository.id,
                :type => 'inline',
                :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7'
              }
            )
            assert_response :success
            assert @response.body.include?("... This diff was truncated")
          end
          with_settings :default_language => 'fr' do
            get(
              :diff,
              :params => {
                :id   => PRJ_ID,
                :repository_id => @repository.id,
                :type => 'inline',
                :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7'
              }
            )
            assert_response :success
            assert ! @response.body.include?("... This diff was truncated")
            assert @response.body.include?("... Ce diff")
          end
        end
      end
    end

    def test_diff_two_revs
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['inline', 'sbs'].each do |dt|
        get(
          :diff,
          :params => {
            :id     => PRJ_ID,
            :repository_id => @repository.id,
            :rev    => '61b685fbe55ab05b5ac68402d5720c1a6ac973d1',
            :rev_to => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7',
            :type   => dt
          }
        )
        assert_response :success
        assert_select 'h2', :text => /2f9c0091:61b685fb/
        assert_select 'form[action=?]', "/projects/subproject1/repository/#{@repository.id}/revisions/61b685fbe55ab05b5ac68402d5720c1a6ac973d1/diff"
        assert_select 'input#rev_to[type=hidden][name=rev_to][value=?]', '2f9c0091c754a91af7a9c478e36556b4bde8dcf7'
      end
    end

    def test_diff_path_in_subrepo
      repo =
        Repository::Git.
          create(
            :project       => @project,
            :url           => REPOSITORY_PATH,
            :identifier => 'test-diff-path',
            :path_encoding => 'ISO-8859-1'
          )
      assert repo
      assert_equal false, repo.is_default
      assert_equal 'test-diff-path', repo.identifier
      get(
        :diff,
        :params => {
          :id     => PRJ_ID,
          :repository_id => 'test-diff-path',
          :rev    => '61b685fbe55ab05b',
          :rev_to => '2f9c0091c754a91a',
          :type   => 'inline'
        }
      )
      assert_response :success
      assert_select 'form[action=?]', '/projects/subproject1/repository/test-diff-path/revisions/61b685fbe55ab05b/diff'
      assert_select 'input#rev_to[type=hidden][name=rev_to][value=?]', '2f9c0091c754a91a'
    end

    def test_diff_latin_1
      if @not_utf8_external
        puts_pass_on_not_utf8
      else
        with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
          ['57ca437c', '57ca437c0acbbcb749821fdf3726a1367056d364'].each do |r1|
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
                assert_select 'thead th.filename', :text => /latin-1-dir\/test-Ü.txt/
                assert_select 'tbody td.diff_in', :text => /test-Ü.txt/
              end
            end
          end
        end
      end
    end

    def test_diff_should_show_filenames
      get(
        :diff,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id,
          :rev => 'deff712f05a90d96edbd70facc47d944be5897e3',
          :type => 'inline'
        }
      )
      assert_response :success
      # modified file
      assert_select 'th.filename', :text => 'sources/watchers_controller.rb'
      # deleted file
      assert_select 'th.filename', :text => 'test.txt'
    end

    def test_save_diff_type
      user1 = User.find(1)
      user1.pref[:diff_type] = nil
      user1.preference.save
      user = User.find(1)
      assert_nil user.pref[:diff_type]

      @request.session[:user_id] = 1 # admin
      get(
        :diff,
        :params => {
          :id   => PRJ_ID,
          :repository_id => @repository.id,
          :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7'
        }
      )
      assert_response :success
      user.reload
      assert_equal "inline", user.pref[:diff_type]
      get(
        :diff,
        :params => {
          :id   => PRJ_ID,
          :repository_id => @repository.id,
          :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7',
          :type => 'sbs'
        }
      )
      assert_response :success
      user.reload
      assert_equal "sbs", user.pref[:diff_type]
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

      # Line 23, changeset 2f9c0091
      assert_select 'tr' do
        assert_select 'th.line-num a[data-txt=?]', '23'
        assert_select 'td.revision', :text => /2f9c0091/
        assert_select 'td.author', :text => 'jsmith'
        assert_select 'td', :text => /remove_watcher/
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
          :rev => 'deff7',
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
        }
      )
      assert_response :success
      assert_select 'h2', :text => /@ deff712f/
    end

    def test_annotate_binary_file
      with_settings :default_language => 'en' do
        get(
          :annotate,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['images', 'edit.png'])[:param]
          }
        )
        assert_response :success
        assert_select 'p#errorExplanation', :text => /cannot be annotated/
      end
    end

    def test_annotate_error_when_too_big
      with_settings :file_max_size_displayed => 1 do
        get(
          :annotate,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param],
            :rev => 'deff712f'
          }
        )
        assert_response :success
        assert_select 'p#errorExplanation', :text => /exceeds the maximum text file size/

        get(
          :annotate,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash(['README'])[:param],
            :rev => '7234cb2'
          }
        )
        assert_response :success
      end
    end

    def test_annotate_latin_1
      if @not_utf8_external
        puts_pass_on_not_utf8
      elsif WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      else
        with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
          ['57ca437c', '57ca437c0acbbcb749821fdf3726a1367056d364'].each do |r1|
            get(
              :annotate,
              :params => {
                :id => PRJ_ID,
                :repository_id => @repository.id,
                :path => repository_path_hash(['latin-1-dir', "test-Ü.txt"])[:param],
                :rev => r1
              }
            )
            assert_select "th.line-num" do
              assert_select "a[data-txt=?]", '1'
              assert_select "+ td.revision" do
                assert_select "a", :text => '57ca437c'
                assert_select "+ td.author", :text => "jsmith" do
                  assert_select "+ td",
                                :text => "test-Ü.txt"
                end
              end
            end
          end
        end
      end
    end

    def test_annotate_latin_1_author
      ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', '83ca5fd546063a'].each do |r1|
        get(
          :annotate,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :path => repository_path_hash([" filename with a leading space.txt "])[:param],
            :rev => r1
          }
        )
        assert_select "th.line-num" do
          assert_select "a[data-txt=?]", '1'
          assert_select "+ td.revision" do
            assert_select "a", :text => '83ca5fd5'
            assert_select "+ td.author", :text => "Felix Schäfer" do
              assert_select "+ td",
                            :text => "And this is a file with a leading and trailing space..."
            end
          end
        end
      end
    end

    def test_revisions
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get(
        :revisions,
        :params => {
          :id => PRJ_ID,
          :repository_id => @repository.id
        }
      )
      assert_select 'form[method=get][action=?]', "/projects/subproject1/repository/#{@repository.id}/revision"
    end

    def test_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['61b685fbe55ab05b5ac68402d5720c1a6ac973d1', '61b685f'].each do |r|
        get(
          :revision,
          :params => {
            :id => PRJ_ID,
            :repository_id => @repository.id,
            :rev => r
          }
        )
        assert_response :success
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
        assert_response 404
        assert_select_error /was not found/
      end
    end

    def test_destroy_valid_repository
      @request.session[:user_id] = 1 # admin
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      assert_difference 'Repository.count', -1 do
        delete(
          :destroy,
          :params => {
            :id => @repository.id
          }
        )
      end
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end

    def test_destroy_invalid_repository
      @request.session[:user_id] = 1 # admin
      @project.repository.destroy
      @repository =
        Repository::Git.
          create!(
            :project       => @project,
            :url           => "/invalid",
            :path_encoding => 'ISO-8859-1'
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
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end

    private

    def puts_pass_on_not_utf8
      puts "TODO: This test fails " +
           "when Encoding.default_external is not UTF-8. " +
           "Current value is '#{Encoding.default_external.to_s}'"
    end
  else
    puts "Git test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end

  private

  def with_cache(&block)
    before = ActionController::Base.perform_caching
    ActionController::Base.perform_caching = true
    yield
    ActionController::Base.perform_caching = before
  end
end
