class AddTrackersDescription < ActiveRecord::Migration[5.2]
  def change
    add_column :trackers, :description, :string, :after => :name
  end
end
