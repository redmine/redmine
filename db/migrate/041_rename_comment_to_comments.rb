class RenameCommentToComments < ActiveRecord::Migration[4.2]
  def self.up
    rename_column(:comments, :comment, :comments) if ActiveRecord::Base.connection.columns(Comment.table_name).detect{|c| c.name == "comment"}
    rename_column(:wiki_contents, :comment, :comments) if ActiveRecord::Base.connection.columns(WikiContent.table_name).detect{|c| c.name == "comment"}
    rename_column(:wiki_content_versions, :comment, :comments) if ActiveRecord::Base.connection.columns(WikiContentVersion.table_name).detect{|c| c.name == "comment"}
    rename_column(:time_entries, :comment, :comments) if ActiveRecord::Base.connection.columns(TimeEntry.table_name).detect{|c| c.name == "comment"}
    rename_column(:changesets, :comment, :comments) if ActiveRecord::Base.connection.columns(Changeset.table_name).detect{|c| c.name == "comment"}
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
