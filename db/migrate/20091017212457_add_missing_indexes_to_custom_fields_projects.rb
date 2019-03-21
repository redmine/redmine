class AddMissingIndexesToCustomFieldsProjects < ActiveRecord::Migration[4.2]
  def self.up
    add_index :custom_fields_projects, [:custom_field_id, :project_id]
  end

  def self.down
    remove_index :custom_fields_projects, :column => [:custom_field_id, :project_id]
  end
end
