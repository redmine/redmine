class AddRepositoriesIsDefault < ActiveRecord::Migration[4.2]
  def self.up
    add_column :repositories, :is_default, :boolean, :default => false
  end

  def self.down
    remove_column :repositories, :is_default
  end
end
