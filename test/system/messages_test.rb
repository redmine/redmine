# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
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

require_relative '../application_system_test_case'

class MessagesTest < ApplicationSystemTestCase
  def test_reply_to_topic_message
    with_text_formatting 'common_mark' do
      within '#content > .contextual' do
        click_link 'Quote'
      end

      assert_field 'message_content', with: <<~TEXT
        Redmine Admin wrote:
        > This is the very first post
        > in the forum

      TEXT
    end
  end

  def test_reply_to_message
    with_text_formatting 'textile' do
      within '#message-2' do
        click_link 'Quote'
      end

      assert_field 'message_content', with: <<~TEXT
        Redmine Admin wrote in message#2:
        > Reply to the first post

      TEXT
    end
  end

  def test_reply_to_topic_message_with_partial_quote
    with_text_formatting 'textile' do
      assert_text /This is the very first post/

      # Select the part of the topic message through the entire text of the attachment below it.
      page.execute_script <<-'JS'
        const range = document.createRange();
        const message = document.querySelector('#message_topic_wiki');
        // Select only the text "in the forum" from the text "This is the very first post\nin the forum".
        range.setStartBefore(message.querySelector('p').childNodes[2]);
        range.setEndAfter(message.parentNode.querySelector('.attachments'));

        window.getSelection().addRange(range);
      JS

      within '#content > .contextual' do
        click_link 'Quote'
      end

      assert_field 'message_content', with: <<~TEXT
        Redmine Admin wrote:
        > in the forum

      TEXT
    end
  end

  def test_reply_to_message_with_partial_quote
    with_text_formatting 'common_mark' do
      assert_text 'Reply to the first post'

      # Select the entire message, including the subject and headers of messages #2 and #3.
      page.execute_script <<-JS
        const range = document.createRange();
        range.setStartBefore(document.querySelector('#message-2'));
        range.setEndAfter(document.querySelector('#message-3'));

        window.getSelection().addRange(range);
      JS

      within '#message-2' do
        click_link 'Quote'
      end

      assert_field 'message_content', with: <<~TEXT
        Redmine Admin wrote in message#2:
        > Reply to the first post

      TEXT
    end
  end

  private

  def with_text_formatting(format)
    with_settings text_formatting: format do
      log_user('jsmith', 'jsmith')
      visit '/boards/1/topics/1'

      yield
    end
  end
end
