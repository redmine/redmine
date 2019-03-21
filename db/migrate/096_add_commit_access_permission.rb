class AddCommitAccessPermission < ActiveRecord::Migration[4.2]
  def self.up
    Role.all.select { |r| not r.builtin? }.each do |r|
      r.add_permission!(:commit_access)
    end
  end

  def self.down
    Role.all.select { |r| not r.builtin? }.each do |r|
      r.remove_permission!(:commit_access)
    end
  end
end
