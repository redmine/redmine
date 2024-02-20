module QueryTracker
  extend ActiveSupport::Concern
  included do
    def issue_ids(options={})
      order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)
      Issue.visible.
        joins(:status, :project).
        where(statement).
        includes(([:status, :project] + (options[:include] || [])).uniq).
        references(([:status, :project] + (options[:include] || [])).uniq).
        where(options[:conditions]).
        order(order_option).
        joins(joins_for_order_statement(order_option.join(','))).
        limit(options[:limit]).
        offset(options[:offset]).
        map(&:id)
    rescue ::ActiveRecord::StatementInvalid => e
      raise StatementInvalid.new(e.message)
    end
  end
end