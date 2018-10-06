# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

  class_attribute :valid_statuses

  has_many :members, :foreign_key => 'user_id', :dependent => :destroy
  has_many :memberships,
           lambda {joins(:project).where.not(:projects => {:status => Project::STATUS_ARCHIVED})},
           :class_name => 'Member',
           :foreign_key => 'user_id'
  has_many :projects, :through => :memberships
  has_many :issue_categories, :foreign_key => 'assigned_to_id', :dependent => :nullify

  validate :validate_status

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
      sql = "LOWER(#{table_name}.login) LIKE LOWER(:p)"
      sql << " OR #{table_name}.id IN (SELECT user_id FROM #{EmailAddress.table_name} WHERE LOWER(address) LIKE LOWER(:p))"
      params = {:p => pattern}

      tokens = q.split(/\s+/).reject(&:blank?).map { |token| "%#{token}%" }
      if tokens.present?
        sql << ' OR ('
        sql << tokens.map.with_index do |token, index|
          params.merge!(:"token_#{index}" => token)
          "(LOWER(#{table_name}.firstname) LIKE LOWER(:token_#{index}) OR LOWER(#{table_name}.lastname) LIKE LOWER(:token_#{index}))"
        end.join(' AND ')
        sql << ')'
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
      # include active and locked users
      where(:status => [STATUS_LOCKED, STATUS_ACTIVE]).
      where("#{Principal.table_name}.id IN (SELECT DISTINCT user_id FROM #{Member.table_name} WHERE project_id IN (?))", ids)
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
  before_destroy :nullify_projects_default_assigned_to

  def reload(*args)
    @project_ids = nil
    super
  end

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
    Principal.visible(user).find_by(:id => id) == self
  end

  # Returns true if the principal is a member of project
  def member_of?(project)
    project.is_a?(Project) && project_ids.include?(project.id)
  end

  # Returns an array of the project ids that the principal is a member of
  def project_ids
    @project_ids ||= super.freeze
  end

  def <=>(principal)
    if principal.nil?
      -1
    elsif self.class.name == principal.class.name
      self.to_s.casecmp(principal.to_s)
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

  # Returns the principal that matches the keyword among principals
  def self.detect_by_keyword(principals, keyword)
    keyword = keyword.to_s
    return nil if keyword.blank?

    principal = nil
    principal ||= principals.detect {|a| keyword.casecmp(a.login.to_s) == 0}
    principal ||= principals.detect {|a| keyword.casecmp(a.mail.to_s) == 0}

    if principal.nil? && keyword.match(/ /)
      firstname, lastname = *(keyword.split) # "First Last Throwaway"
      principal ||= principals.detect {|a|
                                 a.is_a?(User) &&
                                   firstname.casecmp(a.firstname.to_s) == 0 &&
                                   lastname.casecmp(a.lastname.to_s) == 0
                               }
    end
    if principal.nil?
      principal ||= principals.detect {|a| keyword.casecmp(a.name) == 0}
    end
    principal
  end

  def nullify_projects_default_assigned_to
    Project.where(default_assigned_to: self).update_all(default_assigned_to_id: nil)
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

  def validate_status
    if status_changed? && self.class.valid_statuses.present?
      unless self.class.valid_statuses.include?(status)
        errors.add :status, :invalid
      end
    end
  end
end

require_dependency "user"
require_dependency "group"
