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
  class ProjectJumpBox
    def initialize(user)
      @user = user
      @pref_project_ids = {}
    end

    def recent_projects_count
      @user.pref.recently_used_projects
    end

    def recently_used_projects
      project_ids = recently_used_project_ids
      Project.where(id: project_ids).
        visible.
        index_by(&:id).
        values_at(*project_ids). # sort according to stored order
        compact
    end

    def bookmarked_projects
      Project.where(id: bookmarked_project_ids).visible.to_a
    end

    def project_used(project)
      return if project.blank? || project.id.blank?

      id_array = recently_used_project_ids
      id_array.reject!{|i| i == project.id}
      # we dont want bookmarks in the recently used list:
      id_array.unshift(project.id) unless bookmark?(project)
      self.recently_used_project_ids = id_array[0, recent_projects_count]
    end

    def bookmark_project(project)
      self.recently_used_project_ids = recently_used_project_ids.reject{|id| id == project.id}
      self.bookmarked_project_ids = (bookmarked_project_ids << project.id)
    end

    def delete_project_bookmark(project)
      self.bookmarked_project_ids = bookmarked_project_ids.reject do |id|
        id == project.id
      end
    end

    def bookmark?(project)
      project && project.id && bookmarked_project_ids.include?(project.id)
    end

    private

    def bookmarked_project_ids
      pref_project_ids :bookmarked_project_ids
    end

    def bookmarked_project_ids=(new_ids)
      set_pref_project_ids :bookmarked_project_ids, new_ids
    end

    def recently_used_project_ids
      pref_project_ids(:recently_used_project_ids)[0, recent_projects_count]
    end

    def recently_used_project_ids=(new_ids)
      set_pref_project_ids :recently_used_project_ids, new_ids
    end

    def pref_project_ids(key)
      return [] unless @user.logged?

      @pref_project_ids[key] ||= (@user.pref[key] || '').split(',').map(&:to_i)
    end

    def set_pref_project_ids(key, new_values)
      return nil unless @user.logged?

      old_value = @user.pref[key]
      new_value = new_values.uniq.join(',')
      if old_value != new_value
        @user.pref[key] = new_value
        @user.pref.save
      end
      @pref_project_ids.delete key
      nil
    end
  end
end
