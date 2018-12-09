class AddIndexOnDiskFilenameToAttachments < ActiveRecord::Migration
  def change
    add_index :attachments, :disk_filename
  end
end
