class RemoveOpenIdSetting < ActiveRecord::Migration[6.1]
  def change
    Setting.where(:name => 'openid').delete_all
  end
end
