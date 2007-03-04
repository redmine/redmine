class CreateWikiContents < ActiveRecord::Migration
  def self.up
    create_table :wiki_contents do |t|
    end
  end

  def self.down
    drop_table :wiki_contents
  end
end
