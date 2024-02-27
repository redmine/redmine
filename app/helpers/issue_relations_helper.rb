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

module IssueRelationsHelper
  def collection_for_relation_type_select
    values = IssueRelation::TYPES
    values.keys.sort_by{|k| values[k][:order]}.collect{|k| [l(values[k][:name]), k]}
  end

  def relation_error_messages(relations)
    messages = {}
    relations.each do |item|
      item.errors.full_messages.each do |message|
        messages[message] ||= []
        messages[message] << item
      end
    end

    messages.map do |message, items|
      ids = items.filter_map(&:issue_to_id)
      if ids.empty?
        message
      else
        "#{message}: ##{ids.join(', ')}"
      end
    end
  end
end
