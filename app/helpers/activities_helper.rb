# encoding: utf-8
#
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

module ActivitiesHelper
  def sort_activity_events(events)
    events_by_group = events.group_by(&:event_group)
    sorted_events = []
    events.sort {|x, y| y.event_datetime <=> x.event_datetime}.each do |event|
      if group_events = events_by_group.delete(event.event_group)
        group_events.sort {|x, y| y.event_datetime <=> x.event_datetime}.each_with_index do |e, i|
          sorted_events << [e, i > 0]
        end
      end
    end
    sorted_events
  end
end
