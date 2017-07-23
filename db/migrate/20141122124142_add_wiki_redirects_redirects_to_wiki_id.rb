class AddWikiRedirectsRedirectsToWikiId < ActiveRecord::Migration[4.2]
  def self.up
    add_column :wiki_redirects, :redirects_to_wiki_id, :integer
    WikiRedirect.update_all "redirects_to_wiki_id = wiki_id"
    change_column :wiki_redirects, :redirects_to_wiki_id, :integer, :null => false
  end

  def self.down
    remove_column :wiki_redirects, :redirects_to_wiki_id
  end
end
