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

class CvsAdapterTest < ActiveSupport::TestCase
  REPOSITORY_PATH = Rails.root.join('tmp/test/cvs_repository').to_s
  REPOSITORY_PATH.tr!('/', "\\") if Redmine::Platform.mswin?
  MODULE_NAME = 'test'

  if File.directory?(REPOSITORY_PATH)
    def setup
      @adapter = Redmine::Scm::Adapters::CvsAdapter.new(MODULE_NAME, REPOSITORY_PATH)
    end

    def test_scm_version
      to_test =
        {
          "\nConcurrent Versions System (CVS) 1.12.13 (client/server)\n" =>
            [1, 12, 13],
          "\r\n1.12.12\r\n1.12.11" => [1, 12, 12],
          "1.12.11\r\n1.12.10\r\n" => [1, 12, 11]
        }
      to_test.each do |s, v|
        test_scm_version_for(s, v)
      end
    end

    def test_revisions_all
      cnt = 0
      @adapter.revisions('', nil, nil, :log_encoding => 'UTF-8') do |revision|
        cnt += 1
      end
      assert_equal 16, cnt
    end

    def test_revisions_from_rev3
      rev3_committed_on = Time.gm(2007, 12, 13, 16, 27, 22)
      cnt = 0
      @adapter.revisions('', rev3_committed_on, nil, :log_encoding => 'UTF-8') do |revision|
        cnt += 1
      end
      assert_equal 4, cnt
    end

    def test_entries_rev3
      rev3_committed_on = Time.gm(2007, 12, 13, 16, 27, 22)
      entries = @adapter.entries('sources', rev3_committed_on)
      assert_equal 2, entries.size
      assert_equal entries[0].name, "watchers_controller.rb"
      assert_equal entries[0].lastrev.time, Time.gm(2007, 12, 13, 16, 27, 22)
    end

    def test_path_encoding_default_utf8
      adpt1 =
        Redmine::Scm::Adapters::CvsAdapter.new(
          MODULE_NAME,
          REPOSITORY_PATH
        )
      assert_equal "UTF-8", adpt1.path_encoding
      adpt2 =
        Redmine::Scm::Adapters::CvsAdapter.new(
          MODULE_NAME,
          REPOSITORY_PATH,
          nil,
          nil,
          ""
        )
      assert_equal "UTF-8", adpt2.path_encoding
    end

    def test_root_url_path
      to_test = {
        ':pserver:cvs_user:cvs_password@123.456.789.123:9876/repo' => '/repo',
        ':pserver:cvs_user:cvs_password@123.456.789.123/repo' => '/repo',
        ':pserver:cvs_user:cvs_password@cvs_server:/repo' => '/repo',
        ':pserver:cvs_user:cvs_password@cvs_server:9876/repo' => '/repo',
        ':pserver:cvs_user:cvs_password@cvs_server/repo' => '/repo',
        ':pserver:cvs_user:cvs_password@cvs_server/path/repo' => '/path/repo',
        ':ext:cvsservername:/path' => '/path'
      }

      to_test.each do |string, expected|
        assert_equal expected, Redmine::Scm::Adapters::CvsAdapter.new('foo', string).send(:root_url_path), "#{string} failed"
      end
    end

    private

    def test_scm_version_for(scm_command_version, version)
      @adapter.class.expects(:scm_version_from_command_line).returns(scm_command_version)
      assert_equal version, @adapter.class.scm_command_version
    end
  else
    puts "Cvs test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
