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

  def sprite_icon(icon_name, label = nil, icon_only: false, size: DEFAULT_ICON_SIZE, style: :outline, css_class: nil, sprite: DEFAULT_SPRITE, plugin: nil, rtl: false)
    sprite = plugin ? "plugin_assets/#{plugin}/#{sprite}.svg" : "#{sprite}.svg"

    svg_icon = svg_sprite_icon(icon_name, size: size, style: style, css_class: css_class, sprite: sprite, rtl: rtl)

    if label
      label_classes = ["icon-label"]
      label_classes << "hidden" if icon_only

      svg_icon + content_tag(:span, label, class: label_classes.join(' '))
    else
      svg_icon
    end
  end

  def file_icon(entry, name, **)
    if entry.is_dir?
      sprite_icon("folder", name, **)
    else
      icon_name = icon_for_mime_type(Redmine::MimeType.css_class_of(name))
      sprite_icon(icon_name, name, **)
    end
  end

  def principal_icon(principal, **)
    raise ArgumentError, "First argument has to be a Principal, was #{principal.inspect}" unless principal.is_a?(Principal)

    principal_class = principal.class.name.downcase
    sprite_icon('group', **) if ['groupanonymous', 'groupnonmember', 'group'].include?(principal_class)
  end

  def activity_event_type_icon(event_type, **)
    icon_name = case event_type
                when 'reply'
                  'comments'
                when 'time-entry'
                  'time'
                when 'message'
                  'comment'
                else
                  event_type
                end

    sprite_icon(icon_name, **)
  end

  def scm_change_icon(action, name, **options)
    icon_name = case action
                when 'A'
                  "add"
                when 'D'
                  "circle-minus"
                else
                  "circle-dot-filled"
                end
    sprite_icon(icon_name, name, size: 14)
  end

  def notice_icon(type, **)
    icon_name = case type
                when 'notice'
                  'checked'
                when 'warning', 'error'
                  'warning'
                end

    sprite_icon(icon_name, **)
  end

  private

  def svg_sprite_icon(icon_name, size: DEFAULT_ICON_SIZE, style: :outline, sprite: DEFAULT_SPRITE, css_class: nil, rtl: false)
    css_classes = "s#{size} icon-svg"
    css_classes += " icon-svg-filled" if style == :filled
    css_classes += " #{css_class}" unless css_class.nil?
    css_classes += " icon-rtl" if rtl

    content_tag(
      :svg,
      content_tag(:use, '', { 'href' => "#{asset_path(sprite)}#icon--#{icon_name}" }),
      class: css_classes,
      aria: {
        hidden: true
      }
    )
  end

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
