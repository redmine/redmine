class PopulateMemberRoles < ActiveRecord::Migration[4.2]
  def self.up
    MemberRole.delete_all
    Member.all.each do |member|
      MemberRole.insert!({:member_id => member.id, :role_id => member.role_id})
    end
  end

  def self.down
    MemberRole.delete_all
  end
end
