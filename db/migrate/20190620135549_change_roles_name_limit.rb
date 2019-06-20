class ChangeRolesNameLimit < ActiveRecord::Migration[5.2]
  def self.up
    change_column :roles, :name, :string, :limit => 255, :default => ''
  end

  def self.down
    change_column :roles, :name, :string, :limit => 30, :default => ''
  end
end
