# frozen_string_literal: true

require File.expand_path('../../../test_helper', __dir__)

class Redmine::TwofaTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses

  def setup
    @user = User.find_by_login 'jsmith'
    @other_user = User.find_by_login 'dlopper'
  end

  test "verify_backup_code! accepts and invalidates the user's own backup code" do
    token = backup_code_for @user, 'abcdef123456'

    assert Redmine::Twofa::Totp.new(@user).verify_backup_code!('abcdef123456')
    assert_nil Token.find_by_id(token.id)
  end

  test "verify_backup_code! rejects but keeps another user's backup code" do
    token = backup_code_for @other_user, 'abcdef654321'

    assert_not Redmine::Twofa::Totp.new(@user).verify_backup_code!('abcdef654321')
    assert Token.find_by_id(token.id), "backup code of another user must not be deleted"
  end

  private

  # creates a backup code token the same way Redmine::Twofa::Base#init_backup_codes! does
  def backup_code_for(user, value)
    token = Token.create!(user_id: user.id, action: 'twofa_backup_code')
    token.update_columns value: value
    token
  end
end
