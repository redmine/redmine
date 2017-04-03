class ChangeAttachmentsDigestLimitTo64 < ActiveRecord::Migration
  def up
    change_column :attachments, :digest, :string, limit: 64
  end
  def down
    change_column :attachments, :digest, :string, limit: 40
  end
end
