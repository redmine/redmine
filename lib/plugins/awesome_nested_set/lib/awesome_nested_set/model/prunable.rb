module CollectiveIdea #:nodoc:
  module Acts #:nodoc:
    module NestedSet #:nodoc:
      module Model
        module Prunable

          # Prunes a branch off of the tree, shifting all of the elements on the right
          # back to the left so the counts still work.
          def destroy_descendants
            return if right.nil? || left.nil? || skip_before_destroy

            in_tenacious_transaction do
              reload_nested_set
              # select the rows in the model that extend past the deletion point and apply a lock
              nested_set_scope.right_of(left).select(id).lock(true)

              destroy_or_delete_descendants

              # update lefts and rights for remaining nodes
              update_siblings_for_remaining_nodes

              # Don't allow multiple calls to destroy to corrupt the set
              self.skip_before_destroy = true
            end
          end

          def destroy_or_delete_descendants
            if acts_as_nested_set_options[:dependent] == :destroy
              descendants.each do |model|
                model.skip_before_destroy = true
                model.destroy
              end
            else
              descendants.delete_all
            end
          end

          def update_siblings_for_remaining_nodes
            update_siblings(:left)
            update_siblings(:right)
          end

          def update_siblings(direction)
            full_column_name = send("quoted_#{direction}_column_full_name")
            column_name = send("quoted_#{direction}_column_name")

            nested_set_scope.where(["#{full_column_name} > ?", right]).
              update_all(["#{column_name} = (#{column_name} - ?)", diff])
          end

          def diff
            right - left + 1
          end
        end
      end
    end
  end
end
