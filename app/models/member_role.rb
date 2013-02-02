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

class MemberRole < ActiveRecord::Base
  belongs_to :member
  belongs_to :role

  after_destroy :remove_member_if_empty

  after_create :add_role_to_group_users, :add_role_to_subprojects
  after_destroy :remove_inherited_roles

  validates_presence_of :role
  validate :validate_role_member

  def validate_role_member
    errors.add :role_id, :invalid if role && !role.member?
  end

  def inherited?
    !inherited_from.nil?
  end

  private

  def remove_member_if_empty
    if member.roles.empty?
      member.destroy
    end
  end

  def add_role_to_group_users
    if member.principal.is_a?(Group) && !inherited?
      member.principal.users.each do |user|
        user_member = Member.find_or_new(member.project_id, user.id)
        user_member.member_roles << MemberRole.new(:role => role, :inherited_from => id)
        user_member.save!
      end
    end
  end

  def add_role_to_subprojects
    member.project.children.each do |subproject|
      if subproject.inherit_members?
        child_member = Member.find_or_new(subproject.id, member.user_id)
        child_member.member_roles << MemberRole.new(:role => role, :inherited_from => id)
        child_member.save!
      end
    end
  end

  def remove_inherited_roles
    MemberRole.where(:inherited_from => id).all.group_by(&:member).each do |member, member_roles|
      member_roles.each(&:destroy)
    end
  end
end
