# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class RepositoryFilesystemTest < ActiveSupport::TestCase
  fixtures :projects

  include Redmine::I18n

  REPOSITORY_PATH = Rails.root.join('tmp/test/filesystem_repository').to_s

  def setup
    User.current = nil
    @project = Project.find(3)
    Setting.enabled_scm << 'Filesystem' unless Setting.enabled_scm.include?('Filesystem')
    @repository = Repository::Filesystem.create(
                               :project => @project,
                               :url     => REPOSITORY_PATH
                                 )
    assert @repository
  end

  def test_blank_root_directory_error_message
    set_language_if_valid 'en'
    repo = Repository::Filesystem.new(
                          :project      => @project,
                          :identifier   => 'test'
                        )
    assert !repo.save
    assert_include "Root directory cannot be blank",
                   repo.errors.full_messages
  end

  def test_blank_root_directory_error_message_fr
    set_language_if_valid 'fr'
    repo = Repository::Filesystem.new(
                          :project      => @project,
                          :url          => "",
                          :identifier   => 'test',
                          :path_encoding => ''
                        )
    assert !repo.save
    assert_include 'Répertoire racine doit être renseigné(e)', repo.errors.full_messages
  end

  if File.directory?(REPOSITORY_PATH)
    def test_fetch_changesets
      assert_equal 0, @repository.changesets.count
      assert_equal 0, @repository.filechanges.count
      @repository.fetch_changesets
      @project.reload
      assert_equal 0, @repository.changesets.count
      assert_equal 0, @repository.filechanges.count
    end

    def test_entries
      entries = @repository.entries("", 2)
      assert_kind_of Redmine::Scm::Adapters::Entries, entries
      assert_equal 3, entries.size
    end

    def test_entries_in_directory
      assert_equal 2, @repository.entries("dir", 3).size
    end

    def test_cat
      assert_equal "TEST CAT\n", @repository.scm.cat("test")
    end
  else
    puts "Filesystem test repository NOT FOUND. Skipping unit tests !!! See doc/RUNNING_TESTS."
    def test_fake; assert true end
  end
end
