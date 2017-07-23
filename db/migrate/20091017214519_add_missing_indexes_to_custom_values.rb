class AddMissingIndexesToCustomValues < ActiveRecord::Migration[4.2]
  def self.up
    add_index :custom_values, :custom_field_id
  end

  def self.down
    remove_index :custom_values, :custom_field_id
  end
end
