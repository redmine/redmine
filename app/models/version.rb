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

module FixedIssuesExtension
  # Returns the total estimated time for this version
  # (sum of leaves estimated_hours)
  def estimated_hours
    @estimated_hours ||= sum(:estimated_hours).to_f
  end

  # Returns the total estimated remaining time for this version
  # (sum of leaves remaining_estimated_hours)
  def estimated_remaining_hours
    @estimated_remaining_hours ||= sum(IssueQuery::ESTIMATED_REMAINING_HOURS_SQL).to_f
  end

  # Returns the total amount of open issues for this version.
  def open_count
    load_counts
    @open_count
  end

  # Returns the total amount of closed issues for this version.
  def closed_count
    load_counts
    @closed_count
  end

  # Returns the completion percentage of this version based on the amount of open/closed issues
  # and the time spent on the open issues.
  def completed_percent
    return 0 if open_count + closed_count == 0
    return 100 if open_count == 0

    issues_progress(false) + issues_progress(true)
  end

  # Returns the percentage of issues that have been marked as 'closed'.
  def closed_percent
    return 0 if open_count + closed_count == 0
    return 100 if open_count == 0

    issues_progress(false)
  end

  private

  def load_counts
    unless @open_count
      @open_count = 0
      @closed_count = 0
      self.group(:status).count.each do |status, count|
        if status.is_closed?
          @closed_count += count
        else
          @open_count += count
        end
      end
    end
  end

  # Returns the average estimated time of assigned issues
  # or 1 if no issue has an estimated time
  # Used to weight unestimated issues in progress calculation
  def estimated_average
    if @estimated_average.nil?
      issues_with_total_estimated_hours = select {|c| c.total_estimated_hours.to_f > 0.0}
      if issues_with_total_estimated_hours.any?
        average = issues_with_total_estimated_hours.sum(&:total_estimated_hours).to_f / issues_with_total_estimated_hours.count
      else
        average = 1.0
      end
      @estimated_average = average
    end
    @estimated_average
  end

  # Returns the total progress of open or closed issues.  The returned percentage takes into account
  # the amount of estimated time set for this version.
  #
  # Examples:
  # issues_progress(true)   => returns the progress percentage for open issues.
  # issues_progress(false)  => returns the progress percentage for closed issues.
  def issues_progress(open)
    @issues_progress ||= {}
    @issues_progress[open] ||= begin
      progress = 0
      issues_count = open_count + closed_count
      if issues_count > 0
        done = self.open(open).sum do |c|
          estimated = c.total_estimated_hours.to_f
          estimated = estimated_average unless estimated > 0.0
          ratio = c.closed? ? 100 : (c.done_ratio || 0)
          estimated * ratio
        end
        progress = done / (estimated_average * issues_count)
      end
      progress
    end
  end
end

class Version < ApplicationRecord
  include Redmine::SafeAttributes

  after_update :update_issues_from_sharing_change
  before_destroy :nullify_projects_default_version
  after_save :update_default_project_version

  belongs_to :project
  has_many :fixed_issues, :class_name => 'Issue', :foreign_key => 'fixed_version_id', :dependent => :nullify, :extend => FixedIssuesExtension

  acts_as_customizable
  acts_as_attachable :view_permission => :view_files,
                     :edit_permission => :manage_files,
                     :delete_permission => :manage_files

  VERSION_STATUSES = %w(open locked closed)
  VERSION_SHARINGS = %w(none descendants hierarchy tree system)

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => [:project_id], :case_sensitive => true
  validates_length_of :name, :maximum => 60
  validates_length_of :description, :wiki_page_title, :maximum => 255
  validates :effective_date, :date => true
  validates_inclusion_of :status, :in => VERSION_STATUSES
  validates_inclusion_of :sharing, :in => VERSION_SHARINGS

  scope :named, lambda {|arg| where("LOWER(#{table_name}.name) = LOWER(?)", arg.to_s.strip)}
  scope :like, (lambda do |arg|
    if arg.present?
      pattern = "%#{sanitize_sql_like arg.to_s.strip}%"
      where([Redmine::Database.like("#{Version.table_name}.name", '?'), pattern])
    end
  end)
  scope :open, lambda {where(:status => 'open')}
  scope :status, (lambda do |status|
    if status.present?
      where(:status => status.to_s)
    end
  end)
  scope :visible, (lambda do |*args|
    joins(:project).
    where(Project.allowed_to_condition(args.first || User.current, :view_issues))
  end)

  safe_attributes 'name',
                  'description',
                  'effective_date',
                  'due_date',
                  'wiki_page_title',
                  'status',
                  'sharing',
                  'default_project_version',
                  'custom_field_values',
                  'custom_fields'

  def safe_attributes=(attrs, user=User.current)
    if attrs.respond_to?(:to_unsafe_hash)
      attrs = attrs.to_unsafe_hash
    end
    return unless attrs.is_a?(Hash)

    attrs = attrs.deep_dup
    # Reject custom fields values not visible by the user
    if attrs['custom_field_values'].present?
      editable_custom_field_ids = editable_custom_field_values(user).map {|v| v.custom_field_id.to_s}
      attrs['custom_field_values'].reject! {|k, v| !editable_custom_field_ids.include?(k.to_s)}
    end

    # Reject custom fields not visible by the user
    if attrs['custom_fields'].present?
      editable_custom_field_ids = editable_custom_field_values(user).map {|v| v.custom_field_id.to_s}
      attrs['custom_fields'].reject! {|c| !editable_custom_field_ids.include?(c['id'].to_s)}
    end

    super
  end

  # Returns true if +user+ or current user is allowed to view the version
  def visible?(user=User.current)
    user.allowed_to?(:view_issues, self.project)
  end

  # Returns the custom_field_values that can be edited by the given user
  def editable_custom_field_values(user=nil)
    visible_custom_field_values(user)
  end

  def visible_custom_field_values(user = nil)
    user ||= User.current
    custom_field_values.select do |value|
      value.custom_field.visible_by?(project, user)
    end
  end

  # Version files have same visibility as project files
  def attachments_visible?(*args)
    project.present? && project.attachments_visible?(*args)
  end

  def attachments_deletable?(usr=User.current)
    project.present? && project.attachments_deletable?(usr)
  end

  alias :base_reload :reload
  def reload(*args)
    @default_project_version = nil
    @visible_fixed_issues = nil
    base_reload(*args)
  end

  def start_date
    @start_date ||= fixed_issues.minimum('start_date')
  end

  def due_date
    effective_date
  end

  def due_date=(arg)
    self.effective_date=(arg)
  end

  # Returns the total estimated time for this version
  # (sum of leaves estimated_hours)
  def estimated_hours
    fixed_issues.estimated_hours
  end

  # Returns the total estimated remaining time for this version
  # (sum of leaves estimated_remaining_hours)
  def estimated_remaining_hours
    @estimated_remaining_hours ||= fixed_issues.estimated_remaining_hours
  end

  # Returns the total reported time for this version
  def spent_hours
    @spent_hours ||= TimeEntry.joins(:issue).where("#{Issue.table_name}.fixed_version_id = ?", id).sum(:hours).to_f
  end

  def closed?
    status == 'closed'
  end

  def open?
    status == 'open'
  end

  # Returns true if the version is completed: closed or due date reached and no open issues
  def completed?
    closed? || (effective_date && (effective_date < User.current.today) && (open_issues_count == 0))
  end

  def behind_schedule?
    # Blank due date, no issues, or 100% completed, so it's not late
    return false if due_date.nil? || start_date.nil? || completed_percent == 100

    done_date = start_date + ((due_date - start_date + 1) * completed_percent / 100).floor
    done_date <= User.current.today
  end

  # Returns the completion percentage of this version based on the amount of open/closed issues
  # and the time spent on the open issues.
  def completed_percent
    fixed_issues.completed_percent
  end

  # Returns the percentage of issues that have been marked as 'closed'.
  def closed_percent
    fixed_issues.closed_percent
  end

  # Returns true if the version is overdue: due date reached and some open issues
  def overdue?
    effective_date && (effective_date < User.current.today) && (open_issues_count > 0)
  end

  # Returns assigned issues count
  def issues_count
    fixed_issues.count
  end

  # Returns the total amount of open issues for this version.
  def open_issues_count
    fixed_issues.open_count
  end

  # Returns the total amount of closed issues for this version.
  def closed_issues_count
    fixed_issues.closed_count
  end

  def visible_fixed_issues
    @visible_fixed_issues ||= fixed_issues.visible
  end

  def wiki_page
    if project.wiki && !wiki_page_title.blank?
      @wiki_page ||= project.wiki.find_page(wiki_page_title)
    end
    @wiki_page
  end

  def to_s; name end

  def to_s_with_project
    "#{project} - #{name}"
  end

  # Versions are sorted by effective_date and name
  # Those with no effective_date are at the end, sorted by name
  def <=>(version)
    return nil unless version.is_a?(Version)

    if self.effective_date
      if version.effective_date
        if self.effective_date == version.effective_date
          name == version.name ? id <=> version.id : name <=> version.name
        else
          self.effective_date <=> version.effective_date
        end
      else
        -1
      end
    else
      if version.effective_date
        1
      else
        name == version.name ? id <=> version.id : name <=> version.name
      end
    end
  end

  # Sort versions by status (open, locked then closed versions)
  def self.sort_by_status(versions)
    versions.sort do |a, b|
      if a.status == b.status
        a <=> b
      else
        b.status <=> a.status
      end
    end
  end

  def css_classes
    [
      completed? ? 'version-completed' : 'version-incompleted',
      "version-#{status}"
    ].join(' ')
  end

  def self.fields_for_order_statement(table=nil)
    table ||= table_name
    [Arel.sql("(CASE WHEN #{table}.effective_date IS NULL THEN 1 ELSE 0 END)"), "#{table}.effective_date", "#{table}.name", "#{table}.id"]
  end

  scope :sorted, lambda {order(fields_for_order_statement)}

  # Returns the sharings that +user+ can set the version to
  def allowed_sharings(user = User.current)
    VERSION_SHARINGS.select do |s|
      if sharing == s
        true
      else
        case s
        when 'system'
          # Only admin users can set a systemwide sharing
          user.admin?
        when 'hierarchy', 'tree'
          # Only users allowed to manage versions of the root project can
          # set sharing to hierarchy or tree
          project.nil? || user.allowed_to?(:manage_versions, project.root)
        else
          true
        end
      end
    end
  end

  # Returns true if the version is shared, otherwise false
  def shared?
    sharing != 'none'
  end

  def deletable?
    fixed_issues.empty? && !referenced_by_a_custom_field? && attachments.empty?
  end

  def default_project_version
    if @default_project_version.nil?
      project.present? && project.default_version == self
    else
      @default_project_version
    end
  end

  def default_project_version=(arg)
    @default_project_version = (arg == '1' || arg == true)
  end

  private

  # Update the issue's fixed versions. Used if a version's sharing changes.
  def update_issues_from_sharing_change
    if saved_change_to_sharing?
      if VERSION_SHARINGS.index(sharing_before_last_save).nil? ||
          VERSION_SHARINGS.index(sharing).nil? ||
          VERSION_SHARINGS.index(sharing_before_last_save) > VERSION_SHARINGS.index(sharing)
        Issue.update_versions_from_sharing_change self
      end
    end
  end

  def update_default_project_version
    if @default_project_version && project.present?
      project.update_columns :default_version_id => id
    end
  end

  def referenced_by_a_custom_field?
    CustomValue.joins(:custom_field).
      where(:value => id.to_s, :custom_fields => {:field_format => 'version'}).any?
  end

  def nullify_projects_default_version
    Project.where(:default_version_id => id).update_all(:default_version_id => nil)
  end
end
