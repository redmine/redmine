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

class Tracker < ActiveRecord::Base

  CORE_FIELDS_UNDISABLABLE = %w(project_id tracker_id subject description priority_id is_private).freeze
  # Fields that can be disabled
  # Other (future) fields should be appended, not inserted!
  CORE_FIELDS = %w(assigned_to_id category_id fixed_version_id parent_issue_id start_date due_date estimated_hours done_ratio).freeze
  CORE_FIELDS_ALL = (CORE_FIELDS_UNDISABLABLE + CORE_FIELDS).freeze

  before_destroy :check_integrity
  has_many :issues
  has_many :workflow_rules, :dependent => :delete_all do
    def copy(source_tracker)
      WorkflowRule.copy(source_tracker, nil, proxy_association.owner, nil)
    end
  end

  has_and_belongs_to_many :projects
  has_and_belongs_to_many :custom_fields, :class_name => 'IssueCustomField', :join_table => "#{table_name_prefix}custom_fields_trackers#{table_name_suffix}", :association_foreign_key => 'custom_field_id'
  acts_as_list

  attr_protected :fields_bits

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 30

  scope :sorted, lambda { order("#{table_name}.position ASC") }
  scope :named, lambda {|arg| where("LOWER(#{table_name}.name) = LOWER(?)", arg.to_s.strip)}

  def to_s; name end

  def <=>(tracker)
    position <=> tracker.position
  end

  # Returns an array of IssueStatus that are used
  # in the tracker's workflows
  def issue_statuses
    if @issue_statuses
      return @issue_statuses
    elsif new_record?
      return []
    end

    ids = WorkflowTransition.
            connection.select_rows("SELECT DISTINCT old_status_id, new_status_id FROM #{WorkflowTransition.table_name} WHERE tracker_id = #{id} AND type = 'WorkflowTransition'").
            flatten.
            uniq

    @issue_statuses = IssueStatus.find_all_by_id(ids).sort
  end

  def disabled_core_fields
    i = -1
    @disabled_core_fields ||= CORE_FIELDS.select { i += 1; (fields_bits || 0) & (2 ** i) != 0}
  end

  def core_fields
    CORE_FIELDS - disabled_core_fields
  end

  def core_fields=(fields)
    raise ArgumentError.new("Tracker.core_fields takes an array") unless fields.is_a?(Array)

    bits = 0
    CORE_FIELDS.each_with_index do |field, i|
      unless fields.include?(field)
        bits |= 2 ** i
      end
    end
    self.fields_bits = bits
    @disabled_core_fields = nil
    core_fields
  end

  # Returns the fields that are disabled for all the given trackers
  def self.disabled_core_fields(trackers)
    if trackers.present?
      trackers.uniq.map(&:disabled_core_fields).reduce(:&)
    else
      []
    end
  end

  # Returns the fields that are enabled for one tracker at least
  def self.core_fields(trackers)
    if trackers.present?
      trackers.uniq.map(&:core_fields).reduce(:|)
    else
      CORE_FIELDS.dup
    end
  end

private
  def check_integrity
    raise Exception.new("Can't delete tracker") if Issue.where(:tracker_id => self.id).any?
  end
end
