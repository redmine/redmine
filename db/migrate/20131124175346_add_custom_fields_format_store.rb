class AddCustomFieldsFormatStore < ActiveRecord::Migration
  def up
    add_column :custom_fields, :format_store, :text
  end

  def down
    remove_column :custom_fields, :format_store
  end
end
