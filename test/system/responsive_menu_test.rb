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

class ResponsiveMenuTest < ApplicationSystemTestCase
  def test_mobile_view_swaps_dom_and_toggles_flyout
    log_user 'jsmith', 'jsmith'
    visit '/projects/ecookbook'

    # 1. Verify initial desktop layout
    assert_selector '#top-menu ul'
    assert_selector '#main-menu ul'
    assert_no_selector '.flyout-menu ul'

    # 2. Resize to mobile layout
    page.current_window.resize_to(500, 800)

    # 3. Verify desktop containers are hidden on mobile
    assert_no_selector '#top-menu ul'
    assert_no_selector '#main-menu ul'

    # 4. Toggle the flyout menu open
    assert_no_selector 'html.flyout-is-active'
    find('.mobile-toggle-button').click
    assert_selector 'html.flyout-is-active'

    # 5. Verify elements are detached, appended to flyout slots, and visible
    assert_selector '.flyout-menu .js-project-menu ul'
    assert_selector '.flyout-menu .js-general-menu ul'
    assert_selector '.flyout-menu .js-profile-menu ul'

    # 6. Click outside (#main) to close the flyout
    find('#main').click
    assert_no_selector 'html.flyout-is-active'

    # 6. Resize back to desktop layout
    page.current_window.resize_to(1024, 900)

    # 7. Verify elements are returned to original desktop containers
    assert_selector '#top-menu ul'
    assert_selector '#main-menu ul'
    assert_no_selector '.flyout-menu ul'
  end
end
