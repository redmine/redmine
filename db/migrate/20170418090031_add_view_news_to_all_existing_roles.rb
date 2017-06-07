class AddViewNewsToAllExistingRoles < ActiveRecord::Migration
  def up
    Role.all.each { |role| role.add_permission! :view_news }
  end

  def down
    # nothing to revert
  end
end
