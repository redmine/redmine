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
  REPOSITORY_PATH = Rails.root.join('tmp/test/git_repository').to_s
  REPOSITORY_PATH.tr!('/', "\\") if Redmine::Platform.mswin?

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

  if repository_configured?('git')
    def test_revisions_page_renders_revision_graph_as_svg
      skip "SCM command is unavailable" unless Repository::Git.scm_available

      git_repository =
        Repository::Git.create(
          :project => @project,
          :identifier => 'graph-test',
          :url => REPOSITORY_PATH,
          :path_encoding => 'ISO-8859-1'
        )
      assert git_repository
      git_repository.fetch_changesets
      revision = git_repository.changesets.order(committed_on: :desc, id: :desc).first&.revision
      assert revision.present?

      log_user('admin', 'admin')

      visit("/projects/#{@project.identifier}/repository/graph-test/revisions")

      assert_selector 'div.revision-graph svg'
      assert_selector 'div.revision-graph svg path'
      assert_selector 'div.revision-graph svg circle'
      assert_selector "div.revision-graph svg a[href*='/revisions/#{revision}']"

      assert_selector(
        :xpath,
        "//div[contains(@class,'revision-graph')]/*[local-name()='svg' and namespace-uri()='http://www.w3.org/2000/svg']"
      )
    end
  end
end
