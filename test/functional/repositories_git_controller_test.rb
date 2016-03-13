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

class RepositoriesGitControllerTest < ActionController::TestCase
  tests RepositoriesController

  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH = Rails.root.join('tmp/test/git_repository').to_s
  REPOSITORY_PATH.gsub!(/\//, "\\") if Redmine::Platform.mswin?
  PRJ_ID     = 3
  CHAR_1_HEX = "\xc3\x9c".force_encoding('UTF-8')
  FELIX_HEX  = "Felix Sch\xC3\xA4fer".force_encoding('UTF-8')
  NUM_REV = 28

  ## Git, Mercurial and CVS path encodings are binary.
  ## Subversion supports URL encoding for path.
  ## Redmine Mercurial adapter and extension use URL encoding.
  ## Git accepts only binary path in command line parameter.
  ## So, there is no way to use binary command line parameter in JRuby.
  JRUBY_SKIP     = (RUBY_PLATFORM == 'java')
  JRUBY_SKIP_STR = "TODO: This test fails in JRuby"

  def setup
    @ruby19_non_utf8_pass = Encoding.default_external.to_s != 'UTF-8'

    User.current = nil
    @project    = Project.find(PRJ_ID)
    @repository = Repository::Git.create(
                      :project       => @project,
                      :url           => REPOSITORY_PATH,
                      :path_encoding => 'ISO-8859-1'
                      )
    assert @repository
  end

  def test_create_and_update
    @request.session[:user_id] = 1
    assert_difference 'Repository.count' do
      post :create, :project_id => 'subproject1',
                    :repository_scm => 'Git',
                    :repository => {
                       :url => '/test',
                       :is_default => '0',
                       :identifier => 'test-create',
                       :extra_report_last_commit => '1',
                     }
    end
    assert_response 302
    repository = Repository.order('id DESC').first
    assert_kind_of Repository::Git, repository
    assert_equal '/test', repository.url
    assert_equal true, repository.extra_report_last_commit

    put :update, :id => repository.id,
                 :repository => {
                     :extra_report_last_commit => '0'
                 }
    assert_response 302
    repo2 = Repository.find(repository.id)
    assert_equal false, repo2.extra_report_last_commit
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
      get :new, :project_id => 'subproject1', :repository_scm => 'Git'
      assert_response :success
      assert_template 'new'
      assert_kind_of Repository::Git, assigns(:repository)
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
      assert_equal 9, assigns(:entries).size
      assert assigns(:entries).detect {|e| e.name == 'images' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'this_is_a_really_long_and_verbose_directory_name' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'sources' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'README' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == 'copied_README' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == 'new_file.txt' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == 'renamed_test.txt' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == 'filemane with spaces.txt' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == ' filename with a leading space.txt ' && e.kind == 'file'}
      assert_not_nil assigns(:changesets)
      assert assigns(:changesets).size > 0
    end

    def test_browse_branch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :show, :id => PRJ_ID, :rev => 'test_branch'
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal 4, assigns(:entries).size
      assert assigns(:entries).detect {|e| e.name == 'images' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'sources' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'README' && e.kind == 'file'}
      assert assigns(:entries).detect {|e| e.name == 'test.txt' && e.kind == 'file'}
      assert_not_nil assigns(:changesets)
      assert assigns(:changesets).size > 0
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
        get :show, :id => PRJ_ID, :rev => t1
        assert_response :success
        assert_template 'show'
        assert_not_nil assigns(:entries)
        assert assigns(:entries).size > 0
        assert_not_nil assigns(:changesets)
        assert assigns(:changesets).size > 0
      end
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
      assert_equal ['edit.png'], assigns(:entries).collect(&:name)
      entry = assigns(:entries).detect {|e| e.name == 'edit.png'}
      assert_not_nil entry
      assert_equal 'file', entry.kind
      assert_equal 'images/edit.png', entry.path
      assert_not_nil assigns(:changesets)
      assert assigns(:changesets).size > 0
    end

    def test_browse_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :show, :id => PRJ_ID, :path => repository_path_hash(['images'])[:param],
          :rev => '7234cb2750b63f47bff735edc50a1c0a433c2518'
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ['delete.png'], assigns(:entries).collect(&:name)
      assert_not_nil assigns(:changesets)
      assert assigns(:changesets).size > 0
    end

    def test_changes
      get :changes, :id => PRJ_ID,
          :path => repository_path_hash(['images', 'edit.png'])[:param]
      assert_response :success
      assert_template 'changes'
      assert_select 'h2', :text => /edit.png/
    end

    def test_entry_show
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
      assert_response :success
      assert_template 'entry'
      # Line 11
      assert_select 'tr#L11 td.line-code', :text => /WITHOUT ANY WARRANTY/
    end

    def test_entry_show_latin_1
      if @ruby19_non_utf8_pass
        puts_ruby19_non_utf8_pass()
      elsif WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
          ['57ca437c', '57ca437c0acbbcb749821fdf3726a1367056d364'].each do |r1|
            get :entry, :id => PRJ_ID,
                :path => repository_path_hash(['latin-1-dir', "test-#{CHAR_1_HEX}.txt"])[:param],
                :rev => r1
            assert_response :success
            assert_template 'entry'
            assert_select 'tr#L1 td.line-code', :text => /test-#{CHAR_1_HEX}.txt/
          end
        end
      end
    end

    def test_entry_download
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param],
          :format => 'raw'
      assert_response :success
      # File content
      assert @response.body.include?('WITHOUT ANY WARRANTY')
    end

    def test_directory_entry
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources'])[:param]
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entry)
      assert_equal 'sources', assigns(:entry).name
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
        get :diff,
            :id   => PRJ_ID,
            :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7',
            :type => dt
        assert_response :success
        assert_template 'diff'
        # Line 22 removed
        assert_select 'th.line-num:contains(22) ~ td.diff_out', :text => /def remove/
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
          get :diff,
              :id   => PRJ_ID,
              :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7',
              :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param],
              :type => dt
          assert_response :success
          assert_template 'diff'
          # Line 22 removed
          assert_select 'th.line-num:contains(22) ~ td.diff_out', :text => /def remove/
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
            get :diff, :id   => PRJ_ID, :type => 'inline',
                :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7'
            assert_response :success
            assert @response.body.include?("... This diff was truncated")
          end
          with_settings :default_language => 'fr' do
            get :diff, :id   => PRJ_ID, :type => 'inline',
                :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7'
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
        get :diff,
            :id     => PRJ_ID,
            :rev    => '61b685fbe55ab05b5ac68402d5720c1a6ac973d1',
            :rev_to => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7',
            :type   => dt
        assert_response :success
        assert_template 'diff'
        diff = assigns(:diff)
        assert_not_nil diff
        assert_select 'h2', :text => /2f9c0091:61b685fb/
        assert_select 'form[action=?]', '/projects/subproject1/repository/revisions/61b685fbe55ab05b5ac68402d5720c1a6ac973d1/diff'
        assert_select 'input#rev_to[type=hidden][name=rev_to][value=?]', '2f9c0091c754a91af7a9c478e36556b4bde8dcf7'
      end
    end

    def test_diff_path_in_subrepo
      repo = Repository::Git.create(
                      :project       => @project,
                      :url           => REPOSITORY_PATH,
                      :identifier => 'test-diff-path',
                      :path_encoding => 'ISO-8859-1'
                      )
      assert repo
      assert_equal false, repo.is_default
      assert_equal 'test-diff-path', repo.identifier
      get :diff,
          :id     => PRJ_ID,
          :repository_id => 'test-diff-path',
          :rev    => '61b685fbe55ab05b',
          :rev_to => '2f9c0091c754a91a',
          :type   => 'inline'
      assert_response :success
      assert_template 'diff'
      diff = assigns(:diff)
      assert_not_nil diff
      assert_select 'form[action=?]', '/projects/subproject1/repository/test-diff-path/revisions/61b685fbe55ab05b/diff'
      assert_select 'input#rev_to[type=hidden][name=rev_to][value=?]', '2f9c0091c754a91a'
    end

    def test_diff_latin_1
      if @ruby19_non_utf8_pass
        puts_ruby19_non_utf8_pass()
      else
        with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
          ['57ca437c', '57ca437c0acbbcb749821fdf3726a1367056d364'].each do |r1|
            ['inline', 'sbs'].each do |dt|
              get :diff, :id => PRJ_ID, :rev => r1, :type => dt
              assert_response :success
              assert_template 'diff'
              assert_select 'table' do
                assert_select 'thead th.filename', :text => /latin-1-dir\/test-#{CHAR_1_HEX}.txt/
                assert_select 'tbody td.diff_in', :text => /test-#{CHAR_1_HEX}.txt/
              end
            end
          end
        end
      end
    end

    def test_diff_should_show_filenames
      get :diff, :id => PRJ_ID, :rev => 'deff712f05a90d96edbd70facc47d944be5897e3', :type => 'inline'
      assert_response :success
      assert_template 'diff'
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
      get :diff,
          :id   => PRJ_ID,
          :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7'
      assert_response :success
      assert_template 'diff'
      user.reload
      assert_equal "inline", user.pref[:diff_type]
      get :diff,
          :id   => PRJ_ID,
          :rev  => '2f9c0091c754a91af7a9c478e36556b4bde8dcf7',
          :type => 'sbs'
      assert_response :success
      assert_template 'diff'
      user.reload
      assert_equal "sbs", user.pref[:diff_type]
    end

    def test_annotate
      get :annotate, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
      assert_response :success
      assert_template 'annotate'

      # Line 23, changeset 2f9c0091
      assert_select 'tr' do
        assert_select 'th.line-num', :text => '23'
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
      get :annotate, :id => PRJ_ID, :rev => 'deff7',
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
      assert_response :success
      assert_template 'annotate'
      assert_select 'h2', :text => /@ deff712f/
    end

    def test_annotate_binary_file
      with_settings :default_language => 'en' do
        get :annotate, :id => PRJ_ID,
            :path => repository_path_hash(['images', 'edit.png'])[:param]
        assert_response 500
        assert_select 'p#errorExplanation', :text => /cannot be annotated/
      end
    end

    def test_annotate_error_when_too_big
      with_settings :file_max_size_displayed => 1 do
        get :annotate, :id => PRJ_ID,
            :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param],
            :rev => 'deff712f'
        assert_response 500
        assert_select 'p#errorExplanation', :text => /exceeds the maximum text file size/

        get :annotate, :id => PRJ_ID,
            :path => repository_path_hash(['README'])[:param],
            :rev => '7234cb2'
        assert_response :success
        assert_template 'annotate'
      end
    end

    def test_annotate_latin_1
      if @ruby19_non_utf8_pass
        puts_ruby19_non_utf8_pass()
      elsif WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
          ['57ca437c', '57ca437c0acbbcb749821fdf3726a1367056d364'].each do |r1|
            get :annotate, :id => PRJ_ID,
                :path => repository_path_hash(['latin-1-dir', "test-#{CHAR_1_HEX}.txt"])[:param],
                :rev => r1
            assert_select "th.line-num", :text => '1' do
              assert_select "+ td.revision" do
                assert_select "a", :text => '57ca437c'
                assert_select "+ td.author", :text => "jsmith" do
                  assert_select "+ td",
                                :text => "test-#{CHAR_1_HEX}.txt"
                end
              end
            end
          end
        end
      end
    end

    def test_annotate_latin_1_author
      ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', '83ca5fd546063a'].each do |r1|
        get :annotate, :id => PRJ_ID,
            :path => repository_path_hash([" filename with a leading space.txt "])[:param],
            :rev => r1
        assert_select "th.line-num", :text => '1' do
          assert_select "+ td.revision" do
            assert_select "a", :text => '83ca5fd5'
            assert_select "+ td.author", :text => FELIX_HEX do
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
      get :revisions, :id => PRJ_ID
      assert_response :success
      assert_template 'revisions'
      assert_select 'form[method=get][action=?]', '/projects/subproject1/repository/revision'
    end

    def test_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['61b685fbe55ab05b5ac68402d5720c1a6ac973d1', '61b685f'].each do |r|
        get :revision, :id => PRJ_ID, :rev => r
        assert_response :success
        assert_template 'revision'
      end
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
      @repository = Repository::Git.create!(
                      :project       => @project,
                      :url           => "/invalid",
                      :path_encoding => 'ISO-8859-1'
                      )
      @repository.fetch_changesets
      @repository.reload
      assert_equal 0, @repository.changesets.count

      assert_difference 'Repository.count', -1 do
        delete :destroy, :id => @repository.id
      end
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end

    private

    def puts_ruby19_non_utf8_pass
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
    block.call
    ActionController::Base.perform_caching = before
  end
end
