class AddAuthSourcesTls < ActiveRecord::Migration[4.2]
  def self.up
    add_column :auth_sources, :tls, :boolean, :default => false, :null => false
  end

  def self.down
    remove_column :auth_sources, :tls
  end
end
