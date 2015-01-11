# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class RepositoryDarcsTest < ActiveSupport::TestCase
  fixtures :projects

  include Redmine::I18n

  REPOSITORY_PATH = Rails.root.join('tmp/test/darcs_repository').to_s
  NUM_REV = 6

  def setup
    @project = Project.find(3)
    @repository = Repository::Darcs.create(
                      :project      => @project,
                      :url          => REPOSITORY_PATH,
                      :log_encoding => 'UTF-8'
                      )
    assert @repository
  end

  def test_blank_path_to_repository_error_message
    set_language_if_valid 'en'
    repo = Repository::Darcs.new(
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
    str = "Chemin du d\xc3\xa9p\xc3\xb4t doit \xc3\xaatre renseign\xc3\xa9(e)".force_encoding('UTF-8')
    repo = Repository::Darcs.new(
                          :project      => @project,
                          :url          => "",
                          :identifier   => 'test',
                          :log_encoding => 'UTF-8'
                        )
    assert !repo.save
    assert_include str, repo.errors.full_messages
  end

  if File.directory?(REPOSITORY_PATH)
    def test_fetch_changesets_from_scratch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload

      assert_equal NUM_REV, @repository.changesets.count
      assert_equal 13, @repository.filechanges.count
      assert_equal "Initial commit.", @repository.changesets.find_by_revision('1').comments
    end

    def test_fetch_changesets_incremental
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count

      # Remove changesets with revision > 3
      @repository.changesets.each {|c| c.destroy if c.revision.to_i > 3}
      @project.reload
      @repository.reload
      assert_equal 3, @repository.changesets.count

      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
    end

    def test_entries
      entries = @repository.entries
      assert_kind_of Redmine::Scm::Adapters::Entries, entries
    end

    def test_entries_invalid_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      assert_nil @repository.entries('', '123')
    end

    def test_deleted_files_should_not_be_listed
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      entries = @repository.entries('sources')
      assert entries.detect {|e| e.name == 'watchers_controller.rb'}
      assert_nil entries.detect {|e| e.name == 'welcome_controller.rb'}
    end

    def test_cat
      if @repository.scm.supports_cat?
        assert_equal 0, @repository.changesets.count
        @repository.fetch_changesets
        @project.reload
        assert_equal NUM_REV, @repository.changesets.count
        cat = @repository.cat("sources/welcome_controller.rb", 2)
        assert_not_nil cat
        assert cat.include?('class WelcomeController < ApplicationController')
      end
    end
  else
    puts "Darcs test repository NOT FOUND. Skipping unit tests !!!"
    def test_fake; assert true end
  end
end
