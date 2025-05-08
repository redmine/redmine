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

class MemberRole < ApplicationRecord
  belongs_to :member
  belongs_to :role

  after_create :add_role_to_group_users, :add_role_to_subprojects
  after_destroy :remove_member_if_empty

  after_destroy :remove_inherited_roles

  validates_presence_of :role
  validate :validate_role_member

  def validate_role_member
    errors.add :role_id, :invalid unless role&.member?
  end

  def inherited?
    !inherited_from.nil?
  end

  # Returns the MemberRole from which self was inherited, or nil
  def inherited_from_member_role
    MemberRole.find_by_id(inherited_from) if inherited_from
  end

  # Destroys the MemberRole without destroying its Member if it doesn't have
  # any other roles
  def destroy_without_member_removal
    @member_removal = false
    destroy
  end

  private

  def remove_member_if_empty
    if @member_removal != false && member.roles.reload.empty?
      member.destroy
    end
  end

  def add_role_to_group_users
    return if inherited? || !member.principal.is_a?(Group)

    member.principal.users.ids.each do |user_id|
      user_member = Member.find_or_initialize_by(:project_id => member.project_id, :user_id => user_id)
      user_member.member_roles << MemberRole.new(:role_id => role_id, :inherited_from => id)
      user_member.save!
    end
  end

  def add_role_to_subprojects
    return if member.project.leaf?

    member.project.children.where(:inherit_members => true).ids.each do |subproject_id|
      child_member = Member.find_or_initialize_by(:project_id => subproject_id, :user_id => member.user_id)
      child_member.member_roles << MemberRole.new(:role => role, :inherited_from => id)
      child_member.save!
    end
  end

  def remove_inherited_roles
    MemberRole.where(:inherited_from => id).destroy_all
  end
end
