class ChangeDocumentsTitleLimit < ActiveRecord::Migration[4.2]
  def self.up
    change_column :documents, :title, :string, :limit => nil, :default => '', :null => false
  end

  def self.down
    change_column :documents, :title, :string, :limit => 60, :default => '', :null => false
  end
end
