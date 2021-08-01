class RemoveBccRecipientsSetting < ActiveRecord::Migration[6.1]
  def change
    Setting.where(:name => 'bcc_recipients').delete_all
  end
end
