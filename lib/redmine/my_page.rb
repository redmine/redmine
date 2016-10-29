# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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
  module MyPage
    include Redmine::I18n

    CORE_BLOCKS = {
        'issuesassignedtome' => :label_assigned_to_me_issues,
        'issuesreportedbyme' => :label_reported_issues,
        'issueswatched' => :label_watched_issues,
        'news' => :label_news_latest,
        'calendar' => :label_calendar,
        'documents' => :label_document_plural,
        'timelog' => :label_spent_time
      }

    # Returns the available blocks
    def self.blocks
      CORE_BLOCKS.merge(additional_blocks).freeze
    end

    def self.block_options
      options = []
      blocks.each do |k, v|
        options << [l("my.blocks.#{v}", :default => [v, v.to_s.humanize]), k.dasherize]
      end
      options
    end

    # Returns the additional blocks that are defined by plugin partials
    def self.additional_blocks
      @@additional_blocks ||= Dir.glob("#{Redmine::Plugin.directory}/*/app/views/my/blocks/_*.{rhtml,erb}").inject({}) do |h,file|
        name = File.basename(file).split('.').first.gsub(/^_/, '')
        h[name] = name.to_sym
        h
      end
    end

    # Returns the default layout for My Page
    def self.default_layout
      {
        'left' => ['issuesassignedtome'],
        'right' => ['issuesreportedbyme']
      }
    end
  end
end
