# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class BazaarAdapterTest < ActiveSupport::TestCase
  REPOSITORY_PATH = Rails.root.join('tmp/test/bazaar_repository').to_s
  REPOSITORY_PATH.gsub!(/\/+/, '/')

  if File.directory?(REPOSITORY_PATH)
    def setup
      @adapter = Redmine::Scm::Adapters::BazaarAdapter.new(
                              File.join(REPOSITORY_PATH, "trunk")
                              )
    end

    def test_scm_version
      to_test = { "Bazaar (bzr) 2.1.2\n"             => [2,1,2],
                  "2.1.1\n1.7\n1.8"                  => [2,1,1],
                  "2.0.1\r\n1.8.1\r\n1.9.1"          => [2,0,1]}
      to_test.each do |s, v|
        test_scm_version_for(s, v)
      end
    end

    def test_cat
      cat = @adapter.cat('directory/document.txt')
      assert cat =~ /Write the contents of a file as of a given revision to standard output/
    end

    def test_cat_path_invalid
      assert_nil @adapter.cat('invalid')
    end

    def test_cat_revision_invalid
      assert_nil @adapter.cat('doc-mkdir.txt', '12345678')
    end

    def test_diff
      diff1 = @adapter.diff('doc-mkdir.txt', 3, 2)
      assert_equal 21, diff1.size
      buf =  diff1[14].gsub(/\r\n|\r|\n/, "")
      assert_equal "-Display more information.", buf
    end

    def test_diff_path_invalid
      assert_equal [], @adapter.diff('invalid', 1)
    end

    def test_diff_revision_invalid
      assert_equal [], @adapter.diff(nil, 12345678)
      assert_equal [], @adapter.diff(nil, 12345678, 87654321)
    end

    def test_annotate
      annotate = @adapter.annotate('doc-mkdir.txt')
      assert_equal 17, annotate.lines.size
      assert_equal '1', annotate.revisions[0].identifier
      assert_equal 'jsmith@', annotate.revisions[0].author
      assert_equal 'mkdir', annotate.lines[0]
    end

    def test_annotate_path_invalid
      assert_nil @adapter.annotate('invalid')
    end

    def test_annotate_revision_invalid
      assert_nil @adapter.annotate('doc-mkdir.txt', '12345678')
    end

    def test_branch_conf_path
      p = "c:\\test\\test\\"
      bcp = Redmine::Scm::Adapters::BazaarAdapter.branch_conf_path(p)
      assert_equal File.join("c:\\test\\test", ".bzr", "branch", "branch.conf"), bcp
      p = "c:\\test\\test\\.bzr"
      bcp = Redmine::Scm::Adapters::BazaarAdapter.branch_conf_path(p)
      assert_equal File.join("c:\\test\\test", ".bzr", "branch", "branch.conf"), bcp
      p = "c:\\test\\test\\.bzr\\"
      bcp = Redmine::Scm::Adapters::BazaarAdapter.branch_conf_path(p)
      assert_equal File.join("c:\\test\\test", ".bzr", "branch", "branch.conf"), bcp
      p = "c:\\test\\test"
      bcp = Redmine::Scm::Adapters::BazaarAdapter.branch_conf_path(p)
      assert_equal File.join("c:\\test\\test", ".bzr", "branch", "branch.conf"), bcp
      p = "\\\\server\\test\\test\\"
      bcp = Redmine::Scm::Adapters::BazaarAdapter.branch_conf_path(p)
      assert_equal File.join("\\\\server\\test\\test", ".bzr", "branch", "branch.conf"), bcp
    end

    def test_append_revisions_only_true
      assert_equal true, @adapter.append_revisions_only
    end

    def test_append_revisions_only_false
      adpt = Redmine::Scm::Adapters::BazaarAdapter.new(
                              File.join(REPOSITORY_PATH, "empty-branch")
                              )
      assert_equal false, adpt.append_revisions_only
    end

    def test_append_revisions_only_shared_repo
      adpt = Redmine::Scm::Adapters::BazaarAdapter.new(
                              REPOSITORY_PATH
                              )
      assert_equal false, adpt.append_revisions_only
    end

    def test_info_not_nil
      assert_not_nil @adapter.info
    end

    def test_info_nil
      adpt = Redmine::Scm::Adapters::BazaarAdapter.new(
                "/invalid/invalid/"
                )
      assert_nil adpt.info
    end

    def test_info
      info = @adapter.info
      assert_equal 4, info.lastrev.identifier.to_i
    end

    def test_info_emtpy
      adpt = Redmine::Scm::Adapters::BazaarAdapter.new(
                              File.join(REPOSITORY_PATH, "empty-branch")
                              )
      assert_equal 0, adpt.info.lastrev.identifier.to_i
    end

    def test_entries_path_invalid
      assert_equal [], @adapter.entries('invalid')
    end

    def test_entries_revision_invalid
      assert_nil @adapter.entries(nil, 12345678)
    end

    def test_revisions
      revisions = @adapter.revisions(nil, 4, 2)
      assert_equal 3, revisions.size
      assert_equal 2, revisions[2].identifier
      assert_equal 'jsmith@foo.bar-20071203175224-v0eog5d5wrgdrshg', revisions[2].scmid
      assert_equal 4, revisions[0].identifier
      assert_equal 'jsmith@foo.bar-20071203175422-t40bf8li5zz0c4cg', revisions[0].scmid
      assert_equal 2, revisions[0].paths.size
      assert_equal 'D', revisions[0].paths[0][:action]
      assert_equal '/doc-deleted.txt', revisions[0].paths[0][:path]
      assert_equal 'docdeleted.txt-20071203175320-iwwj561ojuubs3gt-1', revisions[0].paths[0][:revision]
      assert_equal 'M', revisions[0].paths[1][:action]
      assert_equal '/directory/doc-ls.txt', revisions[0].paths[1][:path]
      assert_equal 'docls.txt-20071203175005-a3hyc3mn0shl7cgu-1', revisions[0].paths[1][:revision]
    end

    def test_revisions_path_invalid
      assert_nil @adapter.revisions('invalid')
    end

    def test_revisions_revision_invalid
      assert_nil @adapter.revisions(nil, 12345678)
      assert_nil @adapter.revisions(nil, 12345678, 87654321)
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
      ["doc-ls.txt", "/doc-ls.txt"].each do |path|
        entry = @adapter.entry(path, 2)
        assert_equal "doc-ls.txt", entry.path
        assert_equal "file", entry.kind
      end
      ["directory", "/directory", "/directory/"].each do |path|
        entry = @adapter.entry(path, 2)
        assert_equal "directory", entry.path
        assert_equal "dir", entry.kind
      end
      ["directory/document.txt", "/directory/document.txt"].each do |path|
        entry = @adapter.entry(path, 2)
        assert_equal "directory/document.txt", entry.path
        assert_equal "file", entry.kind
      end
    end

    private

    def test_scm_version_for(scm_command_version, version)
      @adapter.class.expects(:scm_version_from_command_line).returns(scm_command_version)
      assert_equal version, @adapter.class.scm_command_version
    end
  else
    puts "Bazaar test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
