# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class RepositoryGitTest < ActiveSupport::TestCase
  fixtures :projects, :repositories, :enabled_modules, :users, :roles

  include Redmine::I18n

  REPOSITORY_PATH = Rails.root.join('tmp/test/git_repository').to_s
  REPOSITORY_PATH.gsub!(/\//, "\\") if Redmine::Platform.mswin?

  NUM_REV = 28
  NUM_HEAD = 6

  FELIX_HEX  = "Felix Sch\xC3\xA4fer".force_encoding('UTF-8')
  CHAR_1_HEX = "\xc3\x9c".force_encoding('UTF-8')

  ## Git, Mercurial and CVS path encodings are binary.
  ## Subversion supports URL encoding for path.
  ## Redmine Mercurial adapter and extension use URL encoding.
  ## Git accepts only binary path in command line parameter.
  ## So, there is no way to use binary command line parameter in JRuby.
  JRUBY_SKIP     = (RUBY_PLATFORM == 'java')
  JRUBY_SKIP_STR = "TODO: This test fails in JRuby"

  def setup
    @project = Project.find(3)
    @repository = Repository::Git.create(
                        :project       => @project,
                        :url           => REPOSITORY_PATH,
                        :path_encoding => 'ISO-8859-1'
                        )
    assert @repository
  end

  def test_nondefault_repo_with_blank_identifier_destruction
    Repository.delete_all

    repo1 = Repository::Git.new(
                          :project    => @project,
                          :url        => REPOSITORY_PATH,
                          :identifier => '',
                          :is_default => true
                        )
    assert repo1.save
    repo1.fetch_changesets

    repo2 = Repository::Git.new(
                          :project    => @project,
                          :url        => REPOSITORY_PATH,
                          :identifier => 'repo2',
                          :is_default => true
                    )
    assert repo2.save
    repo2.fetch_changesets

    repo1.reload
    repo2.reload
    assert !repo1.is_default?
    assert  repo2.is_default?

    assert_difference 'Repository.count', -1 do
      repo1.destroy
    end
  end

  def test_blank_path_to_repository_error_message
    set_language_if_valid 'en'
    repo = Repository::Git.new(
                          :project      => @project,
                          :identifier   => 'test'
                        )
    assert !repo.save
    assert_include "Path to repository cannot be blank",
                   repo.errors.full_messages
  end

  def test_blank_path_to_repository_error_message_fr
    set_language_if_valid 'fr'
    str = "Chemin du d\xc3\xa9p\xc3\xb4t doit \xc3\xaatre renseign\xc3\xa9(e)".force_encoding('UTF-8')
    repo = Repository::Git.new(
                          :project      => @project,
                          :url          => "",
                          :identifier   => 'test',
                          :path_encoding => ''
                        )
    assert !repo.save
    assert_include str, repo.errors.full_messages
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

    def test_scm_available
      klass = Repository::Git
      assert_equal "Git", klass.scm_name
      assert klass.scm_adapter_class
      assert_not_equal "", klass.scm_command
      assert_equal true, klass.scm_available
    end

    def test_entries
      entries = @repository.entries
      assert_kind_of Redmine::Scm::Adapters::Entries, entries
    end

    def test_fetch_changesets_from_scratch
      assert_nil @repository.extra_info

      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload

      assert_equal NUM_REV, @repository.changesets.count
      assert_equal 39, @repository.filechanges.count

      commit = @repository.changesets.find_by_revision("7234cb2750b63f47bff735edc50a1c0a433c2518")
      assert_equal "7234cb2750b63f47bff735edc50a1c0a433c2518", commit.scmid
      assert_equal "Initial import.\nThe repository contains 3 files.", commit.comments
      assert_equal "jsmith <jsmith@foo.bar>", commit.committer
      assert_equal User.find_by_login('jsmith'), commit.user
      # TODO: add a commit with commit time <> author time to the test repository
      assert_equal Time.gm(2007, 12, 14, 9, 22, 52), commit.committed_on
      assert_equal "2007-12-14".to_date, commit.commit_date
      assert_equal 3, commit.filechanges.count
      change = commit.filechanges.sort_by(&:path).first
      assert_equal "README", change.path
      assert_nil change.from_path
      assert_equal "A", change.action

      assert_equal NUM_HEAD, @repository.extra_info["heads"].size
    end

    def test_fetch_changesets_incremental
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      extra_info_heads = @repository.extra_info["heads"].dup
      assert_equal NUM_HEAD, extra_info_heads.size
      extra_info_heads.delete_if { |x| x == "83ca5fd546063a3c7dc2e568ba3355661a9e2b2c" }
      assert_equal 4, extra_info_heads.size

      del_revs = [
          "83ca5fd546063a3c7dc2e568ba3355661a9e2b2c",
          "ed5bb786bbda2dee66a2d50faf51429dbc043a7b",
          "4f26664364207fa8b1af9f8722647ab2d4ac5d43",
          "deff712f05a90d96edbd70facc47d944be5897e3",
          "32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf",
          "7e61ac704deecde634b51e59daa8110435dcb3da",
         ]
      @repository.changesets.each do |rev|
        rev.destroy if del_revs.detect {|r| r == rev.scmid.to_s }
      end
      @project.reload
      cs1 = @repository.changesets
      assert_equal NUM_REV - 6, cs1.count
      extra_info_heads << "4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8"
      h = {}
      h["heads"] = extra_info_heads
      @repository.merge_extra_info(h)
      @repository.save
      @project.reload
      assert @repository.extra_info["heads"].index("4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8")
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_equal NUM_HEAD, @repository.extra_info["heads"].size
      assert @repository.extra_info["heads"].index("83ca5fd546063a3c7dc2e568ba3355661a9e2b2c")
    end

    def test_fetch_changesets_history_editing
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      extra_info_heads = @repository.extra_info["heads"].dup
      assert_equal NUM_HEAD, extra_info_heads.size
      extra_info_heads.delete_if { |x| x == "83ca5fd546063a3c7dc2e568ba3355661a9e2b2c" }
      assert_equal 4, extra_info_heads.size

      del_revs = [
          "83ca5fd546063a3c7dc2e568ba3355661a9e2b2c",
          "ed5bb786bbda2dee66a2d50faf51429dbc043a7b",
          "4f26664364207fa8b1af9f8722647ab2d4ac5d43",
          "deff712f05a90d96edbd70facc47d944be5897e3",
          "32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf",
          "7e61ac704deecde634b51e59daa8110435dcb3da",
         ]
      @repository.changesets.each do |rev|
        rev.destroy if del_revs.detect {|r| r == rev.scmid.to_s }
      end
      @project.reload
      assert_equal NUM_REV - 6, @repository.changesets.count

      c = Changeset.new(:repository   => @repository,
                        :committed_on => Time.now,
                        :revision     => "abcd1234efgh",
                        :scmid        => "abcd1234efgh",
                        :comments     => 'test')
      assert c.save
      @project.reload
      assert_equal NUM_REV - 5, @repository.changesets.count

      extra_info_heads << "1234abcd5678"
      h = {}
      h["heads"] = extra_info_heads
      @repository.merge_extra_info(h)
      @repository.save
      @project.reload
      h1 = @repository.extra_info["heads"].dup
      assert h1.index("1234abcd5678")
      assert_equal 5, h1.size

      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV - 5, @repository.changesets.count
      h2 = @repository.extra_info["heads"].dup
      assert_equal h1, h2
    end

    def test_clear_changesets_should_keep_report_last_commit
      assert_nil @repository.extra_info
      @repository.report_last_commit = "1"
      @repository.save
      @repository.send(:clear_changesets)

      assert_equal true, @repository.report_last_commit
    end

    def test_refetch_after_clear_changesets
      assert_nil @repository.extra_info
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      @repository.send(:clear_changesets)
      @project.reload
      assert_equal 0, @repository.changesets.count

      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
    end

    def test_parents
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      r1 = @repository.find_changeset_by_name("7234cb2750b63")
      assert_equal [], r1.parents
      r2 = @repository.find_changeset_by_name("899a15dba03a3")
      assert_equal 1, r2.parents.length
      assert_equal "7234cb2750b63f47bff735edc50a1c0a433c2518",
                   r2.parents[0].identifier
      r3 = @repository.find_changeset_by_name("32ae898b720c2")
      assert_equal 2, r3.parents.length
      r4 = [r3.parents[0].identifier, r3.parents[1].identifier].sort
      assert_equal "4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8", r4[0]
      assert_equal "7e61ac704deecde634b51e59daa8110435dcb3da", r4[1]
    end

    def test_db_consistent_ordering_init
      assert_nil @repository.extra_info
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal 1, @repository.extra_info["db_consistent"]["ordering"]
    end

    def test_db_consistent_ordering_before_1_2
      assert_nil @repository.extra_info
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_not_nil @repository.extra_info
      h = {}
      h["heads"] = []
      h["branches"] = {}
      h["db_consistent"] = {}
      @repository.merge_extra_info(h)
      @repository.save
      assert_equal NUM_REV, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal 0, @repository.extra_info["db_consistent"]["ordering"]

      extra_info_heads = @repository.extra_info["heads"].dup
      extra_info_heads.delete_if { |x| x == "83ca5fd546063a3c7dc2e568ba3355661a9e2b2c" }
      del_revs = [
          "83ca5fd546063a3c7dc2e568ba3355661a9e2b2c",
          "ed5bb786bbda2dee66a2d50faf51429dbc043a7b",
          "4f26664364207fa8b1af9f8722647ab2d4ac5d43",
          "deff712f05a90d96edbd70facc47d944be5897e3",
          "32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf",
          "7e61ac704deecde634b51e59daa8110435dcb3da",
         ]
      @repository.changesets.each do |rev|
        rev.destroy if del_revs.detect {|r| r == rev.scmid.to_s }
      end
      @project.reload
      cs1 = @repository.changesets
      assert_equal NUM_REV - 6, cs1.count
      assert_equal 0, @repository.extra_info["db_consistent"]["ordering"]

      extra_info_heads << "4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8"
      h = {}
      h["heads"] = extra_info_heads
      @repository.merge_extra_info(h)
      @repository.save
      @project.reload
      assert @repository.extra_info["heads"].index("4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8")
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_equal NUM_HEAD, @repository.extra_info["heads"].size

      assert_equal 0, @repository.extra_info["db_consistent"]["ordering"]
    end

    def test_heads_from_branches_hash
      assert_nil @repository.extra_info
      assert_equal 0, @repository.changesets.count
      assert_equal [], @repository.heads_from_branches_hash
      h = {}
      h["branches"] = {}
      h["branches"]["test1"] = {}
      h["branches"]["test1"]["last_scmid"] = "1234abcd"
      h["branches"]["test2"] = {}
      h["branches"]["test2"]["last_scmid"] = "abcd1234"
      @repository.merge_extra_info(h)
      @repository.save
      @project.reload
      assert_equal ["1234abcd", "abcd1234"], @repository.heads_from_branches_hash.sort
    end

    def test_latest_changesets
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      # with limit
      changesets = @repository.latest_changesets('', 'master', 2)
      assert_equal 2, changesets.size

      # with path
      changesets = @repository.latest_changesets('images', 'master')
      assert_equal [
              'deff712f05a90d96edbd70facc47d944be5897e3',
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
              '7234cb2750b63f47bff735edc50a1c0a433c2518',
          ], changesets.collect(&:revision)

      changesets = @repository.latest_changesets('README', nil)
      assert_equal [
              '32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf',
              '4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8',
              '713f4944648826f558cf548222f813dabe7cbb04',
              '61b685fbe55ab05b5ac68402d5720c1a6ac973d1',
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
              '7234cb2750b63f47bff735edc50a1c0a433c2518',
          ], changesets.collect(&:revision)

      # with path, revision and limit
      changesets = @repository.latest_changesets('images', '899a15dba')
      assert_equal [
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
              '7234cb2750b63f47bff735edc50a1c0a433c2518',
          ], changesets.collect(&:revision)

      changesets = @repository.latest_changesets('images', '899a15dba', 1)
      assert_equal [
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
          ], changesets.collect(&:revision)

      changesets = @repository.latest_changesets('README', '899a15dba')
      assert_equal [
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
              '7234cb2750b63f47bff735edc50a1c0a433c2518',
          ], changesets.collect(&:revision)

      changesets = @repository.latest_changesets('README', '899a15dba', 1)
      assert_equal [
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
          ], changesets.collect(&:revision)

      # with path, tag and limit
      changesets = @repository.latest_changesets('images', 'tag01.annotated')
      assert_equal [
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
              '7234cb2750b63f47bff735edc50a1c0a433c2518',
          ], changesets.collect(&:revision)

      changesets = @repository.latest_changesets('images', 'tag01.annotated', 1)
      assert_equal [
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
          ], changesets.collect(&:revision)

      changesets = @repository.latest_changesets('README', 'tag01.annotated')
      assert_equal [
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
              '7234cb2750b63f47bff735edc50a1c0a433c2518',
          ], changesets.collect(&:revision)

      changesets = @repository.latest_changesets('README', 'tag01.annotated', 1)
      assert_equal [
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
          ], changesets.collect(&:revision)

      # with path, branch and limit
      changesets = @repository.latest_changesets('images', 'test_branch')
      assert_equal [
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
              '7234cb2750b63f47bff735edc50a1c0a433c2518',
          ], changesets.collect(&:revision)

      changesets = @repository.latest_changesets('images', 'test_branch', 1)
      assert_equal [
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
          ], changesets.collect(&:revision)

      changesets = @repository.latest_changesets('README', 'test_branch')
      assert_equal [
              '713f4944648826f558cf548222f813dabe7cbb04',
              '61b685fbe55ab05b5ac68402d5720c1a6ac973d1',
              '899a15dba03a3b350b89c3f537e4bbe02a03cdc9',
              '7234cb2750b63f47bff735edc50a1c0a433c2518',
          ], changesets.collect(&:revision)

      changesets = @repository.latest_changesets('README', 'test_branch', 2)
      assert_equal [
              '713f4944648826f558cf548222f813dabe7cbb04',
              '61b685fbe55ab05b5ac68402d5720c1a6ac973d1',
          ], changesets.collect(&:revision)

      if WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        # latin-1 encoding path
        changesets = @repository.latest_changesets(
                      "latin-1-dir/test-#{CHAR_1_HEX}-2.txt", '64f1f3e89')
        assert_equal [
              '64f1f3e89ad1cb57976ff0ad99a107012ba3481d',
              '4fc55c43bf3d3dc2efb66145365ddc17639ce81e',
          ], changesets.collect(&:revision)

        changesets = @repository.latest_changesets(
                    "latin-1-dir/test-#{CHAR_1_HEX}-2.txt", '64f1f3e89', 1)
        assert_equal [
              '64f1f3e89ad1cb57976ff0ad99a107012ba3481d',
          ], changesets.collect(&:revision)
      end
    end

    def test_latest_changesets_latin_1_dir
      if WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        assert_equal 0, @repository.changesets.count
        @repository.fetch_changesets
        @project.reload
        assert_equal NUM_REV, @repository.changesets.count
        changesets = @repository.latest_changesets(
                    "latin-1-dir/test-#{CHAR_1_HEX}-subdir", '1ca7f5ed')
        assert_equal [
              '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127',
          ], changesets.collect(&:revision)
      end
    end

    def test_find_changeset_by_name
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['7234cb2750b63f47bff735edc50a1c0a433c2518', '7234cb2750b'].each do |r|
        assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518',
                     @repository.find_changeset_by_name(r).revision
      end
    end

    def test_find_changeset_by_empty_name
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['', ' ', nil].each do |r|
        assert_nil @repository.find_changeset_by_name(r)
      end
    end

    def test_identifier
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      c = @repository.changesets.find_by_revision(
                          '7234cb2750b63f47bff735edc50a1c0a433c2518')
      assert_equal c.scmid, c.identifier
    end

    def test_format_identifier
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      c = @repository.changesets.find_by_revision(
                          '7234cb2750b63f47bff735edc50a1c0a433c2518')
      assert_equal '7234cb27', c.format_identifier
    end

    def test_activities
      c = Changeset.new(:repository => @repository,
                        :committed_on => Time.now,
                        :revision => 'abc7234cb2750b63f47bff735edc50a1c0a433c2',
                        :scmid    => 'abc7234cb2750b63f47bff735edc50a1c0a433c2',
                        :comments => 'test')
      assert c.event_title.include?('abc7234c:')
      assert_equal 'abc7234cb2750b63f47bff735edc50a1c0a433c2', c.event_url[:rev]
    end

    def test_log_utf8
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      c = @repository.changesets.find_by_revision(
                        'ed5bb786bbda2dee66a2d50faf51429dbc043a7b')
      assert_equal "#{FELIX_HEX} <felix@fachschaften.org>", c.committer
    end

    def test_previous
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      %w|1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127 1ca7f5ed|.each do |r1|
        changeset = @repository.find_changeset_by_name(r1)
        %w|64f1f3e89ad1cb57976ff0ad99a107012ba3481d 64f1f3e89ad1|.each do |r2|
          assert_equal @repository.find_changeset_by_name(r2), changeset.previous
        end
      end
    end

    def test_previous_nil
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      %w|7234cb2750b63f47bff735edc50a1c0a433c2518 7234cb275|.each do |r1|
        changeset = @repository.find_changeset_by_name(r1)
        assert_nil changeset.previous
      end
    end

    def test_next
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      %w|64f1f3e89ad1cb57976ff0ad99a107012ba3481d 64f1f3e89ad1|.each do |r2|
        changeset = @repository.find_changeset_by_name(r2)
        %w|1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127 1ca7f5ed|.each do |r1|
        assert_equal @repository.find_changeset_by_name(r1), changeset.next
        end
      end
    end

    def test_next_nil
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      %w|2a682156a3b6e77a8bf9cd4590e8db757f3c6c78 2a682156a3b6e77a|.each do |r1|
        changeset = @repository.find_changeset_by_name(r1)
        assert_nil changeset.next
      end
    end
  else
    puts "Git test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
