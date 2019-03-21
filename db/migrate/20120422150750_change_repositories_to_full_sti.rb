class ChangeRepositoriesToFullSti < ActiveRecord::Migration[4.2]
  def up
    Repository.connection.
         select_rows("SELECT id, type FROM #{Repository.table_name}").
         each do |repository_id, repository_type|
      unless repository_type =~ /^Repository::/
        Repository.where(["id = ?", repository_id]).
          update_all(["type = ?", "Repository::#{repository_type}"])
      end
    end
  end

  def down
    Repository.connection.
          select_rows("SELECT id, type FROM #{Repository.table_name}").
          each do |repository_id, repository_type|
      if repository_type =~ /^Repository::(.+)$/
        Repository.where(["id = ?", repository_id]).update_all(["type = ?", $1])
      end
    end
  end
end
