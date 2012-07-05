class AddTrackersFieldsBits < ActiveRecord::Migration
  def self.up
    add_column :trackers, :fields_bits, :integer, :default => 0
  end

  def self.down
    remove_column :trackers, :fields_bits
  end
end
