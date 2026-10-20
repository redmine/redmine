class AddAvatarIdToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :avatar_id, :integer
  end
end
