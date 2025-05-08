class AddIndexToCustomValues < ActiveRecord::Migration[6.1]
  def change
    remove_index :custom_values, column: [:customized_type, :customized_id], name: :custom_values_customized, if_exists: true
    add_index :custom_values, [:customized_type, :customized_id, :custom_field_id], name: :custom_values_customized_custom_field
  end
end
