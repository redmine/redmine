class AddPasswordChangedAtToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :passwd_changed_on, :datetime
  end
end
