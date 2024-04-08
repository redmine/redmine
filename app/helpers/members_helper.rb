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

module MembersHelper
  def render_principals_for_new_members(project, limit=100)
    scope = Principal.active.visible.sorted.not_member_of(project).like(params[:q])
    principal_count = scope.count
    principal_pages = Redmine::Pagination::Paginator.new principal_count, limit, params['page']
    principals = scope.offset(principal_pages.offset).limit(principal_pages.per_page).to_a
    s =
      content_tag(
        'div',
        content_tag(
          'div',
          principals_check_box_tags('membership[user_ids][]', principals),
          :id => 'principals'
        ),
        :class => 'objects-selection'
      )
    links =
      pagination_links_full(principal_pages,
                            principal_count,
                            :per_page_links => false) do |text, parameters, options|
        link_to(
          text,
          autocomplete_project_memberships_path(
            project,
            parameters.merge(:q => params[:q], :format => 'js')
          ),
          :remote => true)
      end
    s + content_tag('span', links, :class => 'pagination')
  end

  # Returns inheritance information for an inherited member role
  def render_role_inheritance(member, role)
    content = member.role_inheritance(role).filter_map do |h|
      if h.is_a?(Project)
        l(:label_inherited_from_parent_project)
      elsif h.is_a?(Group)
        l(:label_inherited_from_group, :name => h.name.to_s)
      end
    end.uniq

    if content.present?
      content_tag('em', content.join(", "), :class => "info")
    end
  end
end
