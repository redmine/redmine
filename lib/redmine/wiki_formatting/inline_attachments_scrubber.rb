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
  module WikiFormatting
    class InlineAttachmentsScrubber < Loofah::Scrubber
      def initialize(options = {})
        super()
        @options = options
        @obj = options[:object]
        @view = options[:view]
        @only_path = options[:only_path]
        @attachments = options[:attachments] || []
        if @obj.is_a?(Journal)
          @attachments += @obj.journalized.attachments if @obj.journalized.respond_to?(:attachments)
        elsif @obj.respond_to?(:attachments)
          @attachments += @obj.attachments
        end

        if @attachments.present?
          @attachments = @attachments.sort_by{|attachment| [attachment.created_on, attachment.id]}.reverse
        end
      end

      def scrub(node)
        return unless node.name == 'img' && node['src'].present?

        parse_inline_attachments(node)
      end

      private

      def parse_inline_attachments(node)
        return if @attachments.blank?

        src = node['src']

        if src =~ %r{\A(?<filename>[^/"]+?\.(?:bmp|gif|jpg|jpeg|jpe|png|webp))\z}i
          filename = $~[:filename]
          if found = find_attachment(CGI.unescape(filename))
            image_url = @view.download_named_attachment_url(found, found.filename, :only_path => @only_path)
            node['src'] = image_url

            desc = found.description.to_s.delete('"')
            if !desc.blank? && node['alt'].blank?
              node['title'] = desc
              node['alt'] = desc
            end
            node['loading'] = 'lazy'
          end
        end
      end

      def find_attachment(filename)
        return unless filename.valid_encoding?

        @attachments.detect do |att|
          filename.casecmp?(att.filename)
        end
      end
    end
  end
end
