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

class ProjectNestedSetConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  def setup
    User.current = nil
    CustomField.delete_all
  end

  def teardown
    Project.delete_all
  end

  def test_concurrency
    skip if sqlite?
    # Generates a project and destroys it in order
    # to load all needed classes before starting threads
    p = generate_project!
    p.destroy

    assert_difference 'Project.async_count.value', 60 do
      threads = []
      3.times do |i|
        threads << Thread.new(i) do
          ActiveRecord::Base.connection_pool.with_connection do
            begin
              10.times do
                p = generate_project!
                c1 = generate_project! :parent_id => p.id
                c2 = generate_project! :parent_id => p.id
                c3 = generate_project! :parent_id => p.id
                c2.reload.destroy
                c1.reload.destroy
              end
            rescue => e
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

  # Generates a bare project with random name
  # and identifier
  def generate_project!(attributes={})
    identifier = "a" + Redmine::Utils.random_hex(6)
    Project.generate!(
      {
        :identifier => identifier,
        :name => identifier,
        :tracker_ids => [],
        :enabled_module_names => []
      }.merge(attributes)
    )
  end
end
