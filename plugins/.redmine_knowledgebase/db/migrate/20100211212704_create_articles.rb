class CreateArticles < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    create_table :kb_articles do |t|
      t.column :category_id, :int, :null => false
      t.column :title, :string, :null => false
      t.column :summary, :text
      t.column :content, :text
      t.timestamps
    end
  end

  def self.down
    drop_table :kb_articles
  end
end
