class AddUsersType < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :type, :string
    User.update_all "type = 'User'"
  end

  def self.down
    remove_column :users, :type
  end
end
