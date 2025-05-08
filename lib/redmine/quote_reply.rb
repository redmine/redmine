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
  module QuoteReply
    module Helper
      def javascripts_for_quote_reply_include_tag
        javascript_include_tag 'turndown-7.2.0.min', 'quote_reply'
      end

      def quote_reply(url, selector_for_content, icon_only: false)
        quote_reply_function = "quoteReply('#{j url}', '#{j selector_for_content}', '#{j Setting.text_formatting}')"

        html_options = { class: 'icon icon-comment' }
        html_options[:title] = l(:button_quote) if icon_only

        link_to_function(
          sprite_icon('comment', l(:button_quote), icon_only: icon_only),
          quote_reply_function,
          html_options
        )
      end
    end

    module Builder
      def quote_issue(issue, partial_quote: nil)
        user = issue.author

        build_quote(
          "#{ll(Setting.default_language, :text_user_wrote, user)}\n> ",
          issue.description,
          partial_quote
        )
      end

      def quote_issue_journal(journal, indice:, partial_quote: nil)
        user = journal.user

        build_quote(
          "#{ll(Setting.default_language, :text_user_wrote_in, {value: journal.user, link: "#note-#{indice}"})}\n> ",
          journal.notes,
          partial_quote
        )
      end

      def quote_root_message(message, partial_quote: nil)
        build_quote(
          "#{ll(Setting.default_language, :text_user_wrote, message.author)}\n> ",
          message.content,
          partial_quote
        )
      end

      def quote_message(message, partial_quote: nil)
        build_quote(
          "#{ll(Setting.default_language, :text_user_wrote_in, {value: message.author, link: "message##{message.id}"})}\n> ",
          message.content,
          partial_quote
        )
      end

      private

      def build_quote(quote_header, text, partial_quote = nil)
        quote_text = partial_quote.presence || text.to_s.strip.gsub(%r{<pre>(.*?)</pre>}m, '[...]')

        "#{quote_header}#{quote_text.gsub(/(\r?\n|\r\n?)/, "\n> ") + "\n\n"}"
      end
    end
  end
end
