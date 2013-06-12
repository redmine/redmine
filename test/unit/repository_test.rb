# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

class RepositoryTest < ActiveSupport::TestCase
  fixtures :projects,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :repositories,
           :issues,
           :issue_statuses,
           :issue_categories,
           :changesets,
           :changes,
           :users,
           :members,
           :member_roles,
           :roles,
           :enumerations

  include Redmine::I18n

  def setup
    @repository = Project.find(1).repository
  end

  def test_blank_log_encoding_error_message
    set_language_if_valid 'en'
    repo = Repository::Bazaar.new(
                        :project      => Project.find(3),
                        :url          => "/test",
                        :log_encoding => ''
                      )
    assert !repo.save
    assert_include "Commit messages encoding can't be blank",
                   repo.errors.full_messages
  end

  def test_blank_log_encoding_error_message_fr
    set_language_if_valid 'fr'
    str = "Encodage des messages de commit doit \xc3\xaatre renseign\xc3\xa9(e)"
    str.force_encoding('UTF-8') if str.respond_to?(:force_encoding)
    repo = Repository::Bazaar.new(
                        :project      => Project.find(3),
                        :url          => "/test"
                      )
    assert !repo.save
    assert_include str, repo.errors.full_messages
  end

  def test_create
    repository = Repository::Subversion.new(:project => Project.find(3))
    assert !repository.save

    repository.url = "svn://localhost"
    assert repository.save
    repository.reload

    project = Project.find(3)
    assert_equal repository, project.repository
  end

  def test_first_repository_should_be_set_as_default
    repository1 = Repository::Subversion.new(
                      :project => Project.find(3),
                      :identifier => 'svn1',
                      :url => 'file:///svn1'
                    )
    assert repository1.save
    assert repository1.is_default?

    repository2 = Repository::Subversion.new(
                      :project => Project.find(3),
                      :identifier => 'svn2',
                      :url => 'file:///svn2'
                    )
    assert repository2.save
    assert !repository2.is_default?

    assert_equal repository1, Project.find(3).repository
    assert_equal [repository1, repository2], Project.find(3).repositories.sort
  end

  def test_identifier_should_accept_letters_digits_dashes_and_underscores
    r = Repository::Subversion.new(
      :project_id => 3,
      :identifier => 'svn-123_45',
      :url => 'file:///svn'
    )
    assert r.save
  end
  
  def test_identifier_should_not_be_frozen_for_a_new_repository
    assert_equal false, Repository.new.identifier_frozen?
  end

  def test_identifier_should_not_be_frozen_for_a_saved_repository_with_blank_identifier
    Repository.update_all(["identifier = ''"], "id = 10")

    assert_equal false, Repository.find(10).identifier_frozen?
  end

  def test_identifier_should_be_frozen_for_a_saved_repository_with_valid_identifier
    Repository.update_all(["identifier = 'abc123'"], "id = 10")

    assert_equal true, Repository.find(10).identifier_frozen?
  end

  def test_identifier_should_not_accept_change_if_frozen
    r = Repository.new(:identifier => 'foo')
    r.stubs(:identifier_frozen?).returns(true)

    r.identifier = 'bar'
    assert_equal 'foo', r.identifier
  end

  def test_identifier_should_accept_change_if_not_frozen
    r = Repository.new(:identifier => 'foo')
    r.stubs(:identifier_frozen?).returns(false)

    r.identifier = 'bar'
    assert_equal 'bar', r.identifier
  end

  def test_destroy
    repository = Repository.find(10)
    changesets = repository.changesets.count
    changes = repository.filechanges.count

    assert_difference 'Changeset.count', -changesets do
      assert_difference 'Change.count', -changes do
        Repository.find(10).destroy
      end
    end
  end

  def test_destroy_should_delete_parents_associations
    changeset = Changeset.find(102)
    changeset.parents = Changeset.find_all_by_id([100, 101])

    assert_difference 'Changeset.connection.select_all("select * from changeset_parents").size', -2 do
      Repository.find(10).destroy
    end
  end

  def test_destroy_should_delete_issues_associations
    changeset = Changeset.find(102)
    changeset.issues = Issue.find_all_by_id([1, 2])

    assert_difference 'Changeset.connection.select_all("select * from changesets_issues").size', -2 do
      Repository.find(10).destroy
    end
  end

  def test_should_not_create_with_disabled_scm
    # disable Subversion
    with_settings :enabled_scm => ['Darcs', 'Git'] do
      repository = Repository::Subversion.new(
                      :project => Project.find(3), :url => "svn://localhost")
      assert !repository.save
      assert_include I18n.translate('activerecord.errors.messages.invalid'),
                     repository.errors[:type]
    end
  end

  def test_scan_changesets_for_issue_ids
    Setting.default_language = 'en'

    # choosing a status to apply to fix issues
    Setting.commit_fix_status_id = IssueStatus.where(:is_closed => true).first.id
    Setting.commit_fix_done_ratio = "90"
    Setting.commit_ref_keywords = 'refs , references, IssueID'
    Setting.commit_fix_keywords = 'fixes , closes'
    Setting.default_language = 'en'
    ActionMailer::Base.deliveries.clear

    # make sure issue 1 is not already closed
    fixed_issue = Issue.find(1)
    assert !fixed_issue.status.is_closed?
    old_status = fixed_issue.status

    with_settings :notified_events => %w(issue_added issue_updated) do
      Repository.scan_changesets_for_issue_ids
    end
    assert_equal [101, 102], Issue.find(3).changeset_ids

    # fixed issues
    fixed_issue.reload
    assert fixed_issue.status.is_closed?
    assert_equal 90, fixed_issue.done_ratio
    assert_equal [101], fixed_issue.changeset_ids

    # issue change
    journal = fixed_issue.journals.reorder('created_on desc').first
    assert_equal User.find_by_login('dlopper'), journal.user
    assert_equal 'Applied in changeset r2.', journal.notes

    # 2 email notifications
    assert_equal 2, ActionMailer::Base.deliveries.size
    mail = ActionMailer::Base.deliveries.first
    assert_not_nil mail
    assert mail.subject.starts_with?(
        "[#{fixed_issue.project.name} - #{fixed_issue.tracker.name} ##{fixed_issue.id}]")
    assert_mail_body_match(
        "Status changed from #{old_status} to #{fixed_issue.status}", mail)

    # ignoring commits referencing an issue of another project
    assert_equal [], Issue.find(4).changesets
  end

  def test_for_changeset_comments_strip
    repository = Repository::Mercurial.create(
                    :project => Project.find( 4 ),
                    :url => '/foo/bar/baz' )
    comment = <<-COMMENT
    This is a loooooooooooooooooooooooooooong comment                                                   
                                                                                                       
                                                                                            
    COMMENT
    changeset = Changeset.new(
      :comments => comment, :commit_date => Time.now,
      :revision => 0, :scmid => 'f39b7922fb3c',
      :committer => 'foo <foo@example.com>',
      :committed_on => Time.now, :repository => repository )
    assert( changeset.save )
    assert_not_equal( comment, changeset.comments )
    assert_equal( 'This is a loooooooooooooooooooooooooooong comment',
                  changeset.comments )
  end

  def test_for_urls_strip_cvs
    repository = Repository::Cvs.create(
        :project => Project.find(4),
        :url => ' :pserver:login:password@host:/path/to/the/repository',
        :root_url => 'foo  ',
        :log_encoding => 'UTF-8')
    assert repository.save
    repository.reload
    assert_equal ':pserver:login:password@host:/path/to/the/repository',
                  repository.url
    assert_equal 'foo', repository.root_url
  end

  def test_for_urls_strip_subversion
    repository = Repository::Subversion.create(
        :project => Project.find(4),
        :url => ' file:///dummy   ')
    assert repository.save
    repository.reload
    assert_equal 'file:///dummy', repository.url
  end

  def test_for_urls_strip_git
    repository = Repository::Git.create(
        :project => Project.find(4),
        :url => ' c:\dummy   ')
    assert repository.save
    repository.reload
    assert_equal 'c:\dummy', repository.url
  end

  def test_manual_user_mapping
    assert_no_difference "Changeset.where('user_id <> 2').count" do
      c = Changeset.create!(
              :repository => @repository,
              :committer => 'foo',
              :committed_on => Time.now,
              :revision => 100,
              :comments => 'Committed by foo.'
            )
      assert_nil c.user
      @repository.committer_ids = {'foo' => '2'}
      assert_equal User.find(2), c.reload.user
      # committer is now mapped
      c = Changeset.create!(
              :repository => @repository,
              :committer => 'foo',
              :committed_on => Time.now,
              :revision => 101,
              :comments => 'Another commit by foo.'
            )
      assert_equal User.find(2), c.user
    end
  end

  def test_auto_user_mapping_by_username
    c = Changeset.create!(
          :repository   => @repository,
          :committer    => 'jsmith',
          :committed_on => Time.now,
          :revision     => 100,
          :comments     => 'Committed by john.'
        )
    assert_equal User.find(2), c.user
  end

  def test_auto_user_mapping_by_email
    c = Changeset.create!(
          :repository   => @repository,
          :committer    => 'john <jsmith@somenet.foo>',
          :committed_on => Time.now,
          :revision     => 100,
          :comments     => 'Committed by john.'
        )
    assert_equal User.find(2), c.user
  end

  def test_filesystem_avaialbe
    klass = Repository::Filesystem
    assert klass.scm_adapter_class
    assert_equal true, klass.scm_available
  end

  def test_merge_extra_info
    repo = Repository::Subversion.new(:project => Project.find(3))
    assert !repo.save
    repo.url = "svn://localhost"
    assert repo.save
    repo.reload
    project = Project.find(3)
    assert_equal repo, project.repository
    assert_nil repo.extra_info
    h1 = {"test_1" => {"test_11" => "test_value_11"}}
    repo.merge_extra_info(h1)
    assert_equal h1, repo.extra_info
    h2 = {"test_2" => {
                   "test_21" => "test_value_21",
                   "test_22" => "test_value_22",
                  }}
    repo.merge_extra_info(h2)
    assert_equal (h = {"test_11" => "test_value_11"}),
                 repo.extra_info["test_1"]
    assert_equal "test_value_21",
                 repo.extra_info["test_2"]["test_21"]
    h3 = {"test_2" => {
                   "test_23" => "test_value_23",
                   "test_24" => "test_value_24",
                  }}
    repo.merge_extra_info(h3)
    assert_equal (h = {"test_11" => "test_value_11"}),
                 repo.extra_info["test_1"]
    assert_nil repo.extra_info["test_2"]["test_21"]
    assert_equal "test_value_23",
                 repo.extra_info["test_2"]["test_23"]
  end

  def test_sort_should_not_raise_an_error_with_nil_identifiers
    r1 = Repository.new
    r2 = Repository.new

    assert_nothing_raised do
      [r1, r2].sort
    end
  end
end
