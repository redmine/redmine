class AddAuthSourcesTimeout < ActiveRecord::Migration
  def up
    add_column :auth_sources, :timeout, :integer
  end

  def self.down
    remove_column :auth_sources, :timeout
  end
end
