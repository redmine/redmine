# frozen_string_literal: true

require_relative '../application_system_test_case'

class ApiKeyCopySystemTest < ApplicationSystemTestCase
  def test_api_key_copy_to_clipboard
    with_settings :rest_api_enabled => '1' do
      log_user('jsmith', 'jsmith')

      user = User.find_by_login('jsmith')
      expected_value = user.api_key

      visit '/my/account'
      click_link 'Show'

      assert_selector '#api-access-key', visible: true
      assert_selector '.api-key-actions .copy-api-key-link', visible: true
      assert_equal expected_value, find('#api-access-key').text.strip

      find('.copy-api-key-link').click

      find('#quick-search input').set('')
      find('#quick-search input').send_keys([modifier_key, 'v'])
      assert_equal expected_value, find('#quick-search input').value
    end
  end

  private

  def modifier_key
    modifier = osx? ? 'command' : 'control'
    modifier.to_sym
  end
end
