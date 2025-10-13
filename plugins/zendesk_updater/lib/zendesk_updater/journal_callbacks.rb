module ZendeskUpdater
  module JournalCallbacks
    extend ActiveSupport::Concern

    included do
      after_commit :trigger_lambda_on_journal_update, on: [:create]
    end

    private

    def trigger_lambda_on_journal_update
      if journalized_type == "Issue"
        begin
          # Only process pokemon project issues
          return unless journalized.project.identifier == 'pokemon'
          return unless ENV['WORKSPACE']
          
          Rails.logger.info "Journal creation callback for issue #{journalized.id} journal #{id}"
          
          # This handles both issue updates and issue creations that create journals
          # The deduplication in LambdaClient will prevent double-calls if both 
          # issue and journal callbacks fire for the same creation event
          
          Rails.logger.info "Scheduling Zendesk update for issue #{journalized.id} journal #{id}"
          
          # Use background job with a small delay to ensure field copying callbacks complete first
          # This prevents race conditions with parent/child field copying
          ZendeskUpdateJob.set(wait: 2.seconds).perform_later(journalized.id, self.id)
        rescue => e
          Rails.logger.error "ERROR in journal callback: #{e.message}"
          Rails.logger.error e.backtrace.first(5)
        end
      end
    end
  end
end
