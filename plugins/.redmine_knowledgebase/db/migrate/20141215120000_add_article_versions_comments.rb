class AddArticleVersionsComments < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    add_column :kb_article_versions, :version_comments, :string, limit: 255, default: "" unless column_exists?(:kb_article_versions, :version_comments)
  end
end
