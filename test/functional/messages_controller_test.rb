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

require_relative '../test_helper'

class MessagesControllerTest < Redmine::ControllerTest
  def setup
    User.current = nil
  end

  def test_show
    get(:show, :params => {:board_id => 1, :id => 1})
    assert_response :success

    assert_select 'h2', :text => 'First post'
  end

  def test_show_should_contain_reply_field_tags_for_quoting
    @request.session[:user_id] = 2
    get(:show, :params => {:board_id => 1, :id => 1})
    assert_response :success

    # tags required by MessagesController#quote
    assert_select 'input#message_subject'
    assert_select 'textarea#message_content'
    assert_select 'div#reply'
  end

  def test_show_with_pagination
    message = Message.find(1)
    assert_difference 'Message.count', 30 do
      30.times do
        message.children << Message.new(:subject => 'Reply',
                                        :content => 'Reply body',
                                        :author_id => 2,
                                        :board_id => 1)
      end
    end
    reply_ids = message.children.map(&:id).sort

    get(
      :show,
      :params => {
        :board_id => 1,
        :id => 1,
        :r => reply_ids.last
      }
    )
    assert_response :success

    assert_select 'a[href=?]', "/boards/1/topics/1?r=#{reply_ids.last}#message-#{reply_ids.last}"
    assert_select 'a[href=?]', "/boards/1/topics/1?r=#{reply_ids.first}#message-#{reply_ids.first}", 0
  end

  def test_show_with_reply_permission
    @request.session[:user_id] = 2
    get(:show, :params => {:board_id => 1, :id => 1})
    assert_response :success

    assert_select 'div#reply textarea#message_content'
  end

  def test_show_message_not_found
    get(:show, :params => {:board_id => 1, :id => 99999})
    assert_response :not_found
  end

  def test_show_message_from_invalid_board_should_respond_with_404
    get(:show, :params => {:board_id => 999, :id => 1})
    assert_response :not_found
  end

  def test_show_should_display_watchers
    @request.session[:user_id] = 2
    message = Message.find(1)
    message.add_watcher User.find(2)
    message.add_watcher Group.find(10)
    [['1', true], ['0', false]].each do |(gravatar_enabled, is_display_gravatar)|
      with_settings :gravatar_enabled => gravatar_enabled do
        get(:show, :params => {:board_id => 1, :id => 1})
      end

      assert_select 'div#watchers ul' do
        assert_select 'li.user-2' do
          assert_select 'img.gravatar[title=?]', 'John Smith', is_display_gravatar
          assert_select 'a[href="/users/2"]'
          assert_select 'a[class*=delete]'
        end
        assert_select "li.user-10" do
          assert_select 'a.group', :text => 'A Team'
          assert_select 'svg'
          assert_select 'a[href="/users/10"]', false
          assert_select 'a[class*=delete]'
        end
      end
    end
  end

  def test_show_should_not_display_watchers_without_permission
    @request.session[:user_id] = 2
    Role.find(1).remove_permission! :view_message_watchers
    message = Message.find(1)
    message.add_watcher User.find(2)
    message.add_watcher Group.find(10)
    get(:show, :params => {:board_id => 1, :id => 1})
    assert_select 'div#watchers ul', 0
    assert_select 'h3', {text: /Watchers \(\d*\)/, count: 0}
  end

  def test_get_new
    @request.session[:user_id] = 2
    get(:new, :params => {:board_id => 1})
    assert_response :success

    assert_select 'input[name=?]', 'message[subject]'
  end

  def test_get_new_with_invalid_board
    @request.session[:user_id] = 2
    get(:new, :params => {:board_id => 99})
    assert_response :not_found
  end

  def test_post_new
    @request.session[:user_id] = 2
    ActionMailer::Base.deliveries.clear

    with_settings :notified_events => %w(message_posted) do
      post(
        :new,
        :params => {
          :board_id => 1,
          :message => {
            :subject => 'Test created message',
            :content => 'Message body'
          }
        }
      )
    end
    assert_equal I18n.t(:notice_successful_create), flash[:notice]
    message = Message.find_by_subject('Test created message')
    assert_not_nil message
    assert_redirected_to "/boards/1/topics/#{message.to_param}"
    assert_equal 'Message body', message.content
    assert_equal 2, message.author_id
    assert_equal 1, message.board_id

    mails = ActionMailer::Base.deliveries
    assert_not_empty mails
    mails.each do |mail|
      assert_equal "[#{message.board.project.name} - #{message.board.name} - msg#{message.root.id}] Test created message", mail.subject
      assert_mail_body_match 'Message body', mail
    end

    email_addresses = mails.map(&:to)
    # author
    assert_includes email_addresses, ['jsmith@somenet.foo']
    # project member
    assert_includes email_addresses, ['dlopper@somenet.foo']
  end

  def test_get_edit
    @request.session[:user_id] = 2
    get(:edit, :params => {:board_id => 1, :id => 1})
    assert_response :success

    assert_select 'input[name=?][value=?]', 'message[subject]', 'First post'
  end

  def test_post_edit
    @request.session[:user_id] = 2
    post(
      :edit,
      :params => {
        :board_id => 1,
        :id => 1,
        :message => {
          :subject => 'New subject',
          :content => 'New body'
        }
      }
    )
    assert_redirected_to '/boards/1/topics/1'
    assert_equal I18n.t(:notice_successful_update), flash[:notice]
    message = Message.find(1)
    assert_equal 'New subject', message.subject
    assert_equal 'New body', message.content
  end

  def test_post_edit_sticky_and_locked
    @request.session[:user_id] = 2
    post(
      :edit,
      :params => {
        :board_id => 1,
        :id => 1,
        :message => {
          :subject => 'New subject',
          :content => 'New body',
          :locked => '1',
          :sticky => '1'
        }
      }
    )
    assert_redirected_to '/boards/1/topics/1'
    assert_equal I18n.t(:notice_successful_update), flash[:notice]
    message = Message.find(1)
    assert_equal true, message.sticky?
    assert_equal true, message.locked?
  end

  def test_post_edit_should_allow_to_change_board
    @request.session[:user_id] = 2
    post(
      :edit,
      :params => {
        :board_id => 1,
        :id => 1,
        :message => {
          :subject => 'New subject',
          :content => 'New body',
          :board_id => 2
        }
      }
    )
    assert_redirected_to '/boards/2/topics/1'
    message = Message.find(1)
    assert_equal Board.find(2), message.board
  end

  def test_reply
    @request.session[:user_id] = 2
    post(
      :reply,
      :params => {
        :board_id => 1,
        :id => 1,
        :reply => {
          :content => 'This is a test reply',
          :subject => 'Test reply'
        }
      }
    )
    reply = Message.order('id DESC').first
    assert_redirected_to "/boards/1/topics/1?r=#{reply.id}"
    assert_equal I18n.t(:notice_successful_update), flash[:notice]
    assert Message.find_by_subject('Test reply')
  end

  def test_destroy_topic
    set_tmp_attachments_directory
    @request.session[:user_id] = 2
    assert_difference 'Message.count', -3 do
      post(:destroy, :params => {:board_id => 1, :id => 1})
    end
    assert_redirected_to '/projects/ecookbook/boards/1'
    assert_equal I18n.t(:notice_successful_delete), flash[:notice]
    assert_nil Message.find_by_id(1)
  end

  def test_destroy_reply
    @request.session[:user_id] = 2
    assert_difference 'Message.count', -1 do
      post(:destroy, :params => {:board_id => 1, :id => 2})
    end
    assert_redirected_to '/boards/1/topics/1?r=2'
    assert_equal I18n.t(:notice_successful_delete), flash[:notice]
    assert_nil Message.find_by_id(2)
  end

  def test_quote_if_message_is_root
    @request.session[:user_id] = 2
    post(
      :quote,
      :params => {
        :board_id => 1,
        :id => 1
      },
      :xhr => true
    )
    assert_response :success
    assert_equal 'text/javascript', response.media_type

    assert_include 'RE: First post', response.body
    assert_include "Redmine Admin wrote:", response.body
    assert_include '> This is the very first post\n> in the forum', response.body
  end

  def test_quote_if_message_is_not_root
    @request.session[:user_id] = 2
    post(
      :quote,
      :params => {
        :board_id => 1,
        :id => 3
      },
      :xhr => true
    )
    assert_response :success
    assert_equal 'text/javascript', response.media_type

    assert_include 'RE: First post', response.body
    assert_include 'John Smith wrote in message#3:', response.body
    assert_include '> An other reply', response.body
  end

  def test_quote_with_partial_quote_if_message_is_root
    @request.session[:user_id] = 2

    params = { board_id: 1, id: 1,
               quote: "the very first post\nin the forum" }
    post :quote, params: params, xhr: true

    assert_response :success
    assert_equal 'text/javascript', response.media_type

    assert_include 'RE: First post', response.body
    assert_include "Redmine Admin wrote:", response.body
    assert_include '> the very first post\n> in the forum', response.body
  end

  def test_quote_with_partial_quote_if_message_is_not_root
    @request.session[:user_id] = 2

    params = { board_id: 1, id: 3, quote: 'other reply' }
    post :quote, params: params, xhr: true

    assert_response :success
    assert_equal 'text/javascript', response.media_type

    assert_include 'RE: First post', response.body
    assert_include 'John Smith wrote in message#3:', response.body
    assert_include '> other reply', response.body
  end

  def test_quote_as_html_should_respond_with_404
    @request.session[:user_id] = 2
    post(
      :quote,
      :params => {
        :board_id => 1,
        :id => 3
      }
    )

    assert_response :not_found
  end

  def test_preview_new
    @request.session[:user_id] = 2
    post(
      :preview,
      :params => {
        :board_id => 1,
        :message => {
          :subject => ""
        },
        :text => "Previewed text"
      }
    )
    assert_response :success
    assert_include 'Previewed text', response.body
  end

  def test_preview_edit
    @request.session[:user_id] = 2
    post(
      :preview,
      :params => {
        :id => 4,
        :board_id => 1,
        :message => {
          :subject => "",
        },
        :text => "Previewed text"
      }
    )
    assert_response :success
    assert_include 'Previewed text', response.body
  end
end
