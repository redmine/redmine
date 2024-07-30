class AddOriginalLockedAtToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :original_status, :integer, default: 1
  end
end
