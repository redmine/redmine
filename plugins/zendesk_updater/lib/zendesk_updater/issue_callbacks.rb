module ZendeskUpdater
  module IssueCallbacks
    extend ActiveSupport::Concern

    included do
      after_commit :trigger_lambda_on_issue_update, on: [:create]
    end

    private

    def trigger_lambda_on_issue_update
      begin
        LambdaClient.invoke_lambda(self)
      rescue => e
        puts "ERROR in lambda invocation: #{e.message}"
        puts e.backtrace.first(5)
        STDOUT.flush
      end
    end
  end
end
