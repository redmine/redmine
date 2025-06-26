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

require File.expand_path('../../test_helper', __FILE__)

class ProjectsHelperTest < Redmine::HelperTest
  include ApplicationHelper
  include ProjectsHelper
  include ERB::Util
  include Rails.application.routes.url_helpers

  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :versions,
           :projects_trackers,
           :member_roles,
           :members,
           :groups_users,
           :enabled_modules

  def test_link_to_version_within_project
    @project = Project.find(2)
    User.current = User.find(1)
    assert_equal '<a title="07/01/2006" href="/versions/5">Alpha</a>', link_to_version(Version.find(5))
  end

  def test_link_to_version
    User.current = User.find(1)
    assert_equal '<a title="07/01/2006" href="/versions/5">OnlineStore - Alpha</a>', link_to_version(Version.find(5))
  end

  def test_link_to_version_without_effective_date
    User.current = User.find(1)
    version = Version.find(5)
    version.effective_date = nil
    assert_equal '<a href="/versions/5">OnlineStore - Alpha</a>', link_to_version(version)
  end

  def test_link_to_private_version
    assert_equal 'OnlineStore - Alpha', link_to_version(Version.find(5))
  end

  def test_link_to_version_invalid_version
    assert_equal '', link_to_version(Object)
  end

  def test_format_version_name_within_project
    @project = Project.find(1)
    assert_equal "0.1", format_version_name(Version.find(1))
  end

  def test_format_version_name
    assert_equal "eCookbook - 0.1", format_version_name(Version.find(1))
  end

  def test_format_version_name_for_system_version
    assert_equal "OnlineStore - Systemwide visible version", format_version_name(Version.find(7))
  end

  def test_version_options_for_select_with_no_versions
    assert_equal '', version_options_for_select([])
    assert_equal '', version_options_for_select([], Version.find(1))
  end
end
