class AddCustomFieldsDefaultValue < ActiveRecord::Migration[4.2]
  def self.up
    add_column :custom_fields, :default_value, :text
  end

  def self.down
    remove_column :custom_fields, :default_value
  end
end
