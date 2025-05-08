class EnsureDefaultNotificationOptionIsStoredInDb < ActiveRecord::Migration[6.1]
  def up
    # Set the default value in Redmine <= 5.1 to preserve the behavior of existing installations
    Setting.find_or_create_by!(name: 'default_notification_option') do |setting|
      setting.value = 'only_my_events'
    end
  end

  def down
    # no-op
  end
end
