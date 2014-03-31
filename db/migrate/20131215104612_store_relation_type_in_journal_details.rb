class StoreRelationTypeInJournalDetails < ActiveRecord::Migration

  MAPPING = {
    "label_relates_to" => "relates",
    "label_duplicates" => "duplicates",
    "label_duplicated_by" => "duplicated",
    "label_blocks" => "blocks",
    "label_blocked_by" => "blocked",
    "label_precedes" => "precedes",
    "label_follows" => "follows",
    "label_copied_to" => "copied_to",
    "label_copied_from" => "copied_from"
  }

  def up
    StoreRelationTypeInJournalDetails::MAPPING.each do |prop_key, replacement|
      JournalDetail.where(:property  => 'relation', :prop_key => prop_key).update_all(:prop_key => replacement)
    end
  end

  def down
    StoreRelationTypeInJournalDetails::MAPPING.each do |prop_key, replacement|
      JournalDetail.where(:property  => 'relation', :prop_key => replacement).update_all(:prop_key => prop_key)
    end
  end
end
