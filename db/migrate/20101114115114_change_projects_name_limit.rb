class ChangeProjectsNameLimit < ActiveRecord::Migration[4.2]
  def self.up
    change_column :projects, :name, :string, :limit => nil, :default => '', :null => false
  end

  def self.down
    change_column :projects, :name, :string, :limit => 30, :default => '', :null => false
  end
end
