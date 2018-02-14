class ChangeWikiContentsCommentsLimitTo1024 < ActiveRecord::Migration
  def self.up
    change_column :wiki_content_versions, :comments, :string, :limit => 1024, :default => ''
    change_column :wiki_contents, :comments, :string, :limit => 1024, :default => ''
  end

  def self.down
    change_column :wiki_content_versions, :comments, :string, :limit => 255, :default => ''
    change_column :wiki_contents, :comments, :string, :limit => 255, :default => ''
  end
end
