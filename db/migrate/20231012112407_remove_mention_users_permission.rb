class RemoveMentionUsersPermission < ActiveRecord::Migration[6.1]
  def up
    Role.reset_column_information
    Role.all.each do |r|
      r.remove_permission!(:mention_users) if r.has_permission?(:mention_users)
    end
  end

  def down
    # no-op
  end
end
