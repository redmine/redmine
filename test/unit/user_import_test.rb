# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2022  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../test_helper', __FILE__)

class UserImportTest < ActiveSupport::TestCase
  fixtures :users, :auth_sources, :custom_fields

  include Redmine::I18n

  def setup
    set_language_if_valid 'en'
    User.current = nil
  end

  def test_authorized
    assert  UserImport.authorized?(User.find(1)) # admins
    assert !UserImport.authorized?(User.find(2)) # dose not admin
    assert !UserImport.authorized?(User.find(6)) # dows not admin
  end

  def test_maps_login
    import = generate_import_with_mapping
    first, second, third = new_records(User, 3) {import.run}
    assert_equal 'user1', first.login
    assert_equal 'user2', second.login
    assert_equal 'user3', third.login
  end

  def test_maps_firstname
    import = generate_import_with_mapping
    first, second, third = new_records(User, 3) {import.run}
    assert_equal 'One', first.firstname
    assert_equal 'Two', second.firstname
    assert_equal 'Three', third.firstname
  end

  def test_maps_lastname
    import = generate_import_with_mapping
    first, second, third = new_records(User, 3) {import.run}
    assert_equal 'CSV', first.lastname
    assert_equal 'Import', second.lastname
    assert_equal 'User', third.lastname
  end

  def test_maps_mail
    import = generate_import_with_mapping
    first, second, third = new_records(User, 3) {import.run}
    assert_equal 'user1@somenet.foo', first.mail
    assert_equal 'user2@somenet.foo', second.mail
    assert_equal 'user3@somenet.foo', third.mail
  end

  def test_maps_language
    default_language = 'fr'
    with_settings :default_language => default_language do
      import = generate_import_with_mapping
      first, second, third = new_records(User, 3) {import.run}
      assert_equal 'en', first.language
      assert_equal 'ja', second.language
      assert_equal default_language, third.language
    end
  end

  def test_maps_admin
    import = generate_import_with_mapping
    first, second, third = new_records(User, 3) {import.run}
    assert first.admin?
    assert_not second.admin?
    assert_not third.admin?
  end

  def test_maps_auth_information
    import = generate_import_with_mapping
    first, second, third = new_records(User, 3) {import.run}
    # use password
    assert User.try_to_login(first.login, 'password', false)
    assert User.try_to_login(second.login, 'password', false)
    # use auth_source
    assert_nil first.auth_source
    assert_nil second.auth_source
    assert third.auth_source
    assert_equal 'LDAP test server', third.auth_source.name
    AuthSourceLdap.any_instance.expects(:authenticate).with(third.login, 'ldapassword').returns(true)
    assert User.try_to_login(third.login, 'ldapassword', false)
  end

  def test_map_must_change_password
    import = generate_import_with_mapping
    first, second, third = new_records(User, 3) {import.run}
    assert first.must_change_password?
    assert_not second.must_change_password?
    assert_not third.must_change_password?
  end

  def test_maps_status
    import = generate_import_with_mapping
    first, second, third = new_records(User, 3) {import.run}
    assert first.active?
    assert second.locked?
    assert third.registered?
  end

  def test_maps_custom_fields
    phone_number_cf = UserCustomField.find(4)

    import = generate_import_with_mapping
    import.mapping["cf_#{phone_number_cf.id}"] = '11'
    import.save!
    first, second, third = new_records(User, 3) {import.run}

    assert_equal '000-1111-2222', first.custom_field_value(phone_number_cf)
    assert_equal '333-4444-5555', second.custom_field_value(phone_number_cf)
    assert_equal '666-7777-8888', third.custom_field_value(phone_number_cf)
  end

  def test_deliver_account_information
    import = generate_import_with_mapping
    import.settings['notifications'] = '1'
    %w(admin language auth_source).each do |key|
      import.settings['mapping'].delete(key)
    end
    import.save!

    ActionMailer::Base.deliveries.clear
    first, = new_records(User, 3){import.run}
    assert_equal 3, ActionMailer::Base.deliveries.size

    mail = ActionMailer::Base.deliveries.first
    assert_equal 'Your Redmine account activation', mail.subject
    assert_equal 'user1', first.login
    assert_mail_body_match "Login: #{first.login}", mail
  end

  protected

  def generate_import(fixture_name='import_users.csv')
    import = UserImport.new
    import.user_id = 1
    import.file = uploaded_test_file(fixture_name, 'text/csv')
    import.save!
    import
  end

  def generate_import_with_mapping(fixture_name='import_users.csv')
    import = generate_import(fixture_name)

    import.settings = {
      'separator' => ';', 'wrapper' => '"', 'encoding' => 'UTF-8',
      'mapping' => {
        'login' => '1',
        'firstname' => '2',
        'lastname' => '3',
        'mail' => '4',
        'language' => '5',
        'admin' => '6',
        'auth_source' => '7',
        'password' => '8',
        'must_change_passwd' => '9',
        'status' => '10',
      }
    }
    import.save!
    import
  end
end
