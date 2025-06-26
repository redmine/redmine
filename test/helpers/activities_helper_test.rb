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

require File.expand_path('../../test_helper', __FILE__)

class ActivitiesHelperTest < Redmine::HelperTest
  include ActivitiesHelper

  fixtures :projects, :members, :users

  class MockEvent
    attr_reader :event_datetime, :event_group, :name

    def initialize(group=nil)
      @@count ||= 0
      @name = "e#{@@count}"
      @event_datetime = Time.now + @@count.hours
      @event_group = group || self
      @@count += 1
    end

    def self.clear
      @@count = 0
    end
  end

  def setup
    super
    MockEvent.clear
  end

  def test_sort_activity_events_should_sort_by_datetime
    events = []
    events << MockEvent.new
    events << MockEvent.new
    events << MockEvent.new
    assert_equal(
      [
        ['e2', false],
        ['e1', false],
        ['e0', false]
      ],
      sort_activity_events(events).map {|event, grouped| [event.name, grouped]}
    )
  end

  def test_sort_activity_events_should_group_events
    events = []
    events << MockEvent.new
    events << MockEvent.new(events[0])
    events << MockEvent.new(events[0])
    assert_equal(
      [
        ['e2', false],
        ['e1', true],
        ['e0', true]
      ],
      sort_activity_events(events).map {|event, grouped| [event.name, grouped]}
    )
  end

  def test_sort_activity_events_with_group_not_in_set_should_group_events
    e = MockEvent.new
    events = []
    events << MockEvent.new(e)
    events << MockEvent.new(e)
    assert_equal(
      [
        ['e2', false],
        ['e1', true]
      ],
      sort_activity_events(events).map {|event, grouped| [event.name, grouped]}
    )
  end

  def test_sort_activity_events_should_sort_by_datetime_and_group
    events = []
    events << MockEvent.new
    events << MockEvent.new
    events << MockEvent.new
    events << MockEvent.new(events[1])
    events << MockEvent.new(events[2])
    events << MockEvent.new
    events << MockEvent.new(events[2])
    assert_equal(
      [
        ['e6', false],
        ['e4', true],
        ['e2', true],
        ['e5', false],
        ['e3', false],
        ['e1', true],
        ['e0', false]
      ],
      sort_activity_events(events).map {|event, grouped| [event.name, grouped]}
    )
  end

  def test_activity_authors_options_for_select_if_current_user_is_admin
    User.current = User.find(1)
    project = Project.find(1)

    options = [["<< #{l(:label_me)} >>", 1], ['Dave Lopper', 3], ['John Smith', 2], ['Redmine Admin', 1], ['User Misc', 8]]
    assert_equal(
      options_for_select(options, nil),
      activity_authors_options_for_select(project, nil))
  end

  def test_activity_authors_options_for_select_if_current_user_is_anonymous
    User.current = nil
    project = Project.find(1)

    options = [['Dave Lopper', 3], ['John Smith', 2]]
    assert_equal(
      options_for_select(options, nil),
      activity_authors_options_for_select(project, nil))
  end
end
