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

require 'html/pipeline'
require 'task_list/filter'

module Redmine
  module WikiFormatting
    module CommonMark
      # configuration of the rendering pipeline
      PIPELINE_CONFIG = {
        # https://github.com/gjtorikian/commonmarker#extension-options
        commonmarker_extensions: [
          :table,
          :strikethrough,
          :tagfilter,
          :autolink
        ].freeze,

        # https://github.com/gjtorikian/commonmarker#parse-options
        commonmarker_parse_options: [
          :FOOTNOTES,
          :STRIKETHROUGH_DOUBLE_TILDE,
          :UNSAFE,
          :VALIDATE_UTF8
        ].freeze,

        # https://github.com/gjtorikian/commonmarker#render-options
        commonmarker_render_options: [
          :UNSAFE
        ],
      }.freeze

      if Redmine::Configuration['common_mark_enable_hardbreaks'] == true
        PIPELINE_CONFIG[:commonmarker_render_options].push(:HARDBREAKS)
      end
      PIPELINE_CONFIG[:commonmarker_render_options].freeze

      MarkdownPipeline = HTML::Pipeline.new [
        MarkdownFilter,
        SanitizationFilter,
        SyntaxHighlightFilter,
        FixupAutoLinksFilter,
        ExternalLinksFilter,
        TaskList::Filter
      ], PIPELINE_CONFIG

      class Formatter
        include Redmine::WikiFormatting::SectionHelper

        def initialize(text)
          @text = text
        end

        def to_html(*args)
          result = MarkdownPipeline.call @text
          result[:output].to_s
        end
      end
    end
  end
end
