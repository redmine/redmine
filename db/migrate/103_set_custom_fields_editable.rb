class SetCustomFieldsEditable < ActiveRecord::Migration[4.2]
  def self.up
    UserCustomField.update_all("editable = #{CustomField.connection.quoted_false}")
  end

  def self.down
    UserCustomField.update_all("editable = #{CustomField.connection.quoted_true}")
  end
end
