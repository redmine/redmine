# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class AnonymousUser < User
  validate :validate_anonymous_uniqueness, :on => :create

  self.valid_statuses = [STATUS_ANONYMOUS]

  def validate_anonymous_uniqueness
    # There should be only one AnonymousUser in the database
    errors.add :base, 'An anonymous user already exists.' if AnonymousUser.unscoped.exists?
  end

  def available_custom_fields
    []
  end

  # Overrides a few properties
  def logged?; false end
  def admin; false end
  def name(*args); I18n.t(:label_user_anonymous) end
  def mail=(*args); nil end
  def mail; nil end
  def time_zone; nil end
  def atom_key; nil end

  def pref
    UserPreference.new(:user => self)
  end

  # Returns the user's bult-in role
  def builtin_role
    @builtin_role ||= Role.anonymous
  end

  def membership(*args)
    nil
  end

  def member_of?(*args)
    false
  end

  # Anonymous user can not be destroyed
  def destroy
    false
  end

  protected

  def instantiate_email_address
  end
end
