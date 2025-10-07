# frozen_string_literal: true

require 'rest-client'

class Webhook < ApplicationRecord
  Executor = Struct.new(:url, :payload, :secret) do
    # @return [RestClient::Response] if the POST request was successful
    # @raise [RestClient::Exception, Exception] a `RestClient::Exception` if an
    #   unexpected (i.e. non-successful) response status was set; it may contain
    #   the server response. For connection errors, we may raise any other
    #   exception.
    def call
      # DNS and therefore destination IPs might have changed since the record was saved, so check the URL, again.
      raise URI::BadURIError unless WebhookEndpointValidator.safe_webhook_uri?(url)

      headers = { accept: '*/*', content_type: :json, user_agent: 'Redmine' }
      if secret.present?
        headers['X-Redmine-Signature-256'] = compute_signature
      end
      Rails.logger.debug { "Webhook: POST #{url}" }
      RestClient.post url, payload, headers
    end

    # Computes the HMAC signature for the given payload and secret.
    # https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries
    def compute_signature
      'sha256=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, payload)
    end
  end

  belongs_to :user
  # ToDo: Confirm if we should keep this as it is or we should move to has_many :through
  has_and_belongs_to_many :projects # rubocop:disable Rails/HasAndBelongsToMany

  validates :url, presence: true, webhook_endpoint: true, length: { maximum: 2000 }
  validates :secret, length: { maximum: 255 }, allow_blank: true
  validate :check_events_array

  serialize :events, coder: YAML, type: Array

  scope :active, -> { where(active: true) }

  before_validation ->(hook){ hook.projects = hook.projects.to_a & hook.setable_projects }

  # Triggers the given event for the given object, scheduling qualifying hooks
  # to be called.
  def self.trigger(event, object)
    hooks_for(event, object).each do |hook|
      payload = hook.payload(event, object)
      WebhookJob.perform_later(hook.id, payload.to_json)
    end
  end

  # Finds hooks for the given event and object.
  # Returns an array of hooks that are active, have the given event in their list
  # of events, and whose user can see the object.
  #
  # Object must have a project_id and respond to visible?(user)
  def self.hooks_for(event, object)
    Webhook.active
      .joins("INNER JOIN projects_webhooks on projects_webhooks.webhook_id = webhooks.id")
      .eager_load(:user)
      .where(users: { status: User::STATUS_ACTIVE }, projects_webhooks: { project_id: object.project_id })
      .to_a.select do |hook|
      hook.events.include?(event) && object.visible?(hook.user) && hook.user.allowed_to?(:use_webhooks, object.project)
    end
  end

  def setable_projects
    user = self.user || User.current
    Project.visible(user).to_a.select{|p| user.allowed_to?(:use_webhooks, p)}
  end

  def setable_events
    WebhookPayload::EVENTS
  end

  def setable_event_names
    setable_events.map{|type, actions| actions.map{|action| "#{type}.#{action}"}}.flatten
  end

  # computes the payload. this happens when the hook is triggered, and the
  # payload is stored as part of the hook job definition.
  # event must be of the form 'type.action' (like 'issue.created')
  def payload(event, object)
    WebhookPayload.new(event, object, user).to_h
  end

  # POSTs the given payload to the hook URL, returns true if successful, false otherwise.
  #
  # logs any unsuccessful hook calls, but does not raise
  def call(payload_json)
    Executor.new(url, payload_json, secret).call
    true
  rescue => e
    Rails.logger.warn { "Webhook Error: #{e.message} (#{e.class})\n#{e.backtrace.join "\n"}" }
    false
  end

  private

  def check_events_array
    unless events.is_a?(Array)
      errors.add(:events, :invalid)
      return
    end

    events.reject!(&:blank?)
    if (events - setable_event_names).any?
      errors.add(:events, :invalid)
    end
  end
end
