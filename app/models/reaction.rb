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

  # Represents reaction details for a reactable object
  Detail = Struct.new(
    # Total number of reactions
    :reaction_count,
    # Users who reacted and are visible to the target user
    :visible_users,
    # Reaction of the target user
    :user_reaction
  ) do
    def initialize(reaction_count: 0, visible_users: [], user_reaction: nil)
      super
    end
  end

  def self.build_detail_map_for(reactables, user)
    reactions = preload(:user)
                  .for_reactable(reactables)
                  .select(:id, :reactable_id, :user_id)
                  .order(id: :desc)

    # Prepare IDs of users who reacted and are visible to the user
    visible_user_ids = User.visible(user)
                         .joins(:reactions)
                         .where(reactions: for_reactable(reactables))
                         .pluck(:id).to_set

    reactions.each_with_object({}) do |reaction, m|
      m[reaction.reactable_id] ||= Detail.new

      m[reaction.reactable_id].then do |detail|
        detail.reaction_count += 1
        detail.visible_users << reaction.user if visible_user_ids.include?(reaction.user.id)
        detail.user_reaction = reaction if reaction.user == user
      end
    end
  end
end
