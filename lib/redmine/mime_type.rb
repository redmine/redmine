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

module Redmine
  module MimeType
    MIME_TYPES = {
      'text/plain' => 'txt,tpl,properties,patch,diff,ini,readme,install,upgrade,sql',
      'text/css' => 'css',
      'text/html' => 'html,htm,xhtml',
      'text/jsp' => 'jsp',
      'text/x-c' => 'c,cpp,cc,h,hh',
      'text/x-csharp' => 'cs',
      'text/x-java' => 'java',
      'text/x-html-template' => 'rhtml',
      'text/x-perl' => 'pl,pm',
      'text/x-php' => 'php,php3,php4,php5',
      'text/x-python' => 'py',
      'text/x-ruby' => 'rb,rbw,ruby,rake,erb',
      'text/x-csh' => 'csh',
      'text/x-sh' => 'sh',
      'text/x-textile' => 'textile',
      'text/xml' => 'xml,xsd,mxml',
      'text/yaml' => 'yml,yaml',
      'text/csv' => 'csv',
      'text/x-po' => 'po',
      'image/avif' => 'avif',
      'image/bmp' => 'bmp',
      'image/gif' => 'gif',
      'image/jpeg' => 'jpg,jpeg,jpe',
      'image/png' => 'png',
      'image/tiff' => 'tiff,tif',
      'image/webp' => 'webp',
      'application/javascript' => 'js',
      'application/pdf' => 'pdf',
      'video/mp4' => 'mp4',
      'video/webm' => 'webm',
    }.freeze

    EXTENSIONS = MIME_TYPES.inject({}) do |map, (type, exts)|
      exts.split(',').each {|ext| map[ext.strip] = type}
      map
    end

    # Friendly names for MIME types that are frequently used but very long
    # and do not convey the kind of file to most users. The names are not
    # translated, so they should consist of the name of the application
    # or format, followed by nouns. For example, "(+macro)" is appended for a
    # macro-enabled type instead of "macro-enabled", which may look like
    # untranslated English text.
    #
    # The keys must be in lowercase because the lookup is case-insensitive.
    FRIENDLY_NAMES = {
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 'Microsoft Word Document',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.template' => 'Microsoft Word Document Template',
      'application/vnd.ms-word.document.macroenabled.12' => 'Microsoft Word Document (+macro)',
      'application/vnd.ms-word.template.macroenabled.12' => 'Microsoft Word Document Template (+macro)',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 'Microsoft Excel Workbook',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.template' => 'Microsoft Excel Workbook Template',
      'application/vnd.ms-excel.sheet.macroenabled.12' => 'Microsoft Excel Workbook (+macro)',
      'application/vnd.ms-excel.template.macroenabled.12' => 'Microsoft Excel Workbook Template (+macro)',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation' => 'Microsoft PowerPoint Presentation',
      'application/vnd.openxmlformats-officedocument.presentationml.template' => 'Microsoft PowerPoint Presentation Template',
      'application/vnd.openxmlformats-officedocument.presentationml.slideshow' => 'Microsoft PowerPoint Slide Show',
      'application/vnd.ms-powerpoint.presentation.macroenabled.12' => 'Microsoft PowerPoint Presentation (+macro)',
      'application/vnd.ms-powerpoint.template.macroenabled.12' => 'Microsoft PowerPoint Presentation Template (+macro)',
      'application/vnd.ms-powerpoint.slideshow.macroenabled.12' => 'Microsoft PowerPoint Slide Show (+macro)',
      'application/vnd.oasis.opendocument.text' => 'OpenDocument Text',
      'application/vnd.oasis.opendocument.text-template' => 'OpenDocument Text Template',
      'application/vnd.oasis.opendocument.spreadsheet' => 'OpenDocument Spreadsheet',
      'application/vnd.oasis.opendocument.spreadsheet-template' => 'OpenDocument Spreadsheet Template',
      'application/vnd.oasis.opendocument.presentation' => 'OpenDocument Presentation',
      'application/vnd.oasis.opendocument.presentation-template' => 'OpenDocument Presentation Template',
      'application/vnd.oasis.opendocument.graphics' => 'OpenDocument Graphics',
      'application/vnd.oasis.opendocument.graphics-template' => 'OpenDocument Graphics Template'
    }.freeze

    # returns all full mime types for a given (top level) type
    def self.by_type(type)
      MIME_TYPES.keys.select{|m| m.start_with? "#{type}/"}
    end

    # returns mime type for name or nil if unknown
    def self.of(name)
      ext = File.extname(name.to_s).delete_prefix('.').downcase
      return if ext.empty?

      EXTENSIONS.fetch(ext) do
        type = Marcel::MimeType.for(extension: ext)
        # Marcel falls back to application/octet-stream for unknown extensions
        type unless type == Marcel::MimeType::BINARY
      end
    end

    # Returns the css class associated to
    # the mime type of name
    def self.css_class_of(name)
      mimetype = of(name)
      mimetype&.tr('/', '-')
    end

    def self.main_mimetype_of(name)
      mimetype = of(name)
      mimetype&.split('/')&.first
    end

    # return true if mime-type for name is type/*
    # otherwise false
    def self.is_type?(type, name)
      main_mimetype = main_mimetype_of(name)
      type.to_s == main_mimetype
    end

    # Returns the friendly name for the given mime type, or nil if none is
    # defined in FRIENDLY_NAMES. The lookup is case-insensitive.
    def self.friendly_name_for(type)
      FRIENDLY_NAMES[type.to_s.downcase]
    end
  end
end
