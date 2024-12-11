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

class IconsHelperTest < Redmine::HelperTest
  include IconsHelper

  def test_sprite_icon_should_return_svg_with_defaults
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--edit"></use></svg>$}
    icon = sprite_icon('edit')

    assert_match expected, icon
  end

  def test_sprite_icon_should_return_svg_with_label
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--edit"></use></svg><span class="icon-label">Edit</span>}
    icon = sprite_icon('edit', 'Edit')

    assert_match expected, icon
  end

  def test_sprite_icon_should_return_svg_with_hidden_label_when_icon_only_is_true
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--edit"></use></svg><span class="icon-label hidden">Edit</span>}
    icon = sprite_icon('edit', 'Edit', icon_only: true)

    assert_match expected, icon
  end

  def test_sprite_icon_should_return_svg_with_custom_size
    expected = %r{<svg class="s24 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--edit"></use></svg>$}
    icon = sprite_icon('edit', size: '24')

    assert_match expected, icon
  end

  def test_sprite_icon_should_return_svg_with_custom_css_class
    expected = %r{<svg class="s18 icon-svg custom-class" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--edit"></use></svg>$}
    icon = sprite_icon('edit', css_class: 'custom-class')

    assert_match expected, icon
  end

  def test_sprite_icon_should_return_svg_with_custom_sprite
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/custom.svg#icon--edit"></use></svg>$}
    icon = sprite_icon('edit', sprite: 'custom')

    assert_match expected, icon
  end

  def test_sprite_icon_should_return_svg_with_plugin_sprite
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/plugin_assets/my_plugin/icons.svg#icon--edit"></use></svg>$}
    icon = sprite_icon('edit', plugin: 'my_plugin')

    assert_match expected, icon
  end

  def test_file_icon_should_return_folder_icon_for_directory
    entry = stub(:is_dir? => true)
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--folder"></use></svg><span class="icon-label">folder_name</span>}
    icon = file_icon(entry, "folder_name")

    assert_match expected, icon
  end

  def test_file_icon_should_return_folder_icon_for_files
    entry = stub(:is_dir? => false)
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--file"></use></svg><span class="icon-label">file_name</span>}
    icon = file_icon(entry, "file_name")

    assert_match expected, icon
  end

  def test_file_icon_should_return_file_type_icon_for_files
    entry = stub(:is_dir? => false)
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--text-plain"></use></svg><span class="icon-label">text.txt</span>}
    icon = file_icon(entry, "text.txt")

    assert_match expected, icon
  end

  def test_principal_icon_should_return_group_icon_for_group_classes
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--group"></use></svg>}

    [Principal.find(12), Principal.find(13), Principal.find(10)].each do |principal|
      assert_match expected, principal_icon(principal)
    end
  end

  def test_principal_icon_should_return_nil_for_non_group_classes
    assert_nil principal_icon(Principal.find(1))
  end

  def test_activity_event_type_icon_should_return_correct_icon_for_reply_events
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--comments"></use></svg>}
    assert_match expected, activity_event_type_icon('reply')
  end

  def test_activity_event_type_icon_should_return_correct_icon_for_time_entry_events
    expected = %r{<svg class="s18 icon-svg" aria-hidden="true"><use href="/assets/icons-\w+.svg#icon--time"></use></svg>}
    assert_match expected, activity_event_type_icon('time-entry')
  end

  def test_icon_for_mime_type_should_return_specific_icon_for_known_mime_types
    assert_equal 'text-plain', icon_for_mime_type('text-plain')
    assert_equal 'application-pdf', icon_for_mime_type('application-pdf')
  end

  def test_icon_for_mime_type_should_return_generic_file_icon_for_unknown_mime_types
    assert_equal 'file', icon_for_mime_type('unknown-type')
  end
end
