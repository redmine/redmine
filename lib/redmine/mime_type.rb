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
      'image/gif' => 'gif',
      'image/jpeg' => 'jpg,jpeg,jpe',
      'image/png' => 'png',
      'image/tiff' => 'tiff,tif',
      'image/webp' => 'webp',
      'image/x-ms-bmp' => 'bmp',
      'application/javascript' => 'js',
      'application/pdf' => 'pdf',
      'video/mp4' => 'mp4',
      'video/webm' => 'webm',
    }.freeze

    EXTENSIONS = MIME_TYPES.inject({}) do |map, (type, exts)|
      exts.split(',').each {|ext| map[ext.strip] = type}
      map
    end

    # returns all full mime types for a given (top level) type
    def self.by_type(type)
      MIME_TYPES.keys.select{|m| m.start_with? "#{type}/"}
    end

    # returns mime type for name or nil if unknown
    def self.of(name)
      ext = File.extname(name.to_s)[1..-1]
      if ext
        ext.downcase!
        EXTENSIONS[ext] || MiniMime.lookup_by_extension(ext)&.content_type
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
  end
end
