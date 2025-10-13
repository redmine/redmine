class ZendeskUpdateJob < ApplicationJob
  queue_as :default
  
  # Retry up to 5 times with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  def perform(issue_id, journal_id = nil)
    issue = Issue.find_by(id: issue_id)
    unless issue
      Rails.logger.warn "ZendeskUpdateJob: Issue #{issue_id} not found, skipping"
      return
    end

    journal = journal_id ? Journal.find_by(id: journal_id) : nil
    if journal_id && !journal
      Rails.logger.warn "ZendeskUpdateJob: Journal #{journal_id} not found, proceeding without journal"
    end
    
    Rails.logger.info "ZendeskUpdateJob executing for issue #{issue_id}, journal #{journal_id}"
    
    ZendeskUpdater::LambdaClient.invoke_lambda(issue, journal)
    
    Rails.logger.info "ZendeskUpdateJob completed successfully for issue #{issue_id}, journal #{journal_id}"
  rescue => e
    Rails.logger.error "ZendeskUpdateJob failed for issue #{issue_id}, journal #{journal_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(10)
    
    # Log retry information
    if executions < 5
      Rails.logger.info "ZendeskUpdateJob will retry (attempt #{executions}/5) for issue #{issue_id}, journal #{journal_id}"
    else
      Rails.logger.error "ZendeskUpdateJob exhausted all retries for issue #{issue_id}, journal #{journal_id}"
    end
    
    raise # This will trigger the retry_on configuration
  end
end
