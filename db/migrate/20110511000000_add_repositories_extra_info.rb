class AddRepositoriesExtraInfo < ActiveRecord::Migration[4.2]
  def self.up
    add_column :repositories, :extra_info, :text
  end

  def self.down
    remove_column :repositories, :extra_info
  end
end
