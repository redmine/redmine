class AddRepositoriesIdentifier < ActiveRecord::Migration[4.2]
  def self.up
    add_column :repositories, :identifier, :string
  end

  def self.down
    remove_column :repositories, :identifier
  end
end
