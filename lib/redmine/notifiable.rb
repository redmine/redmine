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
  class Notifiable < Struct.new(:name, :parent)
    def to_s
      name
    end

    # TODO: Plugin API for adding a new notification?
    def self.all
      notifications = []
      notifications << Notifiable.new('issue_added')
      notifications << Notifiable.new('issue_updated')
      notifications << Notifiable.new('issue_note_added', 'issue_updated')
      notifications << Notifiable.new('issue_status_updated', 'issue_updated')
      notifications << Notifiable.new('issue_assigned_to_updated', 'issue_updated')
      notifications << Notifiable.new('issue_priority_updated', 'issue_updated')
      notifications << Notifiable.new('issue_fixed_version_updated', 'issue_updated')
      notifications << Notifiable.new('issue_attachment_added', 'issue_updated')
      notifications << Notifiable.new('news_added')
      notifications << Notifiable.new('news_comment_added')
      notifications << Notifiable.new('document_added')
      notifications << Notifiable.new('file_added')
      notifications << Notifiable.new('message_posted')
      notifications << Notifiable.new('wiki_content_added')
      notifications << Notifiable.new('wiki_content_updated')
      notifications
    end
  end
end
