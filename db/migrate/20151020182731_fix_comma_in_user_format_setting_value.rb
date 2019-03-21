class FixCommaInUserFormatSettingValue < ActiveRecord::Migration[4.2]
  def self.up 
    Setting.
      where(:name => 'user_format', :value => 'lastname_coma_firstname').
      update_all(:value => 'lastname_comma_firstname')
  end

  def self.down
    Setting.
      where(:name => 'user_format', :value => 'lastname_comma_firstname').
      update_all(:value => 'lastname_coma_firstname')
  end
end
