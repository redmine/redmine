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

class Token < ActiveRecord::Base
  belongs_to :user
  validates_uniqueness_of :value

  before_create :delete_previous_tokens, :generate_new_token

  cattr_accessor :validity_time
  self.validity_time = 1.day

  class << self
    attr_reader :actions

    def add_action(name, options)
      options.assert_valid_keys(:max_instances, :validity_time)
      @actions ||= {}
      @actions[name.to_s] = options
    end
  end

  add_action :api,       max_instances: 1,  validity_time: nil
  add_action :autologin, max_instances: 10, validity_time: Proc.new { Setting.autologin.to_i.days }
  add_action :feeds,     max_instances: 1,  validity_time: nil
  add_action :recovery,  max_instances: 1,  validity_time: Proc.new { Token.validity_time }
  add_action :register,  max_instances: 1,  validity_time: Proc.new { Token.validity_time }
  add_action :session,   max_instances: 10, validity_time: nil

  def generate_new_token
    self.value = Token.generate_token_value
  end

  # Return true if token has expired
  def expired?
    validity_time = self.class.invalid_when_created_before(action)
    validity_time.present? && created_on < validity_time
  end

  def max_instances
    Token.actions.has_key?(action) ? Token.actions[action][:max_instances] : 1
  end

  def self.invalid_when_created_before(action = nil)
    if Token.actions.has_key?(action)
      validity_time = Token.actions[action][:validity_time]
      validity_time = validity_time.call(action) if validity_time.respond_to? :call
    else
      validity_time = self.validity_time
    end

    if validity_time
      Time.now - validity_time
    end
  end

  # Delete all expired tokens
  def self.destroy_expired
    t = Token.arel_table

    # Unknown actions have default validity_time
    condition = t[:action].not_in(self.actions.keys).and(t[:created_on].lt(invalid_when_created_before))

    self.actions.each do |action, options|
      validity_time = invalid_when_created_before(action)

      # Do not delete tokens, which don't become invalid
      next if validity_time.nil?

      condition = condition.or(
        t[:action].eq(action).and(t[:created_on].lt(validity_time))
      )
    end

    Token.where(condition).delete_all
  end

  # Returns the active user who owns the key for the given action
  def self.find_active_user(action, key, validity_days=nil)
    user = find_user(action, key, validity_days)
    if user && user.active?
      user
    end
  end

  # Returns the user who owns the key for the given action
  def self.find_user(action, key, validity_days=nil)
    token = find_token(action, key, validity_days)
    if token
      token.user
    end
  end

  # Returns the token for action and key with an optional
  # validity duration (in number of days)
  def self.find_token(action, key, validity_days=nil)
    action = action.to_s
    key = key.to_s
    return nil unless action.present? && /\A[a-z0-9]+\z/i.match?(key)

    token = Token.find_by(:action => action, :value => key)
    if token && (token.action == action) && (token.value == key) && token.user
      if validity_days.nil? || (token.created_on > validity_days.days.ago)
        token
      end
    end
  end

  def self.generate_token_value
    Redmine::Utils.random_hex(20)
  end

  private

  # Removes obsolete tokens (same user and action)
  def delete_previous_tokens
    if user
      scope = Token.where(:user_id => user.id, :action => action)
      if max_instances > 1
        ids = scope.order(:updated_on => :desc).offset(max_instances - 1).ids
        if ids.any?
          Token.delete(ids)
        end
      else
        scope.delete_all
      end
    end
  end
end
