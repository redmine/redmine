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

require_relative '../test_helper'

class ContextMenusHelperTest < Redmine::HelperTest
  include ContextMenusHelper

  test '#context_menu_link' do
    html = context_menu_link('name', 'url', class: 'class-a')
    assert_select_in html, 'a.class-a[href=?]', 'url'

    # When :selected is true
    html = context_menu_link('name', 'url', selected: true, class: 'class-a class-b')
    assert_select_in html, 'a.class-a.class-b.icon.disabled[href=?]', '#' do
      assert_select 'svg.icon-svg'
    end

    # When :disabled is true
    html = context_menu_link('name', 'url', disabled: true, method: 'patch', data: { key: 'value' })
    assert_select_in html,
      'a.disabled[href=?][onclick=?]:not([method]):not([data-key])',
      '#', 'return false;'
  end
end
