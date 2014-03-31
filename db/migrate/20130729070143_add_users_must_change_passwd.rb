class AddUsersMustChangePasswd < ActiveRecord::Migration
  def up
    add_column :users, :must_change_passwd, :boolean, :default => false, :null => false
  end

  def down
    remove_column :users, :must_change_passwd
  end
end
