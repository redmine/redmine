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

class Reaction < ApplicationRecord
  belongs_to :reactable, polymorphic: true
  belongs_to :user

  validates :reactable_type, inclusion: { in: Redmine::Reaction::REACTABLE_TYPES }

  scope :by, ->(user) { where(user: user) }
  scope :for_reactable, ->(reactable) { where(reactable: reactable) }
  scope :visible, ->(user) { where(user: User.visible(user)) }

  # Represents reaction details for a reactable object
  Detail = Struct.new(
    # Users who reacted and are visible to the target user
    :visible_users,
    # Reaction of the target user
    :user_reaction
  ) do
    def initialize(visible_users: [], user_reaction: nil)
      super
    end

    def reaction_count = visible_users.size
  end

  def self.build_detail_map_for(reactables, user)
    reactions = visible(user)
                  .for_reactable(reactables)
                  .preload(:user)
                  .select(:id, :reactable_id, :user_id)
                  .order(id: :desc)

    reactions.each_with_object({}) do |reaction, m|
      m[reaction.reactable_id] ||= Detail.new

      m[reaction.reactable_id].then do |detail|
        detail.visible_users << reaction.user
        detail.user_reaction = reaction if reaction.user == user
      end
    end
  end
end
