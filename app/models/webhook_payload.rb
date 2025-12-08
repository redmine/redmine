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

# Webhook payload
class WebhookPayload
  attr_accessor :event, :object, :user

  def initialize(event, object, user)
    self.event = event
    self.object = object
    self.user = user
  end

  EVENTS = {
    issue: %w[created updated deleted],
    wiki_page: %w[created updated deleted],
    time_entry: %w[created updated deleted],
    news: %w[created updated deleted],
    version: %w[created updated deleted],
  }

  def to_h
    type, action = event.split('.')
    if EVENTS[type.to_sym].include?(action)
      send("#{type}_payload", action)
    else
      raise ArgumentError, "invalid event: #{event}"
    end
  end

  private

  def issue_payload(action)
    issue = object
    if issue.current_journal.present?
      journal = issue.journals.visible(user).find_by_id(issue.current_journal.id)
    end
    ts = case action
         when 'created'
           issue.created_on
         when 'deleted'
           Time.now
         else
           journal&.created_on || issue.updated_on
         end
    h = {
      type: event,
      timestamp: ts.iso8601,
      data: {
        issue: ApiRenderer.new("app/views/issues/show.api.rsb", user).to_h(issue: issue)
      }
    }
    if action == 'updated' && journal.present?
      h[:data][:journal] = journal_payload(journal)
    end
    h
  end

  def journal_payload(journal)
    {
      id: journal.id,
      created_on: journal.created_on.iso8601,
      notes: journal.notes,
      user: {
        id: journal.user.id,
        name: journal.user.name,
      },
      details: journal.visible_details(user).map do |d|
        {
          property: d.property,
          prop_key: d.prop_key,
          old_value: d.old_value,
          value: d.value,
        }
      end
    }
  end

  def wiki_page_payload(action)
    wiki_page = object

    ts = case action
         when 'created'
           wiki_page.created_on
         when 'deleted'
           Time.now
         else
           wiki_page.updated_on
         end

    {
      type: event,
      timestamp: ts.iso8601,
      data: {
        wiki_page: ApiRenderer.new("app/views/wiki/show.api.rsb", user).to_h(page: wiki_page, content: wiki_page.content)
      }
    }
  end

  def time_entry_payload(action)
    time_entry = object
    ts = case action
         when 'created'
           time_entry.created_on
         when 'deleted'
           Time.now
         else
           time_entry.updated_on
         end
    {
      type: event,
      timestamp: ts.iso8601,
      data: {
        time_entry: ApiRenderer.new("app/views/timelog/show.api.rsb", user).to_h(time_entry: time_entry)
      }
    }
  end

  def news_payload(action)
    news = object
    ts = case action
         when 'created'
           news.created_on
         when 'deleted'
           Time.now
         else # rubocop:disable Lint/DuplicateBranch
           # TODO: fix this by adding a update_on column for news.
           Time.now
         end
    {
      type: event,
      timestamp: ts.iso8601,
      data: {
        news: ApiRenderer.new("app/views/news/show.api.rsb", user).to_h(news: news)
      }
    }
  end

  def version_payload(action)
    version = object
    ts = case action
         when 'created'
           version.created_on
         when 'deleted'
           Time.now
         else
           version.updated_on
         end
    {
      type: event,
      timestamp: ts.iso8601,
      data: {
        version: ApiRenderer.new("app/views/versions/show.api.rsb", user).to_h(version: version)
      }
    }
  end

  # given a path to an API template (relative to RAILS_ROOT), renders it and returns the resulting hash
  class ApiRenderer
    include ApplicationHelper
    include CustomFieldsHelper
    attr_accessor :path, :params, :user

    DummyRequest = Struct.new(:params)

    def initialize(path, user, params = nil)
      self.path = path
      self.user = user
      self.params = params || {}
    end

    def to_h(**ivars)
      req = DummyRequest.new(params)
      api = Redmine::Views::Builders::Json.new(req, nil)
      ivars.each { |k, v| instance_variable_set :"@#{k}", v }
      original_user = User.current
      begin
        User.current = self.user
        instance_eval(File.read(Rails.root.join(path)), path, 1)
      ensure
        User.current = original_user
      end
    end
  end
end
