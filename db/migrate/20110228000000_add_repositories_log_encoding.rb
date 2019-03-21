class AddRepositoriesLogEncoding < ActiveRecord::Migration[4.2]
  def self.up
    add_column :repositories, :log_encoding, :string, :limit => 64, :default => nil
  end

  def self.down
    remove_column :repositories, :log_encoding
  end
end
