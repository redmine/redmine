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

require_relative '../application_system_test_case'

class RepositoriesTest < ApplicationSystemTestCase
  def setup
    @project = Project.find(1)
    @repository = Repository::Subversion.create(:project => @project,
                                                :url => self.class.subversion_repository_url)
    assert @repository
  end

  if repository_configured?('subversion')
    def test_revision_diff_for_javascript_file_should_render_layout
      log_user('admin', 'admin')

      visit('projects/ecookbook/repository')
      click_link('Revision 16', match: :first)

      click_link('diff')

      # Assert page is rendered using base layout
      assert page.has_text?("eCookbook")
      assert page.has_css?("div[id=main-menu]")
      assert page.has_css?("a.administration")
    end
  end
end
