class AddMissingIndexesToCustomFields < ActiveRecord::Migration[4.2]
  def self.up
    add_index :custom_fields, [:id, :type]
  end

  def self.down
    remove_index :custom_fields, :column => [:id, :type]
  end
end
