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

class EmailAddress < ActiveRecord::Base
  belongs_to :user
  attr_protected :id

  after_update :destroy_tokens
  after_destroy :destroy_tokens

  validates_presence_of :address
  validates_format_of :address, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i, :allow_blank => true
  validates_length_of :address, :maximum => User::MAIL_LENGTH_LIMIT, :allow_nil => true
  validates_uniqueness_of :address, :case_sensitive => false,
    :if => Proc.new {|email| email.address_changed? && email.address.present?}

  def address=(arg)
    write_attribute(:address, arg.to_s.strip)
  end

  def destroy
    if is_default?
      false
    else
      super
    end
  end

  private

  # Delete all outstanding password reset tokens on email change.
  # This helps to keep the account secure in case the associated email account
  # was compromised.
  def destroy_tokens
    if address_changed? || destroyed?
      tokens = ['recovery']
      Token.where(:user_id => user_id, :action => tokens).delete_all
    end
  end
end
