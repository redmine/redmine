class AddCustomFieldsEditable < ActiveRecord::Migration[4.2]
  def self.up
    add_column :custom_fields, :editable, :boolean, :default => true
  end

  def self.down
    remove_column :custom_fields, :editable
  end
end
