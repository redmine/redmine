class AddMissingIndexesToWikiRedirects < ActiveRecord::Migration[4.2]
  def self.up
    add_index :wiki_redirects, :wiki_id
  end

  def self.down
    remove_index :wiki_redirects, :wiki_id
  end
end
