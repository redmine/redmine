# frozen_string_literal: true

#
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
  module Export
    module PDF
      class RDMPdfEncoding
        def self.rdm_from_utf8(txt, encoding)
          txt ||= ''
          Redmine::CodesetUtil.from_utf8(txt, encoding).b
        end

        def self.attach(attachments, filename, encoding)
          filename_utf8 = Redmine::CodesetUtil.to_utf8(filename, encoding)
          atta = nil
          if /^[^\/"]+\.(gif|jpg|jpe|jpeg|png|webp)$/i.match?(filename_utf8)
            atta = Attachment.latest_attach(attachments, filename_utf8)
          end
          if atta && atta.readable? && atta.visible?
            return atta
          else
            return nil
          end
        end
      end
    end
  end
end
