class AddTaggingsCounterCacheToTags < Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def self.up
    RedmineCrm::Tag.reset_column_information
    RedmineCrm::Tag.find_each do |tag|
      RedmineCrm::Tag.reset_counters(tag.id, :taggings)
    rescue
      next
    end
  end

  def self.down
    remove_column :tags, :taggings_count
  end
end
