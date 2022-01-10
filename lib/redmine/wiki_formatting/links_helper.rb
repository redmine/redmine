# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

require 'loofah/helpers'

module Redmine
  module WikiFormatting
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
                      ((?:&gt;)?|[^[:alnum:]_\=\/;\(\)\-]*?)             # post
                      (?=<|\s|$)
                     }x unless const_defined?(:AUTO_LINK_RE)

      # Destructively replaces urls into clickable links
      def auto_link!(text)
        text.gsub!(AUTO_LINK_RE) do
          all, leading, proto, url, post = $&, $1, $2, $3, $6
          if /<a\s/i.match?(leading) || /![<>=]?/.match?(leading)
            # don't replace URLs that are already linked
            # and URLs prefixed with ! !> !< != (textile images)
            all
          else
            # Idea below : an URL with unbalanced parenthesis and
            # ending by ')' is put into external parenthesis
            if url[-1] == ")" && ((url.count("(") - url.count(")")) < 0)
              url = url[0..-2] # discard closing parenthesis from url
              post = ")" + post # add closing parenthesis to post
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
          if /<a\b[^>]*>(.*)(#{Regexp.escape(mail)})(.*)<\/a>/.match?(text)
            mail
          else
            %(<a class="email" href="mailto:#{ERB::Util.html_escape mail}">#{ERB::Util.html_escape mail}</a>).html_safe
          end
        end
      end

      def restore_redmine_links(html)
        # restore wiki links eg. [[Foo]]
        html.gsub!(%r{\[<a href="(.*?)">(.*?)</a>\]}) do
          "[[#{$2}]]"
        end
        # restore Redmine links with double-quotes, eg. version:"1.0"
        html.gsub!(/(\w):&quot;(.+?)&quot;/) do
          "#{$1}:\"#{$2}\""
        end
        # restore user links with @ in login name eg. [@jsmith@somenet.foo]
        html.gsub!(%r{[@\A]<a(\sclass="email")? href="mailto:(.*?)">(.*?)</a>}) do
          "@#{$2}"
        end
        # restore user links with @ in login name eg. [user:jsmith@somenet.foo]
        html.gsub!(%r{\buser:<a(\sclass="email")? href="mailto:(.*?)">(.*?)<\/a>}) do
          "user:#{$2}"
        end
        # restore attachments links with @ in file name eg. [attachment:image@2x.png]
        html.gsub!(%r{\battachment:<a(\sclass="email")? href="mailto:(.*?)">(.*?)</a>}) do
          "attachment:#{$2}"
        end
        # restore hires images which are misrecognized as email address eg. [printscreen@2x.png]
        html.gsub!(%r{<a(\sclass="email")? href="mailto:[^"]+@\dx\.(bmp|gif|jpg|jpe|jpeg|png)">(.*?)</a>}) do
          "#{$3}"
        end
        html
      end
    end
  end
end
