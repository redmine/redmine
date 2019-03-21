class ChangeProjectsIdentifierLimit < ActiveRecord::Migration[4.2]
  def self.up
    change_column :projects, :identifier, :string, :limit => nil
  end

  def self.down
    change_column :projects, :identifier, :string, :limit => 20
  end
end
