# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

module PrincipalMembershipsHelper
  def render_principal_memberships(principal)
    render :partial => 'principal_memberships/index', :locals => {:principal => principal}
  end

  def call_table_header_hook(principal)
    if principal.is_a?(Group)
      call_hook :view_groups_memberships_table_header, :group => principal
    else
      call_hook :view_users_memberships_table_header, :user => principal
    end
  end

  def call_table_row_hook(principal, membership)
    if principal.is_a?(Group)
      call_hook :view_groups_memberships_table_row, :group => principal, :membership => membership
    else
      call_hook :view_users_memberships_table_row, :user => principal, :membership => membership
    end
  end

  def new_principal_membership_path(principal, *args)
    if principal.is_a?(Group)
      new_group_membership_path(principal, *args)
    else
      new_user_membership_path(principal, *args)
    end
  end

  def edit_principal_membership_path(principal, *args)
    if principal.is_a?(Group)
      edit_group_membership_path(principal, *args)
    else
      edit_user_membership_path(principal, *args)
    end
  end

  def principal_membership_path(principal, membership, *args)
    if principal.is_a?(Group)
      group_membership_path(principal, membership, *args)
    else
      user_membership_path(principal, membership, *args)
    end
  end
end
