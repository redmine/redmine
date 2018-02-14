# Redmine - project management software
# Copyright (C) 2006-2016  Jean-Philippe Lang
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

class SettingsControllerTest < ActionController::TestCase
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :users

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

  def teardown
    Setting.delete_all
    Setting.clear_cache
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'edit'
  end

  def test_get_edit
    get :edit
    assert_response :success
    assert_template 'edit'

    assert_select 'input[name=?][value=""]', 'settings[enabled_scm][]'
  end

  def test_get_edit_should_preselect_default_issue_list_columns
    with_settings :issue_list_default_columns => %w(tracker subject status updated_on) do
      get :edit
      assert_response :success
    end

    assert_select 'select[id=selected_columns][name=?]', 'settings[issue_list_default_columns][]' do
      assert_select 'option', 4
      assert_select 'option[value=tracker]', :text => 'Tracker'
      assert_select 'option[value=subject]', :text => 'Subject'
      assert_select 'option[value=status]', :text => 'Status'
      assert_select 'option[value=updated_on]', :text => 'Updated'
    end

    assert_select 'select[id=available_columns]' do
      assert_select 'option[value=tracker]', 0
      assert_select 'option[value=priority]', :text => 'Priority'
    end
  end

  def test_get_edit_without_trackers_should_succeed
    Tracker.delete_all

    get :edit
    assert_response :success
  end

  def test_post_edit_notifications
    post :edit, :settings => {:mail_from => 'functional@test.foo',
                              :bcc_recipients  => '0',
                              :notified_events => %w(issue_added issue_updated news_added),
                              :emails_footer => 'Test footer'
                              }
    assert_redirected_to '/settings'
    assert_equal 'functional@test.foo', Setting.mail_from
    assert !Setting.bcc_recipients?
    assert_equal %w(issue_added issue_updated news_added), Setting.notified_events
    assert_equal 'Test footer', Setting.emails_footer
  end

  def test_edit_commit_update_keywords
    with_settings :commit_update_keywords => [
      {"keywords" => "fixes, resolves", "status_id" => "3"},
      {"keywords" => "closes", "status_id" => "5", "done_ratio" => "100", "if_tracker_id" => "2"}
    ] do
      get :edit
    end
    assert_response :success
    assert_select 'tr.commit-keywords', 2
    assert_select 'tr.commit-keywords:nth-child(1)' do
      assert_select 'input[name=?][value=?]', 'settings[commit_update_keywords][keywords][]', 'fixes, resolves'
      assert_select 'select[name=?]', 'settings[commit_update_keywords][status_id][]' do
        assert_select 'option[value="3"][selected=selected]'
      end
    end
    assert_select 'tr.commit-keywords:nth-child(2)' do
      assert_select 'input[name=?][value=?]', 'settings[commit_update_keywords][keywords][]', 'closes'
      assert_select 'select[name=?]', 'settings[commit_update_keywords][status_id][]' do
        assert_select 'option[value="5"][selected=selected]', :text => 'Closed'
      end
      assert_select 'select[name=?]', 'settings[commit_update_keywords][done_ratio][]' do
        assert_select 'option[value="100"][selected=selected]', :text => '100 %'
      end
      assert_select 'select[name=?]', 'settings[commit_update_keywords][if_tracker_id][]' do
        assert_select 'option[value="2"][selected=selected]', :text => 'Feature request'
      end
    end
  end

  def test_edit_without_commit_update_keywords_should_show_blank_line
    with_settings :commit_update_keywords => [] do
      get :edit
    end
    assert_response :success
    assert_select 'tr.commit-keywords', 1 do
      assert_select 'input[name=?]:not([value])', 'settings[commit_update_keywords][keywords][]'
    end
  end

  def test_post_edit_commit_update_keywords
    post :edit, :settings => {
      :commit_update_keywords => {
        :keywords => ["resolves", "closes"],
        :status_id => ["3", "5"],
        :done_ratio => ["", "100"],
        :if_tracker_id => ["", "2"]
      }
    }
    assert_redirected_to '/settings'
    assert_equal([
      {"keywords" => "resolves", "status_id" => "3"},
      {"keywords" => "closes", "status_id" => "5", "done_ratio" => "100", "if_tracker_id" => "2"}
    ], Setting.commit_update_keywords)
  end

  def test_post_edit_should_send_security_notification_for_notified_settings
    ActionMailer::Base.deliveries.clear
    post :edit, :settings => {
      :login_required => 1
    }

    assert_not_nil (mail = ActionMailer::Base.deliveries.last)
    assert_mail_body_match '0.0.0.0', mail
    assert_mail_body_match I18n.t(:setting_login_required), mail
    assert_select_email do
      assert_select 'a[href^=?]', 'http://localhost:3000/settings'
    end
    # All admins should receive this
    recipients = [mail.bcc, mail.cc].flatten
    User.active.where(admin: true).each do |admin|
      assert_include admin.mail, recipients
    end
  end

  def test_post_edit_should_not_send_security_notification_for_non_notified_settings
    ActionMailer::Base.deliveries.clear
    post :edit, :settings => {
      :app_title => 'MineRed'
    }

    assert_nil (mail = ActionMailer::Base.deliveries.last)
  end

  def test_post_edit_should_not_send_security_notification_for_unchanged_settings
    ActionMailer::Base.deliveries.clear
    post :edit, :settings => {
      :login_required => 0
    }

    assert_nil (mail = ActionMailer::Base.deliveries.last)
  end


  def test_get_plugin_settings
    ActionController::Base.append_view_path(File.join(Rails.root, "test/fixtures/plugins"))
    Redmine::Plugin.register :foo do
      settings :partial => "foo_plugin/foo_plugin_settings"
    end
    Setting.plugin_foo = {'sample_setting' => 'Plugin setting value'}

    get :plugin, :id => 'foo'
    assert_response :success
    assert_template 'plugin'
    assert_select 'form[action="/settings/plugin/foo"]' do
      assert_select 'input[name=?][value=?]', 'settings[sample_setting]', 'Plugin setting value'
    end
  ensure
    Redmine::Plugin.unregister(:foo)
  end

  def test_get_invalid_plugin_settings
    get :plugin, :id => 'none'
    assert_response 404
  end

  def test_get_non_configurable_plugin_settings
    Redmine::Plugin.register(:foo) {}

    get :plugin, :id => 'foo'
    assert_response 404

  ensure
    Redmine::Plugin.unregister(:foo)
  end

  def test_post_plugin_settings
    Redmine::Plugin.register(:foo) do
      settings :partial => 'not blank', # so that configurable? is true
        :default => {'sample_setting' => 'Plugin setting value'}
    end

    post :plugin, :id => 'foo', :settings => {'sample_setting' => 'Value'}
    assert_redirected_to '/settings/plugin/foo'

    assert_equal({'sample_setting' => 'Value'}, Setting.plugin_foo)
  end

  def test_post_non_configurable_plugin_settings
    Redmine::Plugin.register(:foo) {}

    post :plugin, :id => 'foo', :settings => {'sample_setting' => 'Value'}
    assert_response 404

  ensure
    Redmine::Plugin.unregister(:foo)
  end
end
