class AddAuthSourcesFilter < ActiveRecord::Migration[4.2]
  def self.up
    add_column :auth_sources, :filter, :string
  end

  def self.down
    remove_column :auth_sources, :filter
  end
end
