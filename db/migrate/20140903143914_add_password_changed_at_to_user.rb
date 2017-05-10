class AddPasswordChangedAtToUser < ActiveRecord::Migration
  def change
    add_column :users, :passwd_changed_on, :datetime
  end
end
