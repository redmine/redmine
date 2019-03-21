class AddRepositoryLoginAndPassword < ActiveRecord::Migration[4.2]
  def self.up
    add_column :repositories, :login, :string, :limit => 60, :default => ""
    add_column :repositories, :password, :string, :limit => 60, :default => ""
  end

  def self.down
    remove_column :repositories, :login
    remove_column :repositories, :password
  end
end
