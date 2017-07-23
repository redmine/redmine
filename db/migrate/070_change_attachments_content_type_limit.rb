class ChangeAttachmentsContentTypeLimit < ActiveRecord::Migration[4.2]
  def self.up
    change_column :attachments, :content_type, :string, :limit => nil
  end

  def self.down
    change_column :attachments, :content_type, :string, :limit => 60
  end
end
