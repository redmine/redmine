# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class DarcsAdapterTest < ActiveSupport::TestCase
  REPOSITORY_PATH = Rails.root.join('tmp/test/darcs_repository').to_s

  if File.directory?(REPOSITORY_PATH)
    def setup
      @adapter = Redmine::Scm::Adapters::DarcsAdapter.new(REPOSITORY_PATH)
    end

    def test_darcsversion
      to_test = { "1.0.9 (release)\n"  => [1,0,9] ,
                  "2.2.0 (release)\n"  => [2,2,0] }
      to_test.each do |s, v|
        test_darcsversion_for(s, v)
      end
    end

    def test_revisions
      id1 = '20080308225258-98289-761f654d669045eabee90b91b53a21ce5593cadf.gz'
      revs = @adapter.revisions('', nil, nil, {:with_path => true})
      assert_equal 6, revs.size
      assert_equal id1, revs[5].scmid
      paths = revs[5].paths
      assert_equal 5, paths.size
      assert_equal 'A', paths[0][:action]
      assert_equal '/README', paths[0][:path]
      assert_equal 'A', paths[1][:action]
      assert_equal '/images', paths[1][:path]
    end

    private

    def test_darcsversion_for(darcsversion, version)
      @adapter.class.expects(:darcs_binary_version_from_command_line).returns(darcsversion)
      assert_equal version, @adapter.class.darcs_binary_version
    end

  else
    puts "Darcs test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
