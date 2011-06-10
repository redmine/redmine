# encoding: utf-8

# This file includes UTF-8 "Felix Schäfer".
# We need to consider Ruby 1.9 compatibility.

require File.expand_path('../../../../../../test_helper', __FILE__)
begin
  require 'mocha'

  class GitAdapterTest < ActiveSupport::TestCase
    REPOSITORY_PATH = Rails.root.join('tmp/test/git_repository').to_s

    FELIX_UTF8 = "Felix Schäfer"
    FELIX_HEX  = "Felix Sch\xC3\xA4fer"
    CHAR_1_HEX = "\xc3\x9c"

    ## Ruby uses ANSI api to fork a process on Windows.
    ## Japanese Shift_JIS and Traditional Chinese Big5 have 0x5c(backslash) problem
    ## and these are incompatible with ASCII.
    # WINDOWS_PASS = Redmine::Platform.mswin?
    WINDOWS_PASS = false

    ## Git, Mercurial and CVS path encodings are binary.
    ## Subversion supports URL encoding for path.
    ## Redmine Mercurial adapter and extension use URL encoding.
    ## Git accepts only binary path in command line parameter.
    ## So, there is no way to use binary command line parameter in JRuby.
    JRUBY_SKIP     = (RUBY_PLATFORM == 'java')
    JRUBY_SKIP_STR = "TODO: This test fails in JRuby"

    if File.directory?(REPOSITORY_PATH)
      def setup
        adapter_class = Redmine::Scm::Adapters::GitAdapter
        assert adapter_class
        assert adapter_class.client_command
        assert_equal true, adapter_class.client_available
        assert_equal true, adapter_class.client_version_above?([1])
        assert_equal true, adapter_class.client_version_above?([1, 0])

        @adapter = Redmine::Scm::Adapters::GitAdapter.new(
                      REPOSITORY_PATH,
                      nil,
                      nil,
                      nil,
                      'ISO-8859-1'
                      )
        assert @adapter
        @char_1        = CHAR_1_HEX.dup
        if @char_1.respond_to?(:force_encoding)
          @char_1.force_encoding('UTF-8')
        end
      end

      def test_scm_version
        to_test = { "git version 1.7.3.4\n"             => [1,7,3,4],
                    "1.6.1\n1.7\n1.8"                   => [1,6,1],
                    "1.6.2\r\n1.8.1\r\n1.9.1"           => [1,6,2]}
        to_test.each do |s, v|
          test_scm_version_for(s, v)
        end
      end

      def test_branches
        assert_equal  [
              'latin-1-path-encoding',
              'master',
              'test-latin-1',
              'test_branch',
            ], @adapter.branches
      end

      def test_tags
        assert_equal  [
              "tag00.lightweight",
              "tag01.annotated",
            ], @adapter.tags
      end

      def test_getting_all_revisions
        assert_equal 21, @adapter.revisions('',nil,nil,:all => true).length
      end

      def test_getting_certain_revisions
        assert_equal 1, @adapter.revisions('','899a15d^','899a15d').length
      end

      def test_revisions_reverse
        revs1 = @adapter.revisions('',nil,nil,{:all => true, :reverse => true })
        assert_equal 21, revs1.length
        assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs1[0].identifier
        assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs1[20].identifier
      end

      def test_revisions_reverse_with_time
        since2 = Time.gm(2010, 9, 30, 0, 0, 0)
        revs2  = @adapter.revisions('', nil, nil,
                                    {:all => true, :since => since2, :reverse => true})
        assert_equal 6, revs2.length
        assert_equal '67e7792ce20ccae2e4bb73eed09bb397819c8834', revs2[0].identifier
        assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs2[5].identifier
      end

      def test_revisions_master_all
        revs1 = []
        @adapter.revisions('', nil, "master",{}) do |rev|
          revs1 << rev
        end
        assert_equal 15, revs1.length
        assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[ 0].identifier
        assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs1[-1].identifier

        revs2 = []
        @adapter.revisions('', nil, "master",
                                    {:reverse => true}) do |rev|
          revs2 << rev
        end
        assert_equal 15, revs2.length
        assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs2[-1].identifier
        assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs2[ 0].identifier
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
        assert_equal 'fba357b886984ee71185ad2065e65fc0417d9b92', revs1[ 0].identifier
        assert_equal '7e61ac704deecde634b51e59daa8110435dcb3da', revs1[ 1].identifier
        # 4a07fe31b is not a child of 713f49446
        assert_equal '4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8', revs1[ 2].identifier
        # Merged revision
        assert_equal '32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf', revs1[ 3].identifier
        assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs1[-1].identifier

        revs2 = []
        @adapter.revisions('',
                           "fba357b886984ee71185ad2065e65fc0417d9b92",
                           "master",
                           {:reverse => true}) do |rev|
          revs2 << rev
        end
        assert_equal 7, revs2.length
        assert_equal '7e61ac704deecde634b51e59daa8110435dcb3da', revs2[ 0].identifier
        # 4a07fe31b is not a child of fba357b8869
        assert_equal '4a07fe31bffcf2888791f3e6cbc9c4545cefe3e8', revs2[ 1].identifier
        # Merged revision
        assert_equal '32ae898b720c2f7eec2723d5bdd558b4cb2d3ddf', revs2[ 2].identifier
        assert_equal '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c', revs2[-1].identifier
      end

      def test_revisions_branch_latin_1_path_encoding_all
        revs1 = []
        @adapter.revisions('', nil, "latin-1-path-encoding",{}) do |rev|
          revs1 << rev
        end
        assert_equal 8, revs1.length
        assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs1[ 0].identifier
        assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs1[-1].identifier

        revs2 = []
        @adapter.revisions('', nil, "latin-1-path-encoding",
                                    {:reverse => true}) do |rev|
          revs2 << rev
        end
        assert_equal 8, revs2.length
        assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs2[-1].identifier
        assert_equal '7234cb2750b63f47bff735edc50a1c0a433c2518', revs2[ 0].identifier
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
        assert_equal '899a15dba03a3b350b89c3f537e4bbe02a03cdc9', revs1[ 0].identifier
        assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs1[-1].identifier

        revs2 = []
        @adapter.revisions('',
                           '57ca437c0acbbcb749821fdf3726a1367056d364',
                           "latin-1-path-encoding",
                           {:reverse => true}) do |rev|
          revs2 << rev
        end
        assert_equal 3, revs2.length
        assert_equal '4fc55c43bf3d3dc2efb66145365ddc17639ce81e', revs2[ 0].identifier
        assert_equal '1ca7f5ed374f3cb31a93ae5215c2e25cc6ec5127', revs2[-1].identifier
      end

      def test_revisions_invalid_rev
        revs1 = []
        @adapter.revisions('',
                                    '1234abcd',
                                    "master",
                                    {:reverse => true}) do |rev|
          revs1 << rev
        end
        assert_equal [], revs1
      end

      def test_getting_revisions_with_spaces_in_filename
        assert_equal 1, @adapter.revisions("filemane with spaces.txt",
                                           nil, nil, :all => true).length
      end

      def test_getting_revisions_with_leading_and_trailing_spaces_in_filename
        assert_equal " filename with a leading space.txt ",
           @adapter.revisions(" filename with a leading space.txt ",
                               nil, nil, :all => true)[0].paths[0][:path]
      end

      def test_getting_entries_with_leading_and_trailing_spaces_in_filename
        assert_equal " filename with a leading space.txt ",
           @adapter.entries('',
                   '83ca5fd546063a3c7dc2e568ba3355661a9e2b2c')[3].name
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
        assert_equal "2009-06-24 05:27:38".to_time, last_rev.time
      end

      def test_last_rev_with_spaces_in_filename
        last_rev = @adapter.lastrev("filemane with spaces.txt",
                                    "ed5bb786bbda2dee66a2d50faf51429dbc043a7b")
        str_felix_utf8 = FELIX_UTF8.dup
        str_felix_hex  = FELIX_HEX.dup
        last_rev_author = last_rev.author
        if last_rev_author.respond_to?(:force_encoding)
          last_rev_author.force_encoding('UTF-8')
        end
        assert_equal "ed5bb786bbda2dee66a2d50faf51429dbc043a7b", last_rev.scmid
        assert_equal "ed5bb786bbda2dee66a2d50faf51429dbc043a7b", last_rev.identifier
        assert_equal "#{str_felix_utf8} <felix@fachschaften.org>",
                       last_rev.author
        assert_equal "#{str_felix_hex} <felix@fachschaften.org>",
                       last_rev.author
        assert_equal "2010-09-18 19:59:46".to_time, last_rev.time
      end

      def test_latin_1_path
        if WINDOWS_PASS
          #
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
          #
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

      def test_path_encoding_default_utf8
        adpt1 = Redmine::Scm::Adapters::GitAdapter.new(
                                  REPOSITORY_PATH
                                )
        assert_equal "UTF-8", adpt1.path_encoding
        adpt2 = Redmine::Scm::Adapters::GitAdapter.new(
                                  REPOSITORY_PATH,
                                  nil,
                                  nil,
                                  nil,
                                  ""
                                )
        assert_equal "UTF-8", adpt2.path_encoding
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

rescue LoadError
  class GitMochaFake < ActiveSupport::TestCase
    def test_fake; assert(false, "Requires mocha to run those tests")  end
  end
end
