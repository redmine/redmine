# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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
  include Redmine::SafeAttributes

  CORE_FIELDS_UNDISABLABLE = %w(project_id tracker_id subject priority_id is_private).freeze
  # Fields that can be disabled
  # Other (future) fields should be appended, not inserted!
  CORE_FIELDS = %w(assigned_to_id category_id fixed_version_id parent_issue_id start_date due_date estimated_hours done_ratio description).freeze
  CORE_FIELDS_ALL = (CORE_FIELDS_UNDISABLABLE + CORE_FIELDS).freeze

  before_destroy :check_integrity
  belongs_to :default_status, :class_name => 'IssueStatus'
  has_many :issues
  has_many :workflow_rules, :dependent => :delete_all
  has_and_belongs_to_many :projects
  has_and_belongs_to_many :custom_fields, :class_name => 'IssueCustomField', :join_table => "#{table_name_prefix}custom_fields_trackers#{table_name_suffix}", :association_foreign_key => 'custom_field_id'
  acts_as_positioned

  validates_presence_of :default_status
  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 30
  validates_length_of :description, :maximum => 255

  scope :sorted, lambda { order(:position) }
  scope :named, lambda {|arg| where("LOWER(#{table_name}.name) = LOWER(?)", arg.to_s.strip)}

  # Returns the trackers that are visible by the user.
  #
  # Examples:
  #   project.trackers.visible(user)
  #   => returns the trackers that are visible by the user in project
  #
  #   Tracker.visible(user)
  #   => returns the trackers that are visible by the user in at least on project
  scope :visible, lambda {|*args|
    user = args.shift || User.current
    condition = Project.allowed_to_condition(user, :view_issues) do |role, user|
      unless role.permissions_all_trackers?(:view_issues)
        tracker_ids = role.permissions_tracker_ids(:view_issues)
        if tracker_ids.any?
          "#{Tracker.table_name}.id IN (#{tracker_ids.join(',')})"
        else
          '1=0'
        end
      end
    end
    joins(:projects).where(condition).distinct
  }

  safe_attributes(
    'name',
    'default_status_id',
    'is_in_roadmap',
    'core_fields',
    'position',
    'custom_field_ids',
    'project_ids',
    'description')

  def to_s; name end

  def <=>(tracker)
    position <=> tracker.position
  end

  # Returns an array of IssueStatus that are used
  # in the tracker's workflows
  def issue_statuses
    @issue_statuses ||= IssueStatus.where(:id => issue_status_ids).to_a.sort
  end

  def issue_status_ids
    if new_record?
      []
    else
      @issue_status_ids ||= WorkflowTransition.where(:tracker_id => id).distinct.pluck(:old_status_id, :new_status_id).flatten.uniq
    end
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

  def copy_workflow_rules(source_tracker)
    WorkflowRule.copy(source_tracker, nil, self, nil)
  end

  # Returns the fields that are disabled for all the given trackers
  def self.disabled_core_fields(trackers)
    if trackers.present?
      trackers.map(&:disabled_core_fields).reduce(:&)
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
    raise "Cannot delete tracker" if Issue.where(:tracker_id => self.id).any?
  end
end
