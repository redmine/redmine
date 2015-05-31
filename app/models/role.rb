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

class Role < ActiveRecord::Base
  # Custom coder for the permissions attribute that should be an
  # array of symbols. Rails 3 uses Psych which can be *unbelievably*
  # slow on some platforms (eg. mingw32).
  class PermissionsAttributeCoder
    def self.load(str)
      str.to_s.scan(/:([a-z0-9_]+)/).flatten.map(&:to_sym)
    end

    def self.dump(value)
      YAML.dump(value)
    end
  end

  # Built-in roles
  BUILTIN_NON_MEMBER = 1
  BUILTIN_ANONYMOUS  = 2

  ISSUES_VISIBILITY_OPTIONS = [
    ['all', :label_issues_visibility_all],
    ['default', :label_issues_visibility_public],
    ['own', :label_issues_visibility_own]
  ]

  TIME_ENTRIES_VISIBILITY_OPTIONS = [
    ['all', :label_time_entries_visibility_all],
    ['own', :label_time_entries_visibility_own]
  ]

  USERS_VISIBILITY_OPTIONS = [
    ['all', :label_users_visibility_all],
    ['members_of_visible_projects', :label_users_visibility_members_of_visible_projects]
  ]

  scope :sorted, lambda { order(:builtin, :position) }
  scope :givable, lambda { order(:position).where(:builtin => 0) }
  scope :builtin, lambda { |*args|
    compare = (args.first == true ? 'not' : '')
    where("#{compare} builtin = 0")
  }

  before_destroy :check_deletable
  has_many :workflow_rules, :dependent => :delete_all do
    def copy(source_role)
      WorkflowRule.copy(nil, source_role, nil, proxy_association.owner)
    end
  end
  has_and_belongs_to_many :custom_fields, :join_table => "#{table_name_prefix}custom_fields_roles#{table_name_suffix}", :foreign_key => "role_id"

  has_and_belongs_to_many :managed_roles, :class_name => 'Role',
    :join_table => "#{table_name_prefix}roles_managed_roles#{table_name_suffix}",
    :association_foreign_key => "managed_role_id"

  has_many :member_roles, :dependent => :destroy
  has_many :members, :through => :member_roles
  acts_as_list

  serialize :permissions, ::Role::PermissionsAttributeCoder
  attr_protected :builtin

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 30
  validates_inclusion_of :issues_visibility,
    :in => ISSUES_VISIBILITY_OPTIONS.collect(&:first),
    :if => lambda {|role| role.respond_to?(:issues_visibility) && role.issues_visibility_changed?}
  validates_inclusion_of :users_visibility,
    :in => USERS_VISIBILITY_OPTIONS.collect(&:first),
    :if => lambda {|role| role.respond_to?(:users_visibility) && role.users_visibility_changed?}
  validates_inclusion_of :time_entries_visibility,
    :in => TIME_ENTRIES_VISIBILITY_OPTIONS.collect(&:first),
    :if => lambda {|role| role.respond_to?(:time_entries_visibility) && role.time_entries_visibility_changed?}

  # Copies attributes from another role, arg can be an id or a Role
  def copy_from(arg, options={})
    return unless arg.present?
    role = arg.is_a?(Role) ? arg : Role.find_by_id(arg.to_s)
    self.attributes = role.attributes.dup.except("id", "name", "position", "builtin", "permissions")
    self.permissions = role.permissions.dup
    self
  end

  def permissions=(perms)
    perms = perms.collect {|p| p.to_sym unless p.blank? }.compact.uniq if perms
    write_attribute(:permissions, perms)
  end

  def add_permission!(*perms)
    self.permissions = [] unless permissions.is_a?(Array)

    permissions_will_change!
    perms.each do |p|
      p = p.to_sym
      permissions << p unless permissions.include?(p)
    end
    save!
  end

  def remove_permission!(*perms)
    return unless permissions.is_a?(Array)
    permissions_will_change!
    perms.each { |p| permissions.delete(p.to_sym) }
    save!
  end

  # Returns true if the role has the given permission
  def has_permission?(perm)
    !permissions.nil? && permissions.include?(perm.to_sym)
  end

  def consider_workflow?
    has_permission?(:add_issues) || has_permission?(:edit_issues)
  end

  def <=>(role)
    if role
      if builtin == role.builtin
        position <=> role.position
      else
        builtin <=> role.builtin
      end
    else
      -1
    end
  end

  def to_s
    name
  end

  def name
    case builtin
    when 1; l(:label_role_non_member, :default => read_attribute(:name))
    when 2; l(:label_role_anonymous,  :default => read_attribute(:name))
    else; read_attribute(:name)
    end
  end

  # Return true if the role is a builtin role
  def builtin?
    self.builtin != 0
  end

  # Return true if the role is the anonymous role
  def anonymous?
    builtin == 2
  end

  # Return true if the role is a project member role
  def member?
    !self.builtin?
  end

  # Return true if role is allowed to do the specified action
  # action can be:
  # * a parameter-like Hash (eg. :controller => 'projects', :action => 'edit')
  # * a permission Symbol (eg. :edit_project)
  def allowed_to?(action)
    if action.is_a? Hash
      allowed_actions.include? "#{action[:controller]}/#{action[:action]}"
    else
      allowed_permissions.include? action
    end
  end

  # Return all the permissions that can be given to the role
  def setable_permissions
    setable_permissions = Redmine::AccessControl.permissions - Redmine::AccessControl.public_permissions
    setable_permissions -= Redmine::AccessControl.members_only_permissions if self.builtin == BUILTIN_NON_MEMBER
    setable_permissions -= Redmine::AccessControl.loggedin_only_permissions if self.builtin == BUILTIN_ANONYMOUS
    setable_permissions
  end

  # Find all the roles that can be given to a project member
  def self.find_all_givable
    Role.givable.to_a
  end

  # Return the builtin 'non member' role.  If the role doesn't exist,
  # it will be created on the fly.
  def self.non_member
    find_or_create_system_role(BUILTIN_NON_MEMBER, 'Non member')
  end

  # Return the builtin 'anonymous' role.  If the role doesn't exist,
  # it will be created on the fly.
  def self.anonymous
    find_or_create_system_role(BUILTIN_ANONYMOUS, 'Anonymous')
  end

private

  def allowed_permissions
    @allowed_permissions ||= permissions + Redmine::AccessControl.public_permissions.collect {|p| p.name}
  end

  def allowed_actions
    @actions_allowed ||= allowed_permissions.inject([]) { |actions, permission| actions += Redmine::AccessControl.allowed_actions(permission) }.flatten
  end

  def check_deletable
    raise "Cannot delete role" if members.any?
    raise "Cannot delete builtin role" if builtin?
  end

  def self.find_or_create_system_role(builtin, name)
    role = where(:builtin => builtin).first
    if role.nil?
      role = create(:name => name, :position => 0) do |r|
        r.builtin = builtin
      end
      raise "Unable to create the #{name} role." if role.new_record?
    end
    role
  end
end
