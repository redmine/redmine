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

class IssueStatus < ActiveRecord::Base
  before_destroy :check_integrity
  has_many :workflows, :class_name => 'WorkflowTransition', :foreign_key => "old_status_id"
  acts_as_list

  before_destroy :delete_workflow_rules
  after_save     :update_default

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 30
  validates_inclusion_of :default_done_ratio, :in => 0..100, :allow_nil => true

  scope :sorted, lambda { order("#{table_name}.position ASC") }
  scope :named, lambda {|arg| where("LOWER(#{table_name}.name) = LOWER(?)", arg.to_s.strip)}

  def update_default
    IssueStatus.update_all({:is_default => false}, ['id <> ?', id]) if self.is_default?
  end

  # Returns the default status for new issues
  def self.default
    where(:is_default => true).first
  end

  # Update all the +Issues+ setting their done_ratio to the value of their +IssueStatus+
  def self.update_issue_done_ratios
    if Issue.use_status_for_done_ratio?
      IssueStatus.where("default_done_ratio >= 0").all.each do |status|
        Issue.update_all({:done_ratio => status.default_done_ratio}, {:status_id => status.id})
      end
    end

    return Issue.use_status_for_done_ratio?
  end

  # Returns an array of all statuses the given role can switch to
  # Uses association cache when called more than one time
  def new_statuses_allowed_to(roles, tracker, author=false, assignee=false)
    if roles && tracker
      role_ids = roles.collect(&:id)
      transitions = workflows.select do |w|
        role_ids.include?(w.role_id) &&
        w.tracker_id == tracker.id &&
        ((!w.author && !w.assignee) || (author && w.author) || (assignee && w.assignee))
      end
      transitions.map(&:new_status).compact.sort
    else
      []
    end
  end

  # Same thing as above but uses a database query
  # More efficient than the previous method if called just once
  def find_new_statuses_allowed_to(roles, tracker, author=false, assignee=false)
    if roles.present? && tracker
      conditions = "(author = :false AND assignee = :false)"
      conditions << " OR author = :true" if author
      conditions << " OR assignee = :true" if assignee

      workflows.
        includes(:new_status).
        where(["role_id IN (:role_ids) AND tracker_id = :tracker_id AND (#{conditions})",
          {:role_ids => roles.collect(&:id), :tracker_id => tracker.id, :true => true, :false => false}
          ]).all.
        map(&:new_status).compact.sort
    else
      []
    end
  end

  def <=>(status)
    position <=> status.position
  end

  def to_s; name end

  private

  def check_integrity
    raise "Can't delete status" if Issue.where(:status_id => id).any?
  end

  # Deletes associated workflows
  def delete_workflow_rules
    WorkflowRule.delete_all(["old_status_id = :id OR new_status_id = :id", {:id => id}])
  end
end
