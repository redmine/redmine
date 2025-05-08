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

class DestroyProjectJobTest < ActiveJob::TestCase
  setup do
    @project = Project.find 1
    @user = User.find_by_admin true
    ActionMailer::Base.deliveries.clear
  end

  test "schedule should mark project and children for deletion" do
    assert @project.descendants.any?
    DestroyProjectJob.schedule @project, user: @user
    @project.reload
    assert_equal Project::STATUS_SCHEDULED_FOR_DELETION, @project.status
    @project.descendants.each do |child|
      assert_equal Project::STATUS_SCHEDULED_FOR_DELETION, child.status
    end
  end

  test "schedule should enqueue job" do
    DestroyProjectJob.schedule @project, user: @user
    assert_enqueued_with(
      job: DestroyProjectJob,
      args: ->(job_args){
        job_args[0] == @project.id &&
        job_args[1] == @user.id
      }
    )
  end

  test "should destroy project and send email" do
    assert_difference 'Project.count', -5 do
      DestroyProjectJob.perform_now @project.id, @user.id, '127.0.0.1'
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
