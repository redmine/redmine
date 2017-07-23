class AddCustomFieldsDescription < ActiveRecord::Migration[4.2]
  def up
    add_column :custom_fields, :description, :text
  end

  def down
    remove_column :custom_fields, :description
  end
end
