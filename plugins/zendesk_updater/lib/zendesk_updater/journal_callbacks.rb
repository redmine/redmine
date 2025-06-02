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
          LambdaClient.invoke_lambda(journalized, self)
        rescue => e
          puts "ERROR in lambda invocation: #{e.message}"
          puts e.backtrace.first(5)
          STDOUT.flush
        end
      end
    end
  end
end
