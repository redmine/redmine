class AddMissingIndexesToWikiContents < ActiveRecord::Migration[4.2]
  def self.up
    add_index :wiki_contents, :author_id
  end

  def self.down
    remove_index :wiki_contents, :author_id
  end
end
