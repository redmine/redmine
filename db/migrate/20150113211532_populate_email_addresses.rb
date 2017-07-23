class PopulateEmailAddresses < ActiveRecord::Migration[4.2]
  def self.up
    t = EmailAddress.connection.quoted_true
    n = EmailAddress.connection.quoted_date(Time.now)

    sql = "INSERT INTO #{EmailAddress.table_name} (user_id, address, is_default, notify, created_on, updated_on)" +
          " SELECT id, mail, #{t}, #{t}, '#{n}', '#{n}' FROM #{User.table_name} WHERE type = 'User' ORDER BY id"
    EmailAddress.connection.execute(sql)
  end

  def self.down
    EmailAddress.delete_all
  end
end
