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

class IssueNestedSetConcurrencyTest < ActiveSupport::TestCase
  fixtures :projects, :users,
           :trackers, :projects_trackers,
           :enabled_modules,
           :issue_statuses,
           :enumerations

  self.use_transactional_fixtures = false

  def setup
    skip if sqlite?
    CustomField.delete_all
  end

  def teardown
    Issue.delete_all
  end

  def test_concurrency
    # Generates an issue and destroys it in order
    # to load all needed classes before starting threads
    i = Issue.generate!
    i.destroy

    root = Issue.generate!
    assert_difference 'Issue.count', 60 do
      threaded(3) do
        10.times do
          i = Issue.generate! :parent_issue_id => root.id
          c1 = Issue.generate! :parent_issue_id => i.id
          c2 = Issue.generate! :parent_issue_id => i.id
          c3 = Issue.generate! :parent_issue_id => i.id
          c2.reload.destroy
          c1.reload.destroy
        end
      end
    end
  end

  def test_concurrent_subtasks_creation
    root = Issue.generate!
    assert_difference 'Issue.count', 30 do
      threaded(3) do
        10.times do
          Issue.generate! :parent_issue_id => root.id
        end
      end
    end
    root.reload
    assert_equal [1, 62], [root.lft, root.rgt]
    children_bounds = root.children.sort_by(&:lft).map {|c| [c.lft, c.rgt]}.flatten
    assert_equal (2..61).to_a, children_bounds
  end

  private

  def threaded(count, &block)
    with_settings :notified_events => [] do
      threads = []
      count.times do |i|
        threads << Thread.new(i) do
          ActiveRecord::Base.connection_pool.with_connection do
            begin
              yield
            rescue Exception => e
              Thread.current[:exception] = e.message
            end
          end
        end
      end
      threads.each do |thread|
        thread.join
        assert_nil thread[:exception]
      end
    end
  end
end
