# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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

class WikiIntegrationTest < Redmine::IntegrationTest
  fixtures :projects,
           :users, :email_addresses,
           :roles,
           :members,
           :member_roles,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :wikis,
           :wiki_pages,
           :wiki_contents

  def test_updating_a_renamed_page
    log_user('jsmith', 'jsmith')

    get '/projects/ecookbook/wiki'
    assert_response :success

    get '/projects/ecookbook/wiki/Wiki/edit'
    assert_response :success

    # this update should not end up with a loss of content
    put(
      '/projects/ecookbook/wiki/Wiki',
      :params => {
        :content => {
          :text => "# Wiki\r\n\r\ncontent",
          :comments => ""
        },
      :wiki_page => {:parent_id => ""}
      }
    )
    assert_redirected_to "/projects/ecookbook/wiki/Wiki"
    follow_redirect!
    assert_select 'div', /content/
    assert content = WikiContent.last

    # Let's assume somebody else, or the same user in another tab, renames the
    # page while it is being edited.
    post(
      '/projects/ecookbook/wiki/Wiki/rename',
      :params => {
        :wiki_page => {:title => "NewTitle"}
      }
    )
    assert_redirected_to "/projects/ecookbook/wiki/NewTitle"

    # this update should not end up with a loss of content
    put(
      '/projects/ecookbook/wiki/Wiki',
      :params => {
        :content => {
          :version => content.version,
          :text => "# Wiki\r\n\r\nnew content",
          :comments => ""
        },
      :wiki_page => {:parent_id => ""}
      }
    )
    assert_redirected_to "/projects/ecookbook/wiki/NewTitle"
    follow_redirect!
    assert_select 'div', /new content/
  end
end
