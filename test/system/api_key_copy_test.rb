# frozen_string_literal: true

require_relative '../application_system_test_case'

class ApiKeyCopySystemTest < ApplicationSystemTestCase
  def test_api_key_copy_to_clipboard
    with_settings :rest_api_enabled => '1' do
      log_user('jsmith', 'jsmith')

      user = User.find_by_login('jsmith')
      user.api_key if user.api_token.nil?
  
      visit '/my/account'
      click_link 'Show'
  
      assert_selector '#api-access-key', visible: true
  
      expected_value = find('#api-access-key').text.strip
  
      find('.copy-api-key-link').click
  
      visit '/issues/1'
  
      first('.icon-edit').click
      find('textarea#issue_notes').set('')
      find('textarea#issue_notes').send_keys([modifier_key, 'v'])
      assert_equal expected_value, find('textarea#issue_notes').value
    end
  end

  def test_api_key_copy_feedback
    with_settings :rest_api_enabled => '1' do
      log_user('jsmith', 'jsmith')

      user = User.find_by_login('jsmith')
      user.api_key if user.api_token.nil?

      visit '/my/account'
      click_link 'Show'

      assert_selector '#api-access-key', visible: true
      assert_selector '.api-key-actions .copy-api-key-link', visible: true

      find('.copy-api-key-link').click

      assert_selector '.copy-api-key-link', visible: true
      sleep 2.1
      assert_selector '.copy-api-key-link', visible: true
    end
  end

  def test_api_key_copy_button_show_and_hide
    with_settings :rest_api_enabled => '1' do
      log_user('jsmith', 'jsmith')

      user = User.find_by_login('jsmith')
      user.api_key if user.api_token.nil?

      visit '/my/account'

      assert_no_selector '.copy-api-key-link'

      click_link 'Show'
      assert_selector '.api-key-actions .copy-api-key-link', visible: true

      click_link 'Show'
      assert_no_selector '.copy-api-key-link'
    end
  end

  private

  def modifier_key
    modifier = osx? ? 'command' : 'control'
    modifier.to_sym
  end
end