# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class Issue < ActiveRecord::Base
  include Redmine::SafeAttributes
  include Redmine::Utils::DateCalculation
  include Redmine::I18n
  before_save :set_parent_id
  include Redmine::NestedSet::IssueNestedSet

  belongs_to :project
  belongs_to :tracker
  belongs_to :status, :class_name => 'IssueStatus'
  belongs_to :author, :class_name => 'User'
  belongs_to :assigned_to, :class_name => 'Principal'
  belongs_to :fixed_version, :class_name => 'Version'
  belongs_to :priority, :class_name => 'IssuePriority'
  belongs_to :category, :class_name => 'IssueCategory'

  has_many :journals, :as => :journalized, :dependent => :destroy, :inverse_of => :journalized
  has_many :time_entries, :dependent => :destroy
  has_and_belongs_to_many :changesets, lambda {order("#{Changeset.table_name}.committed_on ASC, #{Changeset.table_name}.id ASC")}

  has_many :relations_from, :class_name => 'IssueRelation', :foreign_key => 'issue_from_id', :dependent => :delete_all
  has_many :relations_to, :class_name => 'IssueRelation', :foreign_key => 'issue_to_id', :dependent => :delete_all

  acts_as_attachable :after_add => :attachment_added, :after_remove => :attachment_removed
  acts_as_customizable
  acts_as_watchable
  acts_as_searchable :columns => ['subject', "#{table_name}.description"],
                     :preload => [:project, :status, :tracker],
                     :scope => lambda {|options| options[:open_issues] ? self.open : self.all}

  acts_as_event :title => Proc.new {|o| "#{o.tracker.name} ##{o.id} (#{o.status}): #{o.subject}"},
                :url => Proc.new {|o| {:controller => 'issues', :action => 'show', :id => o.id}},
                :type => Proc.new {|o| 'issue' + (o.closed? ? '-closed' : '')}

  acts_as_activity_provider :scope => proc {preload(:project, :author, :tracker, :status)},
                            :author_key => :author_id

  acts_as_mentionable :attributes => ['description']

  DONE_RATIO_OPTIONS = %w(issue_field issue_status)

  attr_reader :transition_warning
  attr_writer :deleted_attachment_ids
  delegate :notes, :notes=, :private_notes, :private_notes=, :to => :current_journal, :allow_nil => true

  validates_presence_of :subject, :project, :tracker
  validates_presence_of :priority, :if => Proc.new {|issue| issue.new_record? || issue.priority_id_changed?}
  validates_presence_of :status, :if => Proc.new {|issue| issue.new_record? || issue.status_id_changed?}
  validates_presence_of :author, :if => Proc.new {|issue| issue.new_record? || issue.author_id_changed?}

  validates_length_of :subject, :maximum => 255
  validates_inclusion_of :done_ratio, :in => 0..100
  validates :estimated_hours, :numericality => {:greater_than_or_equal_to => 0, :allow_nil => true, :message => :invalid}
  validates :start_date, :date => true
  validates :due_date, :date => true
  validate :validate_issue, :validate_required_fields, :validate_permissions

  scope :visible, (lambda do |*args|
    joins(:project).
    where(Issue.visible_condition(args.shift || User.current, *args))
  end)

  scope :open, (lambda do |*args|
    is_closed = !args.empty? ? !args.first : false
    joins(:status).
    where(:issue_statuses => {:is_closed => is_closed})
  end)

  scope :recently_updated, lambda {order(:updated_on => :desc)}
  scope :on_active_project, (lambda do
    joins(:project).
    where(:projects => {:status => Project::STATUS_ACTIVE})
  end)
  scope :fixed_version, (lambda do |versions|
    ids = [versions].flatten.compact.map {|v| v.is_a?(Version) ? v.id : v}
    ids.any? ? where(:fixed_version_id => ids) : none
  end)
  scope :assigned_to, (lambda do |arg|
    arg = Array(arg).uniq
    ids = arg.map {|p| p.is_a?(Principal) ? p.id : p}
    ids += arg.select {|p| p.is_a?(User)}.map(&:group_ids).flatten.uniq
    ids.compact!
    ids.any? ? where(:assigned_to_id => ids) : none
  end)
  scope :like, (lambda do |q|
    if q.present?
      where(*::Query.tokenized_like_conditions("#{table_name}.subject", q))
    end
  end)

  before_validation :default_assign, on: :create
  before_validation :clear_disabled_fields
  before_save :close_duplicates, :update_done_ratio_from_issue_status,
              :force_updated_on_change, :update_closed_on
  after_save do |issue|
    if !issue.saved_change_to_id? && issue.saved_change_to_project_id?
      issue.send :after_project_change
    end
  end
  after_save :reschedule_following_issues, :update_nested_set_attributes,
             :update_parent_attributes, :delete_selected_attachments, :create_journal
  # Should be after_create but would be called before previous after_save callbacks
  after_save :after_create_from_copy, :create_parent_issue_journal
  after_destroy :update_parent_attributes, :create_parent_issue_journal
  after_create_commit :send_notification

  # Returns a SQL conditions string used to find all issues visible by the specified user
  def self.visible_condition(user, options={})
    Project.allowed_to_condition(user, :view_issues, options) do |role, user|
      sql =
        if user.id && user.logged?
          case role.issues_visibility
          when 'all'
            '1=1'
          when 'default'
            user_ids = [user.id] + user.groups.pluck(:id).compact
            "(#{table_name}.is_private = #{connection.quoted_false} " \
              "OR #{table_name}.author_id = #{user.id} " \
              "OR #{table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
          when 'own'
            user_ids = [user.id] + user.groups.pluck(:id).compact
            "(#{table_name}.author_id = #{user.id} OR " \
              "#{table_name}.assigned_to_id IN (#{user_ids.join(',')}))"
          else
            '1=0'
          end
        else
          "(#{table_name}.is_private = #{connection.quoted_false})"
        end
      unless role.permissions_all_trackers?(:view_issues)
        tracker_ids = role.permissions_tracker_ids(:view_issues)
        if tracker_ids.any?
          sql = "(#{sql} AND #{table_name}.tracker_id IN (#{tracker_ids.join(',')}))"
        else
          sql = '1=0'
        end
      end
      sql
    end
  end

  # Returns true if usr or current user is allowed to view the issue
  def visible?(usr=nil)
    (usr || User.current).allowed_to?(:view_issues, self.project) do |role, user|
      visible =
        if user.logged?
          case role.issues_visibility
          when 'all'
            true
          when 'default'
            !self.is_private? || (self.author == user || user.is_or_belongs_to?(assigned_to))
          when 'own'
            self.author == user || user.is_or_belongs_to?(assigned_to)
          else
            false
          end
        else
          !self.is_private?
        end
      unless role.permissions_all_trackers?(:view_issues)
        visible &&= role.permissions_tracker_ids?(:view_issues, tracker_id)
      end
      visible
    end
  end

  # Returns true if user or current user is allowed to edit or add notes to the issue
  def editable?(user=User.current)
    attributes_editable?(user) || notes_addable?(user)
  end

  # Returns true if user or current user is allowed to edit the issue
  def attributes_editable?(user=User.current)
    user_tracker_permission?(user, :edit_issues) || (
      user_tracker_permission?(user, :edit_own_issues) && author == user
    )
  end

  # Overrides Redmine::Acts::Attachable::InstanceMethods#attachments_editable?
  def attachments_editable?(user=User.current)
    attributes_editable?(user)
  end

  # Returns true if user or current user is allowed to add notes to the issue
  def notes_addable?(user=User.current)
    user_tracker_permission?(user, :add_issue_notes)
  end

  # Returns true if user or current user is allowed to delete the issue
  def deletable?(user=User.current)
    user_tracker_permission?(user, :delete_issues)
  end

  # Overrides Redmine::Acts::Attachable::InstanceMethods#attachments_deletable?
  def attachments_deletable?(user=User.current)
    attributes_editable?(user)
  end

  def initialize(attributes=nil, *args)
    super
    if new_record?
      # set default values for new records only
      self.priority ||= IssuePriority.default
      self.watcher_user_ids = []
    end
  end

  def create_or_update(*args)
    super()
  ensure
    @status_was = nil
  end
  private :create_or_update

  # AR#Persistence#destroy would raise and RecordNotFound exception
  # if the issue was already deleted or updated (non matching lock_version).
  # This is a problem when bulk deleting issues or deleting a project
  # (because an issue may already be deleted if its parent was deleted
  # first).
  # The issue is reloaded by the nested_set before being deleted so
  # the lock_version condition should not be an issue but we handle it.
  def destroy
    super
  rescue ActiveRecord::StaleObjectError, ActiveRecord::RecordNotFound
    # Stale or already deleted
    begin
      reload
    rescue ActiveRecord::RecordNotFound
      # The issue was actually already deleted
      @destroyed = true
      return freeze
    end
    # The issue was stale, retry to destroy
    super
  end

  alias :base_reload :reload
  def reload(*args)
    @workflow_rule_by_attribute = nil
    @assignable_versions = nil
    @relations = nil
    @spent_hours = nil
    @total_spent_hours = nil
    @total_estimated_hours = nil
    @last_updated_by = nil
    @last_notes = nil
    base_reload(*args)
  end

  # Overrides Redmine::Acts::Customizable::InstanceMethods#available_custom_fields
  def available_custom_fields
    (project && tracker) ? (project.all_issue_custom_fields & tracker.custom_fields) : []
  end

  def visible_custom_field_values(user=nil)
    user_real = user || User.current
    custom_field_values.select do |value|
      value.custom_field.visible_by?(project, user_real)
    end
  end

  # Overrides Redmine::Acts::Customizable::InstanceMethods#set_custom_field_default?
  def set_custom_field_default?(custom_value)
    new_record? || project_id_changed?|| tracker_id_changed?
  end

  # Copies attributes from another issue, arg can be an id or an Issue
  def copy_from(arg, options={})
    issue = arg.is_a?(Issue) ? arg : Issue.visible.find(arg)
    self.attributes =
      issue.attributes.dup.except(
        "id", "root_id", "parent_id", "lft", "rgt",
        "created_on", "updated_on", "status_id", "closed_on"
      )
    self.custom_field_values =
      issue.custom_field_values.inject({}) do |h, v|
        h[v.custom_field_id] = v.value
        h
      end
    if options[:keep_status]
      self.status = issue.status
    end
    self.author = User.current
    unless options[:attachments] == false
      self.attachments = issue.attachments.map do |attachement|
        attachement.copy(:container => self)
      end
    end
    unless options[:watchers] == false
      self.watcher_user_ids =
        issue.watcher_users.select{|u| u.status == User::STATUS_ACTIVE}.map(&:id)
    end
    @copied_from = issue
    @copy_options = options
    self
  end

  # Returns an unsaved copy of the issue
  def copy(attributes=nil, copy_options={})
    copy = self.class.new.copy_from(self, copy_options)
    copy.attributes = attributes if attributes
    copy
  end

  # Returns true if the issue is a copy
  def copy?
    @copied_from.present?
  end

  def status_id=(status_id)
    if status_id.to_s != self.status_id.to_s
      self.status = (status_id.present? ? IssueStatus.find_by_id(status_id) : nil)
    end
    self.status_id
  end

  # Sets the status.
  def status=(status)
    if status != self.status
      @workflow_rule_by_attribute = nil
    end
    association(:status).writer(status)
  end

  def priority_id=(pid)
    self.priority = nil
    write_attribute(:priority_id, pid)
  end

  def category_id=(cid)
    self.category = nil
    write_attribute(:category_id, cid)
  end

  def fixed_version_id=(vid)
    self.fixed_version = nil
    write_attribute(:fixed_version_id, vid)
  end

  def tracker_id=(tracker_id)
    if tracker_id.to_s != self.tracker_id.to_s
      self.tracker = (tracker_id.present? ? Tracker.find_by_id(tracker_id) : nil)
    end
    self.tracker_id
  end

  # Sets the tracker.
  # This will set the status to the default status of the new tracker if:
  # * the status was the default for the previous tracker
  # * or if the status was not part of the new tracker statuses
  # * or the status was nil
  def tracker=(tracker)
    tracker_was = self.tracker
    association(:tracker).writer(tracker)
    if tracker != tracker_was
      if status == tracker_was.try(:default_status)
        self.status = nil
      elsif status && tracker && !tracker.issue_status_ids.include?(status.id)
        self.status = nil
      end
      reassign_custom_field_values
      @workflow_rule_by_attribute = nil
    end
    self.status ||= default_status
    self.tracker
  end

  def project_id=(project_id)
    if project_id.to_s != self.project_id.to_s
      self.project = (project_id.present? ? Project.find_by_id(project_id) : nil)
    end
    self.project_id
  end

  # Sets the project.
  # Unless keep_tracker argument is set to true, this will change the tracker
  # to the first tracker of the new project if the previous tracker is not part
  # of the new project trackers.
  # This will:
  # * clear the fixed_version is it's no longer valid for the new project.
  # * clear the parent issue if it's no longer valid for the new project.
  # * set the category to the category with the same name in the new
  #   project if it exists, or clear it if it doesn't.
  # * for new issue, set the fixed_version to the project default version
  #   if it's a valid fixed_version.
  def project=(project, keep_tracker=false)
    project_was = self.project
    association(:project).writer(project)
    if project != project_was
      @safe_attribute_names = nil
    end
    if project_was && project && project_was != project
      @assignable_versions = nil

      unless keep_tracker || project.trackers.include?(tracker)
        self.tracker = project.trackers.first
      end
      # Reassign to the category with same name if any
      if category
        self.category = project.issue_categories.find_by_name(category.name)
      end
      # Clear the assignee if not available in the new project for new issues (eg. copy)
      # For existing issue, the previous assignee is still valid, so we keep it
      if new_record? && assigned_to && !assignable_users.include?(assigned_to)
        self.assigned_to_id = nil
      end
      # Keep the fixed_version if it's still valid in the new_project
      if fixed_version && fixed_version.project != project && !project.shared_versions.include?(fixed_version)
        self.fixed_version = nil
      end
      # Clear the parent task if it's no longer valid
      unless valid_parent_project?
        self.parent_issue_id = nil
      end
      reassign_custom_field_values
      @workflow_rule_by_attribute = nil
    end
    # Set fixed_version to the project default version if it's valid
    if new_record? && fixed_version.nil? && project && project.default_version_id?
      if project.shared_versions.open.exists?(project.default_version_id)
        self.fixed_version_id = project.default_version_id
      end
    end
    self.project
  end

  def description=(arg)
    if arg.is_a?(String)
      arg = arg.gsub(/(\r\n|\n|\r)/, "\r\n")
    end
    write_attribute(:description, arg)
  end

  def deleted_attachment_ids
    Array(@deleted_attachment_ids).map(&:to_i)
  end

  # Overrides assign_attributes so that project and tracker get assigned first
  def assign_attributes(new_attributes, *args)
    return if new_attributes.nil?

    attrs = new_attributes.dup
    attrs.stringify_keys!

    %w(project project_id tracker tracker_id).each do |attr|
      if attrs.has_key?(attr)
        send "#{attr}=", attrs.delete(attr)
      end
    end
    super attrs, *args
  end

  def attributes=(new_attributes)
    assign_attributes new_attributes
  end

  def estimated_hours=(h)
    write_attribute :estimated_hours, (h.is_a?(String) ? (h.to_hours || h) : h)
  end

  safe_attributes(
    'project_id',
    'tracker_id',
    'status_id',
    'category_id',
    'assigned_to_id',
    'priority_id',
    'fixed_version_id',
    'subject',
    'description',
    'start_date',
    'due_date',
    'done_ratio',
    'estimated_hours',
    'custom_field_values',
    'custom_fields',
    'lock_version',
    :if => lambda {|issue, user| issue.new_record? || issue.attributes_editable?(user)})
  safe_attributes(
    'notes',
    :if => lambda {|issue, user| issue.notes_addable?(user)})
  safe_attributes(
    'private_notes',
    :if => lambda {|issue, user| !issue.new_record? && user.allowed_to?(:set_notes_private, issue.project)})
  safe_attributes(
    'watcher_user_ids',
    :if => lambda {|issue, user| issue.new_record? && user.allowed_to?(:add_issue_watchers, issue.project)})
  safe_attributes(
    'is_private',
    :if => lambda do |issue, user|
      user.allowed_to?(:set_issues_private, issue.project) ||
        (issue.author_id == user.id && user.allowed_to?(:set_own_issues_private, issue.project))
    end)
  safe_attributes(
    'parent_issue_id',
    :if => lambda do |issue, user|
      (issue.new_record? || issue.attributes_editable?(user)) &&
        user.allowed_to?(:manage_subtasks, issue.project)
    end)
  safe_attributes(
    'deleted_attachment_ids',
    :if => lambda {|issue, user| issue.attachments_deletable?(user)})

  def safe_attribute_names(user=nil)
    names = super
    names -= disabled_core_fields
    names -= read_only_attribute_names(user)
    if new_record?
      # Make sure that project_id can always be set for new issues
      names |= %w(project_id)
    end
    if dates_derived?
      names -= %w(start_date due_date)
    end
    if priority_derived?
      names -= %w(priority_id)
    end
    if done_ratio_derived?
      names -= %w(done_ratio)
    end
    names
  end

  # Safely sets attributes
  # Should be called from controllers instead of #attributes=
  # attr_accessible is too rough because we still want things like
  # Issue.new(:project => foo) to work
  def safe_attributes=(attrs, user=User.current)
    if attrs.respond_to?(:to_unsafe_hash)
      attrs = attrs.to_unsafe_hash
    end

    @attributes_set_by = user
    return unless attrs.is_a?(Hash)

    attrs = attrs.deep_dup

    # Project and Tracker must be set before since new_statuses_allowed_to depends on it.
    if (p = attrs.delete('project_id')) && safe_attribute?('project_id')
      if p.is_a?(String) && !/^\d*$/.match?(p)
        p_id = Project.find_by_identifier(p).try(:id)
      else
        p_id = p.to_i
      end
      if allowed_target_projects(user).where(:id => p_id).exists?
        self.project_id = p_id
      end

      if project_id_changed? && attrs['category_id'].present? && attrs['category_id'].to_s == category_id_was.to_s
        # Discard submitted category on previous project
        attrs.delete('category_id')
      end
    end

    if (t = attrs.delete('tracker_id')) && safe_attribute?('tracker_id')
      if allowed_target_trackers(user).where(:id => t.to_i).exists?
        self.tracker_id = t
      end
    end
    if project && tracker.nil?
      # Set a default tracker to accept custom field values
      # even if tracker is not specified
      allowed_trackers = allowed_target_trackers(user)

      if attrs['parent_issue_id'].present?
        # If parent_issue_id is present, the first tracker for which this field
        # is not disabled is chosen as default
        self.tracker = allowed_trackers.detect {|t| t.core_fields.include?('parent_issue_id')}
      end
      self.tracker ||= allowed_trackers.first
    end

    statuses_allowed = new_statuses_allowed_to(user)
    if (s = attrs.delete('status_id')) && safe_attribute?('status_id')
      if statuses_allowed.collect(&:id).include?(s.to_i)
        self.status_id = s
      end
    end
    if new_record? && !statuses_allowed.include?(status)
      self.status = statuses_allowed.first || default_status
    end
    if (u = attrs.delete('assigned_to_id')) && safe_attribute?('assigned_to_id')
      self.assigned_to_id = u
    end
    attrs = delete_unsafe_attributes(attrs, user)
    return if attrs.empty?

    if attrs['parent_issue_id'].present?
      s = attrs['parent_issue_id'].to_s
      unless (m = s.match(%r{\A#?(\d+)\z})) && (m[1] == parent_id.to_s || Issue.visible(user).exists?(m[1]))
        @invalid_parent_issue_id = attrs.delete('parent_issue_id')
      end
    end

    if attrs['custom_field_values'].present?
      editable_custom_field_ids = editable_custom_field_values(user).map {|v| v.custom_field_id.to_s}
      attrs['custom_field_values'].select! {|k, v| editable_custom_field_ids.include?(k.to_s)}
    end

    if attrs['custom_fields'].present?
      editable_custom_field_ids = editable_custom_field_values(user).map {|v| v.custom_field_id.to_s}
      attrs['custom_fields'].select! {|c| editable_custom_field_ids.include?(c['id'].to_s)}
    end

    assign_attributes attrs
  end

  def disabled_core_fields
    tracker ? tracker.disabled_core_fields : []
  end

  # Returns the custom_field_values that can be edited by the given user
  def editable_custom_field_values(user=nil)
    read_only = read_only_attribute_names(user)
    visible_custom_field_values(user).reject do |value|
      read_only.include?(value.custom_field_id.to_s)
    end
  end

  # Returns the custom fields that can be edited by the given user
  def editable_custom_fields(user=nil)
    editable_custom_field_values(user).map(&:custom_field).uniq
  end

  # Returns the names of attributes that are read-only for user or the current user
  # For users with multiple roles, the read-only fields are the intersection of
  # read-only fields of each role
  # The result is an array of strings where sustom fields are represented with their ids
  #
  # Examples:
  #   issue.read_only_attribute_names # => ['due_date', '2']
  #   issue.read_only_attribute_names(user) # => []
  def read_only_attribute_names(user=nil)
    workflow_rule_by_attribute(user).reject {|attr, rule| rule != 'readonly'}.keys
  end

  # Returns the names of required attributes for user or the current user
  # For users with multiple roles, the required fields are the intersection of
  # required fields of each role
  # The result is an array of strings where sustom fields are represented with their ids
  #
  # Examples:
  #   issue.required_attribute_names # => ['due_date', '2']
  #   issue.required_attribute_names(user) # => []
  def required_attribute_names(user=nil)
    workflow_rule_by_attribute(user).reject {|attr, rule| rule != 'required'}.keys
  end

  # Returns true if the attribute is required for user
  def required_attribute?(name, user=nil)
    required_attribute_names(user).include?(name.to_s)
  end

  # Returns a hash of the workflow rule by attribute for the given user
  #
  # Examples:
  #   issue.workflow_rule_by_attribute # => {'due_date' => 'required', 'start_date' => 'readonly'}
  def workflow_rule_by_attribute(user=nil)
    return @workflow_rule_by_attribute if @workflow_rule_by_attribute && user.nil?

    user_real = user || User.current
    roles = user_real.admin ? Role.all.to_a : user_real.roles_for_project(project)
    roles = roles.select(&:consider_workflow?)
    return {} if roles.empty?

    result = {}
    workflow_permissions =
      WorkflowPermission.where(
        :tracker_id => tracker_id, :old_status_id => status_id,
        :role_id => roles.map(&:id)
      ).to_a
    if workflow_permissions.any?
      workflow_rules = workflow_permissions.inject({}) do |h, wp|
        h[wp.field_name] ||= {}
        h[wp.field_name][wp.role_id] = wp.rule
        h
      end
      fields_with_roles = {}
      IssueCustomField.where(:visible => false).
        joins(:roles).pluck(:id, "role_id").
          each do |field_id, role_id|
        fields_with_roles[field_id] ||= []
        fields_with_roles[field_id] << role_id
      end
      roles.each do |role|
        fields_with_roles.each do |field_id, role_ids|
          unless role_ids.include?(role.id)
            field_name = field_id.to_s
            workflow_rules[field_name] ||= {}
            workflow_rules[field_name][role.id] = 'readonly'
          end
        end
      end
      workflow_rules.each do |attr, rules|
        next if rules.size < roles.size

        uniq_rules = rules.values.uniq
        if uniq_rules.size == 1
          result[attr] = uniq_rules.first
        else
          result[attr] = 'required'
        end
      end
    end
    @workflow_rule_by_attribute = result if user.nil?
    result
  end
  private :workflow_rule_by_attribute

  def done_ratio
    if Issue.use_status_for_done_ratio? && status && status.default_done_ratio
      status.default_done_ratio
    else
      read_attribute(:done_ratio)
    end
  end

  def self.use_status_for_done_ratio?
    Setting.issue_done_ratio == 'issue_status'
  end

  def self.use_field_for_done_ratio?
    Setting.issue_done_ratio == 'issue_field'
  end

  def validate_issue
    if due_date && start_date && (start_date_changed? || due_date_changed?) && due_date < start_date
      errors.add :due_date, :greater_than_start_date
    end

    if start_date && start_date_changed? && soonest_start && start_date < soonest_start
      errors.add :start_date, :earlier_than_minimum_start_date, :date => format_date(soonest_start)
    end

    if project && fixed_version_id
      if fixed_version.nil? || assignable_versions.exclude?(fixed_version)
        errors.add :fixed_version_id, :inclusion
      elsif reopening? && fixed_version.closed?
        errors.add :base, I18n.t(:error_can_not_reopen_issue_on_closed_version)
      end
    end

    if project && category_id
      unless project.issue_category_ids.include?(category_id)
        errors.add :category_id, :inclusion
      end
    end

    # Checks that the issue can not be added/moved to a disabled tracker
    if project && (tracker_id_changed? || project_id_changed?)
      if tracker && !project.trackers.include?(tracker)
        errors.add :tracker_id, :inclusion
      end
    end

    if project && assigned_to_id_changed? && assigned_to_id.present?
      unless assignable_users.include?(assigned_to)
        errors.add :assigned_to_id, :invalid
      end
    end

    # Checks parent issue assignment
    if @invalid_parent_issue_id.present?
      errors.add :parent_issue_id, :invalid
    elsif @parent_issue
      if !valid_parent_project?(@parent_issue)
        errors.add :parent_issue_id, :invalid
      elsif (@parent_issue != parent) && (
          self.would_reschedule?(@parent_issue) ||
          @parent_issue.self_and_ancestors.any? do |a|
            a.relations_from.any? do |r|
              r.relation_type == IssueRelation::TYPE_PRECEDES &&
                 r.issue_to.would_reschedule?(self)
            end
          end
        )
        errors.add :parent_issue_id, :invalid
      elsif !closed? && @parent_issue.closed?
        # cannot attach an open issue to a closed parent
        errors.add :base, :open_issue_with_closed_parent
      elsif !new_record?
        # moving an existing issue
        if move_possible?(@parent_issue)
          # move accepted
        else
          errors.add :parent_issue_id, :invalid
        end
      end
    end
  end

  # Validates the issue against additional workflow requirements
  def validate_required_fields
    user = new_record? ? author : current_journal.try(:user)

    required_attribute_names(user).each do |attribute|
      if /^\d+$/.match?(attribute)
        attribute = attribute.to_i
        v = custom_field_values.detect {|v| v.custom_field_id == attribute}
        if v && Array(v.value).detect(&:present?).nil?
          errors.add(v.custom_field.name, l('activerecord.errors.messages.blank'))
        end
      else
        if respond_to?(attribute) && send(attribute).blank? && !disabled_core_fields.include?(attribute)
          next if attribute == 'category_id' && project.try(:issue_categories).blank?
          next if attribute == 'fixed_version_id' && assignable_versions.blank?

          errors.add attribute, :blank
        end
      end
    end
  end

  def validate_permissions
    if @attributes_set_by && new_record? && copy?
      unless allowed_target_trackers(@attributes_set_by).include?(tracker)
        errors.add :tracker, :invalid
      end
    end
  end

  # Overrides Redmine::Acts::Customizable::InstanceMethods#validate_custom_field_values
  # so that custom values that are not editable are not validated (eg. a custom field that
  # is marked as required should not trigger a validation error if the user is not allowed
  # to edit this field).
  def validate_custom_field_values
    user = new_record? ? author : current_journal.try(:user)
    if new_record? || custom_field_values_changed?
      editable_custom_field_values(user).each(&:validate_value)
    end
  end

  # Set the done_ratio using the status if that setting is set.  This will keep the done_ratios
  # even if the user turns off the setting later
  def update_done_ratio_from_issue_status
    if Issue.use_status_for_done_ratio? && status && status.default_done_ratio
      self.done_ratio = status.default_done_ratio
    end
  end

  def init_journal(user, notes = "")
    @current_journal ||= Journal.new(:journalized => self, :user => user, :notes => notes)
  end

  # Returns the current journal or nil if it's not initialized
  def current_journal
    @current_journal
  end

  # Clears the current journal
  def clear_journal
    @current_journal = nil
  end

  # Returns the names of attributes that are journalized when updating the issue
  def journalized_attribute_names
    names = Issue.column_names - %w(id root_id lft rgt lock_version created_on updated_on closed_on)
    if tracker
      names -= tracker.disabled_core_fields
    end
    names
  end

  # Returns the id of the last journal or nil
  def last_journal_id
    if new_record?
      nil
    else
      journals.maximum(:id)
    end
  end

  # Returns a scope for journals that have an id greater than journal_id
  def journals_after(journal_id)
    scope = journals.reorder("#{Journal.table_name}.id ASC")
    if journal_id.present?
      scope = scope.where("#{Journal.table_name}.id > ?", journal_id.to_i)
    end
    scope
  end

  # Returns the journals that are visible to user with their index
  # Used to display the issue history
  def visible_journals_with_index(user=User.current)
    result = journals.
      preload(:details).
      preload(:user => :email_address).
      reorder(:created_on, :id).to_a

    result.each_with_index {|j, i| j.indice = i + 1}

    unless user.allowed_to?(:view_private_notes, project)
      result.select! do |journal|
        !journal.private_notes? || journal.user == user
      end
    end
    Journal.preload_journals_details_custom_fields(result)
    result.select! {|journal| journal.notes? || journal.visible_details.any?}
    result
  end

  # Returns the initial status of the issue
  # Returns nil for a new issue
  def status_was
    if status_id_changed?
      if status_id_was.to_i > 0
        @status_was ||= IssueStatus.find_by_id(status_id_was)
      end
    else
      @status_was ||= status
    end
  end

  # Return true if the issue is closed, otherwise false
  def closed?
    status.present? && status.is_closed?
  end

  # Returns true if the issue was closed when loaded
  def was_closed?
    status_was.present? && status_was.is_closed?
  end

  # Return true if the issue is being reopened
  def reopening?
    if new_record?
      false
    else
      status_id_changed? && !closed? && was_closed?
    end
  end
  alias :reopened? :reopening?

  # Return true if the issue is being closed
  def closing?
    if new_record?
      closed?
    else
      status_id_changed? && closed? && !was_closed?
    end
  end

  # Returns true if the issue is overdue
  def overdue?
    due_date.present? && (due_date < User.current.today) && !closed?
  end

  # Is the amount of work done less than it should for the due date
  def behind_schedule?
    return false if start_date.nil? || due_date.nil?

    done_date = start_date + ((due_date - start_date + 1) * done_ratio / 100).floor
    return done_date <= User.current.today
  end

  # Does this issue have children?
  def children?
    !leaf?
  end

  # Users the issue can be assigned to
  def assignable_users
    return [] if project.nil?

    users = project.assignable_users(tracker).to_a
    users << author if author && author.active?
    if assigned_to_id_was.present? && assignee = Principal.find_by_id(assigned_to_id_was)
      users << assignee
    end
    users.uniq.sort
  end

  # Versions that the issue can be assigned to
  def assignable_versions
    return @assignable_versions if @assignable_versions
    return [] if project.nil?

    versions = project.shared_versions.open.to_a
    if fixed_version
      if fixed_version_id_changed?
        # nothing to do
      elsif project_id_changed?
        if project.shared_versions.include?(fixed_version)
          versions << fixed_version
        end
      else
        versions << fixed_version
      end
    end
    @assignable_versions = versions.uniq.sort
  end

  # Returns true if this issue is blocked by another issue that is still open
  def blocked?
    !relations_to.detect {|ir| ir.relation_type == 'blocks' && !ir.issue_from.closed?}.nil?
  end

  # Returns true if this issue can be closed and if not, returns false and populates the reason
  def closable?
    if descendants.open.any?
      @transition_warning = l(:notice_issue_not_closable_by_open_tasks)
      return false
    end
    if blocked?
      @transition_warning = l(:notice_issue_not_closable_by_blocking_issue)
      return false
    end
    return true
  end

  # Returns true if this issue can be reopen and if not, returns false and populates the reason
  def reopenable?
    if ancestors.open(false).any?
      @transition_warning = l(:notice_issue_not_reopenable_by_closed_parent_issue)
      return false
    end
    return true
  end

  # Returns the default status of the issue based on its tracker
  # Returns nil if tracker is nil
  def default_status
    tracker.try(:default_status)
  end

  # Returns an array of statuses that user is able to apply
  def new_statuses_allowed_to(user=User.current, include_default=false)
    initial_status = nil
    if new_record?
      # nop
    elsif tracker_id_changed?
      if Tracker.where(:id => tracker_id_was, :default_status_id => status_id_was).any?
        initial_status = default_status
      elsif tracker.issue_status_ids.include?(status_id_was)
        initial_status = IssueStatus.find_by_id(status_id_was)
      else
        initial_status = default_status
      end
    else
      initial_status = status_was
    end

    initial_assigned_to_id = assigned_to_id_changed? ? assigned_to_id_was : assigned_to_id
    assignee_transitions_allowed = initial_assigned_to_id.present? &&
      (user.id == initial_assigned_to_id || user.group_ids.include?(initial_assigned_to_id))

    statuses = []
    statuses += IssueStatus.new_statuses_allowed(
      initial_status,
      user.admin ? Role.all.to_a : user.roles_for_project(project),
      tracker,
      author == user,
      assignee_transitions_allowed
    )
    statuses << initial_status unless statuses.empty?
    statuses << default_status if include_default || (new_record? && statuses.empty?)

    statuses = statuses.compact.uniq.sort
    unless closable?
      # cannot close a blocked issue or a parent with open subtasks
      statuses.reject!(&:is_closed?)
    end
    unless reopenable?
      # cannot reopen a subtask of a closed parent
      statuses.select!(&:is_closed?)
    end
    statuses
  end

  # Returns the original tracker
  def tracker_was
    Tracker.find_by_id(tracker_id_in_database)
  end

  # Returns the previous assignee whenever we're before the save
  # or in after_* callbacks
  def previous_assignee
    previous_assigned_to_id =
      if assigned_to_id_change_to_be_saved.nil?
        assigned_to_id_before_last_save
      else
        assigned_to_id_in_database
      end
    if previous_assigned_to_id
      Principal.find_by_id(previous_assigned_to_id)
    end
  end

  # Returns the users that should be notified
  def notified_users
    # Author and assignee are always notified unless they have been
    # locked or don't want to be notified
    notified = [author, assigned_to, previous_assignee].compact.uniq
    notified = notified.map {|n| n.is_a?(Group) ? n.users : n}.flatten
    notified.uniq!
    notified = notified.select {|u| u.active? && u.notify_about?(self)}

    notified += project.notified_users
    notified += project.users.preload(:preference).select(&:notify_about_high_priority_issues?) if priority.high?
    notified.uniq!
    # Remove users that can not view the issue
    notified.reject! {|user| !visible?(user)}
    notified
  end

  # Returns the email addresses that should be notified
  def recipients
    notified_users.collect(&:mail)
  end

  def notify?
    @notify != false
  end

  def notify=(arg)
    @notify = arg
  end

  # Returns the number of hours spent on this issue
  def spent_hours
    @spent_hours ||= time_entries.sum(:hours) || 0.0
  end

  # Returns the total number of hours spent on this issue and its descendants
  def total_spent_hours
    @total_spent_hours ||=
      if leaf?
        spent_hours
      else
        self_and_descendants.joins(:time_entries).sum("#{TimeEntry.table_name}.hours").to_f || 0.0
      end
  end

  def total_estimated_hours
    if leaf?
      estimated_hours
    else
      @total_estimated_hours ||= self_and_descendants.visible.sum(:estimated_hours)
    end
  end

  def relations
    @relations ||= IssueRelation::Relations.new(self, (relations_from + relations_to).sort)
  end

  def last_updated_by
    if @last_updated_by
      @last_updated_by.presence
    else
      journals.reorder(:id => :desc).first.try(:user)
    end
  end

  def last_notes
    if @last_notes
      @last_notes
    else
      journals.visible.where.not(notes: '').reorder(:id => :desc).first.try(:notes)
    end
  end

  # Preloads relations for a collection of issues
  def self.load_relations(issues)
    if issues.any?
      relations =
        IssueRelation.where(
          "issue_from_id IN (:ids) OR issue_to_id IN (:ids)", :ids => issues.map(&:id)
        ).all
      issues.each do |issue|
        issue.instance_variable_set(
          :@relations,
          relations.select {|r| r.issue_from_id == issue.id || r.issue_to_id == issue.id}
        )
      end
    end
  end

  # Preloads visible spent time for a collection of issues
  def self.load_visible_spent_hours(issues, user=User.current)
    if issues.any?
      hours_by_issue_id = TimeEntry.visible(user).where(:issue_id => issues.map(&:id)).group(:issue_id).sum(:hours)
      issues.each do |issue|
        issue.instance_variable_set :@spent_hours, (hours_by_issue_id[issue.id] || 0.0)
      end
    end
  end

  # Preloads visible total spent time for a collection of issues
  def self.load_visible_total_spent_hours(issues, user=User.current)
    if issues.any?
      hours_by_issue_id = TimeEntry.visible(user).joins(:issue).
        joins("JOIN #{Issue.table_name} parent ON parent.root_id = #{Issue.table_name}.root_id" +
          " AND parent.lft <= #{Issue.table_name}.lft AND parent.rgt >= #{Issue.table_name}.rgt").
        where("parent.id IN (?)", issues.map(&:id)).group("parent.id").sum(:hours)
      issues.each do |issue|
        issue.instance_variable_set :@total_spent_hours, (hours_by_issue_id[issue.id] || 0.0)
      end
    end
  end

  # Preloads visible relations for a collection of issues
  def self.load_visible_relations(issues, user=User.current)
    if issues.any?
      issue_ids = issues.map(&:id)
      # Relations with issue_from in given issues and visible issue_to
      relations_from = IssueRelation.joins(:issue_to => :project).
                         where(visible_condition(user)).where(:issue_from_id => issue_ids).to_a
      # Relations with issue_to in given issues and visible issue_from
      relations_to = IssueRelation.joins(:issue_from => :project).
                         where(visible_condition(user)).
                         where(:issue_to_id => issue_ids).to_a
      issues.each do |issue|
        relations =
          relations_from.select {|relation| relation.issue_from_id == issue.id} +
          relations_to.select {|relation| relation.issue_to_id == issue.id}

        issue.instance_variable_set :@relations, IssueRelation::Relations.new(issue, relations.sort)
      end
    end
  end

  # Returns a scope of the given issues and their descendants
  def self.self_and_descendants(issues)
    Issue.joins(
      "JOIN #{Issue.table_name} ancestors" +
      " ON ancestors.root_id = #{Issue.table_name}.root_id" +
      " AND ancestors.lft <= #{Issue.table_name}.lft AND ancestors.rgt >= #{Issue.table_name}.rgt"
    ).
      where(:ancestors => {:id => issues.map(&:id)})
  end

  # Preloads users who updated last a collection of issues
  def self.load_visible_last_updated_by(issues, user=User.current)
    if issues.any?
      issue_ids = issues.map(&:id)
      journal_ids = Journal.joins(issue: :project).
        where(:journalized_type => 'Issue', :journalized_id => issue_ids).
        where(Journal.visible_notes_condition(user, :skip_pre_condition => true)).
        group(:journalized_id).
        maximum(:id).
        values
      journals = Journal.where(:id => journal_ids).preload(:user).to_a

      issues.each do |issue|
        journal = journals.detect {|j| j.journalized_id == issue.id}
        issue.instance_variable_set(:@last_updated_by, journal.try(:user) || '')
      end
    end
  end

  # Preloads visible last notes for a collection of issues
  def self.load_visible_last_notes(issues, user=User.current)
    if issues.any?
      issue_ids = issues.map(&:id)
      journal_ids = Journal.joins(issue: :project).
        where(:journalized_type => 'Issue', :journalized_id => issue_ids).
        where(Journal.visible_notes_condition(user, :skip_pre_condition => true)).
        where.not(notes: '').
        group(:journalized_id).
        maximum(:id).
        values
      journals = Journal.where(:id => journal_ids).to_a

      issues.each do |issue|
        journal = journals.detect {|j| j.journalized_id == issue.id}
        issue.instance_variable_set(:@last_notes, journal.try(:notes) || '')
      end
    end
  end

  # Finds an issue relation given its id.
  def find_relation(relation_id)
    IssueRelation.where("issue_to_id = ? OR issue_from_id = ?", id, id).find(relation_id)
  end

  # Returns true if this issue blocks the other issue, otherwise returns false
  def blocks?(other)
    all = [self]
    last = [self]
    while last.any?
      current =
        last.map do |i|
          i.relations_from.where(:relation_type => IssueRelation::TYPE_BLOCKS).map(&:issue_to)
        end.flatten.uniq
      current -= last
      current -= all
      return true if current.include?(other)

      last = current
      all += last
    end
    false
  end

  # Returns true if the other issue might be rescheduled if the start/due dates of this issue change
  def would_reschedule?(other)
    all = [self]
    last = [self]
    while last.any?
      current = last.map do |i|
        i.relations_from.where(:relation_type => IssueRelation::TYPE_PRECEDES).map(&:issue_to) +
        i.leaves.to_a +
        i.ancestors.map {|a| a.relations_from.where(:relation_type => IssueRelation::TYPE_PRECEDES).map(&:issue_to)}
      end.flatten.uniq
      current -= last
      current -= all
      return true if current.include?(other)

      last = current
      all += last
    end
    false
  end

  # Returns an array of issues that duplicate this one
  def duplicates
    relations_to.select {|r| r.relation_type == IssueRelation::TYPE_DUPLICATES}.collect {|r| r.issue_from}
  end

  # Returns the due date or the target due date if any
  # Used on gantt chart
  def due_before
    due_date || (fixed_version ? fixed_version.effective_date : nil)
  end

  # Returns the time scheduled for this issue.
  #
  # Example:
  #   Start Date: 2/26/09, End Date: 3/04/09
  #   duration => 6
  def duration
    (start_date && due_date) ? due_date - start_date : 0
  end

  # Returns the duration in working days
  def working_duration
    (start_date && due_date) ? working_days(start_date, due_date) : 0
  end

  def soonest_start(reload=false)
    if @soonest_start.nil? || reload
      relations_to.reload if reload
      dates = relations_to.collect{|relation| relation.successor_soonest_start}
      p = @parent_issue || parent
      if p && Setting.parent_issue_dates == 'derived'
        dates << p.soonest_start
      end
      @soonest_start = dates.compact.max
    end
    @soonest_start
  end

  # Sets start_date on the given date or the next working day
  # and changes due_date to keep the same working duration.
  def reschedule_on(date)
    wd = working_duration
    date = next_working_date(date)
    self.start_date = date
    self.due_date = add_working_days(date, wd)
  end

  # Reschedules the issue on the given date or the next working day and saves the record.
  # If the issue is a parent task, this is done by rescheduling its subtasks.
  def reschedule_on!(date, journal=nil)
    return if date.nil?

    if leaf? || !dates_derived?
      if start_date.nil? || start_date != date
        if start_date && start_date > date
          # Issue can not be moved earlier than its soonest start date
          date = [soonest_start(true), date].compact.max
        end
        if journal
          init_journal(journal.user)
        end
        reschedule_on(date)
        begin
          save
        rescue ActiveRecord::StaleObjectError
          reload
          reschedule_on(date)
          save
        end
      end
    else
      leaves.each do |leaf|
        if leaf.start_date
          # Only move subtask if it starts at the same date as the parent
          # or if it starts before the given date
          if start_date == leaf.start_date || date > leaf.start_date
            leaf.reschedule_on!(date)
          end
        else
          leaf.reschedule_on!(date)
        end
      end
    end
  end

  def dates_derived?
    !leaf? && Setting.parent_issue_dates == 'derived'
  end

  def priority_derived?
    !leaf? && Setting.parent_issue_priority == 'derived'
  end

  def done_ratio_derived?
    !leaf? && Setting.parent_issue_done_ratio == 'derived'
  end

  def <=>(issue)
    if issue.nil?
      -1
    elsif root_id != issue.root_id
      (root_id || 0) <=> (issue.root_id || 0)
    else
      (lft || 0) <=> (issue.lft || 0)
    end
  end

  def to_s
    "#{tracker} ##{id}: #{subject}"
  end

  # Returns a string of css classes that apply to the issue
  def css_classes(user=User.current)
    s = +"issue tracker-#{tracker_id} status-#{status_id} #{priority.try(:css_classes)}"
    s << ' closed' if closed?
    s << ' overdue' if overdue?
    s << ' child' if child?
    s << ' parent' unless leaf?
    s << ' private' if is_private?
    s << ' behind-schedule' if behind_schedule?
    if user.logged?
      s << ' created-by-me' if author_id == user.id
      s << ' assigned-to-me' if assigned_to_id == user.id
      s << ' assigned-to-my-group' if user.groups.any? {|g| g.id == assigned_to_id}
    end
    s
  end

  # Unassigns issues from +version+ if it's no longer shared with issue's project
  def self.update_versions_from_sharing_change(version)
    # Update issues assigned to the version
    update_versions(["#{Issue.table_name}.fixed_version_id = ?", version.id])
  end

  # Unassigns issues from versions that are no longer shared
  # after +project+ was moved
  def self.update_versions_from_hierarchy_change(project)
    moved_project_ids = project.self_and_descendants.reload.pluck(:id)
    # Update issues of the moved projects and issues assigned to a version of a moved project
    Issue.
      update_versions(
        ["#{Version.table_name}.project_id IN (?) OR #{Issue.table_name}.project_id IN (?)",
         moved_project_ids, moved_project_ids]
      )
  end

  def parent_issue_id=(arg)
    s = arg.to_s.strip.presence
    if s && (m = s.match(%r{\A#?(\d+)\z})) && (@parent_issue = Issue.find_by_id(m[1]))
      @invalid_parent_issue_id = nil
    elsif s.blank?
      @parent_issue = nil
      @invalid_parent_issue_id = nil
    else
      @parent_issue = nil
      @invalid_parent_issue_id = arg
    end
  end

  def parent_issue_id
    if @invalid_parent_issue_id
      @invalid_parent_issue_id
    elsif instance_variable_defined? :@parent_issue
      @parent_issue.nil? ? nil : @parent_issue.id
    else
      parent_id
    end
  end

  def set_parent_id
    self.parent_id = parent_issue_id
  end

  # Returns true if issue's project is a valid
  # parent issue project
  def valid_parent_project?(issue=parent)
    return true if issue.nil? || issue.project_id == project_id

    case Setting.cross_project_subtasks
    when 'system'
      true
    when 'tree'
      issue.project.root == project.root
    when 'hierarchy'
      issue.project.is_or_is_ancestor_of?(project) || issue.project.is_descendant_of?(project)
    when 'descendants'
      issue.project.is_or_is_ancestor_of?(project)
    else
      false
    end
  end

  # Returns an issue scope based on project and scope
  def self.cross_project_scope(project, scope=nil)
    if project.nil?
      return Issue
    end

    case scope
    when 'all', 'system'
      Issue
    when 'tree'
      Issue.joins(:project).where("(#{Project.table_name}.lft >= :lft AND #{Project.table_name}.rgt <= :rgt)",
                                  :lft => project.root.lft, :rgt => project.root.rgt)
    when 'hierarchy'
      Issue.joins(:project).
        where(
          "(#{Project.table_name}.lft >= :lft AND " \
            "#{Project.table_name}.rgt <= :rgt) OR " \
            "(#{Project.table_name}.lft < :lft AND #{Project.table_name}.rgt > :rgt)",
          :lft => project.lft, :rgt => project.rgt
        )
    when 'descendants'
      Issue.joins(:project).where("(#{Project.table_name}.lft >= :lft AND #{Project.table_name}.rgt <= :rgt)",
                                  :lft => project.lft, :rgt => project.rgt)
    else
      Issue.where(:project_id => project.id)
    end
  end

  def self.by_tracker(project, with_subprojects=false)
    count_and_group_by(:project => project, :association => :tracker, :with_subprojects => with_subprojects)
  end

  def self.by_version(project, with_subprojects=false)
    count_and_group_by(:project => project, :association => :fixed_version, :with_subprojects => with_subprojects)
  end

  def self.by_priority(project, with_subprojects=false)
    count_and_group_by(:project => project, :association => :priority, :with_subprojects => with_subprojects)
  end

  def self.by_category(project, with_subprojects=false)
    count_and_group_by(:project => project, :association => :category, :with_subprojects => with_subprojects)
  end

  def self.by_assigned_to(project, with_subprojects=false)
    count_and_group_by(:project => project, :association => :assigned_to, :with_subprojects => with_subprojects)
  end

  def self.by_author(project, with_subprojects=false)
    count_and_group_by(:project => project, :association => :author, :with_subprojects => with_subprojects)
  end

  def self.by_subproject(project)
    r = count_and_group_by(:project => project, :with_subprojects => true, :association => :project)
    r.reject {|r| r["project_id"] == project.id.to_s}
  end

  # Query generator for selecting groups of issue counts for a project
  # based on specific criteria
  #
  # Options
  # * project - Project to search in.
  # * with_subprojects - Includes subprojects issues if set to true.
  # * association - Symbol. Association for grouping.
  def self.count_and_group_by(options)
    assoc = reflect_on_association(options[:association])
    select_field = assoc.foreign_key

    Issue.
      visible(User.current, :project => options[:project], :with_subprojects => options[:with_subprojects]).
      joins(:status).
      group(:status_id, :is_closed, select_field).
      count.
      map do |columns, total|
        status_id, is_closed, field_value = columns
        is_closed = ['t', 'true', '1'].include?(is_closed.to_s)
        {
          "status_id" => status_id.to_s,
          "closed" => is_closed,
          select_field => field_value.to_s,
          "total" => total.to_s
        }
      end
  end

  # Returns a scope of projects that user can assign the subtask
  def allowed_target_projects_for_subtask(user=User.current)
    if parent_issue_id.present?
      scope = filter_projects_scope(Setting.cross_project_subtasks)
    end

    self.class.allowed_target_projects(user, project, scope)
  end

  # Returns a scope of projects that user can assign the issue to
  def allowed_target_projects(user=User.current, scope=nil)
    current_project = new_record? ? nil : project
    if scope
      scope = filter_projects_scope(scope)
    end

    self.class.allowed_target_projects(user, current_project, scope)
  end

  # Returns a scope of projects that user can assign issues to
  # If current_project is given, it will be included in the scope
  def self.allowed_target_projects(user=User.current, current_project=nil, scope=nil)
    condition = Project.allowed_to_condition(user, :add_issues)
    if current_project
      condition = ["(#{condition}) OR #{Project.table_name}.id = ?", current_project.id]
    end

    if scope.nil?
      scope = Project
    end

    scope.where(condition).having_trackers
  end

  # Returns a scope of trackers that user can assign the issue to
  def allowed_target_trackers(user=User.current)
    self.class.allowed_target_trackers(project, user, tracker_id_was)
  end

  # Returns a scope of trackers that user can assign project issues to
  def self.allowed_target_trackers(project, user=User.current, current_tracker=nil)
    if project
      scope = project.trackers.sorted
      unless user.admin?
        roles = user.roles_for_project(project).select {|r| r.has_permission?(:add_issues)}
        unless roles.any? {|r| r.permissions_all_trackers?(:add_issues)}
          tracker_ids = roles.map {|r| r.permissions_tracker_ids(:add_issues)}.flatten.uniq
          if current_tracker
            tracker_ids << current_tracker
          end
          scope = scope.where(:id => tracker_ids)
        end
      end
      scope
    else
      Tracker.none
    end
  end

  private

  def user_tracker_permission?(user, permission)
    if project && !project.active?
      perm = Redmine::AccessControl.permission(permission)
      return false unless perm && perm.read?
    end

    if user.admin?
      true
    else
      roles = user.roles_for_project(project).select {|r| r.has_permission?(permission)}
      roles.any? do |r|
        r.permissions_all_trackers?(permission) ||
          r.permissions_tracker_ids?(permission, tracker_id)
      end
    end
  end

  def after_project_change
    # Update project_id on related time entries
    TimeEntry.where({:issue_id => id}).update_all(["project_id = ?", project_id])

    # Delete issue relations
    unless Setting.cross_project_issue_relations?
      relations_from.clear
      relations_to.clear
    end

    # Move subtasks that were in the same project
    children.each do |child|
      next unless child.project_id == project_id_before_last_save

      # Change project and keep project
      child.send :project=, project, true
      unless child.save
        errors.add(
          :base,
          l(:error_move_of_child_not_possible,
            :child => "##{child.id}",
            :errors => child.errors.full_messages.join(", "))
        )
        raise ActiveRecord::Rollback
      end
    end
  end

  # Callback for after the creation of an issue by copy
  # * adds a "copied to" relation with the copied issue
  # * copies subtasks from the copied issue
  def after_create_from_copy
    return unless copy? && !@after_create_from_copy_handled

    if (@copied_from.project_id == project_id ||
          Setting.cross_project_issue_relations?) &&
        @copy_options[:link] != false
      if @current_journal
        @copied_from.init_journal(@current_journal.user)
      end
      relation =
        IssueRelation.new(:issue_from => @copied_from, :issue_to => self,
                          :relation_type => IssueRelation::TYPE_COPIED_TO)
      unless relation.save
        if logger
          logger.error(
            "Could not create relation while copying ##{@copied_from.id} to ##{id} " \
              "due to validation errors: #{relation.errors.full_messages.join(', ')}"
          )
        end
      end
    end

    unless @copied_from.leaf? || @copy_options[:subtasks] == false
      copy_options = (@copy_options || {}).merge(:subtasks => false)
      copied_issue_ids = {@copied_from.id => self.id}
      @copied_from.reload.descendants.reorder("#{Issue.table_name}.lft").each do |child|
        # Do not copy self when copying an issue as a descendant of the copied issue
        next if child == self
        # Do not copy subtasks of issues that were not copied
        next unless copied_issue_ids[child.parent_id]

        # Do not copy subtasks that are not visible to avoid potential disclosure of private data
        unless child.visible?
          if logger
            logger.error(
              "Subtask ##{child.id} was not copied during ##{@copied_from.id} copy " \
                "because it is not visible to the current user"
            )
          end
          next
        end
        copy = Issue.new.copy_from(child, copy_options)
        if @current_journal
          copy.init_journal(@current_journal.user)
        end
        copy.author = author
        copy.project = project
        copy.parent_issue_id = copied_issue_ids[child.parent_id]
        unless child.fixed_version.present? && child.fixed_version.status == 'open'
          copy.fixed_version_id = nil
        end
        unless child.assigned_to_id.present? &&
                 child.assigned_to.status == User::STATUS_ACTIVE
          copy.assigned_to = nil
        end
        unless copy.save
          if logger
            logger.error(
              "Could not copy subtask ##{child.id} " \
                "while copying ##{@copied_from.id} to ##{id} due to validation errors: " \
                "#{copy.errors.full_messages.join(', ')}"
            )
          end
          next
        end
        copied_issue_ids[child.id] = copy.id
      end
    end
    @after_create_from_copy_handled = true
  end

  def update_nested_set_attributes
    if saved_change_to_parent_id?
      update_nested_set_attributes_on_parent_change
    end
    remove_instance_variable(:@parent_issue) if instance_variable_defined?(:@parent_issue)
  end

  # Updates the nested set for when an existing issue is moved
  def update_nested_set_attributes_on_parent_change
    former_parent_id = parent_id_before_last_save
    # delete invalid relations of all descendants
    self_and_descendants.each do |issue|
      issue.relations.each do |relation|
        relation.destroy unless relation.valid?
      end
    end
    # update former parent
    recalculate_attributes_for(former_parent_id) if former_parent_id
  end

  def update_parent_attributes
    if parent_id
      recalculate_attributes_for(parent_id)
      association(:parent).reset
    end
  end

  def recalculate_attributes_for(issue_id)
    if issue_id && p = Issue.find_by_id(issue_id)
      if p.priority_derived?
        # priority = highest priority of open children
        # priority is left unchanged if all children are closed and there's no default priority defined
        if priority_position =
             p.children.open.joins(:priority).maximum("#{IssuePriority.table_name}.position")
          p.priority = IssuePriority.find_by_position(priority_position)
        elsif default_priority = IssuePriority.default
          p.priority = default_priority
        end
      end

      if p.dates_derived?
        # start/due dates = lowest/highest dates of children
        p.start_date = p.children.minimum(:start_date)
        p.due_date = p.children.maximum(:due_date)
        if p.start_date && p.due_date && p.due_date < p.start_date
          p.start_date, p.due_date = p.due_date, p.start_date
        end
      end

      if p.done_ratio_derived?
        # done ratio = average ratio of children weighted with their total estimated hours
        unless Issue.use_status_for_done_ratio? && p.status && p.status.default_done_ratio
          children = p.children.to_a
          if children.any?
            child_with_total_estimated_hours = children.select {|c| c.total_estimated_hours.to_f > 0.0}
            if child_with_total_estimated_hours.any?
              average = Rational(
                child_with_total_estimated_hours.sum(&:total_estimated_hours).to_s,
                child_with_total_estimated_hours.count
              )
            else
              average = Rational(1)
            end
            done = children.sum do |c|
              estimated = Rational(c.total_estimated_hours.to_f.to_s)
              estimated = average unless estimated > 0.0
              ratio = c.closed? ? 100 : (c.done_ratio || 0)
              estimated * ratio
            end
            progress = Rational(done, average * children.count)
            p.done_ratio = progress.floor
          end
        end
      end

      # ancestors will be recursively updated
      p.save(:validate => false)
    end
  end

  # Singleton class method is public
  class << self
    # Update issues so their versions are not pointing to a
    # fixed_version that is not shared with the issue's project
    def update_versions(conditions=nil)
      # Only need to update issues with a fixed_version from
      # a different project and that is not systemwide shared
      Issue.joins(:project, :fixed_version).
        where("#{Issue.table_name}.fixed_version_id IS NOT NULL" +
          " AND #{Issue.table_name}.project_id <> #{::Version.table_name}.project_id" +
          " AND #{::Version.table_name}.sharing <> 'system'").
        where(conditions).each do |issue|
        next if issue.project.nil? || issue.fixed_version.nil?

        unless issue.project.shared_versions.include?(issue.fixed_version)
          issue.init_journal(User.current)
          issue.fixed_version = nil
          issue.save
        end
      end
    end
  end

  def delete_selected_attachments
    if deleted_attachment_ids.present?
      objects = attachments.where(:id => deleted_attachment_ids.map(&:to_i))
      attachments.delete(objects)
    end
  end

  # Callback on file attachment
  def attachment_added(attachment)
    if current_journal && !attachment.new_record? && !copy?
      current_journal.journalize_attachment(attachment, :added)
    end
  end

  # Callback on attachment deletion
  def attachment_removed(attachment)
    if current_journal && !attachment.new_record?
      current_journal.journalize_attachment(attachment, :removed)
      current_journal.save
    end
  end

  # Called after a relation is added
  def relation_added(relation)
    if current_journal
      current_journal.journalize_relation(relation, :added)
      current_journal.save
    end
  end

  # Called after a relation is removed
  def relation_removed(relation)
    if current_journal
      current_journal.journalize_relation(relation, :removed)
      current_journal.save
    end
  end

  # Default assignment based on project or category
  def default_assign
    if assigned_to.nil?
      if category && category.assigned_to
        self.assigned_to = category.assigned_to
      elsif project && project.default_assigned_to
        self.assigned_to = project.default_assigned_to
      end
    end
  end

  # Updates start/due dates of following issues
  def reschedule_following_issues
    if saved_change_to_start_date? || saved_change_to_due_date?
      relations_from.each do |relation|
        relation.set_issue_to_dates(@current_journal)
      end
    end
  end

  # Closes duplicates if the issue is being closed
  def close_duplicates
    if Setting.close_duplicate_issues? && closing?
      duplicates.each do |duplicate|
        # Reload is needed in case the duplicate was updated by a previous duplicate
        duplicate.reload
        # Don't re-close it if it's already closed
        next if duplicate.closed?

        # Same user and notes
        if @current_journal
          duplicate.init_journal(@current_journal.user, @current_journal.notes)
          duplicate.private_notes = @current_journal.private_notes
        end
        duplicate.update_attribute :status, self.status
      end
    end
  end

  # Make sure updated_on is updated when adding a note and set updated_on now
  # so we can set closed_on with the same value on closing
  def force_updated_on_change
    if @current_journal || changed?
      self.updated_on = current_time_from_proper_timezone
      if new_record?
        self.created_on = updated_on
      end
    end
  end

  # Callback for setting closed_on when the issue is closed.
  # The closed_on attribute stores the time of the last closing
  # and is preserved when the issue is reopened.
  def update_closed_on
    if closing?
      self.closed_on = updated_on
    end
  end

  # Saves the changes in a Journal
  # Called after_save
  def create_journal
    if current_journal
      current_journal.save
    end
  end

  def create_parent_issue_journal
    return if persisted? && !saved_change_to_parent_id?
    return if destroyed? && @without_nested_set_update

    child_id = self.id
    old_parent_id, new_parent_id =
      if persisted?
        [parent_id_before_last_save, parent_id]
      elsif destroyed?
        [parent_id, nil]
      else
        [nil, parent_id]
      end

    if old_parent_id.present? && old_parent_issue = Issue.visible.find_by_id(old_parent_id)
      old_parent_issue.init_journal(User.current)
      old_parent_issue.current_journal.__send__(:add_attribute_detail, 'child_id', child_id, nil)
      old_parent_issue.save
    end
    if new_parent_id.present? && new_parent_issue = Issue.visible.find_by_id(new_parent_id)
      new_parent_issue.init_journal(User.current)
      new_parent_issue.current_journal.__send__(:add_attribute_detail, 'child_id', nil, child_id)
      new_parent_issue.save
    end
  end

  def send_notification
    if notify? && Setting.notified_events.include?('issue_added')
      Mailer.deliver_issue_add(self)
    end
  end

  def clear_disabled_fields
    if tracker
      tracker.disabled_core_fields.each do |attribute|
        send "#{attribute}=", nil
      end
      self.done_ratio ||= 0
    end
  end

  def filter_projects_scope(scope=nil)
    case scope
    when 'system'
      Project
    when 'tree'
      project.root.self_and_descendants
    when 'hierarchy'
      project.hierarchy
    when 'descendants'
      project.self_and_descendants
    when ''
      Project.where(:id => project.id)
    else
      Project
    end
  end
end
