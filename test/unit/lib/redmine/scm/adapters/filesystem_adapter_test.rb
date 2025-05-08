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

require_relative '../../../../../test_helper'

class FilesystemAdapterTest < ActiveSupport::TestCase
  REPOSITORY_PATH = Rails.root.join('tmp/test/filesystem_repository').to_s

  if File.directory?(REPOSITORY_PATH)
    def setup
      @adapter = Redmine::Scm::Adapters::FilesystemAdapter.new(REPOSITORY_PATH)
    end

    def test_entries
      assert_equal 3, @adapter.entries.size
      assert_equal ["dir", "japanese", "test"], @adapter.entries.collect(&:name)
      assert_equal ["dir", "japanese", "test"], @adapter.entries(nil).collect(&:name)
      assert_equal ["dir", "japanese", "test"], @adapter.entries("/").collect(&:name)
      ["dir", "/dir", "/dir/", "dir/"].each do |path|
        assert_equal ["subdir", "dirfile"], @adapter.entries(path).collect(&:name)
      end
      # If y try to use "..", the path is ignored
      ["/../", "dir/../", "..", "../", "/..", "dir/.."].each do |path|
        assert_equal(
          ["dir", "japanese", "test"], @adapter.entries(path).collect(&:name),
          ".. must be ignored in path argument")
      end
    end

    def test_cat
      assert_equal "TEST CAT\n", @adapter.cat("test")
      assert_equal "TEST CAT\n", @adapter.cat("/test")
      # Revision number is ignored
      assert_equal "TEST CAT\n", @adapter.cat("/test", 1)
    end

    def test_path_encoding_default_utf8
      adpt1 = Redmine::Scm::Adapters::FilesystemAdapter.new(
                                  REPOSITORY_PATH
                                )
      assert_equal "UTF-8", adpt1.path_encoding
      adpt2 = Redmine::Scm::Adapters::FilesystemAdapter.new(
                                  REPOSITORY_PATH,
                                  nil,
                                  nil,
                                  nil,
                                  ""
                                )
      assert_equal "UTF-8", adpt2.path_encoding
    end
  else
    puts "Filesystem test repository NOT FOUND. Skipping unit tests !!! See doc/RUNNING_TESTS."
    def test_fake; assert true end
  end
end
