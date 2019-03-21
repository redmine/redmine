class AddRepositoriesType < ActiveRecord::Migration[4.2]
  def self.up
    add_column :repositories, :type, :string
    # Set class name for existing SVN repositories
    Repository.update_all "type = 'Subversion'"
  end

  def self.down
    remove_column :repositories, :type
  end
end
