class SetDefaultRepositories < ActiveRecord::Migration[4.2]
  def self.up
    Repository.update_all(["is_default = ?", false])
    # Sets the last repository as default in case multiple repositories exist for the same project
    Repository.connection.select_values("SELECT r.id FROM #{Repository.table_name} r" +
      " WHERE r.id = (SELECT max(r1.id) FROM #{Repository.table_name} r1 WHERE r1.project_id = r.project_id)").each do |i|
        Repository.where(["id = ?", i]).update_all(["is_default = ?", true])
    end
  end

  def self.down
    Repository.update_all(["is_default = ?", false])
  end
end
