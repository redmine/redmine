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

require File.expand_path('../../../test_helper', __FILE__)

class VersionsHelperTest < ActionView::TestCase

  fixtures :projects, :versions

  def test_version_filtered_issues_path_sharing_none
    version = Version.new(:name => 'test', :sharing => 'none')
    version.project = Project.find(5)
    assert_match '/projects/private-child/issues?', version_filtered_issues_path(version)
  end

  def test_version_filtered_issues_path_sharing_descendants
    version = Version.new(:name => 'test', :sharing => 'descendants')
    version.project = Project.find(5)
    assert_match '/projects/private-child/issues?', version_filtered_issues_path(version)
  end

  def test_version_filtered_issues_path_sharing_hierarchy
    version = Version.new(:name => 'test', :sharing => 'hierarchy')
    version.project = Project.find(5)
    assert_match '/projects/ecookbook/issues?', version_filtered_issues_path(version)
  end

  def test_version_filtered_issues_path_sharing_tree
    version = Version.new(:name => 'test', :sharing => 'tree')
    version.project = Project.find(5)
    assert_match '/projects/ecookbook/issues?', version_filtered_issues_path(version)
  end

  def test_version_filtered_issues_path_sharing_system
    version = Version.new(:name => 'test', :sharing => 'system')
    version.project = Project.find(5)
    assert_match /^\/issues\?/, version_filtered_issues_path(version)
  end
end
