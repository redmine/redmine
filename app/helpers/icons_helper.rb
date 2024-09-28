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
  DEFAULT_ICON_SIZE = "18"
  DEFAULT_SPRITE = "icons"

  def icon_with_label(icon_name, label_text, icon_only: false, size: DEFAULT_ICON_SIZE, css_class: nil)
    label_classes = ["icon-label"]
    label_classes << "hidden" if icon_only
    sprite_icon(icon_name, size: size, css_class: css_class) + content_tag(:span, label_text, class: label_classes.join(' '))
  end

  def icon_for_file(entry, name, size: DEFAULT_ICON_SIZE, css_class: nil)
    if entry.is_dir?
      icon_with_label("folder", name, size: size, css_class: css_class)
    else
      icon = icon_for_mime_type(Redmine::MimeType.css_class_of(name))
      icon_with_label(icon, name, size: size, css_class: css_class)
    end
  end

  def icon_for_principal(principal_class, size: DEFAULT_ICON_SIZE, css_class: nil)
    sprite_icon('group', size: size, css_class: css_class) if ['groupanonymous', 'groupnonmember', 'group'].include?(principal_class)
  end

  def icon_for_event_type(event_type, size: DEFAULT_ICON_SIZE, css_class: nil)
    icon = case event_type
           when 'reply'
             'comments'
           when 'time-entry'
             'time'
           when 'message'
             'comment'
           else
             event_type
           end

    sprite_icon(icon, size: size, css_class: css_class)
  end

  def sprite_icon(icon_name, size: DEFAULT_ICON_SIZE, sprite: DEFAULT_SPRITE, css_class: nil)
    sprite_path = "#{sprite}.svg"

    content_tag(
      :svg,
      content_tag(:use, '', { 'href' => "#{asset_path(sprite_path)}#icon--#{icon_name}" }),
      class: "s#{size} icon-svg",
      aria: {
        hidden: true
      }
    )
  end

  private

  def icon_for_mime_type(mime)
    if %w(text-plain text-x-c text-x-csharp text-x-java text-x-php
          text-x-ruby text-xml text-css text-html text-css text-html
          image-gif image-jpeg image-png image-tiff
          application-pdf application-zip application-gzip application-javascript).include?(mime)
      mime
    else
      "file"
    end
  end
end
