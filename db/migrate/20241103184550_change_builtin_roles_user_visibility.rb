class ChangeBuiltinRolesUserVisibility < ActiveRecord::Migration[7.2]
  def up
    # Default to members_of_visible_projects for all newly created roles
    change_column_default :roles, :users_visibility, 'members_of_visible_projects'

    # Set the users visibility of the builtin roles (Anonymous and Non-Member)
    # to members_of_visible_projects as a saf(er) default.
    Role.where.not(builtin: 0).update_all(users_visibility: 'members_of_visible_projects')
  end

  def down
    change_column_default :roles, :users_visibility, 'all'
  end
end
