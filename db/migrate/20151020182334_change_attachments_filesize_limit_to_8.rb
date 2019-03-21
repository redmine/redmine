class ChangeAttachmentsFilesizeLimitTo8 < ActiveRecord::Migration[4.2]
  def self.up 
    change_column :attachments, :filesize, :integer, :limit => 8, :default => 0, :null => false
  end

  def self.down
    change_column :attachments, :filesize, :integer, :limit => 4, :default => 0, :null => false
  end
end
