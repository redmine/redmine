# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

require File.expand_path('../../../../../../test_helper', __FILE__)

class GitAdapterTest < ActiveSupport::TestCase
  REPOSITORY_PATH = Rails.root.join('tmp/test/git_repository').to_s

  ## Git, Mercurial and CVS path encodings are binary.
  ## Subversion supports URL encoding for path.
  ## Redmine Mercurial adapter and extension use URL encoding.
  ## Git accepts only binary path in command line parameter.
  ## So, there is no way to use binary command line parameter in JRuby.
  JRUBY_SKIP     = (RUBY_PLATFORM == 'java')
  JRUBY_SKIP_STR = "TODO: This test fails in JRuby"

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

    def setup
      adapter_class = Redmine::Scm::Adapters::GitAdapter
      assert adapter_class
      assert adapter_class.client_command
      assert_equal true, adapter_class.client_available
      assert_equal true, adapter_class.client_version_above?([1])
      assert_equal true, adapter_class.client_version_above?([1, 0])

      @adapter =
        Redmine::Scm::Adapters::GitAdapter.
          new(
            REPOSITORY_PATH,
            nil,
            nil,
            nil,
            'ISO-8859-1'
          )
      assert @adapter
      @char_1 = 'Ü'
      @str_felix_hex  = "Felix Sch\xC3\xA4fer".b
    end

    def test_scm_version
      to_test = {
        "git version 1.7.3.4\n"   => [1, 7, 3, 4],
        "1.6.1\n1.7\n1.8"         => [1, 6, 1],
        "1.6.2\r\n1.8.1\r\n1.9.1" => [1, 6, 2]
      }
      to_test.each do |s, v|
        test_scm_version_for(s, v)
      end
    end

    def test_branches
      brs = []
      @adapter.branches.each do |b|
        brs << b
      end
      assert_equal 8, brs.length
      br_issue_8857 = brs[0]
      assert_equal 'issue-8857', br_issue_8857.to_s
      assert_equal '2a682156a3b6e77a8bf9cd4590e8db757f3c6c78', br_issue_8857.revision
      assert_equal br_issue_8857.scmid, br_issue_8857.revision
      assert_equal false, br_issue_8857.is_default
      br_latin_1_branch1 = brs[1]
      assert_equal "latin-1-branch-#{@char_1}-01", br_latin_1_branch1.to_s
      assert_equal '4fc55c43bf3d3dc2efb66145365ddc17639ce81e', br_latin_1_branch1.revision
      assert_equal br_latin_1_branch1.scmid, br_latin_1_branch1.revision
      assert_equal false, br_latin_1_branch1.is_default
      br_latin_1_branch2 = brs[2]
      assert_equal "latin-1-branch-#{@char_1}-02", br_latin_1_branch2.to_s
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', br_latin_1_branch2.revision
      assert_equal br_latin_1_branch2.scmid, br_latin_1_branch2.revision
      assert_equal false, br_latin_1_branch2.is_default
      br_latin_1_path = brs[3]
      assert_equal 'latin-1-path-encoding', br_latin_1_path.to_s
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', br_latin_1_path.revision
      assert_equal br_latin_1_path.scmid, br_latin_1_path.revision
      assert_equal false, br_latin_1_path.is_default
      br_master = brs[4]
      assert_equal 'master', br_master.to_s
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', br_master.revision
      assert_equal br_master.scmid, br_master.revision
      assert_equal false, br_master.is_default
      br_master_20120212 = brs[5]
      assert_equal 'master-20120212', br_master_20120212.to_s
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', br_master_20120212.revision
      assert_equal br_master_20120212.scmid, br_master_20120212.revision
      assert_equal true, br_master_20120212.is_default
      br_latin_1 = brs[-2]
      assert_equal 'test-latin-1', br_latin_1.to_s
      assert_equal '67e7792ce20ccae2e4bb73eed09bb397819c8834', br_latin_1.revision
      assert_equal br_latin_1.scmid, br_latin_1.revision
      assert_equal false, br_latin_1.is_default
      br_test = brs[-1]
      assert_equal 'test_branch', br_test.to_s
      assert_equal 'fba357b886984ee71185ad2065e65fc0417d9b92', br_test.revision
      assert_equal br_test.scmid, br_test.revision
      assert_equal false, br_test.is_default
    end

    def test_default_branch
      assert_equal 'master-20120212', @adapter.default_branch

      # When no branch is marked as the default, GitAdapter treats
      # "main" or "master" branch as the default
      b_foo, b_bar, b_main, b_master =
        %w[foo bar main master].map do |name|
          Redmine::Scm::Adapters::GitAdapter::GitBranch.new(name)
        end
      @adapter.stubs(:branches).returns([b_foo, b_main, b_bar])
      assert_equal 'main', @adapter.default_branch
      @adapter.stubs(:branches).returns([b_foo, b_master, b_bar])
      assert_equal 'master', @adapter.default_branch

      # The first found branch is treated as the default branch
      # when neither "main" nor "master" is found
      @adapter.stubs(:branches).returns([b_foo, b_bar])
      assert_equal 'foo', @adapter.default_branch

      @adapter.stubs(:branches).returns([])
      assert_nil @adapter.default_branch
    end

    def test_tags
      assert_equal(
        [
          "tag00.lightweight",
          "tag01.annotated",
          "tag02.lightweight.#{@char_1}.01",
        ],
        @adapter.tags
      )
    end

    def test_revisions_master_all
      revs1 = []
      @adapter.revisions('', nil, "master", {}) do |rev|
        revs1 << rev
      end
      assert_equal 15, revs1.length
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[0].identifier
      assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs1[-1].identifier

      revs2 = []
      @adapter.revisions('', nil, "master",
                         {:reverse => true}) do |rev|
        revs2 << rev
      end
      assert_equal 15, revs2.length
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs2[-1].identifier
      assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs2[0].identifier
    end

    def test_revisions_master_merged_rev
      revs1 = []
      @adapter.revisions('',
                         "713f4944648826f558cf548222f813dabe7cbb04",
                         "master",
                         {:reverse => true}) do |rev|
        revs1 << rev
      end
      assert_equal 8, revs1.length
      assert_equal 'fba357b886984ee71185ad2065e65fc0417d9b92', revs1[0].identifier
      assert_equal '7e61ac704deecde634b51e59daa8110435dcb3da', revs1[1].identifier
      # 4a07fe31b is not a child of 713f49446
      assert_equal '4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8', revs1[2].identifier
      # Merged revision
      assert_equal '32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf', revs1[3].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[-1].identifier

      revs2 = []
      @adapter.revisions('',
                         "fba357b886984ee71185ad2065e65fc0417d9b92",
                         "master",
                         {:reverse => true}) do |rev|
        revs2 << rev
      end
      assert_equal 7, revs2.length
      assert_equal '7e61ac704deecde634b51e59daa8110435dcb3da', revs2[0].identifier
      # 4a07fe31b is not a child of fba357b8869
      assert_equal '4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8', revs2[1].identifier
      # Merged revision
      assert_equal '32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf', revs2[2].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs2[-1].identifier
    end

    def test_revisions_branch_latin_1_path_encoding_all
      revs1 = []
      @adapter.revisions('', nil, "latin-1-path-encoding", {}) do |rev|
        revs1 << rev
      end
      assert_equal 8, revs1.length
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs1[0].identifier
      assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs1[-1].identifier

      revs2 = []
      @adapter.revisions('', nil, "latin-1-path-encoding",
                         {:reverse => true}) do |rev|
        revs2 << rev
      end
      assert_equal 8, revs2.length
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs2[-1].identifier
      assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs2[0].identifier
    end

    def test_revisions_branch_latin_1_path_encoding_with_rev
      revs1 = []
      @adapter.revisions('',
                         '7234cb2750b63f47bff735edc50a1c0a433c2518',
                         "latin-1-path-encoding",
                         {:reverse => true}) do |rev|
        revs1 << rev
      end
      assert_equal 7, revs1.length
      assert_equal '899a15dba03a3b350b89c3f537e4bbe02a03cdc9', revs1[0].identifier
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs1[-1].identifier

      revs2 = []
      @adapter.revisions('',
                         '57ca437c0acbbcb749821fdf3726a1367056d364',
                         "latin-1-path-encoding",
                         {:reverse => true}) do |rev|
        revs2 << rev
      end
      assert_equal 3, revs2.length
      assert_equal '4fc55c43bf3d3dc2efb66145365ddc17639ce81e', revs2[0].identifier
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs2[-1].identifier
    end

    def test_revisions_latin_1_identifier
      if WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        revs1 = []
        @adapter.revisions(
          '',
          "latin-1-branch-#{@char_1}-01",
          "latin-1-branch-#{@char_1}-02",
          {:reverse => true}
        ) do |rev|
          revs1 << rev
        end
        assert_equal 2, revs1.length
        assert_equal '64f1f3e89ad1cb57976ff0ad99a107012ba3481d', revs1[0].identifier
        assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs1[1].identifier
      end
    end

    def test_revisions_invalid_rev
      assert_equal [], @adapter.revisions('', '1234abcd', "master")
      assert_raise Redmine::Scm::Adapters::CommandFailed do
        revs1 = []
        @adapter.revisions(
          '',
          '1234abcd',
          "master",
          {:reverse => true}
        ) do |rev|
          revs1 << rev
        end
      end
    end

    def test_revisions_includes_master_two_revs
      revs1 = []
      @adapter.revisions('', nil, nil,
                         {:reverse => true,
                          :includes => ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c'],
                          :excludes => ['4f26664364207fa8b1af9f8722647ab2d4ac5d43']}) do |rev|
        revs1 << rev
      end
      assert_equal 2, revs1.length
      assert_equal 'ed5bb786bbda2dee66a2d50faf51429dbc043a7b', revs1[0].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[-1].identifier
    end

    def test_revisions_includes_master_two_revs_from_origin
      revs1 = []
      @adapter.revisions('', nil, nil,
                         {:reverse => true,
                          :includes => ['899a15dba03a3b350b89c3f537e4bbe02a03cdc9'],
                          :excludes => []}) do |rev|
        revs1 << rev
      end
      assert_equal 2, revs1.length
      assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs1[0].identifier
      assert_equal '899a15dba03a3b350b89c3f537e4bbe02a03cdc9', revs1[1].identifier
    end

    def test_revisions_includes_merged_revs
      revs1 = []
      @adapter.revisions('', nil, nil,
                         {:reverse => true,
                          :includes => ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c'],
                          :excludes => ['fba357b886984ee71185ad2065e65fc0417d9b92']}) do |rev|
        revs1 << rev
      end
      assert_equal 7, revs1.length
      assert_equal '7e61ac704deecde634b51e59daa8110435dcb3da', revs1[0].identifier
      assert_equal '4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8', revs1[1].identifier
      assert_equal '32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf', revs1[2].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[-1].identifier
    end

    def test_revisions_includes_two_heads
      revs1 = []
      @adapter.revisions('', nil, nil,
                         {:reverse => true,
                          :includes => ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c',
                                        '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127'],
                          :excludes => ['4f26664364207fa8b1af9f8722647ab2d4ac5d43',
                                        '4fc55c43bf3d3dc2efb66145365ddc17639ce81e']}) do |rev|
        revs1 << rev
      end
      assert_equal 4, revs1.length
      assert_equal 'ed5bb786bbda2dee66a2d50faf51429dbc043a7b', revs1[0].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[1].identifier
      assert_equal '64f1f3e89ad1cb57976ff0ad99a107012ba3481d', revs1[-2].identifier
      assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs1[-1].identifier
    end

    def test_revisions_disjointed_histories_revisions
      revs1 = []
      @adapter.revisions('', nil, nil,
                         {:reverse => true,
                          :includes => ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c',
                                        '92397af84d22f27389c822848ecd5b463c181583'],
                          :excludes => ['95488a44bc25f7d1f97d775a31359539ff333a63',
                                        '4f26664364207fa8b1af9f8722647ab2d4ac5d43']}) do |rev|
        revs1 << rev
      end
      assert_equal 4, revs1.length
      assert_equal 'ed5bb786bbda2dee66a2d50faf51429dbc043a7b', revs1[0].identifier
      assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[1].identifier
      assert_equal 'bc201c95999c4f10d018b0aa03b541cd6a2ff0ee', revs1[-2].identifier
      assert_equal '92397af84d22f27389c822848ecd5b463c181583', revs1[-1].identifier
    end

    def test_revisions_invalid_rev_excludes
      assert_equal [],
                   @adapter.revisions('', nil, nil,
                                      {:reverse => true,
                                       :includes => ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c'],
                                       :excludes => ['0123abcd4567']})
      assert_raise Redmine::Scm::Adapters::CommandFailed do
        revs1 = []
        @adapter.revisions('', nil, nil,
                           {:reverse => true,
                            :includes => ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c'],
                            :excludes => ['0123abcd4567']}) do |rev|
          revs1 << rev
        end
      end
    end

    def test_getting_revisions_with_spaces_in_filename
      assert_equal 1, @adapter.revisions("filemane with spaces.txt",
                                         nil, "master").length
    end

    def test_parents
      revs1 = []
      @adapter.revisions('',
                         nil,
                         "master",
                         {:reverse => true}) do |rev|
        revs1 << rev
      end
      assert_equal 15, revs1.length
      assert_equal "7234cb2750b63f47bff735edc50a1c0a433c2518",
                   revs1[0].identifier
      assert_nil revs1[0].parents
      assert_equal "899a15dba03a3b350b89c3f537e4bbe02a03cdc9",
                   revs1[1].identifier
      assert_equal 1, revs1[1].parents.length
      assert_equal "7234cb2750b63f47bff735edc50a1c0a433c2518",
                   revs1[1].parents[0]
      assert_equal "32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf",
                   revs1[10].identifier
      assert_equal 2, revs1[10].parents.length
      assert_equal "4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8",
                   revs1[10].parents[0]
      assert_equal "7e61ac704deecde634b51e59daa8110435dcb3da",
                   revs1[10].parents[1]
    end

    def test_getting_revisions_with_leading_and_trailing_spaces_in_filename
      assert_equal(
        " filename with a leading space.txt ",
        @adapter.revisions(" filename with a leading space.txt ",
                           nil, "master")[0].paths[0][:path]
      )
    end

    def test_getting_entries_with_leading_and_trailing_spaces_in_filename
      assert_equal(
        " filename with a leading space.txt ",
        @adapter.entries(
          '',
          '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c'
        )[3].name
      )
    end

    def test_annotate
      annotate = @adapter.annotate('sources/watchers_controller.rb')
      assert_kind_of Redmine::Scm::Adapters::Annotate, annotate
      assert_equal 41, annotate.lines.size
      assert_equal "# This program is free software; you can redistribute it and/or",
                   annotate.lines[4].strip
      assert_equal "7234cb2750b63f47bff735edc50a1c0a433c2518",
                   annotate.revisions[4].identifier
      assert_equal "jsmith", annotate.revisions[4].author
    end

    def test_annotate_latin_1_identifier
      if WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        annotate = @adapter.annotate('sources/watchers_controller.rb',
                                     "latin-1-branch-#{@char_1}-02")
        assert_equal 40, annotate.lines.size
        assert_equal "# This program is free software; you can redistribute it and/or",
                     annotate.lines[3].strip
        assert_equal "7234cb2750b63f47bff735edc50a1c0a433c2518",
                     annotate.revisions[3].identifier
        assert_equal "jsmith", annotate.revisions[3].author
      end
    end

    def test_annotate_moved_file
      annotate = @adapter.annotate('renamed_test.txt')
      assert_kind_of Redmine::Scm::Adapters::Annotate, annotate
      assert_equal 2, annotate.lines.size
    end

    def test_last_rev
      last_rev = @adapter.lastrev("README",
                                  "4f26664364207fa8b1af9f8722647ab2d4ac5d43")
      assert_equal "4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8", last_rev.scmid
      assert_equal "4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8", last_rev.identifier
      assert_equal "Adam Soltys <asoltys@gmail.com>", last_rev.author
      assert_equal Time.gm(2009, 6, 24, 5, 27, 38), last_rev.time
    end

    def test_last_rev_with_spaces_in_filename
      last_rev = @adapter.lastrev("filemane with spaces.txt",
                                  "ed5bb786bbda2dee66a2d50faf51429dbc043a7b")
      assert_equal "ed5bb786bbda2dee66a2d50faf51429dbc043a7b", last_rev.scmid
      assert_equal "ed5bb786bbda2dee66a2d50faf51429dbc043a7b", last_rev.identifier
      assert_equal "#{@str_felix_hex} <felix@fachschaften.org>",
                   last_rev.author
      assert_equal Time.gm(2010, 9, 18, 19, 59, 46), last_rev.time
    end

    def test_latin_1_path
      if WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        p2 = "latin-1-dir/test-#{@char_1}-2.txt"
        ['4fc55c43bf3d3dc2efb66145365ddc17639ce81e', '4fc55c43bf3'].each do |r1|
          assert @adapter.diff(p2, r1)
          assert @adapter.cat(p2, r1)
          assert_equal 1, @adapter.annotate(p2, r1).lines.length
          ['64f1f3e89ad1cb57976ff0ad99a107012ba3481d', '64f1f3e89ad1cb5797'].each do |r2|
            assert @adapter.diff(p2, r1, r2)
          end
        end
      end
    end

    def test_latin_1_user_annotate
      ['83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', '83ca5fd546063a'].each do |r1|
        annotate = @adapter.annotate(" filename with a leading space.txt ", r1)
        assert_kind_of Redmine::Scm::Adapters::Annotate, annotate
        assert_equal 1, annotate.lines.size
        assert_equal "And this is a file with a leading and trailing space...",
                     annotate.lines[0].strip
        assert_equal "83ca5fd546063a3c7dc2e568ba3355661a9e2b2c",
                     annotate.revisions[0].identifier
        assert_equal @str_felix_hex, annotate.revisions[0].author
      end
    end

    def test_entries_tag
      entries1 = @adapter.entries(nil, 'tag01.annotated',
                                  options = {:report_last_commit => true})
      assert entries1
      assert_equal 3, entries1.size
      assert_equal 'sources', entries1[1].name
      assert_equal 'sources', entries1[1].path
      assert_equal 'dir', entries1[1].kind
      readme = entries1[2]
      assert_equal 'README', readme.name
      assert_equal 'README', readme.path
      assert_equal 'file', readme.kind
      assert_equal 27, readme.size
      assert_equal '899a15dba03a3b350b89c3f537e4bbe02a03cdc9', readme.lastrev.identifier
      assert_equal Time.gm(2007, 12, 14, 9, 24, 1), readme.lastrev.time
    end

    def test_entries_branch
      entries1 = @adapter.entries(nil, 'test_branch',
                                  options = {:report_last_commit => true})
      assert entries1
      assert_equal 4, entries1.size
      assert_equal 'sources', entries1[1].name
      assert_equal 'sources', entries1[1].path
      assert_equal 'dir', entries1[1].kind
      readme = entries1[2]
      assert_equal 'README', readme.name
      assert_equal 'README', readme.path
      assert_equal 'file', readme.kind
      assert_equal 159, readme.size
      assert_equal '713f4944648826f558cf548222f813dabe7cbb04', readme.lastrev.identifier
      assert_equal Time.gm(2009, 6, 19, 4, 37, 23), readme.lastrev.time
    end

    def test_entries_wrong_path_encoding
      adpt =
        Redmine::Scm::Adapters::GitAdapter.
          new(
            REPOSITORY_PATH,
            nil,
            nil,
            nil,
            'EUC-JP'
          )
      entries1 = adpt.entries('latin-1-dir', '64f1f3e8')
      assert entries1
      assert_equal 3, entries1.size
      f1 = entries1[1]
      assert_nil f1.name
      assert_nil f1.path
      assert_equal 'file', f1.kind
    end

    def test_entries_latin_1_files
      entries1 = @adapter.entries('latin-1-dir', '64f1f3e8')
      assert entries1
      assert_equal 3, entries1.size
      f1 = entries1[1]
      assert_equal "test-#{@char_1}-2.txt", f1.name
      assert_equal "latin-1-dir/test-#{@char_1}-2.txt", f1.path
      assert_equal 'file', f1.kind
    end

    def test_entries_latin_1_dir
      if WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        entries1 = @adapter.entries("latin-1-dir/test-#{@char_1}-subdir",
                                    '1ca7f5ed')
        assert entries1
        assert_equal 3, entries1.size
        f1 = entries1[1]
        assert_equal "test-#{@char_1}-2.txt", f1.name
        assert_equal "latin-1-dir/test-#{@char_1}-subdir/test-#{@char_1}-2.txt", f1.path
        assert_equal 'file', f1.kind
      end
    end

    def test_entries_latin_1_identifier
      if WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        entries1 = @adapter.entries(nil,
                                    "latin-1-branch-#{@char_1}-02")
        assert entries1
        assert_equal 4, entries1.size
        f1 = entries1[0]
        assert_equal "images", f1.name
        assert_equal "images", f1.path
        assert_equal 'dir', f1.kind
      end
    end

    def test_entry
      entry = @adapter.entry()
      assert_equal "", entry.path
      assert_equal "dir", entry.kind
      entry = @adapter.entry('')
      assert_equal "", entry.path
      assert_equal "dir", entry.kind
      assert_nil @adapter.entry('invalid')
      assert_nil @adapter.entry('/invalid')
      assert_nil @adapter.entry('/invalid/')
      assert_nil @adapter.entry('invalid/invalid')
      assert_nil @adapter.entry('invalid/invalid/')
      assert_nil @adapter.entry('/invalid/invalid')
      assert_nil @adapter.entry('/invalid/invalid/')
      ["README", "/README"].each do |path|
        entry = @adapter.entry(path, '7234cb2750b63f')
        assert_equal "README", entry.path
        assert_equal "file", entry.kind
      end
      ["sources", "/sources", "/sources/"].each do |path|
        entry = @adapter.entry(path, '7234cb2750b63f')
        assert_equal "sources", entry.path
        assert_equal "dir", entry.kind
      end
      ["sources/watchers_controller.rb", "/sources/watchers_controller.rb"].each do |path|
        entry = @adapter.entry(path, '7234cb2750b63f')
        assert_equal "sources/watchers_controller.rb", entry.path
        assert_equal "file", entry.kind
      end
    end

    def test_path_encoding_default_utf8
      adpt1 =
        Redmine::Scm::Adapters::GitAdapter.new(
          REPOSITORY_PATH
        )
      assert_equal "UTF-8", adpt1.path_encoding
      adpt2 =
        Redmine::Scm::Adapters::GitAdapter.new(
          REPOSITORY_PATH,
          nil,
          nil,
          nil,
          ""
        )
      assert_equal "UTF-8", adpt2.path_encoding
    end

    def test_cat_latin_1_identifier
      if WINDOWS_PASS
        puts WINDOWS_SKIP_STR
      elsif JRUBY_SKIP
        puts JRUBY_SKIP_STR
      else
        assert @adapter.cat('sources/watchers_controller.rb',
                            "latin-1-branch-#{@char_1}-02")
      end
    end

    def test_cat_path_invalid
      assert_nil @adapter.cat('invalid')
    end

    def test_cat_revision_invalid
      assert     @adapter.cat('README')
      assert_nil @adapter.cat('README', '1234abcd5678')
    end

    def test_diff_path_invalid
      assert_equal [], @adapter.diff('invalid', '713f4944648826f5')
    end

    def test_diff_revision_invalid
      assert_nil @adapter.diff(nil, '1234abcd5678')
      assert_nil @adapter.diff(nil, '713f4944648826f5', '1234abcd5678')
      assert_nil @adapter.diff(nil, '1234abcd5678', '713f4944648826f5')
    end

    def test_annotate_path_invalid
      assert_nil @adapter.annotate('invalid')
    end

    def test_annotate_revision_invalid
      assert     @adapter.annotate('README')
      assert_nil @adapter.annotate('README', '1234abcd5678')
    end

    private

    def test_scm_version_for(scm_command_version, version)
      @adapter.class.expects(:scm_version_from_command_line).returns(scm_command_version)
      assert_equal version, @adapter.class.scm_command_version
    end

  else
    puts "Git test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
