class AddCustomFieldIsFilter < ActiveRecord::Migration[4.2]
  def self.up
    add_column :custom_fields, :is_filter, :boolean, :null => false, :default => false
  end

  def self.down
    remove_column :custom_fields, :is_filter
  end
end
