class AddCustomFieldsSearchable < ActiveRecord::Migration[4.2]
  def self.up
    add_column :custom_fields, :searchable, :boolean, :default => false
  end

  def self.down
    remove_column :custom_fields, :searchable
  end
end
