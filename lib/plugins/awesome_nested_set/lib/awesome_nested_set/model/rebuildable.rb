require 'awesome_nested_set/tree'

module CollectiveIdea
  module Acts
    module NestedSet
      module Model
        module Rebuildable


          # Rebuilds the left & rights if unset or invalid.
          # Also very useful for converting from acts_as_tree.
          def rebuild!(validate_nodes = true)
            # default_scope with order may break database queries so we do all operation without scope
            unscoped do
              Tree.new(self, validate_nodes).rebuild!
            end
          end

          private
          def scope_for_rebuild
            scope = proc {}

            if acts_as_nested_set_options[:scope]
              scope = proc {|node|
                scope_column_names.inject("") {|str, column_name|
                  str << "AND #{connection.quote_column_name(column_name)} = #{connection.quote(node.send(column_name))} "
                }
              }
            end
            scope
          end

          def order_for_rebuild
            "#{quoted_left_column_full_name}, #{quoted_right_column_full_name}, #{primary_key}"
          end
        end

      end
    end
  end
end
