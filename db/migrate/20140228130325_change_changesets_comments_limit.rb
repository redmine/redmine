class ChangeChangesetsCommentsLimit < ActiveRecord::Migration
  def up
    if ActiveRecord::Base.connection.adapter_name =~ /mysql/i
      max_size = 16.megabytes
      change_column :changesets, :comments, :text, :limit => max_size
    end
  end

  def down
    # no-op
  end
end
