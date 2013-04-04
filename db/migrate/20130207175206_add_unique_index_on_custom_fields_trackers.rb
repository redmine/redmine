class AddUniqueIndexOnCustomFieldsTrackers < ActiveRecord::Migration
  def up
    table_name = "#{CustomField.table_name_prefix}custom_fields_trackers#{CustomField.table_name_suffix}"
    duplicates = CustomField.connection.select_rows("SELECT custom_field_id, tracker_id FROM #{table_name} GROUP BY custom_field_id, tracker_id HAVING COUNT(*) > 1")
    duplicates.each do |custom_field_id, tracker_id|
      # Removes duplicate rows
      CustomField.connection.execute("DELETE FROM #{table_name} WHERE custom_field_id=#{custom_field_id} AND tracker_id=#{tracker_id}")
      # And insert one
      CustomField.connection.execute("INSERT INTO #{table_name} (custom_field_id, tracker_id) VALUES (#{custom_field_id}, #{tracker_id})")
    end

    if index_exists? :custom_fields_trackers, [:custom_field_id, :tracker_id]
      remove_index :custom_fields_trackers, [:custom_field_id, :tracker_id]
    end
    add_index :custom_fields_trackers, [:custom_field_id, :tracker_id], :unique => true
  end

  def down
    if index_exists? :custom_fields_trackers, [:custom_field_id, :tracker_id]
      remove_index :custom_fields_trackers, [:custom_field_id, :tracker_id]
    end
    add_index :custom_fields_trackers, [:custom_field_id, :tracker_id]
  end
end
