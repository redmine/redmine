require 'awesome_nested_set/set_validator'

module CollectiveIdea
  module Acts
    module NestedSet
      module Model
        module Validatable

          def valid?
            left_and_rights_valid? && no_duplicates_for_columns? && all_roots_valid?
          end

          def left_and_rights_valid?
            SetValidator.new(self).valid?
          end

          def no_duplicates_for_columns?
            [quoted_left_column_full_name, quoted_right_column_full_name].all? do |column|
              # No duplicates
              select("#{scope_string}#{column}, COUNT(#{column})").
                group("#{scope_string}#{column}").
                having("COUNT(#{column}) > 1").
                first.nil?
            end
          end

          # Wrapper for each_root_valid? that can deal with scope.
          def all_roots_valid?
            if acts_as_nested_set_options[:scope]
              all_roots_valid_by_scope?(roots)
            else
              each_root_valid?(roots)
            end
          end

          def all_roots_valid_by_scope?(roots_to_validate)
            roots_grouped_by_scope(roots_to_validate).all? do |scope, grouped_roots|
              each_root_valid?(grouped_roots)
            end
          end

          def each_root_valid?(roots_to_validate)
            left = right = 0
            roots_to_validate.all? do |root|
              (root.left > left && root.right > right).tap do
                left = root.left
                right = root.right
              end
            end
          end

          private
          def roots_grouped_by_scope(roots_to_group)
            roots_to_group.group_by {|record|
              scope_column_names.collect {|col| record.send(col) }
            }
          end

          def scope_string
            Array(acts_as_nested_set_options[:scope]).map do |c|
              connection.quote_column_name(c)
            end.push(nil).join(", ")
          end

        end
      end
    end
  end
end
