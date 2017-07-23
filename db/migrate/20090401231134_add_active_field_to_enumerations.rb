class AddActiveFieldToEnumerations < ActiveRecord::Migration[4.2]
  def self.up
    add_column :enumerations, :active, :boolean, :default => true, :null => false
  end

  def self.down
    remove_column :enumerations, :active
  end
end
