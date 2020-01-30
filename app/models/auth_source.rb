# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

# Generic exception for when the AuthSource can not be reached
# (eg. can not connect to the LDAP)
class AuthSourceException < StandardError; end
class AuthSourceTimeoutException < AuthSourceException; end

class AuthSource < ActiveRecord::Base
  include Redmine::SafeAttributes
  include Redmine::SubclassFactory
  include Redmine::Ciphering

  has_many :users

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 60

  safe_attributes(
    'name',
    'host',
    'port',
    'account',
    'account_password',
    'base_dn',
    'attr_login',
    'attr_firstname',
    'attr_lastname',
    'attr_mail',
    'onthefly_register',
    'tls',
    'verify_peer',
    'filter',
    'timeout')

  def authenticate(login, password)
  end

  def test_connection
  end

  def auth_method_name
    "Abstract"
  end

  def account_password
    read_ciphered_attribute(:account_password)
  end

  def account_password=(arg)
    write_ciphered_attribute(:account_password, arg)
  end

  def searchable?
    false
  end

  def self.search(q)
    results = []
    AuthSource.all.each do |source|
      begin
        if source.searchable?
          results += source.search(q)
        end
      rescue AuthSourceException => e
        logger.error "Error while searching users in #{source.name}: #{e.message}"
      end
    end
    results
  end

  def allow_password_changes?
    self.class.allow_password_changes?
  end

  # Does this auth source backend allow password changes?
  def self.allow_password_changes?
    false
  end

  # Try to authenticate a user not yet registered against available sources
  def self.authenticate(login, password)
    AuthSource.where(:onthefly_register => true).each do |source|
      begin
        logger.debug "Authenticating '#{login}' against '#{source.name}'" if logger && logger.debug?
        attrs = source.authenticate(login, password)
      rescue => e
        logger.error "Error during authentication: #{e.message}"
        attrs = nil
      end
      return attrs if attrs
    end
    return nil
  end
end
