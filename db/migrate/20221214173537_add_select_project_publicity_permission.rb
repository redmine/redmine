class AddSelectProjectPublicityPermission < ActiveRecord::Migration[6.1]
  def up
    Role.find_each do |r|
      r.add_permission!(:select_project_publicity) if r.permissions.include?(:edit_project)
    end
  end

  def down
    Role.find_each do |r|
      r.remove_permission!(:select_project_publicity)
    end
  end
end
