class PopulateUsersType < ActiveRecord::Migration[4.2]
  def self.up
    Principal.where("type IS NULL").update_all("type = 'User'")
  end

  def self.down
  end
end
