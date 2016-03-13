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

require File.expand_path('../../../../../../test_helper', __FILE__)

class MercurialAdapterTest < ActiveSupport::TestCase
  HELPERS_DIR        = Redmine::Scm::Adapters::MercurialAdapter::HELPERS_DIR
  TEMPLATE_NAME      = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATE_NAME
  TEMPLATE_EXTENSION = Redmine::Scm::Adapters::MercurialAdapter::TEMPLATE_EXTENSION

  REPOSITORY_PATH = repository_path('mercurial')
  CHAR_1_HEX = "\xc3\x9c"

  if File.directory?(REPOSITORY_PATH)
    def setup
      adapter_class = Redmine::Scm::Adapters::MercurialAdapter
      assert adapter_class
      assert adapter_class.client_command
      assert_equal true, adapter_class.client_available
      assert_equal true, adapter_class.client_version_above?([0, 9, 5])

      @adapter = Redmine::Scm::Adapters::MercurialAdapter.new(
                            REPOSITORY_PATH,
                            nil,
                            nil,
                            nil,
                           'ISO-8859-1')
      @diff_c_support = true
      @char_1        = CHAR_1_HEX.dup.force_encoding('UTF-8')
      @tag_char_1    = "tag-#{CHAR_1_HEX}-00".force_encoding('UTF-8')
      @branch_char_0 = "branch-#{CHAR_1_HEX}-00".force_encoding('UTF-8')
      @branch_char_1 = "branch-#{CHAR_1_HEX}-01".force_encoding('UTF-8')
    end

    def test_hgversion
      to_test = { "Mercurial Distributed SCM (version 0.9.5)\n"  => [0,9,5],
                  "Mercurial Distributed SCM (1.0)\n"            => [1,0],
                  "Mercurial Distributed SCM (1e4ddc9ac9f7+20080325)\n" => nil,
                  "Mercurial Distributed SCM (1.0.1+20080525)\n" => [1,0,1],
                  "Mercurial Distributed SCM (1916e629a29d)\n"   => nil,
                  "Mercurial SCM Distribuito (versione 0.9.5)\n" => [0,9,5],
                  "(1.6)\n(1.7)\n(1.8)"                          => [1,6],
                  "(1.7.1)\r\n(1.8.1)\r\n(1.9.1)"                => [1,7,1]}

      to_test.each do |s, v|
        test_hgversion_for(s, v)
      end
    end

    def test_template_path
      to_test = {
                  [1,2]    => "1.0",
                  []       => "1.0",
                  [1,2,1]  => "1.0",
                  [1,7]    => "1.0",
                  [1,7,1]  => "1.0",
                  [2,0]    => "1.0",
                 }
      to_test.each do |v, template|
        test_template_path_for(v, template)
      end
    end

    def test_info
      [REPOSITORY_PATH, REPOSITORY_PATH + "/",
           REPOSITORY_PATH + "//"].each do |repo|
        adp = Redmine::Scm::Adapters::MercurialAdapter.new(repo)
        repo_path =  adp.info.root_url.gsub(/\\/, "/")
        assert_equal REPOSITORY_PATH, repo_path
        assert_equal '33', adp.info.lastrev.revision
        assert_equal '2e6d546429230f377d7d19c2078abd2dd909f235',adp.info.lastrev.scmid
      end
    end

    def test_revisions
      revisions = @adapter.revisions(nil, 2, 4)
      assert_equal 3, revisions.size
      assert_equal '2', revisions[0].revision
      assert_equal '400bb86721098697c7d17b3724c794c57636de70', revisions[0].scmid
      assert_equal '4', revisions[2].revision
      assert_equal 'def6d2f1254a56fb8fbe9ec3b5c0451674dbd8b8', revisions[2].scmid

      revisions = @adapter.revisions(nil, 2, 4, {:limit => 2})
      assert_equal 2, revisions.size
      assert_equal '2', revisions[0].revision
      assert_equal '400bb86721098697c7d17b3724c794c57636de70', revisions[0].scmid
    end

    def test_parents
      revs1 = @adapter.revisions(nil, 0, 0)
      assert_equal 1, revs1.size
      assert_equal [], revs1[0].parents
      revs2 = @adapter.revisions(nil, 1, 1)
      assert_equal 1, revs2.size
      assert_equal 1, revs2[0].parents.size
      assert_equal "0885933ad4f68d77c2649cd11f8311276e7ef7ce", revs2[0].parents[0]
      revs3 = @adapter.revisions(nil, 30, 30)
      assert_equal 1, revs3.size
      assert_equal 2, revs3[0].parents.size
      assert_equal "a94b0528f24fe05ebaef496ae0500bb050772e36", revs3[0].parents[0]
      assert_equal "3a330eb329586ea2adb3f83237c23310e744ebe9", revs3[0].parents[1]
    end

    def test_diff
      if @adapter.class.client_version_above?([1, 2])
        assert_nil @adapter.diff(nil, '100000')
      end
      assert_nil @adapter.diff(nil, '100000', '200000')
      [2, '400bb8672109', '400', 400].each do |r1|
        diff1 = @adapter.diff(nil, r1)
        if @diff_c_support
          assert_equal 28, diff1.size
          buf = diff1[24].gsub(/\r\n|\r|\n/, "")
          assert_equal "+    return true unless klass.respond_to?('watched_by')", buf
        else
          assert_equal 0, diff1.size
        end
        [4, 'def6d2f1254a'].each do |r2|
          diff2 = @adapter.diff(nil, r1, r2)
          assert_equal 49, diff2.size
          buf =  diff2[41].gsub(/\r\n|\r|\n/, "")
          assert_equal "+class WelcomeController < ApplicationController", buf
          diff3 = @adapter.diff('sources/watchers_controller.rb', r1, r2)
          assert_equal 20, diff3.size
          buf =  diff3[12].gsub(/\r\n|\r|\n/, "")
          assert_equal "+    @watched.remove_watcher(user)", buf

          diff4 = @adapter.diff(nil, r2, r1)
          assert_equal 49, diff4.size
          buf =  diff4[41].gsub(/\r\n|\r|\n/, "")
          assert_equal "-class WelcomeController < ApplicationController", buf
          diff5 = @adapter.diff('sources/watchers_controller.rb', r2, r1)
          assert_equal 20, diff5.size
          buf =  diff5[9].gsub(/\r\n|\r|\n/, "")
          assert_equal "-    @watched.remove_watcher(user)", buf
        end
      end
    end

    def test_diff_made_by_revision
      if @diff_c_support
        [24, '24', '4cddb4e45f52'].each do |r1|
          diff1 = @adapter.diff(nil, r1)
          assert_equal 5, diff1.size
          buf = diff1[4].gsub(/\r\n|\r|\n/, "")
          assert_equal '+0885933ad4f68d77c2649cd11f8311276e7ef7ce tag-init-revision', buf
        end
      end
    end

    def test_cat
      [2, '400bb8672109', '400', 400].each do |r|
        buf = @adapter.cat('sources/welcome_controller.rb', r)
        assert buf
        lines = buf.split("\r\n")
        assert_equal 25, lines.length
        assert_equal 'class WelcomeController < ApplicationController', lines[17]
      end
      assert_nil @adapter.cat('sources/welcome_controller.rb')
    end

    def test_annotate
      assert_equal [], @adapter.annotate("sources/welcome_controller.rb").lines
      [2, '400bb8672109', '400', 400].each do |r|
        ann = @adapter.annotate('sources/welcome_controller.rb', r)
        assert ann
        assert_equal '1', ann.revisions[17].revision
        assert_equal '9d5b5b004199', ann.revisions[17].identifier
        assert_equal 'jsmith', ann.revisions[0].author
        assert_equal 25, ann.lines.length
        assert_equal 'class WelcomeController < ApplicationController', ann.lines[17]
      end
    end

    def test_entries
      assert_nil @adapter.entries(nil, '100000')

      assert_equal 1, @adapter.entries("sources", 3).size
      assert_equal 1, @adapter.entries("sources", 'b3a615152df8').size

      [2, '400bb8672109', '400', 400].each do |r|
        entries1 = @adapter.entries(nil, r)
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
        assert_equal '1', readme.lastrev.revision
        assert_equal '9d5b5b00419901478496242e0768deba1ce8c51e', readme.lastrev.identifier
        # 2007-12-14 10:24:01 +0100
        assert_equal Time.gm(2007, 12, 14, 9, 24, 1), readme.lastrev.time

        entries2 = @adapter.entries('sources', r)
        assert entries2
        assert_equal 2, entries2.size
        assert_equal 'watchers_controller.rb', entries2[0].name
        assert_equal 'sources/watchers_controller.rb', entries2[0].path
        assert_equal 'file', entries2[0].kind
        assert_equal 'welcome_controller.rb', entries2[1].name
        assert_equal 'sources/welcome_controller.rb', entries2[1].path
        assert_equal 'file', entries2[1].kind
      end
    end

    def test_entries_tag
      entries1 = @adapter.entries(nil, 'tag_test.00')
      assert entries1
      assert_equal 3, entries1.size
      assert_equal 'sources', entries1[1].name
      assert_equal 'sources', entries1[1].path
      assert_equal 'dir', entries1[1].kind
      readme = entries1[2]
      assert_equal 'README', readme.name
      assert_equal 'README', readme.path
      assert_equal 'file', readme.kind
      assert_equal 21, readme.size
      assert_equal '0', readme.lastrev.revision
      assert_equal '0885933ad4f68d77c2649cd11f8311276e7ef7ce', readme.lastrev.identifier
      # 2007-12-14 10:22:52 +0100
      assert_equal Time.gm(2007, 12, 14, 9, 22, 52), readme.lastrev.time
    end

    def test_entries_branch
      entries1 = @adapter.entries(nil, 'test-branch-00')
      assert entries1
      assert_equal 5, entries1.size
      assert_equal 'sql_escape', entries1[2].name
      assert_equal 'sql_escape', entries1[2].path
      assert_equal 'dir', entries1[2].kind
      readme = entries1[4]
      assert_equal 'README', readme.name
      assert_equal 'README', readme.path
      assert_equal 'file', readme.kind
      assert_equal 365, readme.size
      assert_equal '8', readme.lastrev.revision
      assert_equal 'c51f5bb613cd60793c2a9fe9df29332e74bb949f', readme.lastrev.identifier
      # 2001-02-01 00:00:00 -0900
      assert_equal Time.gm(2001, 2, 1, 9, 0, 0), readme.lastrev.time
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
        ["0", "0885933ad4f6", "0885933ad4f68d77c2649cd11f8311276e7ef7ce"].each do |rev|
          entry = @adapter.entry(path, rev)
          assert_equal "README", entry.path
          assert_equal "file", entry.kind
          assert_equal '0', entry.lastrev.revision
          assert_equal '0885933ad4f68d77c2649cd11f8311276e7ef7ce', entry.lastrev.identifier
        end
      end
      ["sources", "/sources", "/sources/"].each do |path|
        ["0", "0885933ad4f6", "0885933ad4f68d77c2649cd11f8311276e7ef7ce"].each do |rev|
          entry = @adapter.entry(path, rev)
          assert_equal "sources", entry.path
          assert_equal "dir", entry.kind
        end
      end
      ["sources/watchers_controller.rb", "/sources/watchers_controller.rb"].each do |path|
        ["0", "0885933ad4f6", "0885933ad4f68d77c2649cd11f8311276e7ef7ce"].each do |rev|
          entry = @adapter.entry(path, rev)
          assert_equal "sources/watchers_controller.rb", entry.path
          assert_equal "file", entry.kind
          assert_equal '0', entry.lastrev.revision
          assert_equal '0885933ad4f68d77c2649cd11f8311276e7ef7ce', entry.lastrev.identifier
        end
      end
    end

    def test_locate_on_outdated_repository
      assert_equal 1, @adapter.entries("images", 0).size
      assert_equal 2, @adapter.entries("images").size
      assert_equal 2, @adapter.entries("images", 2).size
    end

    def test_access_by_nodeid
      path = 'sources/welcome_controller.rb'
      assert_equal @adapter.cat(path, 2), @adapter.cat(path, '400bb8672109')
    end

    def test_access_by_fuzzy_nodeid
      path = 'sources/welcome_controller.rb'
      # falls back to nodeid
      assert_equal @adapter.cat(path, 2), @adapter.cat(path, '400')
    end

    def test_tags
      assert_equal [@tag_char_1, 'tag_test.00', 'tag-init-revision'], @adapter.tags
    end

    def test_tagmap
      tm = {
        @tag_char_1         => 'adf805632193500ad3b615cd04f58f9b0769f576',
        'tag_test.00'       => '6987191f453a5f6557018d522feea2c450d5588d',
        'tag-init-revision' => '0885933ad4f68d77c2649cd11f8311276e7ef7ce',
        }
      assert_equal tm, @adapter.tagmap
    end

    def test_branches
      brs = []
      @adapter.branches.each do |b|
        brs << b
      end
      assert_equal 7, brs.length
      assert_equal 'default', brs[0].to_s
      assert_equal '31', brs[0].revision
      assert_equal '31eeee7395c8c78e66dd54c50addd078d10b2355', brs[0].scmid
      assert_equal 'test-branch-01', brs[1].to_s
      assert_equal '30', brs[1].revision
      assert_equal 'ad4dc4f80284a4f9168b77e0b6de288e5d207ee7', brs[1].scmid
      assert_equal @branch_char_1, brs[2].to_s
      assert_equal '27', brs[2].revision
      assert_equal '7bbf4c738e7145149d2e5eb1eed1d3a8ddd3b914', brs[2].scmid
      assert_equal 'branch (1)[2]&,%.-3_4', brs[3].to_s
      assert_equal '25', brs[3].revision
      assert_equal 'afc61e85bde74de930e5846c8451bd55b5bafc9c', brs[3].scmid
      assert_equal @branch_char_0, brs[4].to_s
      assert_equal '23', brs[4].revision
      assert_equal 'c8d3e4887474af6a589190140508037ebaa9d9c3', brs[4].scmid
      assert_equal 'test_branch.latin-1', brs[5].to_s
      assert_equal '22', brs[5].revision
      assert_equal 'c2ffe7da686aa3d956e59f2a2854cf8980a8b768', brs[5].scmid
      assert_equal 'test-branch-00', brs[6].to_s
      assert_equal '13', brs[6].revision
      assert_equal '3a330eb329586ea2adb3f83237c23310e744ebe9', brs[6].scmid
    end

    def test_branchmap
      bm = {
         'default'               => '31eeee7395c8c78e66dd54c50addd078d10b2355',
         'test_branch.latin-1'   => 'c2ffe7da686aa3d956e59f2a2854cf8980a8b768',
         'branch (1)[2]&,%.-3_4' => 'afc61e85bde74de930e5846c8451bd55b5bafc9c',
         'test-branch-00'        => '3a330eb329586ea2adb3f83237c23310e744ebe9',
         "test-branch-01"        => 'ad4dc4f80284a4f9168b77e0b6de288e5d207ee7',
         @branch_char_0          => 'c8d3e4887474af6a589190140508037ebaa9d9c3',
         @branch_char_1          => '7bbf4c738e7145149d2e5eb1eed1d3a8ddd3b914',
       }
      assert_equal bm, @adapter.branchmap
    end

    def test_path_space
      p = 'README (1)[2]&,%.-3_4'
      [15, '933ca60293d7'].each do |r1|
        assert @adapter.diff(p, r1)
        assert @adapter.cat(p, r1)
        assert_equal 1, @adapter.annotate(p, r1).lines.length
        [25, 'afc61e85bde7'].each do |r2|
          assert @adapter.diff(p, r1, r2)
        end
      end
    end

    def test_tag_non_ascii
      p = "latin-1-dir/test-#{@char_1}-1.txt"
      assert @adapter.cat(p, @tag_char_1)
      assert_equal 1, @adapter.annotate(p, @tag_char_1).lines.length
    end

    def test_branch_non_ascii
      p = "latin-1-dir/test-#{@char_1}-subdir/test-#{@char_1}-1.txt"
      assert @adapter.cat(p, @branch_char_1)
      assert_equal 1, @adapter.annotate(p, @branch_char_1).lines.length
    end

    def test_nodes_in_branch
       [
          'default',
          @branch_char_1,
          'branch (1)[2]&,%.-3_4',
          @branch_char_0,
          'test_branch.latin-1',
          'test-branch-00',
             ].each do |bra|
        nib0 = @adapter.nodes_in_branch(bra)
        assert nib0
        nib1 = @adapter.nodes_in_branch(bra, :limit => 1)
        assert_equal 1, nib1.size
        case bra
          when 'branch (1)[2]&,%.-3_4'
            if @adapter.class.client_version_above?([1, 6])
              assert_equal 3, nib0.size
              assert_equal 'afc61e85bde74de930e5846c8451bd55b5bafc9c', nib0[0]
              nib2 = @adapter.nodes_in_branch(bra, :limit => 2)
              assert_equal 2, nib2.size
              assert_equal '933ca60293d78f7c7979dd123cc0c02431683575', nib2[1]
            end
          when @branch_char_1
            if @adapter.class.client_version_above?([1, 6])
              assert_equal 2, nib0.size
              assert_equal '08ff3227303ec0dfcc818efa8e9cc652fe81859f', nib0[1]
              nib2 = @adapter.nodes_in_branch(bra, :limit => 1)
              assert_equal 1, nib2.size
              assert_equal '7bbf4c738e7145149d2e5eb1eed1d3a8ddd3b914', nib2[0]
            end
        end
      end
    end

    def test_path_encoding_default_utf8
      adpt1 = Redmine::Scm::Adapters::MercurialAdapter.new(
                                REPOSITORY_PATH
                              )
      assert_equal "UTF-8", adpt1.path_encoding
      adpt2 = Redmine::Scm::Adapters::MercurialAdapter.new(
                                REPOSITORY_PATH,
                                nil,
                                nil,
                                nil,
                                ""
                              )
      assert_equal "UTF-8", adpt2.path_encoding
    end

    private

    def test_hgversion_for(hgversion, version)
      @adapter.class.expects(:hgversion_from_command_line).returns(hgversion)
      assert_equal version, @adapter.class.hgversion
    end

    def test_template_path_for(version, template)
      assert_equal "#{HELPERS_DIR}/#{TEMPLATE_NAME}-#{template}.#{TEMPLATE_EXTENSION}",
                   @adapter.class.template_path_for(version)
      assert File.exist?(@adapter.class.template_path_for(version))
    end
  else
    puts "Mercurial test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
