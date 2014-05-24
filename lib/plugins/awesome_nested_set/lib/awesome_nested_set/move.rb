module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      class Move
        attr_reader :target, :position, :instance

        def initialize(target, position, instance)
          @target = target
          @position = position
          @instance = instance
        end

        def move
          prevent_impossible_move

          bound, other_bound = get_boundaries

          # there would be no change
          return if bound == right || bound == left

          # we have defined the boundaries of two non-overlapping intervals,
          # so sorting puts both the intervals and their boundaries in order
          a, b, c, d = [left, right, bound, other_bound].sort

          lock_nodes_between! a, d

          nested_set_scope.where(where_statement(a, d)).update_all(
            conditions(a, b, c, d)
          )
        end

        private

        delegate :left, :right, :left_column_name, :right_column_name,
                 :quoted_left_column_name, :quoted_right_column_name,
                 :quoted_parent_column_name, :parent_column_name, :nested_set_scope,
                 :to => :instance

        delegate :arel_table, :class, :to => :instance, :prefix => true
        delegate :base_class, :to => :instance_class, :prefix => :instance

        def where_statement(left_bound, right_bound)
          instance_arel_table[left_column_name].in(left_bound..right_bound).
            or(instance_arel_table[right_column_name].in(left_bound..right_bound))
        end

        def conditions(a, b, c, d)
          _conditions = case_condition_for_direction(:quoted_left_column_name) +
                        case_condition_for_direction(:quoted_right_column_name) +
                        case_condition_for_parent

          # We want the record to be 'touched' if it timestamps.
          if @instance.respond_to?(:updated_at)
            _conditions << ", updated_at = :timestamp"
          end

          [
            _conditions,
            {
              :a => a, :b => b, :c => c, :d => d,
              :id => instance.id,
              :new_parent => new_parent,
              :timestamp => Time.now.utc
            }
          ]
        end

        def case_condition_for_direction(column_name)
          column = send(column_name)
          "#{column} = CASE " +
            "WHEN #{column} BETWEEN :a AND :b " +
            "THEN #{column} + :d - :b " +
            "WHEN #{column} BETWEEN :c AND :d " +
            "THEN #{column} + :a - :c " +
            "ELSE #{column} END, "
        end

        def case_condition_for_parent
          "#{quoted_parent_column_name} = CASE " +
            "WHEN #{instance_base_class.primary_key} = :id THEN :new_parent " +
            "ELSE #{quoted_parent_column_name} END"
        end

        def lock_nodes_between!(left_bound, right_bound)
          # select the rows in the model between a and d, and apply a lock
          instance_base_class.right_of(left_bound).left_of_right_side(right_bound).
                              select(:id).lock(true)
        end

        def root
          position == :root
        end

        def new_parent
          case position
          when :child
            target.id
          else
            target[parent_column_name]
          end
        end

        def get_boundaries
          if (bound = target_bound) > right
            bound -= 1
            other_bound = right + 1
          else
            other_bound = left - 1
          end
          [bound, other_bound]
        end

        def prevent_impossible_move
          if !root && !instance.move_possible?(target)
            raise ActiveRecord::ActiveRecordError, "Impossible move, target node cannot be inside moved tree."
          end
        end

        def target_bound
          case position
          when :child;  right(target)
          when :left;   left(target)
          when :right;  right(target) + 1
          else raise ActiveRecord::ActiveRecordError, "Position should be :child, :left, :right or :root ('#{position}' received)."
          end
        end
      end
    end
  end
end
