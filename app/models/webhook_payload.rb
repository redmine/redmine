# frozen_string_literal: true

# Webhook payload
class WebhookPayload
  attr_accessor :event, :object, :user

  def initialize(event, object, user)
    self.event = event
    self.object = object
    self.user = user
  end

  EVENTS = {
    issue: %w[created updated deleted]
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
