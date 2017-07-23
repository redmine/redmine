class AddCustomFieldsMultiple < ActiveRecord::Migration[4.2]
  def self.up
    add_column :custom_fields, :multiple, :boolean, :default => false
  end

  def self.down
    remove_column :custom_fields, :multiple
  end
end
