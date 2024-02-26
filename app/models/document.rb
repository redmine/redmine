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

class Document < ApplicationRecord
  include Redmine::SafeAttributes
  belongs_to :project
  belongs_to :category, :class_name => "DocumentCategory"
  acts_as_attachable :delete_permission => :delete_documents
  acts_as_customizable

  acts_as_searchable :columns => ['title', "#{table_name}.description"],
                     :preload => :project
  acts_as_event(
    :title => Proc.new {|o| "#{l(:label_document)}: #{o.title}"},
    :author =>
      Proc.new do |o|
        o.attachments.reorder("#{Attachment.table_name}.created_on ASC").
          first.try(:author)
      end,
    :url =>
      Proc.new do |o|
        {:controller => 'documents', :action => 'show', :id => o.id}
      end
  )
  acts_as_activity_provider :scope => proc {preload(:project)}

  validates_presence_of :project, :title, :category
  validates_length_of :title, :maximum => 255

  after_create_commit :send_notification

  scope :visible, (lambda do |*args|
    joins(:project).
    where(Project.allowed_to_condition(args.shift || User.current, :view_documents, *args))
  end)

  safe_attributes 'category_id', 'title', 'description', 'custom_fields', 'custom_field_values'

  def visible?(user=User.current)
    !user.nil? && user.allowed_to?(:view_documents, project)
  end

  def initialize(attributes=nil, *args)
    super
    if new_record?
      self.category ||= DocumentCategory.default
    end
  end

  def updated_on
    unless @updated_on
      a = attachments.last
      @updated_on = (a && a.created_on) || created_on
    end
    @updated_on
  end

  def notified_users
    project.notified_users.reject {|user| !visible?(user)}
  end

  private

  def send_notification
    if Setting.notified_events.include?('document_added')
      Mailer.deliver_document_added(self, User.current)
    end
  end
end
