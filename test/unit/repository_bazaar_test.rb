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

class RepositoryBazaarTest < ActiveSupport::TestCase
  include Redmine::I18n

  REPOSITORY_PATH = repository_path('bazaar')
  REPOSITORY_PATH_TRUNK = File.join(REPOSITORY_PATH, "trunk")
  NUM_REV = 4

  REPOSITORY_PATH_NON_ASCII = Rails.root.join(REPOSITORY_PATH + '/' + 'non_ascii').to_s

  # Bazaar core does not support xml output such as Subversion and Mercurial.
  # "bzr" command output and command line parameter depend on locale.
  # So, non ASCII path tests cannot run independent locale.
  #
  # On Windows, because it is too hard to change system locale,
  # you cannot run Bazaar non ASCII path tests.
  #
  RUN_LATIN1_OUTPUT_TEST = (RUBY_PLATFORM != 'java' &&
                             Encoding.locale_charmap == "ISO-8859-1")

  CHAR_1_UTF8_HEX   = 'Ü'
  CHAR_1_LATIN1_HEX = "\xdc".b

  def setup
    User.current = nil
    @project = Project.find(3)
    @repository =
      Repository::Bazaar.create(
        :project => @project, :url => REPOSITORY_PATH_TRUNK,
        :log_encoding => 'UTF-8'
      )
    assert @repository
  end

  def test_blank_path_to_repository_error_message
    set_language_if_valid 'en'
    repo =
      Repository::Bazaar.new(
        :project      => @project,
        :identifier   => 'test',
        :log_encoding => 'UTF-8'
      )
    assert !repo.save
    assert_include "Path to repository cannot be blank",
                   repo.errors.full_messages
  end

  def test_blank_path_to_repository_error_message_fr
    set_language_if_valid 'fr'
    repo =
      Repository::Bazaar.new(
        :project      => @project,
        :url          => "",
        :identifier   => 'test',
        :log_encoding => 'UTF-8'
      )
    assert !repo.save
    assert_include 'Chemin du dépôt doit être renseigné(e)', repo.errors.full_messages
  end

  if File.directory?(REPOSITORY_PATH_TRUNK)
    def test_fetch_changesets_from_scratch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload

      assert_equal NUM_REV, @repository.changesets.count
      assert_equal 9, @repository.filechanges.count
      assert_equal 'Initial import', @repository.changesets.find_by_revision('1').comments
    end

    def test_fetch_changesets_incremental
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      # Remove changesets with revision > 5
      @repository.changesets.each {|c| c.destroy if c.revision.to_i > 2}
      @project.reload
      @repository.reload
      assert_equal 2, @repository.changesets.count

      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
    end

    def test_entries
      entries = @repository.entries
      assert_kind_of Redmine::Scm::Adapters::Entries, entries
      assert_equal 2, entries.size

      assert_equal 'dir', entries[0].kind
      assert_equal 'directory', entries[0].name
      assert_equal 'directory', entries[0].path

      assert_equal 'file', entries[1].kind
      assert_equal 'doc-mkdir.txt', entries[1].name
      assert_equal 'doc-mkdir.txt', entries[1].path
    end

    def test_entries_in_subdirectory
      entries = @repository.entries('directory')
      assert_equal 3, entries.size

      assert_equal 'file', entries.last.kind
      assert_equal 'edit.png', entries.last.name
      assert_equal 'directory/edit.png', entries.last.path
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
      changeset = @repository.find_changeset_by_name('4')
      assert_nil changeset.next
    end

    if File.directory?(REPOSITORY_PATH_NON_ASCII) && RUN_LATIN1_OUTPUT_TEST
      # https://www.redmine.org/issues/42024
      def skip_bzr_failure_on_ubuntu24
        return unless File.exist?('/etc/os-release')

        os_release = File.read('/etc/os-release')
        name = os_release[/^NAME="(.+?)"$/, 1]
        version = os_release[/^VERSION_ID="(.+?)"$/, 1]

        if name == 'Ubuntu' && version == '24.04'
          skip 'bzr command fails on Ubuntu 24.04, causing this test to fail'
        end
      end

      def test_cat_latin1_path
        skip_bzr_failure_on_ubuntu24

        latin1_repo = create_latin1_repo
        buf =
          latin1_repo.cat(
            "test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-2.txt", 2
          )
        assert buf
        lines = buf.split("\n")
        assert_equal 2, lines.length
        assert_equal 'It is written in Python.', lines[1]
        buf =
          latin1_repo.cat(
            "test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-1.txt", 2
          )
        assert buf
        lines = buf.split("\n")
        assert_equal 1, lines.length
        assert_equal "test-#{CHAR_1_LATIN1_HEX}.txt", lines[0]
      end

      def test_annotate_latin1_path
        skip_bzr_failure_on_ubuntu24

        latin1_repo = create_latin1_repo
        ann1 =
          latin1_repo.annotate(
            "test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-2.txt", 2
          )
        assert_equal 2, ann1.lines.size
        assert_equal '2', ann1.revisions[0].identifier
        assert_equal 'test00@', ann1.revisions[0].author
        assert_equal 'It is written in Python.', ann1.lines[1]
        ann2 =
          latin1_repo.annotate(
            "test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-1.txt", 2
          )
        assert_equal 1, ann2.lines.size
        assert_equal '2', ann2.revisions[0].identifier
        assert_equal 'test00@', ann2.revisions[0].author
        assert_equal "test-#{CHAR_1_LATIN1_HEX}.txt", ann2.lines[0]
      end

      def test_diff_latin1_path
        skip_bzr_failure_on_ubuntu24

        latin1_repo = create_latin1_repo
        diff1 =
          latin1_repo.diff(
            "test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-1.txt", 2, 1
          )
        assert_equal 7, diff1.size
        buf =  diff1[5].gsub(/\r\n|\r|\n/, "")
        assert_equal "+test-#{CHAR_1_LATIN1_HEX}.txt", buf
      end

      def test_entries_latin1_path
        skip_bzr_failure_on_ubuntu24

        latin1_repo = create_latin1_repo
        entries = latin1_repo.entries("test-#{CHAR_1_UTF8_HEX}-dir", 2)
        assert_kind_of Redmine::Scm::Adapters::Entries, entries
        assert_equal 3, entries.size
        assert_equal 'file', entries[1].kind
        assert_equal "test-#{CHAR_1_UTF8_HEX}-1.txt", entries[0].name
        assert_equal "test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-1.txt", entries[0].path
      end

      def test_entry_latin1_path
        skip_bzr_failure_on_ubuntu24

        latin1_repo = create_latin1_repo
        ["test-#{CHAR_1_UTF8_HEX}-dir",
         "/test-#{CHAR_1_UTF8_HEX}-dir",
         "/test-#{CHAR_1_UTF8_HEX}-dir/"].each do |path|
          entry = latin1_repo.entry(path, 2)
          assert_equal "test-#{CHAR_1_UTF8_HEX}-dir", entry.path
          assert_equal "dir", entry.kind
        end
        ["test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-1.txt",
         "/test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-1.txt"].each do |path|
          entry = latin1_repo.entry(path, 2)
          assert_equal "test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-1.txt",
                       entry.path
          assert_equal "file", entry.kind
        end
      end

      def test_changeset_latin1_path
        skip_bzr_failure_on_ubuntu24

        latin1_repo = create_latin1_repo
        assert_equal 0, latin1_repo.changesets.count
        latin1_repo.fetch_changesets
        @project.reload
        assert_equal 3, latin1_repo.changesets.count

        cs2 = latin1_repo.changesets.find_by_revision('2')
        assert_not_nil cs2
        assert_equal "test-#{CHAR_1_UTF8_HEX}", cs2.comments
        c2  = cs2.filechanges.sort_by(&:path)
        assert_equal 4, c2.size
        assert_equal 'A', c2[0].action
        assert_equal "/test-#{CHAR_1_UTF8_HEX}-dir/", c2[0].path
        assert_equal 'A', c2[1].action
        assert_equal "/test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-1.txt", c2[1].path
        assert_equal 'A', c2[2].action
        assert_equal "/test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-2.txt", c2[2].path
        assert_equal 'A', c2[3].action
        assert_equal "/test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}.txt", c2[3].path

        cs3 = latin1_repo.changesets.find_by_revision('3')
        assert_not_nil cs3
        assert_equal "modify, move and delete #{CHAR_1_UTF8_HEX} files", cs3.comments
        c3  = cs3.filechanges.sort_by(&:path)
        assert_equal 3, c3.size
        assert_equal 'M', c3[0].action
        assert_equal "/test-#{CHAR_1_UTF8_HEX}-1.txt", c3[0].path
        assert_equal 'D', c3[1].action
        assert_equal "/test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}-2.txt", c3[1].path
        assert_equal 'M', c3[2].action
        assert_equal "/test-#{CHAR_1_UTF8_HEX}-dir/test-#{CHAR_1_UTF8_HEX}.txt", c3[2].path
      end
    else
      msg = "Bazaar non ASCII output test cannot run on this environment.\n"
      msg += "Encoding.locale_charmap: " + Encoding.locale_charmap + "\n"
      puts msg
    end

    private

    def create_latin1_repo
      repo =
        Repository::Bazaar.create(
          :project      => @project,
          :identifier   => 'latin1',
          :url => REPOSITORY_PATH_NON_ASCII,
          :log_encoding => 'ISO-8859-1'
        )
      assert repo
      repo
    end
  else
    puts "Bazaar test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
