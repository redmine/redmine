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

require_relative '../application_system_test_case'

class VersionsSystemTest < ApplicationSystemTestCase
  def test_create_from_issue_form_with_file_custom_field
    VersionCustomField.generate!(:field_format => 'attachment')

    log_user('jsmith', 'jsmith')

    version_name = 'Version with file custom field'

    assert_difference 'Version.count' do
      visit '/projects/ecookbook/issues/new'
      fill_in 'Subject', :with => 'With a new version'

      click_on 'New version'
      within '#ajax-modal' do
        fill_in 'Name', :with => version_name
        click_on 'Create'
      end
      click_on 'Create'
    end

    assert_equal version_name, Version.last.name
  end
end
