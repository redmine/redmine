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

require File.expand_path('../../test_helper', __FILE__)

class ProjectCopyTest < ActiveSupport::TestCase
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
           :documents

  def setup
    User.current = nil
    ProjectCustomField.destroy_all
    @source_project = Project.find(2)
    @project = Project.new(:name => 'Copy Test', :identifier => 'copy-test')
    @project.trackers = @source_project.trackers
    @project.enabled_module_names = @source_project.enabled_modules.collect(&:name)
  end

  def test_copy_should_return_false_if_save_fails
    project = Project.new(:name => 'Copy', :identifier => nil)
    assert_equal false, project.copy(@source_project)
  end

  test "#copy should copy project attachments" do
    Attachment.create!(:container => @source_project, :file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 1)
    assert @project.copy(@source_project)

    assert_equal 1, @project.attachments.count, "Attachment not copied"
    assert_equal "testfile.txt", @project.attachments.first.filename
  end

  test "#copy should copy issues" do
    @source_project.issues << Issue.generate!(:status => IssueStatus.find_by_name('Closed'),
                                              :subject => "copy issue status",
                                              :tracker_id => 1,
                                              :assigned_to_id => 2,
                                              :project_id => @source_project.id)
    assert @project.valid?
    assert @project.issues.empty?
    assert @project.copy(@source_project)

    assert_equal @source_project.issues.size, @project.issues.size
    @project.issues.each do |issue|
      assert issue.valid?
      assert ! issue.assigned_to.blank?
      assert_equal @project, issue.project
    end

    copied_issue = @project.issues.where(:subject => "copy issue status").first
    assert copied_issue
    assert copied_issue.status
    assert_equal "Closed", copied_issue.status.name
  end

  test "#copy should copy issues custom values" do
    field = IssueCustomField.generate!(:is_for_all => true, :trackers => Tracker.all)
    issue = Issue.generate!(:project => @source_project, :subject => 'Custom field copy')
    issue.custom_field_values = {field.id => 'custom'}
    issue.save!
    assert_equal 'custom', issue.reload.custom_field_value(field)

    assert @project.copy(@source_project)
    copy = @project.issues.find_by_subject('Custom field copy')
    assert copy
    assert_equal 'custom', copy.reload.custom_field_value(field)
  end

  test "#copy should copy issues assigned to a locked version" do
    User.current = User.find(1)
    assigned_version = Version.generate!(:name => "Assigned Issues")
    @source_project.versions << assigned_version
    Issue.generate!(:project => @source_project,
                    :fixed_version_id => assigned_version.id,
                    :subject => "copy issues assigned to a locked version")
    assigned_version.update_attribute :status, 'locked'

    assert @project.copy(@source_project)
    @project.reload
    copied_issue = @project.issues.where(:subject => "copy issues assigned to a locked version").first

    assert copied_issue
    assert copied_issue.fixed_version
    assert_equal "Assigned Issues", copied_issue.fixed_version.name # Same name
    assert_equal 'locked', copied_issue.fixed_version.status
  end

  test "#copy should change the new issues to use the copied version" do
    User.current = User.find(1)
    assigned_version = Version.generate!(:name => "Assigned Issues", :status => 'open')
    @source_project.versions << assigned_version
    assert_equal 3, @source_project.versions.size
    Issue.generate!(:project => @source_project,
                    :fixed_version_id => assigned_version.id,
                    :subject => "change the new issues to use the copied version")

    assert @project.copy(@source_project)
    @project.reload
    copied_issue = @project.issues.where(:subject => "change the new issues to use the copied version").first

    assert copied_issue
    assert copied_issue.fixed_version
    assert_equal "Assigned Issues", copied_issue.fixed_version.name # Same name
    assert_not_equal assigned_version.id, copied_issue.fixed_version.id # Different record
  end

  test "#copy should keep target shared versions from other project" do
    assigned_version = Version.generate!(:name => "Assigned Issues", :status => 'open', :project_id => 1, :sharing => 'system')
    issue = Issue.generate!(:project => @source_project,
                            :fixed_version => assigned_version,
                            :subject => "keep target shared versions")

    assert @project.copy(@source_project)
    @project.reload
    copied_issue = @project.issues.where(:subject => "keep target shared versions").first

    assert copied_issue
    assert_equal assigned_version, copied_issue.fixed_version
  end

  def test_copy_issues_should_reassign_version_custom_fields_to_copied_versions
    User.current = User.find(1)
    CustomField.destroy_all
    field = IssueCustomField.generate!(:field_format => 'version', :is_for_all => true, :trackers => Tracker.all)
    source_project = Project.generate!(:trackers => Tracker.all)
    source_version = Version.generate!(:project => source_project)
    source_issue = Issue.generate!(:project => source_project) do |issue|
      issue.custom_field_values = {field.id.to_s => source_version.id.to_s}
    end
    assert_equal source_version.id.to_s, source_issue.custom_field_value(field)

    project = Project.new(:name => 'Copy Test', :identifier => 'copy-test', :trackers => Tracker.all)
    assert project.copy(source_project)
    assert_equal 1, project.issues.count
    issue = project.issues.first
    assert_equal 1, project.versions.count
    version = project.versions.first

    assert_equal version.id.to_s, issue.custom_field_value(field)
  end

  test "#copy should copy issue relations" do
    Setting.cross_project_issue_relations = '1'

    second_issue = Issue.generate!(:status_id => 5,
                                   :subject => "copy issue relation",
                                   :tracker_id => 1,
                                   :assigned_to_id => 2,
                                   :project_id => @source_project.id)
    source_relation = IssueRelation.create!(:issue_from => Issue.find(4),
                                              :issue_to => second_issue,
                                              :relation_type => "relates")
    source_relation_cross_project = IssueRelation.create!(:issue_from => Issue.find(1),
                                                            :issue_to => second_issue,
                                                            :relation_type => "duplicates")

    assert @project.copy(@source_project)
    assert_equal @source_project.issues.count, @project.issues.count
    copied_issue = @project.issues.find_by_subject("Issue on project 2") # Was #4
    copied_second_issue = @project.issues.find_by_subject("copy issue relation")

    # First issue with a relation on project
    assert_equal 1, copied_issue.relations.size, "Relation not copied"
    copied_relation = copied_issue.relations.first
    assert_equal "relates", copied_relation.relation_type
    assert_equal copied_second_issue.id, copied_relation.issue_to_id
    assert_not_equal source_relation.id, copied_relation.id

    # Second issue with a cross project relation
    assert_equal 2, copied_second_issue.relations.size, "Relation not copied"
    copied_relation = copied_second_issue.relations.select {|r| r.relation_type == 'duplicates'}.first
    assert_equal "duplicates", copied_relation.relation_type
    assert_equal 1, copied_relation.issue_from_id, "Cross project relation not kept"
    assert_not_equal source_relation_cross_project.id, copied_relation.id
  end

  test "#copy should copy issue attachments" do
    issue = Issue.generate!(:subject => "copy with attachment", :tracker_id => 1, :project_id => @source_project.id)
    Attachment.create!(:container => issue, :file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 1)
    @source_project.issues << issue
    assert @project.copy(@source_project)

    copied_issue = @project.issues.where(:subject => "copy with attachment").first
    assert_not_nil copied_issue
    assert_equal 1, copied_issue.attachments.count, "Attachment not copied"
    assert_equal "testfile.txt", copied_issue.attachments.first.filename
  end

  test "#copy should copy memberships" do
    assert @project.valid?
    assert @project.members.empty?
    assert @project.copy(@source_project)

    assert_equal @source_project.memberships.size, @project.memberships.size
    @project.memberships.each do |membership|
      assert membership
      assert_equal @project, membership.project
    end
  end

  test "#copy should copy memberships with groups and additional roles" do
    group = Group.create!(:lastname => "Copy group")
    user = User.find(7)
    group.users << user
    # group role
    Member.create!(:project_id => @source_project.id, :principal => group, :role_ids => [2])
    member = Member.find_by_user_id_and_project_id(user.id, @source_project.id)
    # additional role
    member.role_ids = [1]

    assert @project.copy(@source_project)
    member = Member.find_by_user_id_and_project_id(user.id, @project.id)
    assert_not_nil member
    assert_equal [1, 2], member.role_ids.sort
  end

  def test_copy_should_copy_project_specific_issue_queries
    source = Project.generate!
    target = Project.new(:name => 'Copy Test', :identifier => 'copy-test')
    IssueQuery.generate!(:project => source, :user => User.find(2))
    assert target.copy(source)

    assert_equal 1, target.queries.size
    query = target.queries.first
    assert_kind_of IssueQuery, query
    assert_equal 2, query.user_id
  end

  def test_copy_should_copy_project_specific_time_entry_queries
    source = Project.generate!
    target = Project.new(:name => 'Copy Test', :identifier => 'copy-test')
    TimeEntryQuery.generate!(:project => source, :user => User.find(2))
    assert target.copy(source)

    assert_equal 1, target.queries.size
    query = target.queries.first
    assert_kind_of TimeEntryQuery, query
    assert_equal 2, query.user_id
  end

  def test_copy_should_copy_queries_roles_visibility
    source = Project.generate!
    target = Project.new(:name => 'Copy Test', :identifier => 'copy-test')
    IssueQuery.generate!(:project => source, :visibility => Query::VISIBILITY_ROLES, :roles => Role.where(:id => [1, 3]).to_a)

    assert target.copy(source)
    assert_equal 1, target.queries.size
    query = target.queries.first
    assert_equal [1, 3], query.role_ids.sort
  end

  test "#copy should copy versions" do
    @source_project.versions << Version.generate!
    @source_project.versions << Version.generate!

    assert @project.versions.empty?
    assert @project.copy(@source_project)

    assert_equal @source_project.versions.size, @project.versions.size
    @project.versions.each do |version|
      assert version
      assert_equal @project, version.project
    end
  end

  test "#copy should copy version attachments" do
    version = Version.generate!(:name => "copy with attachment")
    Attachment.create!(:container => version, :file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 1)
    @source_project.versions << version
    assert @project.copy(@source_project)

    copied_version = @project.versions.where(:name => "copy with attachment").first
    assert_not_nil copied_version
    assert_equal 1, copied_version.attachments.count, "Attachment not copied"
    assert_equal "testfile.txt", copied_version.attachments.first.filename
  end

  test "#copy should copy wiki" do
    assert_difference 'Wiki.count' do
      assert @project.copy(@source_project)
    end

    assert @project.wiki
    assert_not_equal @source_project.wiki, @project.wiki
    assert_equal "Start page", @project.wiki.start_page
  end

  test "#copy should copy wiki without wiki module" do
    project = Project.new(:name => 'Copy Test', :identifier => 'copy-test', :enabled_module_names => [])
    assert_difference 'Wiki.count' do
      assert project.copy(@source_project)
    end

    assert project.wiki
  end

  test "#copy should copy wiki pages, attachment and content with hierarchy" do
    @source_project.wiki.pages.first.attachments << Attachment.first.copy
    assert_difference 'WikiPage.count', @source_project.wiki.pages.size do
      assert @project.copy(@source_project)
    end

    assert @project.wiki
    assert_equal @source_project.wiki.pages.size, @project.wiki.pages.size

    assert_equal @source_project.wiki.pages.first.attachments.first.filename, @project.wiki.pages.first.attachments.first.filename

    @project.wiki.pages.each do |wiki_page|
      assert wiki_page.content
      assert !@source_project.wiki.pages.include?(wiki_page)
    end

    parent = @project.wiki.find_page('Parent_page')
    child1 = @project.wiki.find_page('Child_page_1')
    child2 = @project.wiki.find_page('Child_page_2')
    assert_equal parent, child1.parent
    assert_equal parent, child2.parent
  end

  test "#copy should copy issue categories" do
    assert @project.copy(@source_project)

    assert_equal 2, @project.issue_categories.size
    @project.issue_categories.each do |issue_category|
      assert !@source_project.issue_categories.include?(issue_category)
    end
  end

  test "#copy should copy boards" do
    assert @project.copy(@source_project)

    assert_equal 1, @project.boards.size
    @project.boards.each do |board|
      assert !@source_project.boards.include?(board)
    end
  end

  test "#copy should copy documents" do
    source_project = Project.find(1)
    assert @project.copy(source_project)

    assert_equal 2, @project.documents.size
    @project.documents.each do |document|
      assert !source_project.documents.include?(document)
    end
  end

  test "#copy should copy document attachments" do
    document = Document.generate!(:title => "copy with attachment", :category_id => 1, :project_id => @source_project.id)
    Attachment.create!(:container => document, :file => uploaded_test_file("testfile.txt", "text/plain"), :author_id => 1)
    @source_project.documents << document
    assert @project.copy(@source_project)

    copied_document = @project.documents.where(:title => "copy with attachment").first
    assert_not_nil copied_document
    assert_equal 1, copied_document.attachments.count, "Attachment not copied"
    assert_equal "testfile.txt", copied_document.attachments.first.filename
  end

  test "#copy should change the new issues to use the copied issue categories" do
    issue = Issue.find(4)
    issue.update_attribute(:category_id, 3)

    assert @project.copy(@source_project)

    @project.issues.each do |issue|
      assert issue.category
      assert_equal "Stock management", issue.category.name # Same name
      assert_not_equal IssueCategory.find(3), issue.category # Different record
    end
  end

  test "#copy should limit copy with :only option" do
    assert @project.members.empty?
    assert @project.issue_categories.empty?
    assert @source_project.issues.any?

    assert @project.copy(@source_project, :only => ['members', 'issue_categories'])

    assert @project.members.any?
    assert @project.issue_categories.any?
    assert @project.issues.empty?
  end

  test "#copy should copy subtasks" do
    source = Project.generate!(:tracker_ids => [1])
    issue = Issue.generate_with_descendants!(:project => source)
    project = Project.new(:name => 'Copy', :identifier => 'copy', :tracker_ids => [1])

    assert_difference 'Project.count' do
      assert_difference 'Issue.count', 1+issue.descendants.count do
        assert project.copy(source.reload)
      end
    end
    copy = Issue.where(:parent_id => nil).order("id DESC").first
    assert_equal project, copy.project
    assert_equal issue.descendants.count, copy.descendants.count
    child_copy = copy.children.detect {|c| c.subject == 'Child1'}
    assert child_copy.descendants.any?
  end
end
