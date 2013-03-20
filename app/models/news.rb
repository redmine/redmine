# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class News < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :project
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  has_many :comments, :as => :commented, :dependent => :delete_all, :order => "created_on"

  validates_presence_of :title, :description
  validates_length_of :title, :maximum => 60
  validates_length_of :summary, :maximum => 255

  acts_as_attachable :delete_permission => :manage_news
  acts_as_searchable :columns => ['title', 'summary', "#{table_name}.description"], :include => :project
  acts_as_event :url => Proc.new {|o| {:controller => 'news', :action => 'show', :id => o.id}}
  acts_as_activity_provider :find_options => {:include => [:project, :author]},
                            :author_key => :author_id
  acts_as_watchable

  after_create :add_author_as_watcher

  scope :visible, lambda {|*args|
    includes(:project).where(Project.allowed_to_condition(args.shift || User.current, :view_news, *args))
  }

  safe_attributes 'title', 'summary', 'description'

  def visible?(user=User.current)
    !user.nil? && user.allowed_to?(:view_news, project)
  end

  # Returns true if the news can be commented by user
  def commentable?(user=User.current)
    user.allowed_to?(:comment_news, project)
  end

  def recipients
    project.users.select {|user| user.notify_about?(self)}.map(&:mail)
  end

  # returns latest news for projects visible by user
  def self.latest(user = User.current, count = 5)
    visible(user).includes([:author, :project]).order("#{News.table_name}.created_on DESC").limit(count).all
  end

  private

  def add_author_as_watcher
    Watcher.create(:watchable => self, :user => author)
  end
end
