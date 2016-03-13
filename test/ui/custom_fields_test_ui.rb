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

require File.expand_path('../base', __FILE__)

class Redmine::UiTest::CustomFieldsTest < Redmine::UiTest::Base
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :trackers, :projects_trackers, :enabled_modules, 
           :custom_fields, :custom_values, :custom_fields_trackers

  def test_reordering_should_redirect_to_index
    assert_equal 1, UserCustomField.find(4).position
    log_user 'admin', 'admin'
    visit '/custom_fields'

    # click 'User' tab
    page.first('a#tab-UserCustomField').click
    # click 'Move down' link on the first row
    page.first('td.reorder a:nth-child(3)').click

    assert_equal "/custom_fields?tab=UserCustomField", URI.parse(current_url).request_uri
    assert_equal 2, UserCustomField.find(4).position
  end
end
