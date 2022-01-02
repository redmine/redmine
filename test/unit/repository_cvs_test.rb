# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
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
require 'pp'
class RepositoryCvsTest < ActiveSupport::TestCase
  fixtures :projects

  include Redmine::I18n

  REPOSITORY_PATH = repository_path('cvs')
  REPOSITORY_PATH.tr!('/', "\\") if Redmine::Platform.mswin?
  # CVS module
  MODULE_NAME    = 'test'
  CHANGESETS_NUM = 7

  def setup
    User.current = nil
    @project = Project.find(3)
    @repository = Repository::Cvs.create(:project  => @project,
                                         :root_url => REPOSITORY_PATH,
                                         :url      => MODULE_NAME,
                                         :log_encoding => 'UTF-8')
    assert @repository
  end

  def test_blank_module_error_message
    set_language_if_valid 'en'
    repo = Repository::Cvs.new(
                          :project      => @project,
                          :identifier   => 'test',
                          :log_encoding => 'UTF-8',
                          :root_url     => REPOSITORY_PATH
                        )
    assert !repo.save
    assert_include "Module cannot be blank",
                   repo.errors.full_messages
  end

  def test_blank_module_error_message_fr
    set_language_if_valid 'fr'
    repo = Repository::Cvs.new(
                          :project       => @project,
                          :identifier    => 'test',
                          :log_encoding  => 'UTF-8',
                          :path_encoding => '',
                          :url           => '',
                          :root_url      => REPOSITORY_PATH
                        )
    assert !repo.save
    assert_include 'Module doit être renseigné(e)', repo.errors.full_messages
  end

  def test_blank_cvsroot_error_message
    set_language_if_valid 'en'
    repo = Repository::Cvs.new(
                          :project      => @project,
                          :identifier   => 'test',
                          :log_encoding => 'UTF-8',
                          :url          => MODULE_NAME
                        )
    assert !repo.save
    assert_include "CVSROOT cannot be blank",
                   repo.errors.full_messages
  end

  def test_blank_cvsroot_error_message_fr
    set_language_if_valid 'fr'
    repo = Repository::Cvs.new(
                          :project       => @project,
                          :identifier    => 'test',
                          :log_encoding  => 'UTF-8',
                          :path_encoding => '',
                          :url           => MODULE_NAME,
                          :root_url      => ''
                        )
    assert !repo.save
    assert_include 'CVSROOT doit être renseigné(e)', repo.errors.full_messages
  end

  def test_root_url_should_be_validated_against_regexp_set_in_configuration
    Redmine::Configuration.with 'scm_cvs_path_regexp' => '/cvspath/[a-z]+' do
      repo = Repository::Cvs.new(
        :project       => @project,
        :identifier    => 'test',
        :log_encoding  => 'UTF-8',
        :path_encoding => '',
        :url           => MODULE_NAME
      )
      repo.root_url = '/wrong_path'
      assert !repo.valid?
      assert repo.errors[:root_url].present?

      repo.root_url = '/cvspath/foo'
      assert repo.valid?
    end
  end

  if File.directory?(REPOSITORY_PATH)
    def test_fetch_changesets_from_scratch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload

      assert_equal CHANGESETS_NUM, @repository.changesets.count
      assert_equal 16, @repository.filechanges.count
      assert_not_nil @repository.changesets.find_by_comments('Two files changed')

      r2 = @repository.changesets.find_by_revision('2')
      assert_equal 'v1-20071213-162510', r2.scmid
    end

    def test_fetch_changesets_incremental
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal CHANGESETS_NUM, @repository.changesets.count

      # Remove changesets with revision > 3
      @repository.changesets.each {|c| c.destroy if c.revision.to_i > 3}
      @project.reload
      @repository.reload
      assert_equal 3, @repository.changesets.count
      assert_equal %w|3 2 1|, @repository.changesets.collect(&:revision)

      rev3_commit = @repository.changesets.reorder('committed_on DESC').first
      assert_equal '3', rev3_commit.revision
      # 2007-12-14 01:27:22 +0900
      rev3_committed_on = Time.gm(2007, 12, 13, 16, 27, 22)
      assert_equal 'HEAD-20071213-162722', rev3_commit.scmid
      assert_equal rev3_committed_on, rev3_commit.committed_on
      latest_rev = @repository.latest_changeset
      assert_equal rev3_committed_on, latest_rev.committed_on

      @repository.fetch_changesets
      @project.reload
      @repository.reload
      assert_equal CHANGESETS_NUM, @repository.changesets.count
      assert_equal %w|7 6 5 4 3 2 1|, @repository.changesets.collect(&:revision)
      rev5_commit = @repository.changesets.find_by_revision('5')
      assert_equal 'HEAD-20071213-163001', rev5_commit.scmid
      # 2007-12-14 01:30:01 +0900
      rev5_committed_on = Time.gm(2007, 12, 13, 16, 30, 1)
      assert_equal rev5_committed_on, rev5_commit.committed_on
    end

    def test_deleted_files_should_not_be_listed
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal CHANGESETS_NUM, @repository.changesets.count

      entries = @repository.entries('sources')
      assert entries.detect {|e| e.name == 'watchers_controller.rb'}
      assert_nil entries.detect {|e| e.name == 'welcome_controller.rb'}
    end

    def test_entries_rev3
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal CHANGESETS_NUM, @repository.changesets.count

      rev3_commit = @repository.changesets.find_by_revision('3')
      assert_equal "3", rev3_commit.revision
      assert_equal "LANG", rev3_commit.committer
      assert_equal 2, rev3_commit.filechanges.length
      filechanges = rev3_commit.filechanges.order(:path => :asc)
      assert_equal "1.2", filechanges[0].revision
      assert_equal "1.2", filechanges[1].revision
      assert_equal "/README", filechanges[0].path
      assert_equal "/sources/watchers_controller.rb", filechanges[1].path

      entries = @repository.entries('', '3')
      assert_kind_of Redmine::Scm::Adapters::Entries, entries
      assert_equal 3, entries.size
      assert_equal "README", entries[2].name
      assert_equal 'UTF-8', entries[2].path.encoding.to_s
      assert_equal Time.gm(2007, 12, 13, 16, 27, 22), entries[2].lastrev.time
      assert_equal '3', entries[2].lastrev.identifier
      assert_equal '3', entries[2].lastrev.revision
      assert_equal 'LANG', entries[2].lastrev.author
    end

    def test_entries_invalid_path
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal CHANGESETS_NUM, @repository.changesets.count
      assert_nil @repository.entries('missing')
      assert_nil @repository.entries('missing', '3')
    end

    def test_entries_invalid_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal CHANGESETS_NUM, @repository.changesets.count
      assert_nil @repository.entries('', '123')
    end

    def test_cat
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal CHANGESETS_NUM, @repository.changesets.count
      buf = @repository.cat('README')
      assert buf
      lines = buf.split("\n")
      assert_equal 3, lines.length
      buf = lines[1].gsub(/\r$/, "")
      assert_equal 'with one change', buf
      buf = @repository.cat('README', '1')
      assert buf
      lines = buf.split("\n")
      assert_equal 1, lines.length
      buf = lines[0].gsub(/\r$/, "")
      assert_equal 'CVS test repository', buf
      assert_nil @repository.cat('missing.rb')

      # sources/welcome_controller.rb is removed at revision 5.
      assert @repository.cat('sources/welcome_controller.rb', '4')
      assert @repository.cat('sources/welcome_controller.rb', '5').blank?

      # invalid revision
      assert @repository.cat('README', '123').blank?
    end

    def test_annotate
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal CHANGESETS_NUM, @repository.changesets.count
      ann = @repository.annotate('README')
      assert ann
      assert_equal 3, ann.revisions.length
      assert_equal '1.2', ann.revisions[1].revision
      assert_equal 'LANG', ann.revisions[1].author
      assert_equal 'with one change', ann.lines[1]

      ann = @repository.annotate('README', '1')
      assert ann
      assert_equal 1, ann.revisions.length
      assert_equal '1.1', ann.revisions[0].revision
      assert_equal 'LANG', ann.revisions[0].author
      assert_equal 'CVS test repository', ann.lines[0]

      # invalid revision
      assert_nil @repository.annotate('README', '123')
    end

  else
    puts "CVS test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
