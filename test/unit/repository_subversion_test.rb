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

class RepositorySubversionTest < ActiveSupport::TestCase
  include Redmine::I18n

  NUM_REV = 16

  def setup
    User.current = nil
    @project = Project.find(3)
    @repository = Repository::Subversion.create(:project => @project,
                    :url => self.class.subversion_repository_url)
    assert @repository
  end

  def test_invalid_url
    set_language_if_valid 'en'
    ['invalid', 'http://', 'svn://', 'svn+ssh://', 'file://'].each do |url|
      repo =
        Repository::Subversion.new(
          :project      => @project,
          :identifier   => 'test',
          :url => url
        )
      assert !repo.save
      assert_equal ["is invalid"], repo.errors[:url]
    end
  end

  def test_valid_url
    ['http://valid', 'svn://valid', 'svn+ssh://valid', 'file://valid'].each do |url|
      repo =
        Repository::Subversion.new(
          :project      => @project,
          :identifier   => 'test',
          :url => url
        )
      assert repo.save
      assert_equal [], repo.errors[:url]
      assert repo.destroy
    end
  end

  def test_url_should_be_validated_against_regexp_set_in_configuration
    Redmine::Configuration.with 'scm_subversion_path_regexp' => 'file:///svnpath/[a-z]+' do
      repo = Repository::Subversion.new(:project => @project, :identifier => 'test')
      repo.url = 'http://foo'
      assert repo.invalid?
      assert repo.errors[:url].present?

      repo.url = 'file:///svnpath/foo/bar'
      assert repo.invalid?
      assert repo.errors[:url].present?

      repo.url = 'file:///svnpath/foo'
      assert repo.valid?
    end
  end

  def test_url_should_be_validated_against_regexp_set_in_configuration_with_project_identifier
    Redmine::Configuration.with 'scm_subversion_path_regexp' => 'file:///svnpath/%project%(\.[a-z]+)?' do
      repo = Repository::Subversion.new(:project => @project, :identifier => 'test')
      repo.url = 'file:///svnpath/invalid'
      assert repo.invalid?
      assert repo.errors[:url].present?

      repo.url = 'file:///svnpath/subproject1'
      assert repo.valid?

      repo.url = 'file:///svnpath/subproject1.foo'
      assert repo.valid?
    end
  end

  if repository_configured?('subversion')
    def test_fetch_changesets_from_scratch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload

      assert_equal NUM_REV, @repository.changesets.count
      assert_equal 26, @repository.filechanges.count
      assert_equal 'Initial import.', @repository.changesets.find_by_revision('1').comments
    end

    def test_fetch_changesets_incremental
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      # Remove changesets with revision > 5
      @repository.changesets.each {|c| c.destroy if c.revision.to_i > 5}
      @project.reload
      @repository.reload
      assert_equal 5, @repository.changesets.count

      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
    end

    def test_entries
      entries = @repository.entries
      assert_kind_of Redmine::Scm::Adapters::Entries, entries
    end

    def test_entries_for_invalid_path_should_return_nil
      entries = @repository.entries('invalid_path')
      assert_nil entries
    end

    def test_latest_changesets
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      # with limit
      changesets = @repository.latest_changesets('', nil, 2)
      assert_equal 2, changesets.size
      assert_equal @repository.latest_changesets('', nil).slice(0, 2), changesets

      # with path
      changesets = @repository.latest_changesets('subversion_test/folder', nil)
      assert_equal ["13", "12", "10", "9", "7", "6", "5", "2"], changesets.collect(&:revision)

      # with path and revision
      changesets = @repository.latest_changesets('subversion_test/folder', 8)
      assert_equal ["7", "6", "5", "2"], changesets.collect(&:revision)
    end

    def test_directory_listing_with_square_brackets_in_path
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      entries = @repository.entries('subversion_test/[folder_with_brackets]')
      assert_not_nil entries, 'Expect to find entries in folder_with_brackets'
      assert_equal 1, entries.size, 'Expect one entry in folder_with_brackets'
      assert_equal 'README.txt', entries.first.name
    end

    def test_directory_listing_with_square_brackets_in_base
      @project = Project.find(3)
      @repository =
        Repository::Subversion.create(
          :project => @project,
          :url => "file:///#{self.class.repository_path('subversion')}/subversion_test/[folder_with_brackets]"
        )
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload

      assert_equal 1, @repository.changesets.count, 'Expected to see 1 revision'
      assert_equal 2, @repository.filechanges.count, 'Expected to see 2 changes, dir add and file add'

      entries = @repository.entries('')
      assert_not_nil entries, 'Expect to find entries'
      assert_equal 1, entries.size, 'Expect a single entry'
      assert_equal 'README.txt', entries.first.name
    end

    def test_identifier
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      c = @repository.changesets.find_by_revision('1')
      assert_equal c.revision, c.identifier
    end

    def test_find_changeset_by_empty_name
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['', ' ', nil].each do |r|
        assert_nil @repository.find_changeset_by_name(r)
      end
    end

    def test_identifier_nine_digit
      c = Changeset.new(:repository => @repository, :committed_on => Time.now,
                        :revision => '123456789', :comments => 'test')
      assert_equal c.identifier, c.revision
    end

    def test_format_identifier
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      c = @repository.changesets.find_by_revision('1')
      assert_equal c.format_identifier, c.revision
    end

    def test_format_identifier_nine_digit
      c = Changeset.new(:repository => @repository, :committed_on => Time.now,
                        :revision => '123456789', :comments => 'test')
      assert_equal c.format_identifier, c.revision
    end

    def test_activities
      c = Changeset.new(:repository => @repository, :committed_on => Time.now,
                        :revision => '1', :comments => 'test')
      assert c.event_title.include?('1:')
      assert_equal '1', c.event_url[:rev]
    end

    def test_activities_nine_digit
      c = Changeset.new(:repository => @repository, :committed_on => Time.now,
                        :revision => '123456789', :comments => 'test')
      assert c.event_title.include?('123456789:')
      assert_equal '123456789', c.event_url[:rev]
    end

    def test_log_encoding_ignore_setting
      with_settings :commit_logs_encoding => 'windows-1252' do
        s2 = "Â\u0080"
        c = Changeset.new(:repository => @repository,
                          :comments   => s2,
                          :revision   => '123',
                          :committed_on => Time.now)
        assert c.save
        assert_equal s2, c.comments
      end
    end

    def test_previous
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      changeset = @repository.find_changeset_by_name('3')
      assert_equal @repository.find_changeset_by_name('2'), changeset.previous
    end

    def test_previous_nil
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      changeset = @repository.find_changeset_by_name('1')
      assert_nil changeset.previous
    end

    def test_next
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      changeset = @repository.find_changeset_by_name('2')
      assert_equal @repository.find_changeset_by_name('3'), changeset.next
    end

    def test_next_nil
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      changeset = @repository.find_changeset_by_name(NUM_REV.to_s)
      assert_nil changeset.next
    end
  else
    puts "Subversion test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
