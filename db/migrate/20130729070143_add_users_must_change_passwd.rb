class AddUsersMustChangePasswd < ActiveRecord::Migration[4.2]
  def up
    add_column :users, :must_change_passwd, :boolean, :default => false, :null => false
  end

  def down
    remove_column :users, :must_change_passwd
  end
end
