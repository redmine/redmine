require 'aws-sdk-lambda'

module ZendeskUpdater
  class LambdaClient
    def self.invoke_lambda(issue, journal = nil)
      return unless ENV['WORKSPACE']
      return unless issue.project.identifier == 'pokemon'

      function_name = "#{ENV['WORKSPACE']}-pokemon-redmine"
      payload = build_payload(issue, journal)
      return if payload.nil?

      begin
        client = Aws::Lambda::Client.new()
        client.invoke(
          function_name: function_name,
          payload: payload.to_json
        )
      rescue => e
        puts "ERROR in lambda invocation: #{e.message}"
        puts e.backtrace.first(5)
        STDOUT.flush
      end
    end

    private

    def self.build_payload(issue, journal)
      return nil unless issue

      # Get all custom fields for the issue
      custom_fields = issue.available_custom_fields
      custom_field_values = issue.custom_field_values

      # For updates, track which custom fields changed
      changed_custom_fields = {}
      if journal
        journal.details.each do |detail|
          if detail.property == 'cf'
            custom_field = custom_fields.find { |cf| cf.id == detail.prop_key.to_i }
            if custom_field
              changed_custom_fields[custom_field.id] = {
                'name' => custom_field.name,
                'value' => detail.value,
                'oldValue' => detail.old_value
              }
            end
          end
        end
      end

      # Build the base payload
      payload = {
        'issue' => {
          'id' => issue.id,
          'subject' => issue.subject,
          'description' => issue.description,
          'status' => issue.status.name,
          'category' => issue.category&.name,
          'priority' => issue.priority.name,
          'project' => issue.project.identifier,
          'author' => issue.author.login,
          'assignedTo' => issue.assigned_to&.login,
          'createdOn' => issue.created_on,
          'customFields' => []
        }
      }

      # Add custom fields
      if journal && journal.details.any? { |d| d.property == 'cf' }
        # For updates, only include changed custom fields
        changed_custom_fields.each do |_, cf_data|
          payload['issue']['customFields'] << cf_data
        end
      else
        # For creates or when no custom fields changed, include all custom fields
        custom_field_values.each do |cfv|
          custom_field = custom_fields.find { |cf| cf.id == cfv.custom_field_id }
          next unless custom_field

          payload['issue']['customFields'] << {
            'name' => custom_field.name,
            'value' => cfv.value
          }
        end
      end

      # Add journal information if present
      if journal
        payload['journal'] = {
          'user' => journal.user.login,
          'notes' => journal.notes,
          'createdOn' => journal.created_on
        }

        # Add changes
        changes = []
        journal.details.each do |detail|
          change = {
            'property' => detail.property,
            'propKey' => detail.prop_key,
            'oldValue' => detail.old_value,
            'value' => detail.value
          }

          # Add custom field name if it's a custom field change
          if detail.property == 'cf'
            custom_field = custom_fields.find { |cf| cf.id == detail.prop_key.to_i }
            change['customFieldName'] = custom_field.name if custom_field
          end

          changes << change
        end
        payload['journal']['changes'] = changes
      end

      payload
    end
  end
end
