# encoding: utf-8
#
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

class RoutesHelperTest < ActionView::TestCase
  fixtures :projects, :issues

  include Rails.application.routes.url_helpers

  def test_time_entries_path
    assert_equal '/projects/ecookbook/time_entries', _time_entries_path(Project.find(1), nil)
    assert_equal '/issues/1/time_entries', _time_entries_path(Project.find(1), Issue.find(1))
    assert_equal '/issues/1/time_entries', _time_entries_path(nil, Issue.find(1))
    assert_equal '/time_entries', _time_entries_path(nil, nil)
  end

  def test_report_time_entries_path
    assert_equal '/projects/ecookbook/time_entries/report', _report_time_entries_path(Project.find(1), nil)
    assert_equal '/issues/1/time_entries/report', _report_time_entries_path(Project.find(1), Issue.find(1))
    assert_equal '/issues/1/time_entries/report', _report_time_entries_path(nil, Issue.find(1))
    assert_equal '/time_entries/report', _report_time_entries_path(nil, nil)
  end

  def test_new_time_entry_path
    assert_equal '/projects/ecookbook/time_entries/new', _new_time_entry_path(Project.find(1), nil)
    assert_equal '/issues/1/time_entries/new', _new_time_entry_path(Project.find(1), Issue.find(1))
    assert_equal '/issues/1/time_entries/new', _new_time_entry_path(nil, Issue.find(1))
    assert_equal '/time_entries/new', _new_time_entry_path(nil, nil)
  end
end
