# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class Version < ActiveRecord::Base
  include Redmine::SafeAttributes

  after_update :update_issues_from_sharing_change
  before_destroy :nullify_projects_default_version

  belongs_to :project
  has_many :fixed_issues, :class_name => 'Issue', :foreign_key => 'fixed_version_id', :dependent => :nullify
  acts_as_customizable
  acts_as_attachable :view_permission => :view_files,
                     :edit_permission => :manage_files,
                     :delete_permission => :manage_files

  VERSION_STATUSES = %w(open locked closed)
  VERSION_SHARINGS = %w(none descendants hierarchy tree system)

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => [:project_id]
  validates_length_of :name, :maximum => 60
  validates_length_of :description, :maximum => 255
  validates :effective_date, :date => true
  validates_inclusion_of :status, :in => VERSION_STATUSES
  validates_inclusion_of :sharing, :in => VERSION_SHARINGS
  attr_protected :id

  scope :named, lambda {|arg| where("LOWER(#{table_name}.name) = LOWER(?)", arg.to_s.strip)}
  scope :open, lambda { where(:status => 'open') }
  scope :visible, lambda {|*args|
    joins(:project).
    where(Project.allowed_to_condition(args.first || User.current, :view_issues))
  }

  safe_attributes 'name',
    'description',
    'effective_date',
    'due_date',
    'wiki_page_title',
    'status',
    'sharing',
    'custom_field_values',
    'custom_fields'

  # Returns true if +user+ or current user is allowed to view the version
  def visible?(user=User.current)
    user.allowed_to?(:view_issues, self.project)
  end

  # Version files have same visibility as project files
  def attachments_visible?(*args)
    project.present? && project.attachments_visible?(*args)
  end

  def attachments_deletable?(usr=User.current)
    project.present? && project.attachments_deletable?(usr)
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
    @estimated_hours ||= fixed_issues.sum(:estimated_hours).to_f
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

  # Returns true if the version is completed: due date reached and no open issues
  def completed?
    effective_date && (effective_date < Date.today) && (open_issues_count == 0)
  end

  def behind_schedule?
    if completed_percent == 100
      return false
    elsif due_date && start_date
      done_date = start_date + ((due_date - start_date+1)* completed_percent/100).floor
      return done_date <= Date.today
    else
      false # No issues so it's not late
    end
  end

  # Returns the completion percentage of this version based on the amount of open/closed issues
  # and the time spent on the open issues.
  def completed_percent
    if issues_count == 0
      0
    elsif open_issues_count == 0
      100
    else
      issues_progress(false) + issues_progress(true)
    end
  end

  # Returns the percentage of issues that have been marked as 'closed'.
  def closed_percent
    if issues_count == 0
      0
    else
      issues_progress(false)
    end
  end

  # Returns true if the version is overdue: due date reached and some open issues
  def overdue?
    effective_date && (effective_date < Date.today) && (open_issues_count > 0)
  end

  # Returns assigned issues count
  def issues_count
    load_issue_counts
    @issue_count
  end

  # Returns the total amount of open issues for this version.
  def open_issues_count
    load_issue_counts
    @open_issues_count
  end

  # Returns the total amount of closed issues for this version.
  def closed_issues_count
    load_issue_counts
    @closed_issues_count
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

  def self.fields_for_order_statement(table=nil)
    table ||= table_name
    ["(CASE WHEN #{table}.effective_date IS NULL THEN 1 ELSE 0 END)", "#{table}.effective_date", "#{table}.name", "#{table}.id"]
  end

  scope :sorted, lambda { order(fields_for_order_statement) }

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
    fixed_issues.empty? && !referenced_by_a_custom_field?
  end

  private

  def load_issue_counts
    unless @issue_count
      @open_issues_count = 0
      @closed_issues_count = 0
      fixed_issues.group(:status).count.each do |status, count|
        if status.is_closed?
          @closed_issues_count += count
        else
          @open_issues_count += count
        end
      end
      @issue_count = @open_issues_count + @closed_issues_count
    end
  end

  # Update the issue's fixed versions. Used if a version's sharing changes.
  def update_issues_from_sharing_change
    if sharing_changed?
      if VERSION_SHARINGS.index(sharing_was).nil? ||
          VERSION_SHARINGS.index(sharing).nil? ||
          VERSION_SHARINGS.index(sharing_was) > VERSION_SHARINGS.index(sharing)
        Issue.update_versions_from_sharing_change self
      end
    end
  end

  # Returns the average estimated time of assigned issues
  # or 1 if no issue has an estimated time
  # Used to weight unestimated issues in progress calculation
  def estimated_average
    if @estimated_average.nil?
      average = fixed_issues.average(:estimated_hours).to_f
      if average == 0
        average = 1
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
      if issues_count > 0
        ratio = open ? 'done_ratio' : 100

        done = fixed_issues.open(open).sum("COALESCE(estimated_hours, #{estimated_average}) * #{ratio}").to_f
        progress = done / (estimated_average * issues_count)
      end
      progress
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
