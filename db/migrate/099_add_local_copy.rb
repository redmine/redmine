class AddLocalCopy < ActiveRecord::Migration
  def self.up
    add_column :repositories, :cache, :boolean
    add_column :repositories, :cache_path, :string, :limit => 255, :default => ""

  end

  def self.down
    remove_column :repositories, :cache
    remove_column :repositories, :cache_path
  end
end
