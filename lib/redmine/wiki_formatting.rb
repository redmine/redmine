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

require 'digest/md5'

module Redmine
  module WikiFormatting
    class StaleSectionError < Exception; end

    @@formatters = {}

    class << self
      def map
        yield self
      end

      def register(name, *args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        name = name.to_s
        raise ArgumentError, "format name '#{name}' is already taken" if @@formatters[name]

        formatter, helper, parser = args.any? ?
          args :
          %w(Formatter Helper HtmlParser).map {|m| "Redmine::WikiFormatting::#{name.classify}::#{m}".constantize rescue nil}

        raise "A formatter class is required" if formatter.nil? 

        @@formatters[name] = {
          :formatter => formatter,
          :helper => helper,
          :html_parser => parser,
          :label => options[:label] || name.humanize
        }
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
        text = if Setting.cache_formatted_text? && text.size > 2.kilobyte && cache_store && cache_key = cache_key_for(format, text, options[:object], options[:attribute])
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
        (formatter.instance_methods & ['update_section', :update_section]).any?
      end

      # Returns a cache key for the given text +format+, +text+, +object+ and +attribute+ or nil if no caching should be done
      def cache_key_for(format, text, object, attribute)
        if object && attribute && !object.new_record? && format.present?
          "formatted_text/#{format}/#{object.class.model_name.cache_key}/#{object.id}-#{attribute}-#{Digest::MD5.hexdigest text}"
        end
      end

      # Returns the cache store used to cache HTML output
      def cache_store
        ActionController::Base.cache_store
      end
    end

    module LinksHelper
      AUTO_LINK_RE = %r{
                      (                          # leading text
                        <\w+[^>]*?>|             # leading HTML tag, or
                        [\s\(\[,;]|              # leading punctuation, or
                        ^                        # beginning of line
                      )
                      (
                        (?:https?://)|           # protocol spec, or
                        (?:s?ftps?://)|
                        (?:www\.)                # www.*
                      )
                      (
                        ([^<]\S*?)               # url
                        (\/)?                    # slash
                      )
                      ((?:&gt;)?|[^[:alnum:]_\=\/;\(\)]*?)               # post
                      (?=<|\s|$)
                     }x unless const_defined?(:AUTO_LINK_RE)

      # Destructively replaces urls into clickable links
      def auto_link!(text)
        text.gsub!(AUTO_LINK_RE) do
          all, leading, proto, url, post = $&, $1, $2, $3, $6
          if leading =~ /<a\s/i || leading =~ /![<>=]?/
            # don't replace URLs that are already linked
            # and URLs prefixed with ! !> !< != (textile images)
            all
          else
            # Idea below : an URL with unbalanced parenthesis and
            # ending by ')' is put into external parenthesis
            if ( url[-1]==?) and ((url.count("(") - url.count(")")) < 0 ) )
              url=url[0..-2] # discard closing parenthesis from url
              post = ")"+post # add closing parenthesis to post
            end
            content = proto + url
            href = "#{proto=="www."?"http://www.":proto}#{url}"
            %(#{leading}<a class="external" href="#{ERB::Util.html_escape href}">#{ERB::Util.html_escape content}</a>#{post}).html_safe
          end
        end
      end

      # Destructively replaces email addresses into clickable links
      def auto_mailto!(text)
        text.gsub!(/([\w\.!#\$%\-+.\/]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)+)/) do
          mail = $1
          if text.match(/<a\b[^>]*>(.*)(#{Regexp.escape(mail)})(.*)<\/a>/)
            mail
          else
            %(<a class="email" href="mailto:#{ERB::Util.html_escape mail}">#{ERB::Util.html_escape mail}</a>).html_safe
          end
        end
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
          simple_format(t, {}, :sanitize => false)
        end
      end

      module Helper
        def wikitoolbar_for(field_id)
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
