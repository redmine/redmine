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

class Principal < ActiveRecord::Base
  self.table_name = "#{table_name_prefix}users#{table_name_suffix}"

  # Account statuses
  STATUS_ANONYMOUS  = 0
  STATUS_ACTIVE     = 1
  STATUS_REGISTERED = 2
  STATUS_LOCKED     = 3

  has_many :members, :foreign_key => 'user_id', :dependent => :destroy
  has_many :memberships,
           lambda {preload(:project, :roles).
                   joins(:project).
                   where("#{Project.table_name}.status<>#{Project::STATUS_ARCHIVED}").
                   order("#{Project.table_name}.name")},
           :class_name => 'Member',
           :foreign_key => 'user_id'
  has_many :projects, :through => :memberships
  has_many :issue_categories, :foreign_key => 'assigned_to_id', :dependent => :nullify

  # Groups and active users
  scope :active, lambda { where(:status => STATUS_ACTIVE) }

  scope :visible, lambda {|*args|
    user = args.first || User.current

    if user.admin?
      all
    else
      view_all_active = false
      if user.memberships.to_a.any?
        view_all_active = user.memberships.any? {|m| m.roles.any? {|r| r.users_visibility == 'all'}}
      else
        view_all_active = user.builtin_role.users_visibility == 'all'
      end
  
      if view_all_active
        active
      else
        # self and members of visible projects
        active.where("#{table_name}.id = ? OR #{table_name}.id IN (SELECT user_id FROM #{Member.table_name} WHERE project_id IN (?))",
          user.id, user.visible_project_ids
        )
      end
    end
  }

  scope :like, lambda {|q|
    q = q.to_s
    if q.blank?
      where({})
    else
      pattern = "%#{q}%"
      sql = %w(login firstname lastname).map {|column| "LOWER(#{table_name}.#{column}) LIKE LOWER(:p)"}.join(" OR ")
      sql << " OR #{table_name}.id IN (SELECT user_id FROM #{EmailAddress.table_name} WHERE LOWER(address) LIKE LOWER(:p))"
      params = {:p => pattern}
      if q =~ /^(.+)\s+(.+)$/
        a, b = "#{$1}%", "#{$2}%"
        sql << " OR (LOWER(#{table_name}.firstname) LIKE LOWER(:a) AND LOWER(#{table_name}.lastname) LIKE LOWER(:b))"
        sql << " OR (LOWER(#{table_name}.firstname) LIKE LOWER(:b) AND LOWER(#{table_name}.lastname) LIKE LOWER(:a))"
        params.merge!(:a => a, :b => b)
      end
      where(sql, params)
    end
  }

  # Principals that are members of a collection of projects
  scope :member_of, lambda {|projects|
    projects = [projects] if projects.is_a?(Project)
    if projects.blank?
      where("1=0")
    else
      ids = projects.map(&:id)
      active.where("#{Principal.table_name}.id IN (SELECT DISTINCT user_id FROM #{Member.table_name} WHERE project_id IN (?))", ids)
    end
  }
  # Principals that are not members of projects
  scope :not_member_of, lambda {|projects|
    projects = [projects] unless projects.is_a?(Array)
    if projects.empty?
      where("1=0")
    else
      ids = projects.map(&:id)
      where("#{Principal.table_name}.id NOT IN (SELECT DISTINCT user_id FROM #{Member.table_name} WHERE project_id IN (?))", ids)
    end
  }
  scope :sorted, lambda { order(*Principal.fields_for_order_statement)}

  before_create :set_default_empty_values

  def name(formatter = nil)
    to_s
  end

  def mail=(*args)
    nil
  end

  def mail
    nil
  end

  def visible?(user=User.current)
    Principal.visible(user).where(:id => id).first == self
  end

  # Return true if the principal is a member of project
  def member_of?(project)
    projects.to_a.include?(project)
  end

  def <=>(principal)
    if principal.nil?
      -1
    elsif self.class.name == principal.class.name
      self.to_s.downcase <=> principal.to_s.downcase
    else
      # groups after users
      principal.class.name <=> self.class.name
    end
  end

  # Returns an array of fields names than can be used to make an order statement for principals.
  # Users are sorted before Groups.
  # Examples:
  def self.fields_for_order_statement(table=nil)
    table ||= table_name
    columns = ['type DESC'] + (User.name_formatter[:order] - ['id']) + ['lastname', 'id']
    columns.uniq.map {|field| "#{table}.#{field}"}
  end

  protected

  # Make sure we don't try to insert NULL values (see #4632)
  def set_default_empty_values
    self.login ||= ''
    self.hashed_password ||= ''
    self.firstname ||= ''
    self.lastname ||= ''
    true
  end
end

require_dependency "user"
require_dependency "group"
