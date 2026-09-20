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

require_relative '../../test_helper'

class DestroyProjectsJobTest < ActiveJob::TestCase
  setup do
    @projects = Project.where(id: [1, 2]).order(:id).to_a
    @user = User.find_by_admin true
    ActionMailer::Base.deliveries.clear
  end

  test "schedule should mark projects and children for deletion" do
    DestroyProjectsJob.schedule @projects, user: @user
    @projects.each do |project|
      project.reload
      assert_equal Project::STATUS_SCHEDULED_FOR_DELETION, project.status
      project.descendants.each do |child|
        assert_equal Project::STATUS_SCHEDULED_FOR_DELETION, child.status
      end
    end
  end

  test "schedule must not mark unrelated projects when the nested set is rebalanced between load and update_all" do
    # Reproduces the race condition where projects[].self_and_descendants
    # uses cached in-memory lft/rgt to build a range UPDATE. When the
    # nested set is rebalanced (concurrent project create/rename/move/
    # destroy) between the controller load and the update, the cached
    # range can match unrelated projects, which then get status=10 even
    # though their ids are never passed to perform_later -> the
    # "vanished but not deleted" customer-visible symptom.
    target = Project.find(1)               # eCookbook, root w/ descendants
    victim = Project.find(2)               # onlinestore, unrelated root
    cached_lft, cached_rgt = target.lft, target.rgt

    assert_not_equal Project::STATUS_SCHEDULED_FOR_DELETION, victim.status

    # Simulate a concurrent transaction renaming the unrelated root so it
    # sorts before `target`. before_update :move_in_nested_set fires (see
    # project_nested_set.rb:28-32) and rebalances the tree under
    # lock_nested_set. After this, the database lft/rgt of every project
    # has shifted, but our in-memory `target` still holds the values it
    # had when it was loaded.
    victim.update!(name: 'AAA renamed earlier than ecookbook')
    victim.reload
    assert victim.lft >= cached_lft && victim.rgt <= cached_rgt,
           "test setup: victim should now sit inside target's stale range"

    # in-memory target is intentionally NOT reloaded
    assert_equal cached_lft, target.lft
    assert_equal cached_rgt, target.rgt

    DestroyProjectsJob.schedule [target], user: @user

    victim.reload
    assert_not_equal Project::STATUS_SCHEDULED_FOR_DELETION, victim.status,
                     "Project #{victim.id} (#{victim.name}) was marked for deletion even though it was not in the deletion id list. "
  end

  test "schedule should enqueue job" do
    assert_enqueued_with(
      job: DestroyProjectsJob,
      args: [[1, 2], @user.id, '127.0.0.1']
    ) do
      @user.remote_ip = '127.0.0.1'
      DestroyProjectsJob.schedule @projects, user: @user
    end
  end

  test "should destroy projects and send emails" do
    assert_difference 'Project.count', -6 do
      DestroyProjectsJob.perform_now @projects.map(&:id), @user.id, '127.0.0.1'
    end
    if m = ActionMailer::Base.deliveries.last
      assert_match /Security notification/, m.subject
      assert_match /deleted successfully/, m.text_part.to_s
    else
      assert_enqueued_with(
        job: Mailer::DeliveryJob,
        args: ->(job_args){
          job_args[1] == 'security_notification' &&
          job_args[3].to_s.include?("mail_destroy_project_with_subprojects_successful")
        }
      )
    end
  end

  def queue_adapter_for_test
    ActiveJob::QueueAdapters::TestAdapter.new
  end
end
