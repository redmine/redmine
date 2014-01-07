class CreateCustomFieldsRoles < ActiveRecord::Migration
  def self.up
    create_table :custom_fields_roles, :id => false do |t|
      t.column :custom_field_id, :integer, :null => false
      t.column :role_id, :integer, :null => false
    end
    add_index :custom_fields_roles, [:custom_field_id, :role_id], :unique => true, :name => :custom_fields_roles_ids
    CustomField.where({:type => 'IssueCustomField'}).update_all({:visible => true})
  end

  def self.down
    drop_table :custom_fields_roles
  end
end
