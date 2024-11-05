class AddTagsAndTaggings < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2];
  def self.up
    ActiveRecord::Base.create_taggable_table
  end

  def self.down
    ActiveRecord::Base.drop_taggable_table
  end
end
