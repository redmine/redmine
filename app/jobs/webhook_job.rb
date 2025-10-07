# frozen_string_literal: true

class WebhookJob < ApplicationJob
  def perform(hook_id, payload_json)
    if hook = Webhook.find_by_id(hook_id)
      if hook.user&.active?
        User.current = hook.user
        hook.call payload_json
      else
        Rails.logger.debug { "WebhookJob: user with id=#{hook.user_id} is not active" }
      end
    else
      Rails.logger.debug { "WebhookJob: couldn't find hook with id=#{hook_id}" }
    end
  end
end
