class AddIndexOnDiskFilenameToAttachments < ActiveRecord::Migration[4.2]
  def change
    add_index :attachments, :disk_filename
  end
end
