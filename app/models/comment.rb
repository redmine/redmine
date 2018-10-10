# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class Comment < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :commented, :polymorphic => true, :counter_cache => true
  belongs_to :author, :class_name => 'User'

  validates_presence_of :commented, :author, :content

  after_create_commit :send_notification

  safe_attributes 'comments'

  def comments=(arg)
    self.content = arg
  end

  def comments
    content
  end

  private

  def send_notification
    event = "#{commented.class.name.underscore}_comment_added"
    if Setting.notified_events.include?(event)
      Mailer.public_send("deliver_#{event}", self)
    end
  end
end
