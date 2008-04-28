# redMine - project management software
# Copyright (C) 2006  Jean-Philippe Lang
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
  belongs_to :project
  belongs_to :role
  belongs_to :principal, :polymorphic => true
  belongs_to :user, :foreign_key => 'principal_id'

  attr_protected :inherited_from
  
  validates_presence_of :project, :role, :principal
  validates_uniqueness_of :principal_id, :scope => [:project_id, :principal_type, :inherited_from]
  
  def validate
    errors.add :role_id, :activerecord_error_invalid if role && !role.member?
  end
  
  def name
    principal.name
  end
  
  # Groups sorted by role then users sorted by role
  def <=>(member)
    principal_type == member.principal_type ?
      (role == member.role ? principal <=> member.principal : role <=> member.role) :
      (principal_type <=> member.principal_type)
  end
  
  def to_s
    principal.to_s
  end
  
  def after_save
    # Update memberships based on group inheritance
    if principal.is_a? Group
      Member.delete_all "inherited_from = #{id}"
      principal.users.each do |user|
        Member.create! :project => project, :role => role, :principal => user, :inherited_from => id
      end
    end
  end
  
  def before_destroy
    # Remove inherited memberships
    Member.delete_all "inherited_from = #{id}"
    
    # Remove category based auto assignments for this member
    if principal.is_a? User
      IssueCategory.update_all "assigned_to_id = NULL", ["project_id = ? AND assigned_to_id = ?", project_id, principal_id]
    end
  end
end
