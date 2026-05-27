class CreateSettings < ActiveRecord::Migration[4.2]
  def self.up
    create_table :settings, :force => true do |t|
      t.column "name", :string, :limit => 30, :default => "", :null => false
      t.column "value", :text
    end

    # Persist default settings for new installations
    Setting.create!(name: 'default_notification_option', value: Setting.default_notification_option)
    Setting.create!(name: 'text_formatting', value: Setting.text_formatting)
    Setting.create!(name: 'wiki_tablesort_enabled', value: Setting.wiki_tablesort_enabled)

    # `default_issue_start_date_to_creation_date` should also be inserted here
    # for new installations, but its name exceeds the 30-character limit of the
    # settings.name column at this point. It is inserted after the column is
    # extended in 20090318181151_extend_settings_name.rb.
  end

  def self.down
    drop_table :settings
  end
end
