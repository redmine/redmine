class AddUniqueIndexOnCustomFieldsProjects < ActiveRecord::Migration[4.2]
  def up
    table_name = "#{CustomField.table_name_prefix}custom_fields_projects#{CustomField.table_name_suffix}"
    duplicates = CustomField.connection.select_rows("SELECT custom_field_id, project_id FROM #{table_name} GROUP BY custom_field_id, project_id HAVING COUNT(*) > 1")
    duplicates.each do |custom_field_id, project_id|
      # Removes duplicate rows
      CustomField.connection.execute("DELETE FROM #{table_name} WHERE custom_field_id=#{custom_field_id} AND project_id=#{project_id}")
      # And insert one
      CustomField.connection.execute("INSERT INTO #{table_name} (custom_field_id, project_id) VALUES (#{custom_field_id}, #{project_id})")
    end

    if index_exists? :custom_fields_projects, [:custom_field_id, :project_id]
      remove_index :custom_fields_projects, [:custom_field_id, :project_id]
    end
    add_index :custom_fields_projects, [:custom_field_id, :project_id], :unique => true
  end

  def down
    if index_exists? :custom_fields_projects, [:custom_field_id, :project_id]
      remove_index :custom_fields_projects, [:custom_field_id, :project_id]
    end
    add_index :custom_fields_projects, [:custom_field_id, :project_id]
  end
end
