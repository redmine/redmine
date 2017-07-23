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

class Board < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :project
  has_many :messages, lambda {order("#{Message.table_name}.created_on DESC")}, :dependent => :destroy
  belongs_to :last_message, :class_name => 'Message'
  acts_as_tree :dependent => :nullify
  acts_as_positioned :scope => [:project_id, :parent_id]
  acts_as_watchable

  validates_presence_of :name, :description
  validates_length_of :name, :maximum => 30
  validates_length_of :description, :maximum => 255
  validate :validate_board

  scope :visible, lambda {|*args|
    joins(:project).
    where(Project.allowed_to_condition(args.shift || User.current, :view_messages, *args))
  }

  safe_attributes 'name', 'description', 'parent_id', 'position'

  def visible?(user=User.current)
    !user.nil? && user.allowed_to?(:view_messages, project)
  end

  def reload(*args)
    @valid_parents = nil
    super
  end

  def to_s
    name
  end

  # Returns a scope for the board topics (messages without parent)
  def topics
    messages.where(:parent_id => nil)
  end

  def valid_parents
    @valid_parents ||= project.boards - self_and_descendants
  end

  def reset_counters!
    self.class.reset_counters!(id)
  end

  # Updates topics_count, messages_count and last_message_id attributes for +board_id+
  def self.reset_counters!(board_id)
    board_id = board_id.to_i
    Board.where(:id => board_id).
      update_all(["topics_count = (SELECT COUNT(*) FROM #{Message.table_name} WHERE board_id=:id AND parent_id IS NULL)," +
               " messages_count = (SELECT COUNT(*) FROM #{Message.table_name} WHERE board_id=:id)," +
               " last_message_id = (SELECT MAX(id) FROM #{Message.table_name} WHERE board_id=:id)", :id => board_id])
  end

  def self.board_tree(boards, parent_id=nil, level=0)
    tree = []
    boards.select {|board| board.parent_id == parent_id}.sort_by(&:position).each do |board|
      tree << [board, level]
      tree += board_tree(boards, board.id, level+1)
    end
    if block_given?
      tree.each do |board, level|
        yield board, level
      end
    end
    tree
  end

  protected

  def validate_board
    if parent_id && parent_id_changed?
      errors.add(:parent_id, :invalid) unless valid_parents.include?(parent)
    end
  end
end
