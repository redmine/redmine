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

class Group < Principal
  include Redmine::SafeAttributes

  has_and_belongs_to_many :users,
                          :join_table   => "#{table_name_prefix}groups_users#{table_name_suffix}",
                          :after_add => :user_added,
                          :after_remove => :user_removed

  acts_as_customizable

  validates_presence_of :lastname
  validates_uniqueness_of :lastname, :case_sensitive => false
  validates_length_of :lastname, :maximum => 255

  self.valid_statuses = [STATUS_ACTIVE]

  before_destroy :remove_references_before_destroy

  scope :sorted, lambda {order(:type => :asc, :lastname => :asc)}
  scope :named, lambda {|arg| where("LOWER(#{table_name}.lastname) = LOWER(?)", arg.to_s.strip)}
  scope :givable, lambda {where(:type => 'Group')}

  safe_attributes(
    'name',
    'twofa_required',
    'user_ids',
    'custom_field_values',
    'custom_fields',
    :if => lambda {|group, user| user.admin? && !group.builtin?})

  def to_s
    name.to_s
  end

  def name
    lastname
  end

  def name=(arg)
    self.lastname = arg
  end

  def builtin_type
    nil
  end

  # Return true if the group is a builtin group
  def builtin?
    false
  end

  # Returns true if the group can be given to a user
  def givable?
    !builtin?
  end

  def css_classes
    'group'
  end

  def user_added(user)
    members.preload(:member_roles).each do |member|
      next if member.project_id.nil?
      # skip if the group is a member without roles in the project
      next if member.member_roles.empty?

      user_member =
        Member.find_or_initialize_by(:project_id => member.project_id, :user_id => user.id)
      user_member.member_roles <<
        member.member_roles.pluck(:id, :role_id).map do |id, role_id|
          MemberRole.new(:role_id => role_id, :inherited_from => id)
        end
      user_member.save!
    end
  end

  def user_removed(user)
    MemberRole.
      joins(:member).
      where("#{Member.table_name}.user_id = ? AND #{MemberRole.table_name}.inherited_from IN (?)", user.id, MemberRole.select(:id).where(:member => members)).
      destroy_all
  end

  def self.human_attribute_name(attribute_key_name, *args)
    attr_name = attribute_key_name.to_s
    if attr_name == 'lastname'
      attr_name = "name"
    end
    super(attr_name, *args)
  end

  def self.anonymous
    GroupAnonymous.load_instance
  end

  def self.non_member
    GroupNonMember.load_instance
  end

  private

  # Removes references that are not handled by associations
  def remove_references_before_destroy
    return if self.id.nil?

    Issue.where(['assigned_to_id = ?', id]).update_all('assigned_to_id = NULL')
    Watcher.where('user_id = ?', id).delete_all
  end
end
