class AddRepositoryRootUrl < ActiveRecord::Migration[4.2]
  def self.up
    add_column :repositories, :root_url, :string, :limit => 255, :default => ""
  end

  def self.down
    remove_column :repositories, :root_url
  end
end
