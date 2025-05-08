# frozen_string_literal: false

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

require_relative 'test_case'
require 'tmpdir'

class RedminePmTest::RepositoryGitTest < RedminePmTest::TestCase
  GIT_BIN = Redmine::Configuration['scm_git_command'] || "git"

  def test_anonymous_read_on_public_repo_with_permission_should_succeed
    assert_success "ls-remote", git_url
  end

  def test_anonymous_read_on_public_repo_without_permission_should_fail
    Role.anonymous.remove_permission! :browse_repository
    assert_failure "ls-remote", git_url
  end

  def test_invalid_credentials_should_fail
    Project.find(1).update_attribute :is_public, false
    with_credentials "dlopper", "foo" do
      assert_success "ls-remote", git_url
    end
    with_credentials "dlopper", "wrong" do
      assert_failure "ls-remote", git_url
    end
  end

  def test_clone
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        assert_success "clone", git_url
      end
    end
  end

  def test_write_commands
    Role.find(2).add_permission! :commit_access
    filename = random_filename

    Dir.mktmpdir do |dir|
      assert_success "clone", git_url, dir
      Dir.chdir(dir) do
        f = File.new(File.join(dir, filename), "w")
        f.write "test file content"
        f.close

        with_credentials "dlopper", "foo" do
          assert_success "add", filename
          assert_success "commit -a --message Committing_a_file"
          assert_success "push", git_url, "--all"
        end
      end
    end

    Dir.mktmpdir do |dir|
      assert_success "clone", git_url, dir
      Dir.chdir(dir) do
        assert File.exist?(File.join(dir, "#{filename}"))
      end
    end
  end

  protected

  def execute(*args)
    a = [GIT_BIN]
    super a, *args
  end

  def git_url(path=nil)
    host = ENV['REDMINE_TEST_DAV_SERVER'] || '127.0.0.1'
    credentials = nil
    if username && password
      credentials = "#{username}:#{password}"
    end
    url = "http://#{credentials}@#{host}/git/ecookbook"
    url << "/#{path}" if path
    url
  end
end
