class ForcePasswordResetDuringSetup < ActiveRecord::Migration[4.2]
  def up
    User.where(login: "admin", last_login_on: nil).update_all(must_change_passwd: true)
  end

  def down
    User.where(login: "admin", last_login_on: nil, must_change_passwd: true).update_all(must_change_passwd: false)
  end
end
