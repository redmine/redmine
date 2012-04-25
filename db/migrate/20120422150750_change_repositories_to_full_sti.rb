class ChangeRepositoriesToFullSti < ActiveRecord::Migration
  def up
    Repository.connection.select_rows("SELECT id, type FROM #{Repository.table_name}").each do |repository_id, repository_type|
      unless repository_type =~ /^Repository::/
        Repository.update_all ["type = ?", "Repository::#{repository_type}"], ["id = ?", repository_id]
      end
    end
  end

  def down
    Repository.connection.select_rows("SELECT id, type FROM #{Repository.table_name}").each do |repository_id, repository_type|
      if repository_type =~ /^Repository::(.+)$/
        Repository.update_all ["type = ?", $1], ["id = ?", repository_id]
      end
    end
  end
end
