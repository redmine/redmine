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

class GroupBuiltin < Group
  validate :validate_uniqueness, :on => :create

  def validate_uniqueness
    errors.add :base, 'The builtin group already exists.' if self.class.exists?
  end

  def builtin?
    true
  end

  def destroy
    false
  end

  def user_added(user)
    raise 'Cannot add users to a builtin group'
  end

  class << self
    def load_instance
      return nil if self == GroupBuiltin
      instance = order('id').first || create_instance
    end

    def create_instance
      raise 'The builtin group already exists.' if exists?
      instance = new
      instance.lastname = name
      instance.save :validate => false
      raise 'Unable to create builtin group.' if instance.new_record?
      instance
    end
    private :create_instance
  end
end

require_dependency "group_anonymous"
require_dependency "group_non_member"
