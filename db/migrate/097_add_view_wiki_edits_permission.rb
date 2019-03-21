class AddViewWikiEditsPermission < ActiveRecord::Migration[4.2]
  def self.up
    Role.all.each do |r|
      r.add_permission!(:view_wiki_edits) if r.has_permission?(:view_wiki_pages)
    end
  end

  def self.down
    Role.all.each do |r|
      r.remove_permission!(:view_wiki_edits)
    end
  end
end
