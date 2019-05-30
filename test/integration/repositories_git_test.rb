# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class RepositoriesGitTest < Redmine::IntegrationTest
  fixtures :projects, :users, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH = Rails.root.join('tmp/test/git_repository').to_s
  REPOSITORY_PATH.gsub!(/\//, "\\") if Redmine::Platform.mswin?
  PRJ_ID     = 3
  NUM_REV = 28

  def setup
    User.current = nil
    @project    = Project.find(PRJ_ID)
    @repository = Repository::Git.create(
                      :project       => @project,
                      :url           => REPOSITORY_PATH,
                      :path_encoding => 'ISO-8859-1'
                      )
    assert @repository
  end

  if File.directory?(REPOSITORY_PATH)
    def test_index
      get '/projects/subproject1/repository/'
      assert_response :success
    end

    def test_diff_two_revs
      get "/projects/subproject1/repository/#{@repository.id}/diff?rev=61b685fbe&rev_to=2f9c0091"
      assert_response :success
    end

    def test_get_raw_diff_of_a_whole_revision
      @repository.fetch_changesets
      assert_equal NUM_REV, @repository.changesets.count

      get "/projects/subproject1/repository/#{@repository.id}/revisions/deff712f05a90d96edbd70facc47d944be5897e3/diff"
      assert_response :success

      assert a = css_select("a.diff").first
      assert_equal 'Unified diff', a.text
      get a['href']
      assert_response :success
      assert_match /\Acommit deff712f05a90d96edbd70facc47d944be5897e3/, response.body
    end

    def test_get_raw_diff_of_a_single_file_change
      @repository.fetch_changesets
      assert_equal NUM_REV, @repository.changesets.count

      get "/projects/subproject1/repository/#{@repository.id}/revisions/deff712f05a90d96edbd70facc47d944be5897e3/diff/sources/watchers_controller.rb"
      assert_response :success

      assert a = css_select("a.diff").first
      assert_equal 'Unified diff', a.text
      get a['href']
      assert_response :success
      assert_match /\Acommit deff712f05a90d96edbd70facc47d944be5897e3/, response.body
    end

    def test_get_diff_with_format_text_should_return_html
      @repository.fetch_changesets
      assert_equal NUM_REV, @repository.changesets.count

      get "/projects/subproject1/repository/#{@repository.id}/revisions/deff712f05a90d96edbd70facc47d944be5897e3/diff/sources/watchers_controller.rb", :params => { :format => 'txt' }
      assert_response :success

      assert a = css_select("a.diff").first
      assert_equal 'Unified diff', a.text
      get a['href']
      assert_response :success
      assert_match /\Acommit deff712f05a90d96edbd70facc47d944be5897e3/, response.body
    end

    def test_entry_txt_should_return_html
      @repository.fetch_changesets
      assert_equal NUM_REV, @repository.changesets.count

      get "/projects/subproject1/repository/#{@repository.id}/revisions/deff712f05a90d96edbd70facc47d944be5897e3/entry/new_file.txt"
      assert_response :success

      assert l1      = css_select("#L1").first
      assert l1_code = css_select(l1, "td.line-code").first
      assert_match 'This is a brand new file', l1_code.text
    end
  else
    puts "Git test repository NOT FOUND. Skipping integration tests !!!"
    def test_fake; assert true end
  end
end
