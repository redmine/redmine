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

module IconsHelper
  DEFAULT_ICON_SIZE = "14"
  DEFAULT_SPRITE = "icons"

  def icon_with_label(icon_name, label_text, icon_only: false)
    sprite_icon(icon_name) + content_tag(:span, label_text, class: "icon-label")
  end

  def icon_for_file(entry, label_text)
    if entry.is_dir?
      icon_with_label("folder", label_text)
    end
  end

  def sprite_icon(icon_name, size: DEFAULT_ICON_SIZE, sprite: DEFAULT_SPRITE)
    sprite_path = "#{sprite}.svg"

    content_tag(
      :svg,
      content_tag(:use, '', { 'href' => "#{asset_path(sprite_path)}#icon--#{icon_name}" }),
      class: "s#{size}",
      aria: {
        hidden: true
      }
    )
  end
end
