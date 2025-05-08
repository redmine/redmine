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

require_relative 'wiki_formatting/textile/redcloth3'

module Redmine
  module WikiFormatting
    class StaleSectionError < StandardError; end

    @@formatters = {}

    class << self
      def map
        yield self
      end

      def register(name, *args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        name = name.to_s

        formatter, helper, parser =
          if args.any?
            args
          else
            %w(Formatter Helper HtmlParser).map {|m| "Redmine::WikiFormatting::#{name.classify}::#{m}".constantize rescue nil}
          end
        raise "A formatter class is required" if formatter.nil?

        entry = {
          :formatter => formatter,
          :helper => helper,
          :html_parser => parser,
          :label => options[:label] || name.humanize
        }
        if @@formatters[name] && @@formatters[name] != entry
          raise ArgumentError, "format name '#{name}' is already taken"
        end

        @@formatters[name] = entry
      end

      def formatter
        formatter_for(Setting.text_formatting)
      end

      def html_parser
        html_parser_for(Setting.text_formatting)
      end

      def formatter_for(name)
        entry = @@formatters[name.to_s]
        (entry && entry[:formatter]) || Redmine::WikiFormatting::NullFormatter::Formatter
      end

      def helper_for(name)
        entry = @@formatters[name.to_s]
        (entry && entry[:helper]) || Redmine::WikiFormatting::NullFormatter::Helper
      end

      def html_parser_for(name)
        entry = @@formatters[name.to_s]
        (entry && entry[:html_parser]) || Redmine::WikiFormatting::HtmlParser
      end

      def format_names
        @@formatters.keys.map
      end

      def formats_for_select
        @@formatters.map {|name, options| [options[:label], name]}
      end

      def to_html(format, text, options = {})
        text =
          if Setting.cache_formatted_text? && text.size > 2.kilobytes && cache_store &&
              cache_key = cache_key_for(format, text, options[:object], options[:attribute])
            # Text retrieved from the cache store may be frozen
            # We need to dup it so we can do in-place substitutions with gsub!
            cache_store.fetch cache_key do
              formatter_for(format).new(text).to_html
            end.dup
          else
            formatter_for(format).new(text).to_html
          end
        text
      end

      # Returns true if the text formatter supports single section edit
      def supports_section_edit?
        formatter.instance_methods.intersect?(['update_section', :update_section])
      end

      # Returns a cache key for the given text +format+, +text+, +object+ and +attribute+ or nil if no caching should be done
      def cache_key_for(format, text, object, attribute)
        if object && attribute && !object.new_record? && format.present?
          "formatted_text/#{format}/#{object.class.model_name.cache_key}/#{object.id}-#{attribute}-#{ActiveSupport::Digest.hexdigest text}"
        end
      end

      # Returns the cache store used to cache HTML output
      def cache_store
        ActionController::Base.cache_store
      end
    end

    # Default formatter module
    module NullFormatter
      class Formatter
        include ActionView::Helpers::TagHelper
        include ActionView::Helpers::TextHelper
        include ActionView::Helpers::UrlHelper
        include Redmine::WikiFormatting::LinksHelper

        def initialize(text)
          @text = text
        end

        def to_html(*args)
          t = CGI::escapeHTML(@text)
          auto_link!(t)
          auto_mailto!(t)
          restore_redmine_links(t)
          simple_format(t, {}, :sanitize => false)
        end
      end

      module Helper
        def wikitoolbar_for(field_id, preview_url = preview_text_path)
        end

        def heads_for_wiki_formatter
        end

        def initial_page_content(page)
          page.pretty_title.to_s
        end
      end
    end
  end
end
