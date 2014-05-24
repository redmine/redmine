module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      module Model
        module Transactable

          protected
          def in_tenacious_transaction(&block)
            retry_count = 0
            begin
              transaction(&block)
            rescue ActiveRecord::StatementInvalid => error
              raise unless connection.open_transactions.zero?
              raise unless error.message =~ /Deadlock found when trying to get lock|Lock wait timeout exceeded/
              raise unless retry_count < 10
              retry_count += 1
              logger.info "Deadlock detected on retry #{retry_count}, restarting transaction"
              sleep(rand(retry_count)*0.1) # Aloha protocol
              retry
            end
          end

        end
      end
    end
  end
end
