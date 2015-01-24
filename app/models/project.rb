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

class Project < ActiveRecord::Base
  include Redmine::SafeAttributes
  include Redmine::NestedSet::ProjectNestedSet

  # Project statuses
  STATUS_ACTIVE     = 1
  STATUS_CLOSED     = 5
  STATUS_ARCHIVED   = 9

  # Maximum length for project identifiers
  IDENTIFIER_MAX_LENGTH = 100

  # Specific overridden Activities
  has_many :time_entry_activities
  has_many :members,
           lambda { joins(:principal, :roles).
                    where("#{Principal.table_name}.type='User' AND #{Principal.table_name}.status=#{Principal::STATUS_ACTIVE}") }
  has_many :memberships, :class_name => 'Member'
  has_many :member_principals,
           lambda { joins(:principal).
                    where("#{Principal.table_name}.status=#{Principal::STATUS_ACTIVE}")},
    :class_name => 'Member'
  has_many :enabled_modules, :dependent => :delete_all
  has_and_belongs_to_many :trackers, lambda {order(:position)}
  has_many :issues, :dependent => :destroy
  has_many :issue_changes, :through => :issues, :source => :journals
  has_many :versions, lambda {order("#{Version.table_name}.effective_date DESC, #{Version.table_name}.name DESC")}, :dependent => :destroy
  has_many :time_entries, :dependent => :destroy
  has_many :queries, :class_name => 'IssueQuery', :dependent => :delete_all
  has_many :documents, :dependent => :destroy
  has_many :news, lambda {includes(:author)}, :dependent => :destroy
  has_many :issue_categories, lambda {order("#{IssueCategory.table_name}.name")}, :dependent => :delete_all
  has_many :boards, lambda {order("position ASC")}, :dependent => :destroy
  has_one :repository, lambda {where(["is_default = ?", true])}
  has_many :repositories, :dependent => :destroy
  has_many :changesets, :through => :repository
  has_one :wiki, :dependent => :destroy
  # Custom field for the project issues
  has_and_belongs_to_many :issue_custom_fields,
                          lambda {order("#{CustomField.table_name}.position")},
                          :class_name => 'IssueCustomField',
                          :join_table => "#{table_name_prefix}custom_fields_projects#{table_name_suffix}",
                          :association_foreign_key => 'custom_field_id'

  acts_as_attachable :view_permission => :view_files,
                     :edit_permission => :manage_files,
                     :delete_permission => :manage_files

  acts_as_customizable
  acts_as_searchable :columns => ['name', 'identifier', 'description'], :project_key => "#{Project.table_name}.id", :permission => nil
  acts_as_event :title => Proc.new {|o| "#{l(:label_project)}: #{o.name}"},
                :url => Proc.new {|o| {:controller => 'projects', :action => 'show', :id => o}},
                :author => nil

  attr_protected :status

  validates_presence_of :name, :identifier
  validates_uniqueness_of :identifier, :if => Proc.new {|p| p.identifier_changed?}
  validates_length_of :name, :maximum => 255
  validates_length_of :homepage, :maximum => 255
  validates_length_of :identifier, :in => 1..IDENTIFIER_MAX_LENGTH
  # downcase letters, digits, dashes but not digits only
  validates_format_of :identifier, :with => /\A(?!\d+$)[a-z0-9\-_]*\z/, :if => Proc.new { |p| p.identifier_changed? }
  # reserved words
  validates_exclusion_of :identifier, :in => %w( new )
  validate :validate_parent

  after_save :update_inherited_members, :if => Proc.new {|project| project.inherit_members_changed?}
  after_save :remove_inherited_member_roles, :add_inherited_member_roles, :if => Proc.new {|project| project.parent_id_changed?}
  after_update :update_versions_from_hierarchy_change, :if => Proc.new {|project| project.parent_id_changed?}
  before_destroy :delete_all_members

  scope :has_module, lambda {|mod|
    where("#{Project.table_name}.id IN (SELECT em.project_id FROM #{EnabledModule.table_name} em WHERE em.name=?)", mod.to_s)
  }
  scope :active, lambda { where(:status => STATUS_ACTIVE) }
  scope :status, lambda {|arg| where(arg.blank? ? nil : {:status => arg.to_i}) }
  scope :all_public, lambda { where(:is_public => true) }
  scope :visible, lambda {|*args| where(Project.visible_condition(args.shift || User.current, *args)) }
  scope :allowed_to, lambda {|*args|
    user = User.current
    permission = nil
    if args.first.is_a?(Symbol)
      permission = args.shift
    else
      user = args.shift
      permission = args.shift
    end
    where(Project.allowed_to_condition(user, permission, *args))
  }
  scope :like, lambda {|arg|
    if arg.blank?
      where(nil)
    else
      pattern = "%#{arg.to_s.strip.downcase}%"
      where("LOWER(identifier) LIKE :p OR LOWER(name) LIKE :p", :p => pattern)
    end
  }
  scope :sorted, lambda {order(:lft)}

  def initialize(attributes=nil, *args)
    super

    initialized = (attributes || {}).stringify_keys
    if !initialized.key?('identifier') && Setting.sequential_project_identifiers?
      self.identifier = Project.next_identifier
    end
    if !initialized.key?('is_public')
      self.is_public = Setting.default_projects_public?
    end
    if !initialized.key?('enabled_module_names')
      self.enabled_module_names = Setting.default_projects_modules
    end
    if !initialized.key?('trackers') && !initialized.key?('tracker_ids')
      default = Setting.default_projects_tracker_ids
      if default.is_a?(Array)
        self.trackers = Tracker.where(:id => default.map(&:to_i)).sorted.to_a
      else
        self.trackers = Tracker.sorted.to_a
      end
    end
  end

  def identifier=(identifier)
    super unless identifier_frozen?
  end

  def identifier_frozen?
    errors[:identifier].blank? && !(new_record? || identifier.blank?)
  end

  # returns latest created projects
  # non public projects will be returned only if user is a member of those
  def self.latest(user=nil, count=5)
    visible(user).limit(count).order("created_on DESC").to_a
  end

  # Returns true if the project is visible to +user+ or to the current user.
  def visible?(user=User.current)
    user.allowed_to?(:view_project, self)
  end

  # Returns a SQL conditions string used to find all projects visible by the specified user.
  #
  # Examples:
  #   Project.visible_condition(admin)        => "projects.status = 1"
  #   Project.visible_condition(normal_user)  => "((projects.status = 1) AND (projects.is_public = 1 OR projects.id IN (1,3,4)))"
  #   Project.visible_condition(anonymous)    => "((projects.status = 1) AND (projects.is_public = 1))"
  def self.visible_condition(user, options={})
    allowed_to_condition(user, :view_project, options)
  end

  # Returns a SQL conditions string used to find all projects for which +user+ has the given +permission+
  #
  # Valid options:
  # * :project => limit the condition to project
  # * :with_subprojects => limit the condition to project and its subprojects
  # * :member => limit the condition to the user projects
  def self.allowed_to_condition(user, permission, options={})
    perm = Redmine::AccessControl.permission(permission)
    base_statement = (perm && perm.read? ? "#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED}" : "#{Project.table_name}.status = #{Project::STATUS_ACTIVE}")
    if perm && perm.project_module
      # If the permission belongs to a project module, make sure the module is enabled
      base_statement << " AND #{Project.table_name}.id IN (SELECT em.project_id FROM #{EnabledModule.table_name} em WHERE em.name='#{perm.project_module}')"
    end
    if project = options[:project]
      project_statement = project.project_condition(options[:with_subprojects])
      base_statement = "(#{project_statement}) AND (#{base_statement})"
    end

    if user.admin?
      base_statement
    else
      statement_by_role = {}
      unless options[:member]
        role = user.builtin_role
        if role.allowed_to?(permission)
          statement_by_role[role] = "#{Project.table_name}.is_public = #{connection.quoted_true}"
        end
      end
      user.projects_by_role.each do |role, projects|
        if role.allowed_to?(permission) && projects.any?
          statement_by_role[role] = "#{Project.table_name}.id IN (#{projects.collect(&:id).join(',')})"
        end
      end
      if statement_by_role.empty?
        "1=0"
      else
        if block_given?
          statement_by_role.each do |role, statement|
            if s = yield(role, user)
              statement_by_role[role] = "(#{statement} AND (#{s}))"
            end
          end
        end
        "((#{base_statement}) AND (#{statement_by_role.values.join(' OR ')}))"
      end
    end
  end

  def override_roles(role)
    @override_members ||= member_principals.
      where("#{Principal.table_name}.type IN (?)", ['GroupAnonymous', 'GroupNonMember']).to_a

    group_class = role.anonymous? ? GroupAnonymous : GroupNonMember
    member = @override_members.detect {|m| m.principal.is_a? group_class}
    member ? member.roles.to_a : [role]
  end

  def principals
    @principals ||= Principal.active.joins(:members).where("#{Member.table_name}.project_id = ?", id).uniq
  end

  def users
    @users ||= User.active.joins(:members).where("#{Member.table_name}.project_id = ?", id).uniq
  end

  # Returns the Systemwide and project specific activities
  def activities(include_inactive=false)
    if include_inactive
      return all_activities
    else
      return active_activities
    end
  end

  # Will create a new Project specific Activity or update an existing one
  #
  # This will raise a ActiveRecord::Rollback if the TimeEntryActivity
  # does not successfully save.
  def update_or_create_time_entry_activity(id, activity_hash)
    if activity_hash.respond_to?(:has_key?) && activity_hash.has_key?('parent_id')
      self.create_time_entry_activity_if_needed(activity_hash)
    else
      activity = project.time_entry_activities.find_by_id(id.to_i)
      activity.update_attributes(activity_hash) if activity
    end
  end

  # Create a new TimeEntryActivity if it overrides a system TimeEntryActivity
  #
  # This will raise a ActiveRecord::Rollback if the TimeEntryActivity
  # does not successfully save.
  def create_time_entry_activity_if_needed(activity)
    if activity['parent_id']
      parent_activity = TimeEntryActivity.find(activity['parent_id'])
      activity['name'] = parent_activity.name
      activity['position'] = parent_activity.position
      if Enumeration.overriding_change?(activity, parent_activity)
        project_activity = self.time_entry_activities.create(activity)
        if project_activity.new_record?
          raise ActiveRecord::Rollback, "Overriding TimeEntryActivity was not successfully saved"
        else
          self.time_entries.
            where(["activity_id = ?", parent_activity.id]).
            update_all("activity_id = #{project_activity.id}")
        end
      end
    end
  end

  # Returns a :conditions SQL string that can be used to find the issues associated with this project.
  #
  # Examples:
  #   project.project_condition(true)  => "(projects.id = 1 OR (projects.lft > 1 AND projects.rgt < 10))"
  #   project.project_condition(false) => "projects.id = 1"
  def project_condition(with_subprojects)
    cond = "#{Project.table_name}.id = #{id}"
    cond = "(#{cond} OR (#{Project.table_name}.lft > #{lft} AND #{Project.table_name}.rgt < #{rgt}))" if with_subprojects
    cond
  end

  def self.find(*args)
    if args.first && args.first.is_a?(String) && !args.first.match(/^\d*$/)
      project = find_by_identifier(*args)
      raise ActiveRecord::RecordNotFound, "Couldn't find Project with identifier=#{args.first}" if project.nil?
      project
    else
      super
    end
  end

  def self.find_by_param(*args)
    self.find(*args)
  end

  alias :base_reload :reload
  def reload(*args)
    @principals = nil
    @users = nil
    @shared_versions = nil
    @rolled_up_versions = nil
    @rolled_up_trackers = nil
    @all_issue_custom_fields = nil
    @all_time_entry_custom_fields = nil
    @to_param = nil
    @allowed_parents = nil
    @allowed_permissions = nil
    @actions_allowed = nil
    @start_date = nil
    @due_date = nil
    @override_members = nil
    @assignable_users = nil
    base_reload(*args)
  end

  def to_param
    # id is used for projects with a numeric identifier (compatibility)
    @to_param ||= (identifier.to_s =~ %r{^\d*$} ? id.to_s : identifier)
  end

  def active?
    self.status == STATUS_ACTIVE
  end

  def archived?
    self.status == STATUS_ARCHIVED
  end

  # Archives the project and its descendants
  def archive
    # Check that there is no issue of a non descendant project that is assigned
    # to one of the project or descendant versions
    version_ids = self_and_descendants.joins(:versions).pluck("#{Version.table_name}.id")

    if version_ids.any? &&
      Issue.
        includes(:project).
        where("#{Project.table_name}.lft < ? OR #{Project.table_name}.rgt > ?", lft, rgt).
        where(:fixed_version_id => version_ids).
        exists?
      return false
    end
    Project.transaction do
      archive!
    end
    true
  end

  # Unarchives the project
  # All its ancestors must be active
  def unarchive
    return false if ancestors.detect {|a| !a.active?}
    update_attribute :status, STATUS_ACTIVE
  end

  def close
    self_and_descendants.status(STATUS_ACTIVE).update_all :status => STATUS_CLOSED
  end

  def reopen
    self_and_descendants.status(STATUS_CLOSED).update_all :status => STATUS_ACTIVE
  end

  # Returns an array of projects the project can be moved to
  # by the current user
  def allowed_parents(user=User.current)
    return @allowed_parents if @allowed_parents
    @allowed_parents = Project.allowed_to(user, :add_subprojects).to_a
    @allowed_parents = @allowed_parents - self_and_descendants
    if user.allowed_to?(:add_project, nil, :global => true) || (!new_record? && parent.nil?)
      @allowed_parents << nil
    end
    unless parent.nil? || @allowed_parents.empty? || @allowed_parents.include?(parent)
      @allowed_parents << parent
    end
    @allowed_parents
  end

  # Sets the parent of the project with authorization check
  def set_allowed_parent!(p)
    ActiveSupport::Deprecation.warn "Project#set_allowed_parent! is deprecated and will be removed in Redmine 4, use #safe_attributes= instead."
    p = p.id if p.is_a?(Project)
    send :safe_attributes, {:project_id => p}
    save
  end

  # Sets the parent of the project and saves the project
  # Argument can be either a Project, a String, a Fixnum or nil
  def set_parent!(p)
    if p.is_a?(Project)
      self.parent = p
    else
      self.parent_id = p
    end
    save
  end

  # Returns an array of the trackers used by the project and its active sub projects
  def rolled_up_trackers
    @rolled_up_trackers ||=
      Tracker.
        joins(:projects).
        joins("JOIN #{EnabledModule.table_name} ON #{EnabledModule.table_name}.project_id = #{Project.table_name}.id AND #{EnabledModule.table_name}.name = 'issue_tracking'").
        where("#{Project.table_name}.lft >= ? AND #{Project.table_name}.rgt <= ? AND #{Project.table_name}.status <> ?", lft, rgt, STATUS_ARCHIVED).
        uniq.
        sorted.
        to_a
  end

  # Closes open and locked project versions that are completed
  def close_completed_versions
    Version.transaction do
      versions.where(:status => %w(open locked)).each do |version|
        if version.completed?
          version.update_attribute(:status, 'closed')
        end
      end
    end
  end

  # Returns a scope of the Versions on subprojects
  def rolled_up_versions
    @rolled_up_versions ||=
      Version.
        joins(:project).
        where("#{Project.table_name}.lft >= ? AND #{Project.table_name}.rgt <= ? AND #{Project.table_name}.status <> ?", lft, rgt, STATUS_ARCHIVED)
  end

  # Returns a scope of the Versions used by the project
  def shared_versions
    if new_record?
      Version.
        joins(:project).
        preload(:project).
        where("#{Project.table_name}.status <> ? AND #{Version.table_name}.sharing = 'system'", STATUS_ARCHIVED)
    else
      @shared_versions ||= begin
        r = root? ? self : root
        Version.
          joins(:project).
          preload(:project).
          where("#{Project.table_name}.id = #{id}" +
                  " OR (#{Project.table_name}.status <> #{Project::STATUS_ARCHIVED} AND (" +
                    " #{Version.table_name}.sharing = 'system'" +
                    " OR (#{Project.table_name}.lft >= #{r.lft} AND #{Project.table_name}.rgt <= #{r.rgt} AND #{Version.table_name}.sharing = 'tree')" +
                    " OR (#{Project.table_name}.lft < #{lft} AND #{Project.table_name}.rgt > #{rgt} AND #{Version.table_name}.sharing IN ('hierarchy', 'descendants'))" +
                    " OR (#{Project.table_name}.lft > #{lft} AND #{Project.table_name}.rgt < #{rgt} AND #{Version.table_name}.sharing = 'hierarchy')" +
                  "))")
      end
    end
  end

  # Returns a hash of project users grouped by role
  def users_by_role
    members.includes(:user, :roles).inject({}) do |h, m|
      m.roles.each do |r|
        h[r] ||= []
        h[r] << m.user
      end
      h
    end
  end

  # Adds user as a project member with the default role
  # Used for when a non-admin user creates a project
  def add_default_member(user)
    role = Role.givable.find_by_id(Setting.new_project_user_role_id.to_i) || Role.givable.first
    member = Member.new(:project => self, :principal => user, :roles => [role])
    self.members << member
    member
  end

  # Deletes all project's members
  def delete_all_members
    me, mr = Member.table_name, MemberRole.table_name
    self.class.connection.delete("DELETE FROM #{mr} WHERE #{mr}.member_id IN (SELECT #{me}.id FROM #{me} WHERE #{me}.project_id = #{id})")
    Member.delete_all(['project_id = ?', id])
  end

  # Return a Principal scope of users/groups issues can be assigned to
  def assignable_users
    types = ['User']
    types << 'Group' if Setting.issue_group_assignment?

    @assignable_users ||= Principal.
      active.
      joins(:members => :roles).
      where(:type => types, :members => {:project_id => id}, :roles => {:assignable => true}).
      uniq.
      sorted
  end

  # Returns the mail addresses of users that should be always notified on project events
  def recipients
    notified_users.collect {|user| user.mail}
  end

  # Returns the users that should be notified on project events
  def notified_users
    # TODO: User part should be extracted to User#notify_about?
    members.select {|m| m.principal.present? && (m.mail_notification? || m.principal.mail_notification == 'all')}.collect {|m| m.principal}
  end

  # Returns a scope of all custom fields enabled for project issues
  # (explicitly associated custom fields and custom fields enabled for all projects)
  def all_issue_custom_fields
    @all_issue_custom_fields ||= IssueCustomField.
      sorted.
      where("is_for_all = ? OR id IN (SELECT DISTINCT cfp.custom_field_id" +
        " FROM #{table_name_prefix}custom_fields_projects#{table_name_suffix} cfp" +
        " WHERE cfp.project_id = ?)", true, id)
  end

  def project
    self
  end

  def <=>(project)
    name.downcase <=> project.name.downcase
  end

  def to_s
    name
  end

  # Returns a short description of the projects (first lines)
  def short_description(length = 255)
    description.gsub(/^(.{#{length}}[^\n\r]*).*$/m, '\1...').strip if description
  end

  def css_classes
    s = 'project'
    s << ' root' if root?
    s << ' child' if child?
    s << (leaf? ? ' leaf' : ' parent')
    unless active?
      if archived?
        s << ' archived'
      else
        s << ' closed'
      end
    end
    s
  end

  # The earliest start date of a project, based on it's issues and versions
  def start_date
    @start_date ||= [
     issues.minimum('start_date'),
     shared_versions.minimum('effective_date'),
     Issue.fixed_version(shared_versions).minimum('start_date')
    ].compact.min
  end

  # The latest due date of an issue or version
  def due_date
    @due_date ||= [
     issues.maximum('due_date'),
     shared_versions.maximum('effective_date'),
     Issue.fixed_version(shared_versions).maximum('due_date')
    ].compact.max
  end

  def overdue?
    active? && !due_date.nil? && (due_date < Date.today)
  end

  # Returns the percent completed for this project, based on the
  # progress on it's versions.
  def completed_percent(options={:include_subprojects => false})
    if options.delete(:include_subprojects)
      total = self_and_descendants.collect(&:completed_percent).sum

      total / self_and_descendants.count
    else
      if versions.count > 0
        total = versions.collect(&:completed_percent).sum

        total / versions.count
      else
        100
      end
    end
  end

  # Return true if this project allows to do the specified action.
  # action can be:
  # * a parameter-like Hash (eg. :controller => 'projects', :action => 'edit')
  # * a permission Symbol (eg. :edit_project)
  def allows_to?(action)
    if archived?
      # No action allowed on archived projects
      return false
    end
    unless active? || Redmine::AccessControl.read_action?(action)
      # No write action allowed on closed projects
      return false
    end
    # No action allowed on disabled modules
    if action.is_a? Hash
      allowed_actions.include? "#{action[:controller]}/#{action[:action]}"
    else
      allowed_permissions.include? action
    end
  end

  # Return the enabled module with the given name
  # or nil if the module is not enabled for the project
  def enabled_module(name)
    name = name.to_s
    enabled_modules.detect {|m| m.name == name}
  end

  # Return true if the module with the given name is enabled
  def module_enabled?(name)
    enabled_module(name).present?
  end

  def enabled_module_names=(module_names)
    if module_names && module_names.is_a?(Array)
      module_names = module_names.collect(&:to_s).reject(&:blank?)
      self.enabled_modules = module_names.collect {|name| enabled_modules.detect {|mod| mod.name == name} || EnabledModule.new(:name => name)}
    else
      enabled_modules.clear
    end
  end

  # Returns an array of the enabled modules names
  def enabled_module_names
    enabled_modules.collect(&:name)
  end

  # Enable a specific module
  #
  # Examples:
  #   project.enable_module!(:issue_tracking)
  #   project.enable_module!("issue_tracking")
  def enable_module!(name)
    enabled_modules << EnabledModule.new(:name => name.to_s) unless module_enabled?(name)
  end

  # Disable a module if it exists
  #
  # Examples:
  #   project.disable_module!(:issue_tracking)
  #   project.disable_module!("issue_tracking")
  #   project.disable_module!(project.enabled_modules.first)
  def disable_module!(target)
    target = enabled_modules.detect{|mod| target.to_s == mod.name} unless enabled_modules.include?(target)
    target.destroy unless target.blank?
  end

  safe_attributes 'name',
    'description',
    'homepage',
    'is_public',
    'identifier',
    'custom_field_values',
    'custom_fields',
    'tracker_ids',
    'issue_custom_field_ids',
    'parent_id'

  safe_attributes 'enabled_module_names',
    :if => lambda {|project, user| project.new_record? || user.allowed_to?(:select_project_modules, project) }

  safe_attributes 'inherit_members',
    :if => lambda {|project, user| project.parent.nil? || project.parent.visible?(user)}

  def safe_attributes=(attrs, user=User.current)
    return unless attrs.is_a?(Hash)
    attrs = attrs.deep_dup

    @unallowed_parent_id = nil
    parent_id_param = attrs['parent_id'].to_s
    if parent_id_param.blank? || parent_id_param != parent_id.to_s
      p = parent_id_param.present? ? Project.find_by_id(parent_id_param) : nil
      unless allowed_parents(user).include?(p)
        attrs.delete('parent_id')
        @unallowed_parent_id = true
      end
    end

    super(attrs, user)
  end

  # Returns an auto-generated project identifier based on the last identifier used
  def self.next_identifier
    p = Project.order('id DESC').first
    p.nil? ? nil : p.identifier.to_s.succ
  end

  # Copies and saves the Project instance based on the +project+.
  # Duplicates the source project's:
  # * Wiki
  # * Versions
  # * Categories
  # * Issues
  # * Members
  # * Queries
  #
  # Accepts an +options+ argument to specify what to copy
  #
  # Examples:
  #   project.copy(1)                                    # => copies everything
  #   project.copy(1, :only => 'members')                # => copies members only
  #   project.copy(1, :only => ['members', 'versions'])  # => copies members and versions
  def copy(project, options={})
    project = project.is_a?(Project) ? project : Project.find(project)

    to_be_copied = %w(wiki versions issue_categories issues members queries boards)
    to_be_copied = to_be_copied & Array.wrap(options[:only]) unless options[:only].nil?

    Project.transaction do
      if save
        reload
        to_be_copied.each do |name|
          send "copy_#{name}", project
        end
        Redmine::Hook.call_hook(:model_project_copy_before_save, :source_project => project, :destination_project => self)
        save
      else
        false
      end
    end
  end

  # Returns a new unsaved Project instance with attributes copied from +project+
  def self.copy_from(project)
    project = project.is_a?(Project) ? project : Project.find(project)
    # clear unique attributes
    attributes = project.attributes.dup.except('id', 'name', 'identifier', 'status', 'parent_id', 'lft', 'rgt')
    copy = Project.new(attributes)
    copy.enabled_modules = project.enabled_modules
    copy.trackers = project.trackers
    copy.custom_values = project.custom_values.collect {|v| v.clone}
    copy.issue_custom_fields = project.issue_custom_fields
    copy
  end

  # Yields the given block for each project with its level in the tree
  def self.project_tree(projects, &block)
    ancestors = []
    projects.sort_by(&:lft).each do |project|
      while (ancestors.any? && !project.is_descendant_of?(ancestors.last))
        ancestors.pop
      end
      yield project, ancestors.size
      ancestors << project
    end
  end

  private

  def update_inherited_members
    if parent
      if inherit_members? && !inherit_members_was
        remove_inherited_member_roles
        add_inherited_member_roles
      elsif !inherit_members? && inherit_members_was
        remove_inherited_member_roles
      end
    end
  end

  def remove_inherited_member_roles
    member_roles = memberships.map(&:member_roles).flatten
    member_role_ids = member_roles.map(&:id)
    member_roles.each do |member_role|
      if member_role.inherited_from && !member_role_ids.include?(member_role.inherited_from)
        member_role.destroy
      end
    end
  end

  def add_inherited_member_roles
    if inherit_members? && parent
      parent.memberships.each do |parent_member|
        member = Member.find_or_new(self.id, parent_member.user_id)
        parent_member.member_roles.each do |parent_member_role|
          member.member_roles << MemberRole.new(:role => parent_member_role.role, :inherited_from => parent_member_role.id)
        end
        member.save!
      end
      memberships.reset
    end
  end

  def update_versions_from_hierarchy_change
    Issue.update_versions_from_hierarchy_change(self)
  end

  def validate_parent
    if @unallowed_parent_id
      errors.add(:parent_id, :invalid)
    elsif parent_id_changed?
      unless parent.nil? || (parent.active? && move_possible?(parent))
        errors.add(:parent_id, :invalid)
      end
    end
  end

  # Copies wiki from +project+
  def copy_wiki(project)
    # Check that the source project has a wiki first
    unless project.wiki.nil?
      wiki = self.wiki || Wiki.new
      wiki.attributes = project.wiki.attributes.dup.except("id", "project_id")
      wiki_pages_map = {}
      project.wiki.pages.each do |page|
        # Skip pages without content
        next if page.content.nil?
        new_wiki_content = WikiContent.new(page.content.attributes.dup.except("id", "page_id", "updated_on"))
        new_wiki_page = WikiPage.new(page.attributes.dup.except("id", "wiki_id", "created_on", "parent_id"))
        new_wiki_page.content = new_wiki_content
        wiki.pages << new_wiki_page
        wiki_pages_map[page.id] = new_wiki_page
      end

      self.wiki = wiki
      wiki.save
      # Reproduce page hierarchy
      project.wiki.pages.each do |page|
        if page.parent_id && wiki_pages_map[page.id]
          wiki_pages_map[page.id].parent = wiki_pages_map[page.parent_id]
          wiki_pages_map[page.id].save
        end
      end
    end
  end

  # Copies versions from +project+
  def copy_versions(project)
    project.versions.each do |version|
      new_version = Version.new
      new_version.attributes = version.attributes.dup.except("id", "project_id", "created_on", "updated_on")
      self.versions << new_version
    end
  end

  # Copies issue categories from +project+
  def copy_issue_categories(project)
    project.issue_categories.each do |issue_category|
      new_issue_category = IssueCategory.new
      new_issue_category.attributes = issue_category.attributes.dup.except("id", "project_id")
      self.issue_categories << new_issue_category
    end
  end

  # Copies issues from +project+
  def copy_issues(project)
    # Stores the source issue id as a key and the copied issues as the
    # value.  Used to map the two together for issue relations.
    issues_map = {}

    # Store status and reopen locked/closed versions
    version_statuses = versions.reject(&:open?).map {|version| [version, version.status]}
    version_statuses.each do |version, status|
      version.update_attribute :status, 'open'
    end

    # Get issues sorted by root_id, lft so that parent issues
    # get copied before their children
    project.issues.reorder('root_id, lft').each do |issue|
      new_issue = Issue.new
      new_issue.copy_from(issue, :subtasks => false, :link => false)
      new_issue.project = self
      # Changing project resets the custom field values
      # TODO: handle this in Issue#project=
      new_issue.custom_field_values = issue.custom_field_values.inject({}) {|h,v| h[v.custom_field_id] = v.value; h}
      # Reassign fixed_versions by name, since names are unique per project
      if issue.fixed_version && issue.fixed_version.project == project
        new_issue.fixed_version = self.versions.detect {|v| v.name == issue.fixed_version.name}
      end
      # Reassign the category by name, since names are unique per project
      if issue.category
        new_issue.category = self.issue_categories.detect {|c| c.name == issue.category.name}
      end
      # Parent issue
      if issue.parent_id
        if copied_parent = issues_map[issue.parent_id]
          new_issue.parent_issue_id = copied_parent.id
        end
      end

      self.issues << new_issue
      if new_issue.new_record?
        logger.info "Project#copy_issues: issue ##{issue.id} could not be copied: #{new_issue.errors.full_messages}" if logger && logger.info?
      else
        issues_map[issue.id] = new_issue unless new_issue.new_record?
      end
    end

    # Restore locked/closed version statuses
    version_statuses.each do |version, status|
      version.update_attribute :status, status
    end

    # Relations after in case issues related each other
    project.issues.each do |issue|
      new_issue = issues_map[issue.id]
      unless new_issue
        # Issue was not copied
        next
      end

      # Relations
      issue.relations_from.each do |source_relation|
        new_issue_relation = IssueRelation.new
        new_issue_relation.attributes = source_relation.attributes.dup.except("id", "issue_from_id", "issue_to_id")
        new_issue_relation.issue_to = issues_map[source_relation.issue_to_id]
        if new_issue_relation.issue_to.nil? && Setting.cross_project_issue_relations?
          new_issue_relation.issue_to = source_relation.issue_to
        end
        new_issue.relations_from << new_issue_relation
      end

      issue.relations_to.each do |source_relation|
        new_issue_relation = IssueRelation.new
        new_issue_relation.attributes = source_relation.attributes.dup.except("id", "issue_from_id", "issue_to_id")
        new_issue_relation.issue_from = issues_map[source_relation.issue_from_id]
        if new_issue_relation.issue_from.nil? && Setting.cross_project_issue_relations?
          new_issue_relation.issue_from = source_relation.issue_from
        end
        new_issue.relations_to << new_issue_relation
      end
    end
  end

  # Copies members from +project+
  def copy_members(project)
    # Copy users first, then groups to handle members with inherited and given roles
    members_to_copy = []
    members_to_copy += project.memberships.select {|m| m.principal.is_a?(User)}
    members_to_copy += project.memberships.select {|m| !m.principal.is_a?(User)}

    members_to_copy.each do |member|
      new_member = Member.new
      new_member.attributes = member.attributes.dup.except("id", "project_id", "created_on")
      # only copy non inherited roles
      # inherited roles will be added when copying the group membership
      role_ids = member.member_roles.reject(&:inherited?).collect(&:role_id)
      next if role_ids.empty?
      new_member.role_ids = role_ids
      new_member.project = self
      self.members << new_member
    end
  end

  # Copies queries from +project+
  def copy_queries(project)
    project.queries.each do |query|
      new_query = IssueQuery.new
      new_query.attributes = query.attributes.dup.except("id", "project_id", "sort_criteria", "user_id", "type")
      new_query.sort_criteria = query.sort_criteria if query.sort_criteria
      new_query.project = self
      new_query.user_id = query.user_id
      new_query.role_ids = query.role_ids if query.visibility == IssueQuery::VISIBILITY_ROLES
      self.queries << new_query
    end
  end

  # Copies boards from +project+
  def copy_boards(project)
    project.boards.each do |board|
      new_board = Board.new
      new_board.attributes = board.attributes.dup.except("id", "project_id", "topics_count", "messages_count", "last_message_id")
      new_board.project = self
      self.boards << new_board
    end
  end

  def allowed_permissions
    @allowed_permissions ||= begin
      module_names = enabled_modules.loaded? ? enabled_modules.map(&:name) : enabled_modules.pluck(:name)
      Redmine::AccessControl.modules_permissions(module_names).collect {|p| p.name}
    end
  end

  def allowed_actions
    @actions_allowed ||= allowed_permissions.inject([]) { |actions, permission| actions += Redmine::AccessControl.allowed_actions(permission) }.flatten
  end

  # Returns all the active Systemwide and project specific activities
  def active_activities
    overridden_activity_ids = self.time_entry_activities.collect(&:parent_id)

    if overridden_activity_ids.empty?
      return TimeEntryActivity.shared.active
    else
      return system_activities_and_project_overrides
    end
  end

  # Returns all the Systemwide and project specific activities
  # (inactive and active)
  def all_activities
    overridden_activity_ids = self.time_entry_activities.collect(&:parent_id)

    if overridden_activity_ids.empty?
      return TimeEntryActivity.shared
    else
      return system_activities_and_project_overrides(true)
    end
  end

  # Returns the systemwide active activities merged with the project specific overrides
  def system_activities_and_project_overrides(include_inactive=false)
    t = TimeEntryActivity.table_name
    scope = TimeEntryActivity.where(
      "(#{t}.project_id IS NULL AND #{t}.id NOT IN (?)) OR (#{t}.project_id = ?)",
      time_entry_activities.map(&:parent_id), id
    )
    unless include_inactive
      scope = scope.active
    end
    scope
  end

  # Archives subprojects recursively
  def archive!
    children.each do |subproject|
      subproject.send :archive!
    end
    update_attribute :status, STATUS_ARCHIVED
  end
end
