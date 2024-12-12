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

class RepositoryMercurialTest < ActiveSupport::TestCase
  include Redmine::I18n

  REPOSITORY_PATH = Rails.root.join('tmp/test/mercurial_repository').to_s
  NUM_REV = 43

  def setup
    User.current = nil
    @project    = Project.find(3)
    @repository =
      Repository::Mercurial.create(
        :project => @project,
        :url     => REPOSITORY_PATH,
        :path_encoding => 'ISO-8859-1'
      )
    assert @repository
  end

  def test_blank_path_to_repository_error_message
    set_language_if_valid 'en'
    repo =
      Repository::Mercurial.new(
        :project      => @project,
        :identifier   => 'test'
      )
    assert !repo.save
    assert_include "Path to repository cannot be blank",
                   repo.errors.full_messages
  end

  def test_blank_path_to_repository_error_message_fr
    set_language_if_valid 'fr'
    repo =
      Repository::Mercurial.new(
        :project      => @project,
        :url          => "",
        :identifier   => 'test',
        :path_encoding => ''
      )
    assert !repo.save
    assert_include 'Chemin du dépôt doit être renseigné(e)', repo.errors.full_messages
  end

  if File.directory?(REPOSITORY_PATH)
    def test_scm_available
      klass = Repository::Mercurial
      assert_equal "Mercurial", klass.scm_name
      assert klass.scm_adapter_class
      assert_not_equal "", klass.scm_command
      assert_equal true, klass.scm_available
    end

    def test_entries_on_tip
      entries = @repository.entries
      assert_kind_of Redmine::Scm::Adapters::Entries, entries
    end

    def assert_entries(is_short_scmid=true)
      hex = "9d5b5b00419901478496242e0768deba1ce8c51e"
      scmid = scmid_for_assert(hex, is_short_scmid)
      [2, '400bb8672109', '400', 400].each do |r|
        entries1 = @repository.entries(nil, r)
        assert entries1
        assert_kind_of Redmine::Scm::Adapters::Entries, entries1
        assert_equal 3, entries1.size
        readme = entries1[2]
        assert_equal '1',   readme.lastrev.revision
        assert_equal scmid, readme.lastrev.identifier
        assert_equal '1',   readme.changeset.revision
        assert_equal scmid, readme.changeset.scmid
      end
    end
    private :assert_entries

    def test_entries_short_id
      assert_equal 0, @repository.changesets.count
      create_rev0_short_id
      assert_equal 1, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_entries(true)
    end

    def test_entries_long_id
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_entries(false)
    end

    def test_entry_on_tip
      entry = @repository.entry
      assert_kind_of Redmine::Scm::Adapters::Entry, entry
      assert_equal "", entry.path
      assert_equal 'dir', entry.kind
    end

    def assert_entry(is_short_scmid=true)
      hex = "0885933ad4f68d77c2649cd11f8311276e7ef7ce"
      scmid = scmid_for_assert(hex, is_short_scmid)
      ["README", "/README"].each do |path|
        ["0", "0885933ad4f6", "0885933ad4f68d77c2649cd11f8311276e7ef7ce"].each do |rev|
          entry = @repository.entry(path, rev)
          assert_kind_of Redmine::Scm::Adapters::Entry, entry
          assert_equal "README", entry.path
          assert_equal "file", entry.kind
          assert_equal '0', entry.lastrev.revision
          assert_equal scmid, entry.lastrev.identifier
        end
      end
      ["sources", "/sources", "/sources/"].each do |path|
        ["0", "0885933ad4f6", "0885933ad4f68d77c2649cd11f8311276e7ef7ce"].each do |rev|
          entry = @repository.entry(path, rev)
          assert_kind_of Redmine::Scm::Adapters::Entry, entry
          assert_equal "sources", entry.path
          assert_equal "dir", entry.kind
        end
      end
      ["sources/watchers_controller.rb", "/sources/watchers_controller.rb"].each do |path|
        ["0", "0885933ad4f6", "0885933ad4f68d77c2649cd11f8311276e7ef7ce"].each do |rev|
          entry = @repository.entry(path, rev)
          assert_kind_of Redmine::Scm::Adapters::Entry, entry
          assert_equal "sources/watchers_controller.rb", entry.path
          assert_equal "file", entry.kind
          assert_equal '0', entry.lastrev.revision
          assert_equal scmid, entry.lastrev.identifier
        end
      end
    end
    private :assert_entry

    def test_entry_short_id
      assert_equal 0, @repository.changesets.count
      create_rev0_short_id
      assert_equal 1, @repository.changesets.count
      assert_entry(true)
    end

    def test_entry_long_id
      assert_entry(false)
    end

    def test_fetch_changesets_from_scratch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_equal 53, @repository.filechanges.count
      rev0 = @repository.changesets.find_by_revision('0')
      assert_equal "Initial import.\nThe repository contains 3 files.",
                   rev0.comments
      assert_equal "0885933ad4f68d77c2649cd11f8311276e7ef7ce", rev0.scmid
      first_rev = @repository.changesets.first
      last_rev  = @repository.changesets.last
      assert_equal (NUM_REV - 1).to_s, first_rev.revision
      assert_equal "0", last_rev.revision
    end

    def test_fetch_changesets_keep_short_id
      assert_equal 0, @repository.changesets.count
      create_rev0_short_id
      assert_equal 1, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      rev1 = @repository.changesets.find_by_revision('1')
      assert_equal "9d5b5b004199", rev1.scmid
    end

    def test_fetch_changesets_keep_long_id
      assert_equal 0, @repository.changesets.count
      Changeset.create!(:repository   => @repository,
                        :committed_on => Time.now,
                        :revision     => '0',
                        :scmid        => '0885933ad4f68d77c2649cd11f8311276e7ef7ce',
                        :comments     => 'test')
      assert_equal 1, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      rev1 = @repository.changesets.find_by_revision('1')
      assert_equal "9d5b5b00419901478496242e0768deba1ce8c51e", rev1.scmid
    end

    def test_fetch_changesets_incremental
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      # Remove changesets with revision > 2
      @repository.changesets.each {|c| c.destroy if c.revision.to_i > 2}
      @project.reload
      @repository.reload
      assert_equal 3, @repository.changesets.count

      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
    end

    def test_isodatesec
      # Template keyword 'isodatesec' supported in Mercurial 1.0 and higher
      if @repository.scm.class.client_version_above?([1, 0])
        assert_equal 0, @repository.changesets.count
        @repository.fetch_changesets
        @project.reload
        assert_equal NUM_REV, @repository.changesets.count
        rev0_committed_on = Time.gm(2007, 12, 14, 9, 22, 52)
        assert_equal @repository.changesets.find_by_revision('0').committed_on, rev0_committed_on
      end
    end

    def test_changeset_order_by_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      c0 = @repository.latest_changeset
      c1 = @repository.changesets.find_by_revision('0')
      # sorted by revision (id), not by date
      assert c0.revision.to_i > c1.revision.to_i
      assert c0.committed_on  < c1.committed_on
    end

    def test_latest_changesets
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      # with_limit
      changesets = @repository.latest_changesets('', nil, 2)
      assert_equal [(NUM_REV - 1).to_s, (NUM_REV - 2).to_s], changesets.collect(&:revision)

      # with_filepath
      changesets =
        @repository.latest_changesets(
          '/sql_escape/percent%dir/percent%file1.txt', nil
        )
      assert_equal %w|30 11 10 9|, changesets.collect(&:revision)

      changesets =
        @repository.latest_changesets(
          '/sql_escape/underscore_dir/understrike_file.txt', nil
        )
      assert_equal %w|30 12 9|, changesets.collect(&:revision)

      changesets = @repository.latest_changesets('README', nil)
      assert_equal %w|31 30 28 17 8 6 1 0|, changesets.collect(&:revision)

      changesets = @repository.latest_changesets('README', '8')
      assert_equal %w|8 6 1 0|, changesets.collect(&:revision)

      changesets = @repository.latest_changesets('README', '8', 2)
      assert_equal %w|8 6|, changesets.collect(&:revision)

      # with_dirpath
      changesets = @repository.latest_changesets('images', nil)
      assert_equal %w|1 0|, changesets.collect(&:revision)

      path = 'sql_escape/percent%dir'
      changesets = @repository.latest_changesets(path, nil)
      assert_equal %w|30 13 11 10 9|, changesets.collect(&:revision)

      changesets = @repository.latest_changesets(path, '11')
      assert_equal %w|11 10 9|, changesets.collect(&:revision)

      changesets = @repository.latest_changesets(path, '11', 2)
      assert_equal %w|11 10|, changesets.collect(&:revision)

      path = 'sql_escape/underscore_dir'
      changesets = @repository.latest_changesets(path, nil)
      assert_equal %w|30 13 12 9|, changesets.collect(&:revision)

      changesets = @repository.latest_changesets(path, '12')
      assert_equal %w|12 9|, changesets.collect(&:revision)

      changesets = @repository.latest_changesets(path, '12', 1)
      assert_equal %w|12|, changesets.collect(&:revision)
    end

    def assert_latest_changesets_tag
      changesets = @repository.latest_changesets('', 'tag_test.00')
      assert_equal %w|5 4 3 2 1 0|, changesets.collect(&:revision)
    end
    private :assert_latest_changesets_tag

    def test_latest_changesets_tag
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_latest_changesets_tag
    end

    def test_latest_changesets_tag_short_id
      assert_equal 0, @repository.changesets.count
      create_rev0_short_id
      assert_equal 1, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_latest_changesets_tag
    end

    def test_latest_changesets_tag_with_path
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      changesets = @repository.latest_changesets('sources', 'tag_test.00')
      assert_equal %w|4 3 2 1 0|, changesets.collect(&:revision)
    end

    def test_latest_changesets_tag_with_limit
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      changesets = @repository.latest_changesets('', 'tag_test.00', 2)
      assert_equal %w|5 4|, changesets.collect(&:revision)

      changesets = @repository.latest_changesets('sources', 'tag_test.00', 2)
      assert_equal %w|4 3|, changesets.collect(&:revision)
    end

    def test_latest_changesets_branch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      if @repository.scm.class.client_version_above?([1, 6])
        changesets = @repository.latest_changesets('', 'branch-Ü-01')
        assert_equal %w|27 26|, changesets.collect(&:revision)
      end

      changesets = @repository.latest_changesets('latin-1-dir/test-Ü-subdir', 'branch-Ü-01')
      assert_equal %w|27|, changesets.collect(&:revision)
    end

    def assert_latest_changesets_default_branch
      changesets = @repository.latest_changesets('', 'default')
      assert_equal %w|31 28 24 6 4 3 2 1 0|, changesets.collect(&:revision)
    end
    private :assert_latest_changesets_default_branch

    def test_latest_changesets_default_branch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_latest_changesets_default_branch
    end

    def test_latest_changesets_default_branch_short_id
      assert_equal 0, @repository.changesets.count
      create_rev0_short_id
      assert_equal 1, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_latest_changesets_default_branch
    end

    def assert_copied_files(is_short_scmid=true)
      cs1 = @repository.changesets.find_by_revision('13')
      assert_not_nil cs1
      c1  = cs1.filechanges.sort_by(&:path)
      assert_equal 2, c1.size

      hex1 = "3a330eb329586ea2adb3f83237c23310e744ebe9"
      scmid1 = scmid_for_assert(hex1, is_short_scmid)
      assert_equal 'A', c1[0].action
      assert_equal '/sql_escape/percent%dir/percentfile1.txt',  c1[0].path
      assert_equal '/sql_escape/percent%dir/percent%file1.txt', c1[0].from_path
      assert_equal scmid1, c1[0].from_revision

      assert_equal 'A', c1[1].action
      assert_equal '/sql_escape/underscore_dir/understrike-file.txt', c1[1].path
      assert_equal '/sql_escape/underscore_dir/understrike_file.txt', c1[1].from_path

      cs2 = @repository.changesets.find_by_revision('15')
      c2  = cs2.filechanges
      assert_equal 1, c2.size

      hex2 = "933ca60293d78f7c7979dd123cc0c02431683575"
      scmid2 = scmid_for_assert(hex2, is_short_scmid)
      assert_equal 'A', c2[0].action
      assert_equal '/README (1)[2]&,%.-3_4', c2[0].path
      assert_equal '/README', c2[0].from_path
      assert_equal scmid2, c2[0].from_revision

      cs3 = @repository.changesets.find_by_revision('19')
      c3  = cs3.filechanges

      hex3 = "5d9891a1b4258ea256552aa856e388f2da28256a"
      scmid3 = scmid_for_assert(hex3, is_short_scmid)
      assert_equal 1, c3.size
      assert_equal 'A', c3[0].action
      assert_equal '/latin-1-dir/test-Ü-1.txt',  c3[0].path
      assert_equal '/latin-1-dir/test-Ü.txt',    c3[0].from_path
      assert_equal scmid3, c3[0].from_revision
    end
    private :assert_copied_files

    def test_copied_files_short_id
      assert_equal 0, @repository.changesets.count
      create_rev0_short_id
      assert_equal 1, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_copied_files(true)
    end

    def test_copied_files_long_id
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_copied_files(false)
    end

    def test_find_changeset_by_name
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      %w|2 400bb8672109 400|.each do |r|
        assert_equal '2', @repository.find_changeset_by_name(r).revision
      end
    end

    def test_find_changeset_by_invalid_name
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_nil @repository.find_changeset_by_name('100000')
    end

    def test_identifier
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      c = @repository.changesets.find_by_revision('2')
      assert_equal c.scmid, c.identifier
    end

    def test_format_identifier
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      c = @repository.changesets.find_by_revision('2')
      assert_equal '2:400bb8672109', c.format_identifier
    end

    def test_format_identifier_long_id
      assert_equal 0, @repository.changesets.count
      Changeset.create!(:repository   => @repository,
                        :committed_on => Time.now,
                        :revision     => '0',
                        :scmid        => '0885933ad4f68d77c2649cd11f8311276e7ef7ce',
                        :comments     => 'test')
      c = @repository.changesets.find_by_revision('0')
      assert_equal '0:0885933ad4f6', c.format_identifier
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

    def assert_parents(is_short_scmid=true)
      r1 = @repository.changesets.find_by_revision('0')
      assert_equal [], r1.parents
      r2 = @repository.changesets.find_by_revision('1')
      hex2 = "0885933ad4f68d77c2649cd11f8311276e7ef7ce"
      scmid2 = scmid_for_assert(hex2, is_short_scmid)
      assert_equal 1, r2.parents.length
      assert_equal scmid2, r2.parents[0].identifier
      r3 = @repository.changesets.find_by_revision('30')
      assert_equal 2, r3.parents.length
      r4 = [r3.parents[0].identifier, r3.parents[1].identifier].sort
      hex41 = "3a330eb329586ea2adb3f83237c23310e744ebe9"
      scmid41 = scmid_for_assert(hex41, is_short_scmid)
      hex42 = "a94b0528f24fe05ebaef496ae0500bb050772e36"
      scmid42 = scmid_for_assert(hex42, is_short_scmid)
      assert_equal scmid41, r4[0]
      assert_equal scmid42, r4[1]
    end
    private :assert_parents

    def test_parents_short_id
      assert_equal 0, @repository.changesets.count
      create_rev0_short_id
      assert_equal 1, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_parents(true)
    end

    def test_parents_long_id
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_parents(false)
    end

    def test_activities
      c = Changeset.new(:repository   => @repository,
                        :committed_on => Time.now,
                        :revision     => '123',
                        :scmid        => 'abc400bb8672',
                        :comments     => 'test')
      assert c.event_title.include?('123:abc400bb8672:')
      assert_equal 'abc400bb8672', c.event_url[:rev]
    end

    def test_previous
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      %w|28 3ae45e2d177d 3ae45|.each do |r1|
        changeset = @repository.find_changeset_by_name(r1)
        %w|27 7bbf4c738e71 7bbf|.each do |r2|
          assert_equal @repository.find_changeset_by_name(r2), changeset.previous
        end
      end
    end

    def test_previous_nil
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      %w|0 0885933ad4f6 0885|.each do |r1|
        changeset = @repository.find_changeset_by_name(r1)
        assert_nil changeset.previous
      end
    end

    def test_next
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      %w|27 7bbf4c738e71 7bbf|.each do |r2|
        changeset = @repository.find_changeset_by_name(r2)
        %w|28 3ae45e2d177d 3ae45|.each do |r1|
          assert_equal @repository.find_changeset_by_name(r1), changeset.next
        end
      end
    end

    def test_next_nil
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [(NUM_REV - 1).to_s, "ba20ebce08db", "ba20e"].each do |r1|
        changeset = @repository.find_changeset_by_name(r1)
        assert_nil changeset.next
      end
    end

    def test_scmid_for_inserting_db_short_id
      assert_equal 0, @repository.changesets.count
      create_rev0_short_id
      assert_equal 1, @repository.changesets.count
      rev = "0123456789012345678901234567890123456789"
      assert_equal 12, @repository.scmid_for_inserting_db(rev).length
    end

    def test_scmid_for_inserting_db_long_id
      rev = "0123456789012345678901234567890123456789"
      assert_equal 0, @repository.changesets.count
      assert_equal 40, @repository.scmid_for_inserting_db(rev).length
      Changeset.create!(:repository   => @repository,
                        :committed_on => Time.now,
                        :revision     => '0',
                        :scmid        => rev,
                        :comments     => 'test')
      assert_equal 1, @repository.changesets.count
      assert_equal 40, @repository.scmid_for_inserting_db(rev).length
    end

    def test_scmid_for_assert
      rev = "0123456789012345678901234567890123456789"
      assert_equal rev, scmid_for_assert(rev, false)
      assert_equal "012345678901", scmid_for_assert(rev, true)
    end

    private

    def scmid_for_assert(hex, is_short=true)
      is_short ? hex[0, 12] : hex
    end

    def create_rev0_short_id
      Changeset.create!(:repository   => @repository,
                        :committed_on => Time.now,
                        :revision     => '0',
                        :scmid        => '0885933ad4f6',
                        :comments     => 'test')
    end
  else
    puts "Mercurial test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
