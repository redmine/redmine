class AddViewMessagesToAllExistingRoles < ActiveRecord::Migration
  def up
    Role.all.each { |role| role.add_permission! :view_messages }
  end

  def down
    # nothing to revert
  end
end
