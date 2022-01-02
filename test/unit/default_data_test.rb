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

class DefaultDataTest < ActiveSupport::TestCase
  include Redmine::I18n
  fixtures :roles

  def setup
    User.current = nil
  end

  def test_no_data
    assert !Redmine::DefaultData::Loader::no_data?
    clear_data
    assert Redmine::DefaultData::Loader::no_data?
  end

  def test_load
    clear_data
    assert Redmine::DefaultData::Loader::load('en')
    assert DocumentCategory.exists?
    assert IssuePriority.exists?
    assert TimeEntryActivity.exists?
    assert WorkflowTransition.exists?
    assert Query.exists?
  end

  def test_load_for_all_language
    valid_languages.each do |lang|
      clear_data
      begin
        assert Redmine::DefaultData::Loader::load(lang, :workflow => false)
        assert DocumentCategory.exists?
        assert IssuePriority.exists?
        assert TimeEntryActivity.exists?
        assert Query.exists?
      rescue ActiveRecord::RecordInvalid => e
        assert false, ":#{lang} default data is invalid (#{e.message})."
      end
    end
  end

  def clear_data
    Role.where("builtin = 0").delete_all
    Tracker.delete_all
    IssueStatus.delete_all
    Enumeration.delete_all
    WorkflowRule.delete_all
    Query.delete_all
  end
end
