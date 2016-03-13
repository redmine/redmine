# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class Member < ActiveRecord::Base
  belongs_to :user
  belongs_to :principal, :foreign_key => 'user_id'
  has_many :member_roles, :dependent => :destroy
  has_many :roles, lambda {uniq}, :through => :member_roles
  belongs_to :project

  validates_presence_of :principal, :project
  validates_uniqueness_of :user_id, :scope => :project_id
  validate :validate_role
  attr_protected :id

  before_destroy :set_issue_category_nil

  scope :active, lambda { joins(:principal).where(:users => {:status => Principal::STATUS_ACTIVE})}

  alias :base_reload :reload
  def reload(*args)
    @managed_roles = nil
    base_reload(*args)
  end

  def role
  end

  def role=
  end

  def name
    self.user.name
  end

  alias :base_role_ids= :role_ids=
  def role_ids=(arg)
    ids = (arg || []).collect(&:to_i) - [0]
    # Keep inherited roles
    ids += member_roles.select {|mr| !mr.inherited_from.nil?}.collect(&:role_id)

    new_role_ids = ids - role_ids
    # Add new roles
    new_role_ids.each {|id| member_roles << MemberRole.new(:role_id => id, :member => self) }
    # Remove roles (Rails' #role_ids= will not trigger MemberRole#on_destroy)
    member_roles_to_destroy = member_roles.select {|mr| !ids.include?(mr.role_id)}
    if member_roles_to_destroy.any?
      member_roles_to_destroy.each(&:destroy)
    end
  end

  def <=>(member)
    a, b = roles.sort, member.roles.sort
    if a == b
      if principal
        principal <=> member.principal
      else
        1
      end
    elsif a.any?
      b.any? ? a <=> b : -1
    else
      1
    end
  end

  # Set member role ids ignoring any change to roles that
  # user is not allowed to manage
  def set_editable_role_ids(ids, user=User.current)
    ids = (ids || []).collect(&:to_i) - [0]
    editable_role_ids = user.managed_roles(project).map(&:id)
    untouched_role_ids = self.role_ids - editable_role_ids
    touched_role_ids = ids & editable_role_ids
    self.role_ids = untouched_role_ids + touched_role_ids
  end

  # Returns true if one of the member roles is inherited
  def any_inherited_role?
    member_roles.any? {|mr| mr.inherited_from}
  end

  # Returns true if the member has the role and if it's inherited
  def has_inherited_role?(role)
    member_roles.any? {|mr| mr.role_id == role.id && mr.inherited_from.present?}
  end

  # Returns true if the member's role is editable by user
  def role_editable?(role, user=User.current)
    if has_inherited_role?(role)
      false
    else
      user.managed_roles(project).include?(role)
    end
  end

  # Returns true if the member is deletable by user
  def deletable?(user=User.current)
    if any_inherited_role?
      false
    else
      roles & user.managed_roles(project) == roles
    end
  end

  # Destroys the member
  def destroy
    member_roles.reload.each(&:destroy_without_member_removal)
    super
  end

  # Returns true if the member is user or is a group
  # that includes user
  def include?(user)
    if principal.is_a?(Group)
      !user.nil? && user.groups.include?(principal)
    else
      self.user == user
    end
  end

  def set_issue_category_nil
    if user_id && project_id
      # remove category based auto assignments for this member
      IssueCategory.where(["project_id = ? AND assigned_to_id = ?", project_id, user_id]).
        update_all("assigned_to_id = NULL")
    end
  end

  # Returns the roles that the member is allowed to manage
  # in the project the member belongs to
  def managed_roles
    @managed_roles ||= begin
      if principal.try(:admin?)
        Role.givable.to_a
      else
        members_management_roles = roles.select do |role|
          role.has_permission?(:manage_members)
        end
        if members_management_roles.empty?
          []
        elsif members_management_roles.any?(&:all_roles_managed?)
          Role.givable.to_a
        else
          members_management_roles.map(&:managed_roles).reduce(&:|)
        end
      end
    end
  end

  # Creates memberships for principal with the attributes
  # * project_ids : one or more project ids
  # * role_ids : ids of the roles to give to each membership
  #
  # Example:
  #   Member.create_principal_memberships(user, :project_ids => [2, 5], :role_ids => [1, 3]
  def self.create_principal_memberships(principal, attributes)
    members = []
    if attributes
      project_ids = Array.wrap(attributes[:project_ids] || attributes[:project_id])
      role_ids = attributes[:role_ids]
      project_ids.each do |project_id|
        members << Member.new(:principal => principal, :role_ids => role_ids, :project_id => project_id)
      end
      principal.members << members
    end
    members
  end

  # Finds or initilizes a Member for the given project and principal
  def self.find_or_new(project, principal)
    project_id = project.is_a?(Project) ? project.id : project
    principal_id = principal.is_a?(Principal) ? principal.id : principal

    member = Member.find_by_project_id_and_user_id(project_id, principal_id)
    member ||= Member.new(:project_id => project_id, :user_id => principal_id)
    member
  end

  protected

  def validate_role
    errors.add_on_empty :role if member_roles.empty? && roles.empty?
  end
end
