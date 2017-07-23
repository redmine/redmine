class ChangeAuthSourcesFilterToText < ActiveRecord::Migration[4.2]
  def self.up 
    change_column :auth_sources, :filter, :text
  end

  def self.down
    change_column :auth_sources, :filter, :string
  end
end
