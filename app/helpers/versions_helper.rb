# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

module VersionsHelper

  def version_anchor(version)
    if @project == version.project
      anchor version.name
    else
      anchor "#{version.project.try(:identifier)}-#{version.name}"
    end
  end

  STATUS_BY_CRITERIAS = %w(tracker status priority author assigned_to category)

  def render_issue_status_by(version, criteria)
    criteria = 'tracker' unless STATUS_BY_CRITERIAS.include?(criteria)

    h = Hash.new {|k,v| k[v] = [0, 0]}
    begin
      # Total issue count
      Issue.where(:fixed_version_id => version.id).group(criteria).count.each {|c,s| h[c][0] = s}
      # Open issues count
      Issue.open.where(:fixed_version_id => version.id).group(criteria).count.each {|c,s| h[c][1] = s}
    rescue ActiveRecord::RecordNotFound
    # When grouping by an association, Rails throws this exception if there's no result (bug)
    end
    # Sort with nil keys in last position
    counts = h.keys.sort {|a,b| a.nil? ? 1 : (b.nil? ? -1 : a <=> b)}.collect {|k| {:group => k, :total => h[k][0], :open => h[k][1], :closed => (h[k][0] - h[k][1])}}
    max = counts.collect {|c| c[:total]}.max

    render :partial => 'issue_counts', :locals => {:version => version, :criteria => criteria, :counts => counts, :max => max}
  end

  def status_by_options_for_select(value)
    options_for_select(STATUS_BY_CRITERIAS.collect {|criteria| [l("field_#{criteria}".to_sym), criteria]}, value)
  end
end
