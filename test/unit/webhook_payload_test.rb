# frozen_string_literal: true

require 'test_helper'

class WebhookPayloadTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  fixtures :projects, :users, :trackers, :projects_trackers, :versions,
           :issue_statuses, :issue_categories, :issue_relations,
           :enumerations, :issues, :journals, :journal_details

  setup do
    @dlopper = User.find_by_login 'dlopper'
    @project = Project.find 'ecookbook'
    @issue = @project.issues.first
  end

  test "issue update payload should contain journal" do
    @issue.init_journal(@dlopper)
    @issue.subject = "new subject"
    @issue.save
    p = WebhookPayload.new('issue.updated', @issue, @dlopper)
    assert h = p.to_h
    assert_equal 'issue.updated', h[:type]
    assert j = h.dig(:data, :journal)
    assert_equal 'Dave Lopper', j[:user][:name]
    assert i = h.dig(:data, :issue)
    assert_equal 'new subject', i[:subject], i.inspect
  end

  test "should compute payload of deleted issue" do
    @issue.destroy
    p = WebhookPayload.new('issue.deleted', @issue, @dlopper)
    assert h = p.to_h
    assert_equal 'issue.deleted', h[:type]
    assert_nil h.dig(:data, :journal)
    assert i = h.dig(:data, :issue)
    assert_equal @issue.subject, i[:subject], i.inspect
  end
end
