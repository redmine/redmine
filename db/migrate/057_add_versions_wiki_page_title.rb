class AddVersionsWikiPageTitle < ActiveRecord::Migration[4.2]
  def self.up
    add_column :versions, :wiki_page_title, :string
  end

  def self.down
    remove_column :versions, :wiki_page_title
  end
end
