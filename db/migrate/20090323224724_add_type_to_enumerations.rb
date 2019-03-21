class AddTypeToEnumerations < ActiveRecord::Migration[4.2]
  def self.up
    add_column :enumerations, :type, :string
  end

  def self.down
    remove_column :enumerations, :type
  end
end
