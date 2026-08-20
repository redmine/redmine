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
  include Redmine::Themes::Helper

  DEFAULT_ICON_SIZE = "18"
  DEFAULT_SPRITE = "icons"

  # Content types covered by each icon. The same kind of file can be denoted by
  # several types, depending on whether the type was detected from the file
  # contents or taken from Redmine::MimeType, so list them all rather than
  # deriving the icon name from the type. An entry with no subtype (eg. audio)
  # covers every type of that top level type that is not listed elsewhere.
  ICON_MIME_TYPES = {
    'application-gzip' => %w(application/gzip),
    'application-javascript' => %w(application/javascript text/javascript),
    'application-pdf' => %w(application/pdf),
    'application-zip' => %w(application/zip),
    'file-music' => %w(audio),
    'movie' => %w(video),
    'photo' => %w(image),
    'text-css' => %w(text/css),
    'text-html' => %w(text/html),
    'text-plain' => %w(text application/sql application/x-csh application/x-sh),
    'text-x-c' => %w(text/x-c text/x-c++hdr text/x-c++src),
    'text-x-csharp' => %w(text/x-csharp),
    'text-x-java' => %w(text/x-java text/x-java-source),
    'text-x-php' => %w(text/x-php),
    'text-x-ruby' => %w(text/x-ruby),
    'text-xml' => %w(text/xml application/xml),
    # Microsoft Office Open XML documents
    # Do not add legacy Office formats (.doc, .xls, .ppt) here because
    # Redmine does not provide attachment preview for these formats.
    'file-type-docx' => %w(application/vnd.openxmlformats-officedocument.wordprocessingml.document),
    'file-type-ppt' => %w(application/vnd.openxmlformats-officedocument.presentationml.presentation),
    'file-type-xls' => %w(application/vnd.openxmlformats-officedocument.spreadsheetml.sheet)
  }.freeze

  MIME_TYPE_ICONS = ICON_MIME_TYPES.each_with_object({}) do |(icon, types), map|
    types.each {|type| map[type] = icon}
  end.freeze

  def sprite_source(icon_name, sprite: DEFAULT_SPRITE, plugin: nil)
    if plugin
      "plugin_assets/#{plugin}/#{sprite}.svg"
    elsif current_theme && current_theme.icons(sprite).include?(icon_name)
      current_theme.image_path("#{sprite}.svg")
    else
      "#{sprite}.svg"
    end
  end

  def sprite_icon(icon_name, label = nil, icon_only: false, size: DEFAULT_ICON_SIZE, style: :outline, css_class: nil, sprite: DEFAULT_SPRITE, plugin: nil, rtl: false)
    sprite = sprite_source(icon_name, sprite: sprite, plugin: plugin)

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
      icon_name = icon_for_mime_type(Redmine::MimeType.of(name))
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

  def scm_change_icon(action, name, **)
    icon_name = case action
                when 'A'
                  "add"
                when 'D'
                  "circle-minus"
                else
                  "circle-dot-filled"
                end
    sprite_icon(icon_name, name, size: 14, **)
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

  def file_type_icon(mime_type, label = nil, filename: nil, **)
    icon_name = icon_for_mime_type(mime_type, filename)
    sprite_icon(icon_name, label, **)
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

  def icon_for_mime_type(mime, filename = nil)
    # Content type detection falls back to application/octet-stream when it
    # cannot tell the type from the file contents. In that case only, guess
    # the type from the filename, as AttachmentsController#detect_content_type
    # does.
    if filename.present? && (mime.blank? || mime == 'application/octet-stream')
      mime = Redmine::MimeType.of(filename)
    end

    MIME_TYPE_ICONS[mime] ||
      MIME_TYPE_ICONS[mime.to_s.split('/').first] ||
      'file'
  end
end
