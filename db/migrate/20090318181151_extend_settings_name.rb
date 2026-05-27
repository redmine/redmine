class ExtendSettingsName < ActiveRecord::Migration[4.2]
  def self.up
    change_column :settings, :name, :string, :limit => 255, :default => '', :null => false

    # This setting is a default setting for new installations. It should be
    # inserted in 017_create_settings.rb with the other default settings, but
    # its name exceeds the original 30-character limit of the settings.name
    # column.
    Setting.create!(
      :name => 'default_issue_start_date_to_creation_date',
      :value => Setting.default_issue_start_date_to_creation_date
    )
  end

  def self.down
    raise ActiveRecord::IrreversibleMigration
  end
end
