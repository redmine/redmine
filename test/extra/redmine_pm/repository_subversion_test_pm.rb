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

class RedminePmTest::RepositorySubversionTest < RedminePmTest::TestCase
  SVN_BIN = Redmine::Configuration['scm_subversion_command'] || "svn"

  def test_anonymous_read_on_public_repo_with_permission_should_succeed
    assert_success "ls", svn_url
  end

  def test_anonymous_read_on_public_repo_with_anonymous_group_permission_should_succeed
    Role.anonymous.remove_permission! :browse_repository
    Member.create!(:project_id => 1, :principal => Group.anonymous, :role_ids => [2])
    assert_success "ls", svn_url
  end

  def test_anonymous_read_on_public_repo_without_permission_should_fail
    Role.anonymous.remove_permission! :browse_repository
    assert_failure "ls", svn_url
  end

  def test_anonymous_read_on_public_project_with_module_disabled_should_fail
    Project.find(1).disable_module! :repository
    assert_failure "ls", svn_url
  end

  def test_anonymous_read_on_private_repo_should_fail
    Project.find(1).update_attribute :is_public, false
    assert_failure "ls", svn_url
  end

  def test_anonymous_commit_on_public_repo_should_fail
    Role.anonymous.add_permission! :commit_access
    assert_failure "mkdir --message Creating_a_directory", svn_url(random_filename)
  end

  def test_anonymous_commit_on_private_repo_should_fail
    Role.anonymous.add_permission! :commit_access
    Project.find(1).update_attribute :is_public, false
    assert_failure "mkdir --message Creating_a_directory", svn_url(random_filename)
  end

  def test_non_member_read_on_public_repo_with_permission_should_succeed
    Role.anonymous.remove_permission! :browse_repository
    with_credentials "miscuser8", "foo" do
      assert_success "ls", svn_url
    end
  end

  def test_non_member_read_on_public_repo_with_non_member_group_permission_should_succeed
    Role.anonymous.remove_permission! :browse_repository
    Role.non_member.remove_permission! :browse_repository
    Member.create!(:project_id => 1, :principal => Group.non_member, :role_ids => [2])
    with_credentials "miscuser8", "foo" do
      assert_success "ls", svn_url
    end
  end

  def test_non_member_read_on_public_repo_without_permission_should_fail
    Role.anonymous.remove_permission! :browse_repository
    Role.non_member.remove_permission! :browse_repository
    with_credentials "miscuser8", "foo" do
      assert_failure "ls", svn_url
    end
  end

  def test_non_member_read_on_private_repo_should_fail
    Project.find(1).update_attribute :is_public, false
    with_credentials "miscuser8", "foo" do
      assert_failure "ls", svn_url
    end
  end

  def test_non_member_commit_on_public_repo_should_fail
    Role.non_member.add_permission! :commit_access
    assert_failure "mkdir --message Creating_a_directory", svn_url(random_filename)
  end

  def test_non_member_commit_on_private_repo_should_fail
    Role.non_member.add_permission! :commit_access
    Project.find(1).update_attribute :is_public, false
    assert_failure "mkdir --message Creating_a_directory", svn_url(random_filename)
  end

  def test_member_read_on_public_repo_with_permission_should_succeed
    Role.anonymous.remove_permission! :browse_repository
    Role.non_member.remove_permission! :browse_repository
    with_credentials "dlopper", "foo" do
      assert_success "ls", svn_url
    end
  end

  def test_member_read_on_public_repo_without_permission_should_fail
    Role.anonymous.remove_permission! :browse_repository
    Role.non_member.remove_permission! :browse_repository
    Role.find(2).remove_permission! :browse_repository
    with_credentials "dlopper", "foo" do
      assert_failure "ls", svn_url
    end
  end

  def test_member_read_on_private_repo_with_permission_should_succeed
    Project.find(1).update_attribute :is_public, false
    with_credentials "dlopper", "foo" do
      assert_success "ls", svn_url
    end
  end

  def test_member_read_on_private_repo_without_permission_should_fail
    Role.find(2).remove_permission! :browse_repository
    Project.find(1).update_attribute :is_public, false
    with_credentials "dlopper", "foo" do
      assert_failure "ls", svn_url
    end
  end

  def test_member_read_on_private_repo_with_module_disabled_should_fail
    Role.find(2).add_permission! :browse_repository
    Project.find(1).update_attribute :is_public, false
    Project.find(1).disable_module! :repository
    with_credentials "dlopper", "foo" do
      assert_failure "ls", svn_url
    end
  end

  def test_member_commit_on_public_repo_with_permission_should_succeed
    Role.find(2).add_permission! :commit_access
    with_credentials "dlopper", "foo" do
      assert_success "mkdir --message Creating_a_directory", svn_url(random_filename)
    end
  end

  def test_member_commit_on_public_repo_without_permission_should_fail
    Role.find(2).remove_permission! :commit_access
    with_credentials "dlopper", "foo" do
      assert_failure "mkdir --message Creating_a_directory", svn_url(random_filename)
    end
  end

  def test_member_commit_on_private_repo_with_permission_should_succeed
    Role.find(2).add_permission! :commit_access
    Project.find(1).update_attribute :is_public, false
    with_credentials "dlopper", "foo" do
      assert_success "mkdir --message Creating_a_directory", svn_url(random_filename)
    end
  end

  def test_member_commit_on_private_repo_without_permission_should_fail
    Role.find(2).remove_permission! :commit_access
    Project.find(1).update_attribute :is_public, false
    with_credentials "dlopper", "foo" do
      assert_failure "mkdir --message Creating_a_directory", svn_url(random_filename)
    end
  end

  def test_member_commit_on_private_repo_with_module_disabled_should_fail
    Role.find(2).add_permission! :commit_access
    Project.find(1).update_attribute :is_public, false
    Project.find(1).disable_module! :repository
    with_credentials "dlopper", "foo" do
      assert_failure "mkdir --message Creating_a_directory", svn_url(random_filename)
    end
  end

  def test_invalid_credentials_should_fail
    Project.find(1).update_attribute :is_public, false
    with_credentials "dlopper", "foo" do
      assert_success "ls", svn_url
    end
    with_credentials "dlopper", "wrong" do
      assert_failure "ls", svn_url
    end
  end

  def test_anonymous_read_should_fail_with_login_required
    assert_success "ls", svn_url
    with_settings :login_required => '1' do
      assert_failure "ls", svn_url
    end
  end

  def test_authenticated_read_should_succeed_with_login_required
    with_settings :login_required => '1' do
      with_credentials "miscuser8", "foo" do
        assert_success "ls", svn_url
      end
    end
  end

  def test_read_on_archived_projects_should_fail
    Project.find(1).update_attribute :status, Project::STATUS_ARCHIVED
    assert_failure "ls", svn_url
  end

  def test_read_on_archived_private_projects_should_fail
    Project.find(1).update_attribute :status, Project::STATUS_ARCHIVED
    Project.find(1).update_attribute :is_public, false
    with_credentials "dlopper", "foo" do
      assert_failure "ls", svn_url
    end
  end

  def test_read_on_closed_projects_should_succeed
    Project.find(1).update_attribute :status, Project::STATUS_CLOSED
    assert_success "ls", svn_url
  end

  def test_read_on_closed_private_projects_should_succeed
    Project.find(1).update_attribute :status, Project::STATUS_CLOSED
    Project.find(1).update_attribute :is_public, false
    with_credentials "dlopper", "foo" do
      assert_success "ls", svn_url
    end
  end

  def test_commit_on_closed_projects_should_fail
    Project.find(1).update_attribute :status, Project::STATUS_CLOSED
    Role.find(2).add_permission! :commit_access
    with_credentials "dlopper", "foo" do
      assert_failure "mkdir --message Creating_a_directory", svn_url(random_filename)
    end
  end

  def test_commit_on_closed_private_projects_should_fail
    Project.find(1).update_attribute :status, Project::STATUS_CLOSED
    Project.find(1).update_attribute :is_public, false
    Role.find(2).add_permission! :commit_access
    with_credentials "dlopper", "foo" do
      assert_failure "mkdir --message Creating_a_directory", svn_url(random_filename)
    end
  end

  if ldap_configured?
    def test_user_with_ldap_auth_source_should_authenticate_with_ldap_credentials
      ldap_user = User.new(:mail => 'example1@redmine.org', :firstname => 'LDAP', :lastname => 'user', :auth_source_id => 1)
      ldap_user.login = 'example1'
      ldap_user.save!

      with_settings :login_required => '1' do
        with_credentials "example1", "123456" do
          assert_success "ls", svn_url
        end
      end

      with_settings :login_required => '1' do
        with_credentials "example1", "wrong" do
          assert_failure "ls", svn_url
        end
      end
    end
  end

  def test_checkout
    Dir.mktmpdir do |dir|
      assert_success "checkout", svn_url, dir
    end
  end

  def test_read_commands
    assert_success "info", svn_url
    assert_success "ls", svn_url
    assert_success "log", svn_url
  end

  def test_write_commands
    Role.find(2).add_permission! :commit_access
    filename = random_filename

    Dir.mktmpdir do |dir|
      assert_success "checkout", svn_url, dir
      Dir.chdir(dir) do
        # creates a file in the working copy
        f = File.new(File.join(dir, filename), "w")
        f.write "test file content"
        f.close

        assert_success "add", filename
        with_credentials "dlopper", "foo" do
          assert_success "commit --message Committing_a_file"
          assert_success "copy   --message Copying_a_file", svn_url(filename), svn_url("#{filename}_copy")
          assert_success "delete --message Deleting_a_file", svn_url(filename)
          assert_success "mkdir  --message Creating_a_directory", svn_url("#{filename}_dir")
        end
        assert_success "update"

        # checks that the working copy was updated
        assert File.exist?(File.join(dir, "#{filename}_copy"))
        assert File.directory?(File.join(dir, "#{filename}_dir"))
      end
    end
  end

  def test_read_invalid_repo_should_fail
    assert_failure "ls", svn_url("invalid")
  end

  protected

  def execute(*args)
    a = [SVN_BIN, "--no-auth-cache --non-interactive"]
    a << "--username #{username}" if username
    a << "--password #{password}" if password

    super a, *args
  end

  def svn_url(path=nil)
    host = ENV['REDMINE_TEST_DAV_SERVER'] || '127.0.0.1'
    url = "http://#{host}/svn/ecookbook"
    url << "/#{path}" if path
    url
  end
end
