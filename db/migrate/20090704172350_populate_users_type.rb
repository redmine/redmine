class PopulateUsersType < ActiveRecord::Migration
  def self.up
    Principal.where("type IS NULL").update_all("type = 'User'")
  end

  def self.down
  end
end
