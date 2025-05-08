class CreateSettings < ActiveRecord::Migration[4.2]
  def self.up
    create_table :settings, :force => true do |t|
      t.column "name", :string, :limit => 30, :default => "", :null => false
      t.column "value", :text
    end

    # Persist default settings for new installations
    Setting.create!(name: 'default_notification_option', value: Setting.default_notification_option)
    Setting.create!(name: 'text_formatting', value: Setting.text_formatting)
  end

  def self.down
    drop_table :settings
  end
end
