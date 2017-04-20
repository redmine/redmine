class CreateCustomFieldEnumerations < ActiveRecord::Migration
  def change
    create_table :custom_field_enumerations do |t|
      t.integer :custom_field_id, :null => false
      t.string :name, :null => false
      t.boolean :active, :default => true, :null => false
      t.integer :position, :default => 1, :null => false
    end
  end
end
