module ZendeskUpdater
  module IssueCallbacks
    extend ActiveSupport::Concern

    included do
      # Only trigger on creation, and only if no journal will be created
      after_commit :trigger_lambda_on_issue_creation, on: [:create]
    end

    private

    def trigger_lambda_on_issue_creation
      # Only process pokemon project issues
      return unless project.identifier == 'pokemon'
      return unless ENV['WORKSPACE']
      
      begin
        Rails.logger.info "Issue creation callback for issue #{id}"
        
        # Check if this issue creation will create a journal
        # If journals exist, the JournalCallbacks will handle it
        if journals.count > 0
          Rails.logger.info "Issue #{id} has journals, skipping issue callback (journal callback will handle)"
          return
        end
        
        Rails.logger.info "Scheduling Zendesk update for new issue #{id} (no journals created)"
        
        # Use background job with small delay to ensure field copying is complete
        ZendeskUpdateJob.set(wait: 3.seconds).perform_later(id, nil)
      rescue => e
        Rails.logger.error "ERROR in issue creation callback: #{e.message}"
        Rails.logger.error e.backtrace.first(5)
      end
    end
  end
end
