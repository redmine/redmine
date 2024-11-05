class ChangeColumnArticleToLongText < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    change_column :kb_articles, :content, :text, :limit => 16.megabytes + 3
  end

end
