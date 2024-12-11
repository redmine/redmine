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

require_relative '../test_helper'

class ChangesetTest < ActiveSupport::TestCase
  def setup
    User.current = nil
  end

  def test_ref_keywords_any
    ActionMailer::Base.deliveries.clear
    Setting.commit_ref_keywords = '*'
    Setting.commit_update_keywords = [{'keywords' => 'fixes , closes', 'status_id' => '5', 'done_ratio' => '90'}]

    c = Changeset.new(:repository   => Project.find(1).repository,
                      :committed_on => Time.now,
                      :comments     => 'New commit (#2). Fixes #1',
                      :revision     => '12345')
    assert c.save
    assert_equal [1, 2], c.issue_ids.sort
    fixed = Issue.find(1)
    assert fixed.closed?
    assert_equal 90, fixed.done_ratio
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  def test_ref_keywords
    Setting.commit_ref_keywords = 'refs'
    Setting.commit_update_keywords = ''
    c = Changeset.new(:repository   => Project.find(1).repository,
                      :committed_on => Time.now,
                      :comments     => 'Ignores #2. Refs #1',
                      :revision     => '12345')
    assert c.save
    assert_equal [1], c.issue_ids.sort
  end

  def test_ref_keywords_any_only
    Setting.commit_ref_keywords = '*'
    Setting.commit_update_keywords = ''
    c = Changeset.new(:repository   => Project.find(1).repository,
                      :committed_on => Time.now,
                      :comments     => 'Ignores #2. Refs #1',
                      :revision     => '12345')
    assert c.save
    assert_equal [1, 2], c.issue_ids.sort
  end

  def test_project_specific_activity
    project = Project.find 1
    activity = TimeEntryActivity.find 9

    Setting.commit_ref_keywords = '*'
    Setting.commit_logtime_enabled = '1'
    Setting.commit_logtime_activity_id = activity.id

    project_specific_activity = TimeEntryActivity.create!(
      name: activity.name,
      parent_id: activity.id,
      position: activity.position,
      project_id: project.id
    )

    c = Changeset.new(:repository   => project.repository,
                      :committed_on => 24.hours.ago,
                      :comments     => "Worked on this issue #1 @8h",
                      :revision     => '520',
                      :user         => User.find(2))
    assert_difference 'TimeEntry.count' do
      c.scan_comment_for_issue_ids
    end

    time = TimeEntry.order('id desc').first
    assert_equal project_specific_activity, time.activity
  end

  def test_ref_keywords_any_with_timelog
    Setting.commit_ref_keywords = '*'
    Setting.commit_logtime_enabled = '1'
    Setting.commit_logtime_activity_id = 9

    {
      '2' => 2.0,
      '2h' => 2.0,
      '2hours' => 2.0,
      '15m' => 0.25,
      '15min' => 0.25,
      '3h15' => 3.25,
      '3h15m' => 3.25,
      '3h15min' => 3.25,
      '3:15' => 3.25,
      '3.25' => 3.25,
      '3.25h' => 3.25,
      '3,25' => 3.25,
      '3,25h' => 3.25,
    }.each do |syntax, expected_hours|
      c = Changeset.new(:repository   => Project.find(1).repository,
                        :committed_on => 24.hours.ago,
                        :comments     => "Worked on this issue #1 @#{syntax}",
                        :revision     => '520',
                        :user         => User.find(2))
      assert_difference 'TimeEntry.count' do
        c.scan_comment_for_issue_ids
      end
      assert_equal [1], c.issue_ids.sort

      time = TimeEntry.order('id desc').first
      assert_equal 1, time.issue_id
      assert_equal 1, time.project_id
      assert_equal 2, time.user_id
      assert_equal(
        expected_hours, time.hours,
        "@#{syntax} should be logged as #{expected_hours} hours but was #{time.hours}"
      )
      assert_equal Date.yesterday, time.spent_on
      assert_equal 9, time.activity_id
      assert(
        time.comments.include?('r520'),
        "r520 was expected in time_entry comments: #{time.comments}"
      )
    end
  end

  def test_ref_keywords_closing_with_timelog
    Setting.commit_ref_keywords = '*'
    Setting.commit_update_keywords = [{'keywords' => 'fixes , closes',
                                       'status_id' => IssueStatus.where(:is_closed => true).first.id.to_s}]
    Setting.commit_logtime_enabled = '1'

    c = Changeset.new(:repository   => Project.find(1).repository,
                      :committed_on => Time.now,
                      :comments     => 'This is a comment. Fixes #1 @4.5, #2 @1',
                      :user         => User.find(2))
    assert_difference 'TimeEntry.count', 2 do
      c.scan_comment_for_issue_ids
    end

    assert_equal [1, 2], c.issue_ids.sort
    assert Issue.find(1).closed?
    assert Issue.find(2).closed?

    times = TimeEntry.order('id desc').limit(2)
    assert_equal [1, 2], times.collect(&:issue_id).sort
  end

  def test_ref_keywords_any_line_start
    Setting.commit_ref_keywords = '*'
    c = Changeset.new(:repository   => Project.find(1).repository,
                      :committed_on => Time.now,
                      :comments     => '#1 is the reason of this commit',
                      :revision     => '12345')
    assert c.save
    assert_equal [1], c.issue_ids.sort
  end

  def test_ref_keywords_allow_brackets_around_a_issue_number
    Setting.commit_ref_keywords = '*'
    c = Changeset.new(:repository   => Project.find(1).repository,
                      :committed_on => Time.now,
                      :comments     => '[#1] Worked on this issue',
                      :revision     => '12345')
    assert c.save
    assert_equal [1], c.issue_ids.sort
  end

  def test_ref_keywords_allow_brackets_around_multiple_issue_numbers
    Setting.commit_ref_keywords = '*'
    c = Changeset.new(:repository   => Project.find(1).repository,
                      :committed_on => Time.now,
                      :comments     => '[#1 #2, #3] Worked on these',
                      :revision     => '12345')
    assert c.save
    assert_equal [1, 2, 3], c.issue_ids.sort
  end

  def test_ref_keywords_with_large_number_should_not_error
    Setting.commit_ref_keywords = '*'
    c = Changeset.new(:repository   => Project.find(1).repository,
                      :committed_on => Time.now,
                      :comments     => 'Out of range #2010021810000121',
                      :revision     => '12345')
    assert_nothing_raised do
      assert c.save
    end
    assert_equal [], c.issue_ids.sort
  end

  def test_update_keywords_with_changes_should_create_journal
    issue = Issue.generate!(:project_id => 1, :status_id => 1)

    with_settings :commit_update_keywords => [{'keywords' => 'fixes', 'status_id' => '3'}] do
      assert_difference 'Journal.count' do
        c = Changeset.
              generate!(
                :repository => Project.find(1).repository,
                :comments => "Fixes ##{issue.id}"
              )
        assert_include c.id, issue.reload.changeset_ids
        journal = Journal.order('id DESC').first
        assert_equal 1, journal.details.count
      end
    end
  end

  def test_update_keywords_without_change_should_not_create_journal
    issue = Issue.generate!(:project_id => 1, :status_id => 3)
    with_settings :commit_update_keywords => [{'keywords' => 'fixes', 'status_id' => '3'}] do
      assert_no_difference 'Journal.count' do
        c = Changeset.
              generate!(
                :repository => Project.find(1).repository,
                :comments => "Fixes ##{issue.id}"
              )
        assert_include c.id, issue.reload.changeset_ids
      end
    end
  end

  def test_update_keywords_with_multiple_rules
    with_settings :commit_update_keywords => [
      {'keywords' => 'fixes, closes', 'status_id' => '5'},
      {'keywords' => 'resolves', 'status_id' => '3'}
    ] do
      issue1 = Issue.generate!
      issue2 = Issue.generate!
      Changeset.generate!(:comments => "Closes ##{issue1.id}\nResolves ##{issue2.id}")
      assert_equal 5, issue1.reload.status_id
      assert_equal 3, issue2.reload.status_id
    end
  end

  def test_update_keywords_with_multiple_rules_for_the_same_keyword_should_match_tracker
    with_settings :commit_update_keywords => [
      {'keywords' => 'fixes', 'status_id' => '5', 'if_tracker_id' => '2'},
      {'keywords' => 'fixes', 'status_id' => '3', 'if_tracker_id' => ''}
    ] do
      issue1 = Issue.generate!(:tracker_id => 2)
      issue2 = Issue.generate!
      Changeset.generate!(:comments => "Fixes ##{issue1.id}, ##{issue2.id}")
      assert_equal 5, issue1.reload.status_id
      assert_equal 3, issue2.reload.status_id
    end
  end

  def test_update_keywords_with_multiple_rules_for_the_same_tracker_should_match_keyword
    with_settings :commit_update_keywords => [
      {'keywords' => 'Fixes, Closes', 'status_id' => '5', 'done_ratio' => '100', 'if_tracker_id' => '2'},
      {'keywords' => 'Testing',       'status_id' => '3', 'done_ratio' => '90',  'if_tracker_id' => '2'}
    ] do
      issue1 = Issue.generate!(:tracker_id => 2)
      issue2 = Issue.generate!(:tracker_id => 2)
      Changeset.generate!(:comments => "Testing ##{issue1.id}, Fixes ##{issue2.id}")
      issue1.reload
      assert_equal 3, issue1.status_id
      assert_equal 90, issue1.done_ratio
      issue2.reload
      assert_equal 5, issue2.status_id
      assert_equal 100, issue2.done_ratio
    end
  end

  def test_update_keywords_with_multiple_rules_and_no_match
    with_settings :commit_update_keywords => [
      {'keywords' => 'fixes', 'status_id' => '5', 'if_tracker_id' => '2'},
      {'keywords' => 'fixes', 'status_id' => '3', 'if_tracker_id' => '3'}
    ] do
      issue1 = Issue.generate!(:tracker_id => 2)
      issue2 = Issue.generate!
      Changeset.generate!(:comments => "Fixes ##{issue1.id}, ##{issue2.id}")
      assert_equal 5, issue1.reload.status_id
      assert_equal 1, issue2.reload.status_id # no updates
    end
  end

  def test_commit_referencing_a_subproject_issue
    c = Changeset.new(:repository   => Project.find(1).repository,
                      :committed_on => Time.now,
                      :comments     => 'refs #5, a subproject issue',
                      :revision     => '12345')
    assert c.save
    assert_equal [5], c.issue_ids.sort
    assert c.issues.first.project != c.project
  end

  def test_commit_closing_a_subproject_issue
    with_settings :commit_update_keywords => [{'keywords' => 'closes', 'status_id' => '5'}],
                  :default_language => 'en' do
      issue = Issue.find(5)
      assert !issue.closed?
      assert_difference 'Journal.count' do
        c = Changeset.new(:repository   => Project.find(1).repository,
                          :committed_on => Time.now,
                          :comments     => 'closes #5, a subproject issue',
                          :revision     => '12345')
        assert c.save
      end
      assert issue.reload.closed?
      journal = Journal.order('id DESC').first
      assert_equal issue, journal.issue
      assert_include "Applied in changeset ecookbook:r12345.", journal.notes
    end
  end

  def test_commit_referencing_a_parent_project_issue
    # repository of child project
    r = Repository::Subversion.
         create!(
           :project => Project.find(3),
           :url     => 'svn://localhost/test'
         )
    c = Changeset.new(:repository   => r,
                      :committed_on => Time.now,
                      :comments     => 'refs #2, an issue of a parent project',
                      :revision     => '12345')
    assert c.save
    assert_equal [2], c.issue_ids.sort
    assert c.issues.first.project != c.project
  end

  def test_commit_referencing_a_project_with_commit_cross_project_ref_disabled
    r = Repository::Subversion.
          create!(
            :project => Project.find(3),
            :url     => 'svn://localhost/test'
          )
    with_settings :commit_cross_project_ref => '0' do
      c = Changeset.new(:repository   => r,
                        :committed_on => Time.now,
                        :comments     => 'refs #4, an issue of a different project',
                        :revision     => '12345')
      assert c.save
      assert_equal [], c.issue_ids
    end
  end

  def test_commit_referencing_a_project_with_commit_cross_project_ref_enabled
    r = Repository::Subversion.
          create!(
            :project => Project.find(3),
            :url     => 'svn://localhost/test'
          )
    with_settings :commit_cross_project_ref => '1' do
      c = Changeset.new(:repository   => r,
                        :committed_on => Time.now,
                        :comments     => 'refs #4, an issue of a different project',
                        :revision     => '12345')
      assert c.save
      assert_equal [4], c.issue_ids
    end
  end

  def test_old_commits_should_not_update_issues_nor_log_time
    Setting.commit_ref_keywords = '*'
    Setting.commit_update_keywords = {'fixes , closes' => {'status_id' => '5', 'done_ratio' => '90'}}
    Setting.commit_logtime_enabled = '1'

    repository = Project.find(1).repository
    repository.created_on = Time.now
    repository.save!

    c = Changeset.new(:repository   => repository,
                      :committed_on => 1.month.ago,
                      :comments     => 'New commit (#2). Fixes #1 @1h',
                      :revision     => '12345')
    assert_no_difference 'TimeEntry.count' do
      assert c.save
    end
    assert_equal [1, 2], c.issue_ids.sort
    issue = Issue.find(1)
    assert_equal 1, issue.status_id
    assert_equal 0, issue.done_ratio
  end

  def test_2_repositories_with_same_backend_should_not_link_issue_multiple_times
    Setting.commit_ref_keywords = '*'
    r1 = Repository::Subversion.create!(:project_id => 1, :identifier => 'svn1', :url => 'file:///svn1')
    r2 = Repository::Subversion.create!(:project_id => 1, :identifier => 'svn2', :url => 'file:///svn1')
    now = Time.now
    assert_difference 'Issue.find(1).changesets.count' do
      c1 = Changeset.create!(:repository => r1, :committed_on => now, :comments => 'Fixes #1', :revision => '12345')
      c1 = Changeset.create!(:repository => r2, :committed_on => now, :comments => 'Fixes #1', :revision => '12345')
    end
  end

  def test_text_tag_revision
    c = Changeset.new(:revision => '520')
    assert_equal 'r520', c.text_tag
  end

  def test_text_tag_revision_with_same_project
    c = Changeset.new(:revision => '520', :repository => Project.find(1).repository)
    assert_equal 'r520', c.text_tag(Project.find(1))
  end

  def test_text_tag_revision_with_different_project
    c = Changeset.new(:revision => '520', :repository => Project.find(1).repository)
    assert_equal 'ecookbook:r520', c.text_tag(Project.find(2))
  end

  def test_text_tag_revision_with_repository_identifier
    r = Repository::Subversion.
         create!(
           :project_id => 1,
           :url     => 'svn://localhost/test',
           :identifier => 'documents'
         )
    c = Changeset.new(:revision => '520', :repository => r)
    assert_equal 'documents|r520', c.text_tag
    assert_equal 'ecookbook:documents|r520', c.text_tag(Project.find(2))
  end

  def test_text_tag_hash
    c = Changeset.
          new(
            :scmid    => '7234cb2750b63f47bff735edc50a1c0a433c2518',
            :revision => '7234cb2750b63f47bff735edc50a1c0a433c2518'
          )
    assert_equal 'commit:7234cb2750b63f47bff735edc50a1c0a433c2518', c.text_tag
  end

  def test_text_tag_hash_with_same_project
    c = Changeset.new(:revision => '7234cb27', :scmid => '7234cb27', :repository => Project.find(1).repository)
    assert_equal 'commit:7234cb27', c.text_tag(Project.find(1))
  end

  def test_text_tag_hash_with_different_project
    c = Changeset.new(:revision => '7234cb27', :scmid => '7234cb27', :repository => Project.find(1).repository)
    assert_equal 'ecookbook:commit:7234cb27', c.text_tag(Project.find(2))
  end

  def test_text_tag_hash_all_number
    c = Changeset.new(:scmid => '0123456789', :revision => '0123456789')
    assert_equal 'commit:0123456789', c.text_tag
  end

  def test_text_tag_hash_with_repository_identifier
    r =
      Repository::Subversion.
        new(
          :project_id => 1,
          :url     => 'svn://localhost/test',
          :identifier => 'documents'
        )
    c = Changeset.new(:revision => '7234cb27', :scmid => '7234cb27', :repository => r)
    assert_equal 'commit:documents|7234cb27', c.text_tag
    assert_equal 'ecookbook:commit:documents|7234cb27', c.text_tag(Project.find(2))
  end

  def test_previous
    changeset = Changeset.find_by_revision('3')
    assert_equal Changeset.find_by_revision('2'), changeset.previous
  end

  def test_previous_nil
    changeset = Changeset.find_by_revision('1')
    assert_nil changeset.previous
  end

  def test_next
    changeset = Changeset.find_by_revision('2')
    assert_equal Changeset.find_by_revision('3'), changeset.next
  end

  def test_next_nil
    changeset = Changeset.find_by_revision('10')
    assert_nil changeset.next
  end

  def test_comments_should_be_converted_to_utf8
    proj = Project.find(3)
    str = "Texte encod\xe9 en ISO-8859-1.".b
    r = Repository::Bazaar.
          create!(
            :project      => proj,
            :url          => '/tmp/test/bazaar',
            :log_encoding => 'ISO-8859-1'
          )
    assert r
    c = Changeset.new(:repository   => r,
                      :committed_on => Time.now,
                      :revision     => '123',
                      :scmid        => '12345',
                      :comments     => str)
    assert(c.save)
    assert_equal 'Texte encodé en ISO-8859-1.', c.comments
  end

  def test_invalid_utf8_sequences_in_comments_should_be_replaced_latin1
    proj = Project.find(3)
    str2 = "\xe9a\xe9b\xe9c\xe9d\xe9e test".b
    r = Repository::Bazaar.
          create!(
            :project      => proj,
            :url          => '/tmp/test/bazaar',
            :log_encoding => 'UTF-8'
          )
    assert r
    c = Changeset.new(:repository   => r,
                      :committed_on => Time.now,
                      :revision     => '123',
                      :scmid        => '12345',
                      :comments     => "Texte encod\xE9 en ISO-8859-1.",
                      :committer    => str2)
    assert(c.save)
    assert_equal "Texte encod? en ISO-8859-1.", c.comments
    assert_equal "?a?b?c?d?e test", c.committer
  end

  def test_invalid_utf8_sequences_in_comments_should_be_replaced_ja_jis
    proj = Project.find(3)
    str = "test\xb5\xfetest\xb5\xfe".b
    r = Repository::Bazaar.
          create!(
            :project      => proj,
            :url          => '/tmp/test/bazaar',
            :log_encoding => 'ISO-2022-JP'
          )
    assert r
    c = Changeset.new(:repository   => r,
                      :committed_on => Time.now,
                      :revision     => '123',
                      :scmid        => '12345',
                      :comments     => str)
    assert(c.save)
    assert_equal "test??test??", c.comments
  end

  def test_comments_should_be_converted_all_latin1_to_utf8
    s1 = +"\xC2\x80"
    s2 = +"\xc3\x82\xc2\x80"
    s4 = s2.dup
    s3 = s1.dup
    s1 = s1.b
    s2 = s2.b
    s3.force_encoding('ISO-8859-1')
    s4.force_encoding('UTF-8')
    assert_equal s3.encode('UTF-8'), s4
    proj = Project.find(3)
    r = Repository::Bazaar.
          create!(
            :project      => proj,
            :url          => '/tmp/test/bazaar',
            :log_encoding => 'ISO-8859-1'
          )
    assert r
    c = Changeset.new(:repository   => r,
                      :committed_on => Time.now,
                      :revision     => '123',
                      :scmid        => '12345',
                      :comments     => s1)
    assert(c.save)
    assert_equal s4, c.comments
  end

  def test_invalid_utf8_sequences_in_paths_should_be_replaced
    proj = Project.find(3)
    str2 = "\xe9a\xe9b\xe9c\xe9d\xe9e test".b
    r = Repository::Bazaar.
          create!(
            :project => proj,
            :url => '/tmp/test/bazaar',
            :log_encoding => 'UTF-8'
          )
    assert r
    cs = Changeset.
           new(
             :repository   => r,
             :committed_on => Time.now,
             :revision     => '123',
             :scmid        => '12345',
             :comments     => "test"
           )
    assert(cs.save)
    ch = Change.
           new(
             :changeset     => cs,
             :action        => "A",
             :path          => "Texte encod\xE9 en ISO-8859-1",
             :from_path     => str2,
             :from_revision => "345"
           )
    assert(ch.save)
    assert_equal "Texte encod? en ISO-8859-1", ch.path
    assert_equal "?a?b?c?d?e test", ch.from_path
  end

  def test_comments_nil
    proj = Project.find(3)
    r = Repository::Bazaar.
          create!(
            :project      => proj,
            :url          => '/tmp/test/bazaar',
            :log_encoding => 'ISO-8859-1'
          )
    assert r
    c = Changeset.new(:repository   => r,
                      :committed_on => Time.now,
                      :revision     => '123',
                      :scmid        => '12345',
                      :comments     => nil,
                      :committer    => nil)
    assert(c.save)
    assert_equal "", c.comments
    assert_nil c.committer
    assert_equal "UTF-8", c.comments.encoding.to_s
  end

  def test_comments_empty
    proj = Project.find(3)
    r = Repository::Bazaar.
          create!(
            :project      => proj,
            :url          => '/tmp/test/bazaar',
            :log_encoding => 'ISO-8859-1'
          )
    assert r
    c = Changeset.new(:repository   => r,
                      :committed_on => Time.now,
                      :revision     => '123',
                      :scmid        => '12345',
                      :comments     => "",
                      :committer    => "")
    assert(c.save)
    assert_equal "", c.comments
    assert_equal "", c.committer
    assert_equal "UTF-8", c.comments.encoding.to_s
    assert_equal "UTF-8", c.committer.encoding.to_s
  end

  def test_comments_should_accept_more_than_64k
    c = Changeset.new(:repository   => Repository.first,
                      :committed_on => Time.now,
                      :revision     => '123',
                      :scmid        => '12345',
                      :comments     => "a" * 500.kilobytes)
    assert c.save
    c.reload
    assert_equal 500.kilobytes, c.comments.size
  end

  def test_identifier
    c = Changeset.find_by_revision('1')
    assert_equal c.revision, c.identifier
  end
end
