class CreateWikis < ActiveRecord::Migration
  def self.up
    create_table :wikis do |t|
    end
  end

  def self.down
    drop_table :wikis
  end
end
