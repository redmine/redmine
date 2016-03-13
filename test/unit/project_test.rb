# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class ProjectTest < ActiveSupport::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :journals, :journal_details,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :custom_fields,
           :custom_fields_projects,
           :custom_fields_trackers,
           :custom_values,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :versions,
           :wikis, :wiki_pages, :wiki_contents, :wiki_content_versions,
           :groups_users,
           :boards, :messages,
           :repositories,
           :news, :comments,
           :documents,
           :workflows

  def setup
    @ecookbook = Project.find(1)
    @ecookbook_sub1 = Project.find(3)
    set_tmp_attachments_directory
    User.current = nil
  end

  def test_truth
    assert_kind_of Project, @ecookbook
    assert_equal "eCookbook", @ecookbook.name
  end

  def test_default_attributes
    with_settings :default_projects_public => '1' do
      assert_equal true, Project.new.is_public
      assert_equal false, Project.new(:is_public => false).is_public
    end

    with_settings :default_projects_public => '0' do
      assert_equal false, Project.new.is_public
      assert_equal true, Project.new(:is_public => true).is_public
    end

    with_settings :sequential_project_identifiers => '1' do
      assert !Project.new.identifier.blank?
      assert Project.new(:identifier => '').identifier.blank?
    end

    with_settings :sequential_project_identifiers => '0' do
      assert Project.new.identifier.blank?
      assert !Project.new(:identifier => 'test').blank?
    end

    with_settings :default_projects_modules => ['issue_tracking', 'repository'] do
      assert_equal ['issue_tracking', 'repository'], Project.new.enabled_module_names
    end
  end

  def test_default_trackers_should_match_default_tracker_ids_setting
    with_settings :default_projects_tracker_ids => ['1', '3'] do
      assert_equal Tracker.find(1, 3).sort, Project.new.trackers.sort
    end
  end

  def test_default_trackers_should_be_all_trackers_with_blank_setting
    with_settings :default_projects_tracker_ids => nil do
      assert_equal Tracker.all.sort, Project.new.trackers.sort
    end
  end

  def test_default_trackers_should_be_empty_with_empty_setting
    with_settings :default_projects_tracker_ids => [] do
      assert_equal [], Project.new.trackers
    end
  end

  def test_default_trackers_should_not_replace_initialized_trackers
    with_settings :default_projects_tracker_ids => ['1', '3'] do
      assert_equal Tracker.find(1, 2).sort, Project.new(:tracker_ids => [1, 2]).trackers.sort
    end
  end

  def test_update
    assert_equal "eCookbook", @ecookbook.name
    @ecookbook.name = "eCook"
    assert @ecookbook.save, @ecookbook.errors.full_messages.join("; ")
    @ecookbook.reload
    assert_equal "eCook", @ecookbook.name
  end

  def test_validate_identifier
    to_test = {"abc" => true,
               "ab12" => true,
               "ab-12" => true,
               "ab_12" => true,
               "12" => false,
               "new" => false}

    to_test.each do |identifier, valid|
      p = Project.new
      p.identifier = identifier
      p.valid?
      if valid
        assert p.errors['identifier'].blank?, "identifier #{identifier} was not valid"
      else
        assert p.errors['identifier'].present?, "identifier #{identifier} was valid"
      end
    end
  end

  def test_identifier_should_not_be_frozen_for_a_new_project
    assert_equal false, Project.new.identifier_frozen?
  end

  def test_identifier_should_not_be_frozen_for_a_saved_project_with_blank_identifier
    Project.where(:id => 1).update_all(["identifier = ''"])
    assert_equal false, Project.find(1).identifier_frozen?
  end

  def test_identifier_should_be_frozen_for_a_saved_project_with_valid_identifier
    assert_equal true, Project.find(1).identifier_frozen?
  end

  def test_to_param_should_be_nil_for_new_records
    project = Project.new
    project.identifier = "foo"
    assert_nil project.to_param
  end

  def test_members_should_be_active_users
    Project.all.each do |project|
      assert_nil project.members.detect {|m| !(m.user.is_a?(User) && m.user.active?) }
    end
  end

  def test_users_should_be_active_users
    Project.all.each do |project|
      assert_nil project.users.detect {|u| !(u.is_a?(User) && u.active?) }
    end
  end

  def test_open_scope_on_issues_association
    assert_kind_of Issue, Project.find(1).issues.open.first
  end

  def test_archive
    user = @ecookbook.members.first.user
    @ecookbook.archive
    @ecookbook.reload

    assert !@ecookbook.active?
    assert @ecookbook.archived?
    assert !user.projects.include?(@ecookbook)
    # Subproject are also archived
    assert !@ecookbook.children.empty?
    assert @ecookbook.descendants.active.empty?
  end

  def test_archive_should_fail_if_versions_are_used_by_non_descendant_projects
    # Assign an issue of a project to a version of a child project
    Issue.find(4).update_attribute :fixed_version_id, 4

    assert_no_difference "Project.where(:status => Project::STATUS_ARCHIVED).count" do
      assert_equal false, @ecookbook.archive
    end
    @ecookbook.reload
    assert @ecookbook.active?
  end

  def test_unarchive
    user = @ecookbook.members.first.user
    @ecookbook.archive
    # A subproject of an archived project can not be unarchived
    assert !@ecookbook_sub1.unarchive

    # Unarchive project
    assert @ecookbook.unarchive
    @ecookbook.reload
    assert @ecookbook.active?
    assert !@ecookbook.archived?
    assert user.projects.include?(@ecookbook)
    # Subproject can now be unarchived
    @ecookbook_sub1.reload
    assert @ecookbook_sub1.unarchive
  end

  def test_destroy
    # 2 active members
    assert_equal 2, @ecookbook.members.size
    # and 1 is locked
    assert_equal 3, Member.where(:project_id => @ecookbook.id).count
    # some boards
    assert @ecookbook.boards.any?

    @ecookbook.destroy
    # make sure that the project non longer exists
    assert_raise(ActiveRecord::RecordNotFound) { Project.find(@ecookbook.id) }
    # make sure related data was removed
    assert_nil Member.where(:project_id => @ecookbook.id).first
    assert_nil Board.where(:project_id => @ecookbook.id).first
    assert_nil Issue.where(:project_id => @ecookbook.id).first
  end

  def test_destroy_should_destroy_subtasks
    issues = (0..2).to_a.map {Issue.create!(:project_id => 1, :tracker_id => 1, :author_id => 1, :subject => 'test')}
    issues[0].update_attribute :parent_issue_id, issues[1].id
    issues[2].update_attribute :parent_issue_id, issues[1].id
    assert_equal 2, issues[1].children.count

    assert_nothing_raised do
      Project.find(1).destroy
    end
    assert_equal 0, Issue.where(:id => issues.map(&:id)).count
  end

  def test_destroying_root_projects_should_clear_data
    Project.roots.each do |root|
      root.destroy
    end

    assert_equal 0, Project.count, "Projects were not deleted: #{Project.all.inspect}"
    assert_equal 0, Member.count, "Members were not deleted: #{Member.all.inspect}"
    assert_equal 0, MemberRole.count
    assert_equal 0, Issue.count
    assert_equal 0, Journal.count
    assert_equal 0, JournalDetail.count
    assert_equal 0, Attachment.count, "Attachments were not deleted: #{Attachment.all.inspect}"
    assert_equal 0, EnabledModule.count
    assert_equal 0, IssueCategory.count
    assert_equal 0, IssueRelation.count
    assert_equal 0, Board.count
    assert_equal 0, Message.count
    assert_equal 0, News.count
    assert_equal 0, Query.where("project_id IS NOT NULL").count
    assert_equal 0, Repository.count
    assert_equal 0, Changeset.count
    assert_equal 0, Change.count
    assert_equal 0, Comment.count
    assert_equal 0, TimeEntry.count
    assert_equal 0, Version.count
    assert_equal 0, Watcher.count
    assert_equal 0, Wiki.count
    assert_equal 0, WikiPage.count
    assert_equal 0, WikiContent.count
    assert_equal 0, WikiContent::Version.count
    assert_equal 0, Project.connection.select_all("SELECT * FROM projects_trackers").count
    assert_equal 0, Project.connection.select_all("SELECT * FROM custom_fields_projects").count
    assert_equal 0, CustomValue.where(:customized_type => ['Project', 'Issue', 'TimeEntry', 'Version']).count
  end

  def test_destroy_should_delete_time_entries_custom_values
    project = Project.generate!
    time_entry = TimeEntry.generate!(:project => project, :custom_field_values => {10 => '1'})

    assert_difference 'CustomValue.where(:customized_type => "TimeEntry").count', -1 do
      assert project.destroy
    end
  end

  def test_move_an_orphan_project_to_a_root_project
    sub = Project.find(2)
    sub.set_parent! @ecookbook
    assert_equal @ecookbook.id, sub.parent.id
    @ecookbook.reload
    assert_equal 4, @ecookbook.children.size
  end

  def test_move_an_orphan_project_to_a_subproject
    sub = Project.find(2)
    assert sub.set_parent!(@ecookbook_sub1)
  end

  def test_move_a_root_project_to_a_project
    sub = @ecookbook
    assert sub.set_parent!(Project.find(2))
  end

  def test_should_not_move_a_project_to_its_children
    sub = @ecookbook
    assert !(sub.set_parent!(Project.find(3)))
  end

  def test_set_parent_should_add_roots_in_alphabetical_order
    ProjectCustomField.delete_all
    Project.delete_all
    Project.create!(:name => 'Project C', :identifier => 'project-c').set_parent!(nil)
    Project.create!(:name => 'Project B', :identifier => 'project-b').set_parent!(nil)
    Project.create!(:name => 'Project D', :identifier => 'project-d').set_parent!(nil)
    Project.create!(:name => 'Project A', :identifier => 'project-a').set_parent!(nil)

    assert_equal 4, Project.count
    assert_equal Project.all.sort_by(&:name), Project.all.sort_by(&:lft)
  end

  def test_set_parent_should_add_children_in_alphabetical_order
    ProjectCustomField.delete_all
    parent = Project.create!(:name => 'Parent', :identifier => 'parent')
    Project.create!(:name => 'Project C', :identifier => 'project-c').set_parent!(parent)
    Project.create!(:name => 'Project B', :identifier => 'project-b').set_parent!(parent)
    Project.create!(:name => 'Project D', :identifier => 'project-d').set_parent!(parent)
    Project.create!(:name => 'Project A', :identifier => 'project-a').set_parent!(parent)

    parent.reload
    assert_equal 4, parent.children.size
    assert_equal parent.children.sort_by(&:name), parent.children.to_a
  end

  def test_set_parent_should_update_issue_fixed_version_associations_when_a_fixed_version_is_moved_out_of_the_hierarchy
    # Parent issue with a hierarchy project's fixed version
    parent_issue = Issue.find(1)
    parent_issue.update_attribute(:fixed_version_id, 4)
    parent_issue.reload
    assert_equal 4, parent_issue.fixed_version_id

    # Should keep fixed versions for the issues
    issue_with_local_fixed_version = Issue.find(5)
    issue_with_local_fixed_version.update_attribute(:fixed_version_id, 4)
    issue_with_local_fixed_version.reload
    assert_equal 4, issue_with_local_fixed_version.fixed_version_id

    # Local issue with hierarchy fixed_version
    issue_with_hierarchy_fixed_version = Issue.find(13)
    issue_with_hierarchy_fixed_version.update_attribute(:fixed_version_id, 6)
    issue_with_hierarchy_fixed_version.reload
    assert_equal 6, issue_with_hierarchy_fixed_version.fixed_version_id

    # Move project out of the issue's hierarchy
    moved_project = Project.find(3)
    moved_project.set_parent!(Project.find(2))
    parent_issue.reload
    issue_with_local_fixed_version.reload
    issue_with_hierarchy_fixed_version.reload

    assert_equal 4, issue_with_local_fixed_version.fixed_version_id, "Fixed version was not keep on an issue local to the moved project"
    assert_equal nil, issue_with_hierarchy_fixed_version.fixed_version_id, "Fixed version is still set after moving the Project out of the hierarchy where the version is defined in"
    assert_equal nil, parent_issue.fixed_version_id, "Fixed version is still set after moving the Version out of the hierarchy for the issue."
  end

  def test_parent
    p = Project.find(6).parent
    assert p.is_a?(Project)
    assert_equal 5, p.id
  end

  def test_ancestors
    a = Project.find(6).ancestors
    assert a.first.is_a?(Project)
    assert_equal [1, 5], a.collect(&:id)
  end

  def test_root
    r = Project.find(6).root
    assert r.is_a?(Project)
    assert_equal 1, r.id
  end

  def test_children
    c = Project.find(1).children
    assert c.first.is_a?(Project)
    assert_equal [5, 3, 4], c.collect(&:id)
  end

  def test_descendants
    d = Project.find(1).descendants
    assert d.first.is_a?(Project)
    assert_equal [5, 6, 3, 4], d.collect(&:id)
  end

  def test_allowed_parents_should_be_empty_for_non_member_user
    Role.non_member.add_permission!(:add_project)
    user = User.find(9)
    assert user.memberships.empty?
    User.current = user
    assert Project.new.allowed_parents.compact.empty?
  end

  def test_allowed_parents_with_add_subprojects_permission
    Role.find(1).remove_permission!(:add_project)
    Role.find(1).add_permission!(:add_subprojects)
    User.current = User.find(2)
    # new project
    assert !Project.new.allowed_parents.include?(nil)
    assert Project.new.allowed_parents.include?(Project.find(1))
    # existing root project
    assert Project.find(1).allowed_parents.include?(nil)
    # existing child
    assert Project.find(3).allowed_parents.include?(Project.find(1))
    assert !Project.find(3).allowed_parents.include?(nil)
  end

  def test_allowed_parents_with_add_project_permission
    Role.find(1).add_permission!(:add_project)
    Role.find(1).remove_permission!(:add_subprojects)
    User.current = User.find(2)
    # new project
    assert Project.new.allowed_parents.include?(nil)
    assert !Project.new.allowed_parents.include?(Project.find(1))
    # existing root project
    assert Project.find(1).allowed_parents.include?(nil)
    # existing child
    assert Project.find(3).allowed_parents.include?(Project.find(1))
    assert Project.find(3).allowed_parents.include?(nil)
  end

  def test_allowed_parents_with_add_project_and_subprojects_permission
    Role.find(1).add_permission!(:add_project)
    Role.find(1).add_permission!(:add_subprojects)
    User.current = User.find(2)
    # new project
    assert Project.new.allowed_parents.include?(nil)
    assert Project.new.allowed_parents.include?(Project.find(1))
    # existing root project
    assert Project.find(1).allowed_parents.include?(nil)
    # existing child
    assert Project.find(3).allowed_parents.include?(Project.find(1))
    assert Project.find(3).allowed_parents.include?(nil)
  end

  def test_users_by_role
    users_by_role = Project.find(1).users_by_role
    assert_kind_of Hash, users_by_role
    role = Role.find(1)
    assert_kind_of Array, users_by_role[role]
    assert users_by_role[role].include?(User.find(2))
  end

  def test_rolled_up_trackers
    parent = Project.find(1)
    parent.trackers = Tracker.find([1,2])
    child = parent.children.find(3)

    assert_equal [1, 2], parent.tracker_ids
    assert_equal [2, 3], child.trackers.collect(&:id)

    assert_kind_of Tracker, parent.rolled_up_trackers.first
    assert_equal Tracker.find(1), parent.rolled_up_trackers.first

    assert_equal [1, 2, 3], parent.rolled_up_trackers.collect(&:id)
    assert_equal [2, 3], child.rolled_up_trackers.collect(&:id)
  end

  def test_rolled_up_trackers_should_ignore_archived_subprojects
    parent = Project.find(1)
    parent.trackers = Tracker.find([1,2])
    child = parent.children.find(3)
    child.trackers = Tracker.find([1,3])
    parent.children.each(&:archive)

    assert_equal [1,2], parent.rolled_up_trackers.collect(&:id)
  end

  test "#rolled_up_trackers should ignore projects with issue_tracking module disabled" do
    parent = Project.generate!
    parent.trackers = Tracker.find([1, 2])
    child = Project.generate_with_parent!(parent)
    child.trackers = Tracker.find([2, 3])

    assert_equal [1, 2, 3], parent.rolled_up_trackers.collect(&:id).sort

    assert child.disable_module!(:issue_tracking)
    parent.reload
    assert_equal [1, 2], parent.rolled_up_trackers.collect(&:id).sort
  end

  test "#rolled_up_versions should include the versions for the current project" do
    project = Project.generate!
    parent_version_1 = Version.generate!(:project => project)
    parent_version_2 = Version.generate!(:project => project)
    assert_equal [parent_version_1, parent_version_2].sort,
      project.rolled_up_versions.sort
  end

  test "#rolled_up_versions should include versions for a subproject" do
    project = Project.generate!
    parent_version_1 = Version.generate!(:project => project)
    parent_version_2 = Version.generate!(:project => project)
    subproject = Project.generate_with_parent!(project)
    subproject_version = Version.generate!(:project => subproject)

    assert_equal [parent_version_1, parent_version_2, subproject_version].sort,
      project.rolled_up_versions.sort
  end

  test "#rolled_up_versions should include versions for a sub-subproject" do
    project = Project.generate!
    parent_version_1 = Version.generate!(:project => project)
    parent_version_2 = Version.generate!(:project => project)
    subproject = Project.generate_with_parent!(project)
    sub_subproject = Project.generate_with_parent!(subproject)
    sub_subproject_version = Version.generate!(:project => sub_subproject)
    project.reload

    assert_equal [parent_version_1, parent_version_2, sub_subproject_version].sort,
      project.rolled_up_versions.sort
  end

  test "#rolled_up_versions should only check active projects" do
    project = Project.generate!
    parent_version_1 = Version.generate!(:project => project)
    parent_version_2 = Version.generate!(:project => project)
    subproject = Project.generate_with_parent!(project)
    subproject_version = Version.generate!(:project => subproject)
    assert subproject.archive
    project.reload

    assert !subproject.active?
    assert_equal [parent_version_1, parent_version_2].sort,
      project.rolled_up_versions.sort
  end

  def test_shared_versions_none_sharing
    p = Project.find(5)
    v = Version.create!(:name => 'none_sharing', :project => p, :sharing => 'none')
    assert p.shared_versions.include?(v)
    assert !p.children.first.shared_versions.include?(v)
    assert !p.root.shared_versions.include?(v)
    assert !p.siblings.first.shared_versions.include?(v)
    assert !p.root.siblings.first.shared_versions.include?(v)
  end

  def test_shared_versions_descendants_sharing
    p = Project.find(5)
    v = Version.create!(:name => 'descendants_sharing', :project => p, :sharing => 'descendants')
    assert p.shared_versions.include?(v)
    assert p.children.first.shared_versions.include?(v)
    assert !p.root.shared_versions.include?(v)
    assert !p.siblings.first.shared_versions.include?(v)
    assert !p.root.siblings.first.shared_versions.include?(v)
  end

  def test_shared_versions_hierarchy_sharing
    p = Project.find(5)
    v = Version.create!(:name => 'hierarchy_sharing', :project => p, :sharing => 'hierarchy')
    assert p.shared_versions.include?(v)
    assert p.children.first.shared_versions.include?(v)
    assert p.root.shared_versions.include?(v)
    assert !p.siblings.first.shared_versions.include?(v)
    assert !p.root.siblings.first.shared_versions.include?(v)
  end

  def test_shared_versions_tree_sharing
    p = Project.find(5)
    v = Version.create!(:name => 'tree_sharing', :project => p, :sharing => 'tree')
    assert p.shared_versions.include?(v)
    assert p.children.first.shared_versions.include?(v)
    assert p.root.shared_versions.include?(v)
    assert p.siblings.first.shared_versions.include?(v)
    assert !p.root.siblings.first.shared_versions.include?(v)
  end

  def test_shared_versions_system_sharing
    p = Project.find(5)
    v = Version.create!(:name => 'system_sharing', :project => p, :sharing => 'system')
    assert p.shared_versions.include?(v)
    assert p.children.first.shared_versions.include?(v)
    assert p.root.shared_versions.include?(v)
    assert p.siblings.first.shared_versions.include?(v)
    assert p.root.siblings.first.shared_versions.include?(v)
  end

  def test_shared_versions
    parent = Project.find(1)
    child = parent.children.find(3)
    private_child = parent.children.find(5)

    assert_equal [1,2,3], parent.version_ids.sort
    assert_equal [4], child.version_ids
    assert_equal [6], private_child.version_ids
    assert_equal [7], Version.where(:sharing => 'system').collect(&:id)

    assert_equal 6, parent.shared_versions.size
    parent.shared_versions.each do |version|
      assert_kind_of Version, version
    end

    assert_equal [1,2,3,4,6,7], parent.shared_versions.collect(&:id).sort
  end

  def test_shared_versions_should_ignore_archived_subprojects
    parent = Project.find(1)
    child = parent.children.find(3)
    child.archive
    parent.reload

    assert_equal [1,2,3], parent.version_ids.sort
    assert_equal [4], child.version_ids
    assert !parent.shared_versions.collect(&:id).include?(4)
  end

  def test_shared_versions_visible_to_user
    user = User.find(3)
    parent = Project.find(1)
    child = parent.children.find(5)

    assert_equal [1,2,3], parent.version_ids.sort
    assert_equal [6], child.version_ids

    versions = parent.shared_versions.visible(user)

    assert_equal 4, versions.size
    versions.each do |version|
      assert_kind_of Version, version
    end

    assert !versions.collect(&:id).include?(6)
  end

  def test_shared_versions_for_new_project_should_include_system_shared_versions
    p = Project.find(5)
    v = Version.create!(:name => 'system_sharing', :project => p, :sharing => 'system')

    assert_include v, Project.new.shared_versions
  end

  def test_next_identifier
    ProjectCustomField.delete_all
    Project.create!(:name => 'last', :identifier => 'p2008040')
    assert_equal 'p2008041', Project.next_identifier
  end

  def test_next_identifier_first_project
    Project.delete_all
    assert_nil Project.next_identifier
  end

  def test_enabled_module_names
    with_settings :default_projects_modules => ['issue_tracking', 'repository'] do
      project = Project.new

      project.enabled_module_names = %w(issue_tracking news)
      assert_equal %w(issue_tracking news), project.enabled_module_names.sort
    end
  end

  def test_enabled_modules_names_with_nil_should_clear_modules
    p = Project.find(1)
    p.enabled_module_names = nil
    assert_equal [], p.enabled_modules
  end

  test "enabled_modules should define module by names and preserve ids" do
    @project = Project.find(1)
    # Remove one module
    modules = @project.enabled_modules.slice(0..-2)
    assert modules.any?
    assert_difference 'EnabledModule.count', -1 do
      @project.enabled_module_names = modules.collect(&:name)
    end
    @project.reload
    # Ids should be preserved
    assert_equal @project.enabled_module_ids.sort, modules.collect(&:id).sort
  end

  test "enabled_modules should enable a module" do
    @project = Project.find(1)
    @project.enabled_module_names = []
    @project.reload
    assert_equal [], @project.enabled_module_names
    #with string
    @project.enable_module!("issue_tracking")
    assert_equal ["issue_tracking"], @project.enabled_module_names
    #with symbol
    @project.enable_module!(:gantt)
    assert_equal ["issue_tracking", "gantt"], @project.enabled_module_names
    #don't add a module twice
    @project.enable_module!("issue_tracking")
    assert_equal ["issue_tracking", "gantt"], @project.enabled_module_names
  end

  test "enabled_modules should disable a module" do
    @project = Project.find(1)
    #with string
    assert @project.enabled_module_names.include?("issue_tracking")
    @project.disable_module!("issue_tracking")
    assert ! @project.reload.enabled_module_names.include?("issue_tracking")
    #with symbol
    assert @project.enabled_module_names.include?("gantt")
    @project.disable_module!(:gantt)
    assert ! @project.reload.enabled_module_names.include?("gantt")
    #with EnabledModule object
    first_module = @project.enabled_modules.first
    @project.disable_module!(first_module)
    assert ! @project.reload.enabled_module_names.include?(first_module.name)
  end

  def test_enabled_module_names_should_not_recreate_enabled_modules
    project = Project.find(1)
    # Remove one module
    modules = project.enabled_modules.slice(0..-2)
    assert modules.any?
    assert_difference 'EnabledModule.count', -1 do
      project.enabled_module_names = modules.collect(&:name)
    end
    project.reload
    # Ids should be preserved
    assert_equal project.enabled_module_ids.sort, modules.collect(&:id).sort
  end

  def test_copy_from_existing_project
    source_project = Project.find(1)
    copied_project = Project.copy_from(1)

    assert copied_project
    # Cleared attributes
    assert copied_project.id.blank?
    assert copied_project.name.blank?
    assert copied_project.identifier.blank?

    # Duplicated attributes
    assert_equal source_project.description, copied_project.description
    assert_equal source_project.trackers, copied_project.trackers

    # Default attributes
    assert_equal 1, copied_project.status
  end

  def test_copy_from_should_copy_enabled_modules
    source = Project.generate!
    source.enabled_module_names = %w(issue_tracking wiki)

    copy = Project.copy_from(source)
    copy.name = 'Copy'
    copy.identifier = 'copy'
    assert_difference 'EnabledModule.count', 2 do
      copy.save!
    end
    assert_equal 2, copy.reload.enabled_modules.count
    assert_equal 2, source.reload.enabled_modules.count
  end

  def test_activities_should_use_the_system_activities
    project = Project.find(1)
    assert_equal project.activities.to_a, TimeEntryActivity.where(:active => true).to_a
    assert_kind_of ActiveRecord::Relation, project.activities
  end


  def test_activities_should_use_the_project_specific_activities
    project = Project.find(1)
    overridden_activity = TimeEntryActivity.new({:name => "Project", :project => project})
    assert overridden_activity.save!

    assert project.activities.include?(overridden_activity), "Project specific Activity not found"
    assert_kind_of ActiveRecord::Relation, project.activities
  end

  def test_activities_should_not_include_the_inactive_project_specific_activities
    project = Project.find(1)
    overridden_activity = TimeEntryActivity.new({:name => "Project", :project => project, :parent => TimeEntryActivity.first, :active => false})
    assert overridden_activity.save!

    assert !project.activities.include?(overridden_activity), "Inactive Project specific Activity found"
  end

  def test_activities_should_not_include_project_specific_activities_from_other_projects
    project = Project.find(1)
    overridden_activity = TimeEntryActivity.new({:name => "Project", :project => Project.find(2)})
    assert overridden_activity.save!

    assert !project.activities.include?(overridden_activity), "Project specific Activity found on a different project"
  end

  def test_activities_should_handle_nils
    overridden_activity = TimeEntryActivity.new({:name => "Project", :project => Project.find(1), :parent => TimeEntryActivity.first})
    TimeEntryActivity.delete_all

    # No activities
    project = Project.find(1)
    assert project.activities.empty?

    # No system, one overridden
    assert overridden_activity.save!
    project.reload
    assert_equal [overridden_activity], project.activities
  end

  def test_activities_should_override_system_activities_with_project_activities
    project = Project.find(1)
    parent_activity = TimeEntryActivity.first
    overridden_activity = TimeEntryActivity.new({:name => "Project", :project => project, :parent => parent_activity})
    assert overridden_activity.save!

    assert project.activities.include?(overridden_activity), "Project specific Activity not found"
    assert !project.activities.include?(parent_activity), "System Activity found when it should have been overridden"
  end

  def test_activities_should_include_inactive_activities_if_specified
    project = Project.find(1)
    overridden_activity = TimeEntryActivity.new({:name => "Project", :project => project, :parent => TimeEntryActivity.first, :active => false})
    assert overridden_activity.save!

    assert project.activities(true).include?(overridden_activity), "Inactive Project specific Activity not found"
  end

  test 'activities should not include active System activities if the project has an override that is inactive' do
    project = Project.find(1)
    system_activity = TimeEntryActivity.find_by_name('Design')
    assert system_activity.active?
    overridden_activity = TimeEntryActivity.create!(:name => "Project", :project => project, :parent => system_activity, :active => false)
    assert overridden_activity.save!

    assert !project.activities.include?(overridden_activity), "Inactive Project specific Activity not found"
    assert !project.activities.include?(system_activity), "System activity found when the project has an inactive override"
  end

  def test_close_completed_versions
    Version.update_all("status = 'open'")
    project = Project.find(1)
    assert_not_nil project.versions.detect {|v| v.completed? && v.status == 'open'}
    assert_not_nil project.versions.detect {|v| !v.completed? && v.status == 'open'}
    project.close_completed_versions
    project.reload
    assert_nil project.versions.detect {|v| v.completed? && v.status != 'closed'}
    assert_not_nil project.versions.detect {|v| !v.completed? && v.status == 'open'}
  end

  test "#start_date should be nil if there are no issues on the project" do
    project = Project.generate!
    assert_nil project.start_date
  end

  test "#start_date should be nil when issues have no start date" do
    project = Project.generate!
    project.trackers << Tracker.generate!
    early = 7.days.ago.to_date
    Issue.generate!(:project => project, :start_date => nil)

    assert_nil project.start_date
  end

  test "#start_date should be the earliest start date of it's issues" do
    project = Project.generate!
    project.trackers << Tracker.generate!
    early = 7.days.ago.to_date
    Issue.generate!(:project => project, :start_date => Date.today)
    Issue.generate!(:project => project, :start_date => early)

    assert_equal early, project.start_date
  end

  test "#due_date should be nil if there are no issues on the project" do
    project = Project.generate!
    assert_nil project.due_date
  end

  test "#due_date should be nil if there are no issues with due dates" do
    project = Project.generate!
    project.trackers << Tracker.generate!
    Issue.generate!(:project => project, :due_date => nil)

    assert_nil project.due_date
  end

  test "#due_date should be the latest due date of it's issues" do
    project = Project.generate!
    project.trackers << Tracker.generate!
    future = 7.days.from_now.to_date
    Issue.generate!(:project => project, :due_date => future)
    Issue.generate!(:project => project, :due_date => Date.today)

    assert_equal future, project.due_date
  end

  test "#due_date should be the latest due date of it's versions" do
    project = Project.generate!
    future = 7.days.from_now.to_date
    project.versions << Version.generate!(:effective_date => future)
    project.versions << Version.generate!(:effective_date => Date.today)

    assert_equal future, project.due_date
  end

  test "#due_date should pick the latest date from it's issues and versions" do
    project = Project.generate!
    project.trackers << Tracker.generate!
    future = 7.days.from_now.to_date
    far_future = 14.days.from_now.to_date
    Issue.generate!(:project => project, :due_date => far_future)
    project.versions << Version.generate!(:effective_date => future)

    assert_equal far_future, project.due_date
  end

  test "#completed_percent with no versions should be 100" do
    project = Project.generate!
    assert_equal 100, project.completed_percent
  end

  test "#completed_percent with versions should return 0 if the versions have no issues" do
    project = Project.generate!
    Version.generate!(:project => project)
    Version.generate!(:project => project)

    assert_equal 0, project.completed_percent
  end

  test "#completed_percent with versions should return 100 if the version has only closed issues" do
    project = Project.generate!
    project.trackers << Tracker.generate!
    v1 = Version.generate!(:project => project)
    Issue.generate!(:project => project, :status => IssueStatus.find_by_name('Closed'), :fixed_version => v1)
    v2 = Version.generate!(:project => project)
    Issue.generate!(:project => project, :status => IssueStatus.find_by_name('Closed'), :fixed_version => v2)

    assert_equal 100, project.completed_percent
  end

  test "#completed_percent with versions should return the averaged completed percent of the versions (not weighted)" do
    project = Project.generate!
    project.trackers << Tracker.generate!
    v1 = Version.generate!(:project => project)
    Issue.generate!(:project => project, :status => IssueStatus.find_by_name('New'), :estimated_hours => 10, :done_ratio => 50, :fixed_version => v1)
    v2 = Version.generate!(:project => project)
    Issue.generate!(:project => project, :status => IssueStatus.find_by_name('New'), :estimated_hours => 10, :done_ratio => 50, :fixed_version => v2)

    assert_equal 50, project.completed_percent
  end

  test "#notified_users" do
    project = Project.generate!
    role = Role.generate!

    user_with_membership_notification = User.generate!(:mail_notification => 'selected')
    Member.create!(:project => project, :roles => [role], :principal => user_with_membership_notification, :mail_notification => true)

    all_events_user = User.generate!(:mail_notification => 'all')
    Member.create!(:project => project, :roles => [role], :principal => all_events_user)

    no_events_user = User.generate!(:mail_notification => 'none')
    Member.create!(:project => project, :roles => [role], :principal => no_events_user)

    only_my_events_user = User.generate!(:mail_notification => 'only_my_events')
    Member.create!(:project => project, :roles => [role], :principal => only_my_events_user)

    only_assigned_user = User.generate!(:mail_notification => 'only_assigned')
    Member.create!(:project => project, :roles => [role], :principal => only_assigned_user)

    only_owned_user = User.generate!(:mail_notification => 'only_owner')
    Member.create!(:project => project, :roles => [role], :principal => only_owned_user)

    assert project.notified_users.include?(user_with_membership_notification), "should include members with a mail notification"
    assert project.notified_users.include?(all_events_user), "should include users with the 'all' notification option"
    assert !project.notified_users.include?(no_events_user), "should not include users with the 'none' notification option"
    assert !project.notified_users.include?(only_my_events_user), "should not include users with the 'only_my_events' notification option"
    assert !project.notified_users.include?(only_assigned_user), "should not include users with the 'only_assigned' notification option"
    assert !project.notified_users.include?(only_owned_user), "should not include users with the 'only_owner' notification option"
  end

  def test_override_roles_without_builtin_group_memberships
    project = Project.generate!
    assert_equal [Role.anonymous], project.override_roles(Role.anonymous)
    assert_equal [Role.non_member], project.override_roles(Role.non_member)
  end

  def test_css_classes
    p = Project.new
    assert_kind_of String, p.css_classes
    assert_not_include 'archived', p.css_classes.split
    assert_not_include 'closed', p.css_classes.split
  end

  def test_css_classes_for_archived_project
    p = Project.new
    p.status = Project::STATUS_ARCHIVED
    assert_include 'archived', p.css_classes.split
  end

  def test_css_classes_for_closed_project
    p = Project.new
    p.status = Project::STATUS_CLOSED
    assert_include 'closed', p.css_classes.split
  end

  def test_combination_of_visible_and_uniq_scopes_in_case_anonymous_group_has_memberships_should_not_error
    project = Project.find(1)
    member = Member.create!(:project => project, :principal => Group.anonymous, :roles => [Role.generate!])
    project.members << member
    assert_nothing_raised do
      Project.uniq.visible.to_a
    end
  end
end
