class AddPrivateByDefaultToTrackers < ActiveRecord::Migration[8.1]
  def change
    add_column :trackers, :private_by_default, :boolean, :default => false, :null => false
  end
end
