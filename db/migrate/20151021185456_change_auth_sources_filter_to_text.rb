class ChangeAuthSourcesFilterToText < ActiveRecord::Migration
  def self.up 
    change_column :auth_sources, :filter, :text
  end

  def self.down
    change_column :auth_sources, :filter, :string
  end
end
