class AddAttachmentsDiskDirectory < ActiveRecord::Migration
  def up
    add_column :attachments, :disk_directory, :string
  end

  def down
    remove_column :attachments, :disk_directory
  end
end
