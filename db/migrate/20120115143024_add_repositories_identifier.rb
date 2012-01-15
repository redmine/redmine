class AddRepositoriesIdentifier < ActiveRecord::Migration
  def self.up
    add_column :repositories, :identifier, :string
  end

  def self.down
    remove_column :repositories, :identifier
  end
end
