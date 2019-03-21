class AddAttachmentsDescription < ActiveRecord::Migration[4.2]
  def self.up
    add_column :attachments, :description, :string
  end

  def self.down
    remove_column :attachments, :description
  end
end
