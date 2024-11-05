class AddVersioning < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    add_column :kb_articles, :version_comments, :string, :limit => 255, :default => ""
    KbArticle.create_versioned_table
    add_index KbArticle.versioned_table_name, :kb_article_id, :name => :kb_article_versions_kbaid
    add_index KbArticle.versioned_table_name, :updated_at, :name => :index_kb_article_versions_on_updated_at
    KbArticle.update_all('version = 0')
  end

  def self.down
    KbArticle.drop_versioned_table
    remove_column :kb_articles, :version
    remove_column :kb_articles, :version_comments
  end
end
