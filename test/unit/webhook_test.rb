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
require 'pp'

class WebhookTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    # Set ActiveJob to use the test adapter
    @original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test

    @project = Project.find 'ecookbook'
    @dlopper = User.find_by_login 'dlopper'
    @role = Role.find_by_name 'Developer'
    @role.permissions << :use_webhooks; @role.save!
    @issue = @project.issues.first
    WebhookEndpointValidator.class_eval do
      @blocked_hosts = nil
    end
  end

  teardown do
    # Restore the original adapter
    ActiveJob::Base.queue_adapter = @original_adapter
  end

  test "should validate url" do
    Redmine::Configuration.with('webhook_blocklist' => ['*.example.org', '10.0.0.0/8', '192.168.0.0/16']) do
      %w[
        mailto:user@example.com
        https://x.example.org/
        https://example.org/
        https://x.example.org/foo/bar?a=b
        foobar
        example.com
        https://10.1.0.12/
      ].each do |url|
        hook = Webhook.new(url: url)
        assert_not hook.valid?, "URL '#{url}' should be invalid"
        assert hook.errors[:url].any?
      end
    end
  end

  test "should validate secret length" do
    hook = Webhook.new secret: 'abdc' * 100
    assert_not hook.valid?
    assert hook.errors[:secret].any?
  end

  test "should validate events" do
    Webhook.new.setable_event_names.each do |event|
      h = create_hook events: [event]
      assert h.persisted?
    end
    hook = Webhook.new(events: ['issue.created', 'invalid.event'])
    assert_not hook.valid?
    assert hook.errors[:events].any?
    assert_raise(ActiveRecord::SerializationTypeMismatch){ Webhook.new(events: 'issue.created') }
  end

  test "should clean up project list based on permissions on save" do
    h = create_hook
    assert_equal [@project], h.projects
    @role.permissions.delete :use_webhooks
    @role.save!

    h.reload
    h.save
    h.reload
    assert_equal [], h.projects
  end

  test "should clean up project list based on project visibility on save" do
    h = create_hook
    assert_equal [@project], h.projects
    @project.memberships.destroy_all
    @project.update is_public: false

    h.reload
    h.save
    h.reload
    assert_equal [], h.projects
  end

  test "should filter setable projects" do
    assert_equal [@project], Webhook.new(user: @dlopper).setable_projects

    @role.permissions.delete :use_webhooks
    @role.save!
    @dlopper.reload
    assert_equal [], Webhook.new(user: @dlopper).setable_projects
  end

  test "should check ip address at run time" do
    Redmine::Configuration.with('webhook_blocklist' => ['*.example.org', '10.0.0.0/8', '192.168.0.0/16']) do
      %w[
        127.0.0.0
        127.0.0.1
        10.0.0.0
        10.0.1.0
        169.254.1.9
        192.168.2.1
        224.0.0.1
        ::1/128
        fe80::/10
      ].each do |ip|
        h = Webhook.new url: "http://#{ip}"
        assert_not h.valid?, "IP #{ip} should be invalid"
        assert h.errors[:url].any?
      end
    end
  end

  test "should find hooks for issue" do
    hook = create_hook
    assert @issue.visible?(hook.user)
    assert_equal [hook], Webhook.hooks_for('issue.created', @issue)
    assert_equal [], Webhook.hooks_for('issue.deleted', @issue)
    @issue.update_column :project_id, 99
    assert_equal [], Webhook.hooks_for('issue.created', @issue)
  end

  test "should check permission when looking for hooks" do
    hook = create_hook
    assert @issue.visible?(hook.user)
    assert_equal [hook], Webhook.hooks_for('issue.created', @issue)
    @role.permissions.delete :use_webhooks
    @role.save!
    assert_equal [], Webhook.hooks_for('issue.created', @issue)
  end

  test "should not find inactive hook" do
    hook = create_hook active: false
    assert @issue.visible?(hook.user)
    assert_equal [], Webhook.hooks_for('issue.created', @issue)
  end

  test "should not find hook of inactive user" do
    admin = User.find_by_login 'admin'
    hook = create_hook user: admin
    assert_equal [hook], Webhook.hooks_for('issue.created', @issue)
    admin.update_column :status, 3
    assert_equal [], Webhook.hooks_for('issue.created', @issue)
  end

  test "should find hook for deleted issue" do
    hook = create_hook events: ['issue.deleted']
    @issue.destroy
    assert_equal [hook], Webhook.hooks_for('issue.deleted', @issue)
  end

  test "schedule should enqueue jobs for hooks" do
    with_settings webhooks_enabled: '1' do
      hook = create_hook
      assert_enqueued_jobs 1 do
        assert_enqueued_with(job: WebhookJob) do
          Webhook.trigger('issue.created', @issue)
        end
      end
    end
  end

  test "should not enqueue job for inactive hook" do
    with_settings webhooks_enabled: '1' do
      hook = create_hook active: false
      assert_no_enqueued_jobs do
        Webhook.trigger('issue.created', @issue)
      end
    end
  end

  test "enabled? should follow setting flag" do
    # Disabled by default
    assert_not Webhook.enabled?

    with_settings webhooks_enabled: '0' do
      assert_not Webhook.enabled?
    end

    with_settings webhooks_enabled: '1' do
      assert Webhook.enabled?
    end
  end

  test "trigger should not enqueue jobs when disabled" do
    create_hook

    with_settings webhooks_enabled: '0' do
      assert_no_enqueued_jobs do
        Webhook.trigger('issue.created', @issue)
      end
    end
  end

  test "should compute payload" do
    hook = create_hook
    payload = hook.payload('issue.created', @issue)
    assert_equal 'issue.created', payload[:type]
    assert_equal @issue.id, payload.dig(:data, :issue, :id)
  end

  test "should compute correct signature" do
    # we're implementing the same signature mechanism as GitHub, so might as well re-use their
    # example. https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries
    e = Webhook::Executor.new('https://example.com', 'Hello, World!', "It's a Secret to Everybody")
    assert_equal "sha256=757107ea0eb2509fc211221cce984b8a37570b6d7586c22c46f4379c8b043e17", e.compute_signature
  end

  private

  def create_hook(url: 'https://example.com/some/hook', user: User.find_by_login('dlopper'), projects: [Project.find('ecookbook')], events: ['issue.created'], active: true)
    Webhook.create!(url: url, user: user, projects: projects, events: events, active: active)
  end
end
