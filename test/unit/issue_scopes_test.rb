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

class IssueScopesTest < ActiveSupport::TestCase
  def setup
    User.current = nil
  end

  def test_cross_project_scope_without_project_should_return_all_issues
    ids = Issue.cross_project_scope(nil).pluck(:id).sort
    assert_equal Issue.pluck(:id).sort, ids
  end

  def test_cross_project_scope_with_project_should_return_project_issues
    project = Project.find(1)
    ids = Issue.cross_project_scope(project).pluck(:id).sort
    assert_equal project.issues.pluck(:id).sort, ids
  end

  def test_cross_project_scope_with_all_scope_should_return_all_issues
    project = Project.find(1)
    ids = Issue.cross_project_scope(project, 'all').pluck(:id).sort
    assert_equal Issue.pluck(:id).sort, ids
  end

  def test_cross_project_scope_with_system_scope_should_return_all_issues
    project = Project.find(1)
    ids = Issue.cross_project_scope(project, 'system').pluck(:id).sort
    assert_equal Issue.pluck(:id).sort, ids
  end

  def test_cross_project_scope_with_tree_scope_should_return_tree_issues
    project = Project.find(5)
    ids = Issue.cross_project_scope(project, 'tree').pluck(:id).sort
    assert_equal project.root.self_and_descendants.map{|p| p.issues.pluck(:id)}.flatten.sort, ids
  end

  def test_cross_project_scope_with_hierarchy_scope_should_return_hierarchy_issues
    project = Project.find(5)
    ids = Issue.cross_project_scope(project, 'hierarchy').pluck(:id).sort
    assert_equal (project.self_and_descendants + project.ancestors).map{|p| p.issues.pluck(:id)}.flatten.sort, ids
  end

  def test_cross_project_scope_with_descendants_scope_should_return_descendants_issues
    project = Project.find(5)
    ids = Issue.cross_project_scope(project, 'descendants').pluck(:id).sort
    assert_equal project.self_and_descendants.map{|p| p.issues.pluck(:id)}.flatten.sort, ids
  end
end
