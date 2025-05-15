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

module Redmine
  module Reaction
    # Types of objects that can have reactions
    REACTABLE_TYPES = %w(Journal Issue Message News Comment)

    # Returns true if the user can view the reaction of the object
    def self.visible?(object, user = User.current)
      Setting.reactions_enabled? && object.visible?(user)
    end

    # Returns true if the user can add/remove a reaction to/from the object
    def self.editable?(object, user = User.current)
      user.logged? && visible?(object, user) && object&.project&.active?
    end

    module Reactable
      extend ActiveSupport::Concern

      included do
        has_many :reactions, as: :reactable, dependent: :delete_all

        attr_writer :reaction_detail
      end

      class_methods do
        # Preloads reaction details for a collection of objects
        def preload_reaction_details(objects)
          return unless Setting.reactions_enabled?

          details = ::Reaction.build_detail_map_for(objects, User.current)

          objects.each do |object|
            object.reaction_detail = details.fetch(object.id) { ::Reaction::Detail.new }
          end
        end
      end

      def reaction_detail
        # Loads and returns reaction details if they are not already loaded.
        # This is intended for cases where explicit preloading is unnecessary,
        # such as retrieving reactions for a single issue on its detail page.
        load_reaction_detail unless defined?(@reaction_detail)
        @reaction_detail
      end

      def load_reaction_detail
        self.class.preload_reaction_details([self])
      end
    end
  end
end
