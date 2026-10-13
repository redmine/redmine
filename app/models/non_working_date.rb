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

class NonWorkingDate < ApplicationRecord
  include Redmine::SafeAttributes

  class Current < ActiveSupport::CurrentAttributes
    attribute :names_by_date, :sorted_dates
  end

  after_save {self.class.clear_dates_cache}
  after_destroy {self.class.clear_dates_cache}
  after_rollback {self.class.clear_dates_cache}

  validates_presence_of :date
  validates_uniqueness_of :date
  validates :date, :date => true
  validates_length_of :name, :maximum => 255

  scope :sorted, lambda {order(:date)}
  scope :in_year, lambda {|year| where(:date => Date.new(year, 1, 1)..Date.new(year, 12, 31))}

  safe_attributes 'date', 'name'

  # Returns a Hash of the registered dates and their names, ordered by date.
  # The result is cached for the duration of the current request.
  def self.names_by_date
    Current.names_by_date ||= order(:date).pluck(:date, :name).to_h
  end

  # Returns the name registered for the given date
  def self.name_for(date)
    names_by_date[date].presence
  end

  # Returns the registered dates as a sorted Array.
  # The result is cached for the duration of the current request.
  def self.sorted_dates
    Current.sorted_dates ||= names_by_date.keys
  end

  def self.clear_dates_cache
    Current.reset
  end

  # Returns the years that have at least one non-working date
  def self.years
    pluck(:date).map(&:year).uniq.sort
  end
end
