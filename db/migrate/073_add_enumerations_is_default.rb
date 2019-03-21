class AddEnumerationsIsDefault < ActiveRecord::Migration[4.2]
  def self.up
    add_column :enumerations, :is_default, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :enumerations, :is_default
  end
end
