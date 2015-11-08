# Redmine - project management software
# Copyright (C) 2006-2015  Jean-Philippe Lang
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

class IssuesCustomFieldsVisibilityTest < ActionController::TestCase
  tests IssuesController
  fixtures :projects,
           :users, :email_addresses,
           :roles,
           :members,
           :member_roles,
           :issue_statuses,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :enumerations,
           :workflows

  def setup
    CustomField.delete_all
    Issue.delete_all
    field_attributes = {:field_format => 'string', :is_for_all => true, :is_filter => true, :trackers => Tracker.all}
    @fields = []
    @fields << (@field1 = IssueCustomField.create!(field_attributes.merge(:name => 'Field 1', :visible => true)))
    @fields << (@field2 = IssueCustomField.create!(field_attributes.merge(:name => 'Field 2', :visible => false, :role_ids => [1, 2])))
    @fields << (@field3 = IssueCustomField.create!(field_attributes.merge(:name => 'Field 3', :visible => false, :role_ids => [1, 3])))
    @issue = Issue.generate!(
      :author_id => 1,
      :project_id => 1,
      :tracker_id => 1,
      :custom_field_values => {@field1.id => 'Value0', @field2.id => 'Value1', @field3.id => 'Value2'}
    )

    @user_with_role_on_other_project = User.generate!
    User.add_to_project(@user_with_role_on_other_project, Project.find(2), Role.find(3))

    @users_to_test = {
      User.find(1) => [@field1, @field2, @field3],
      User.find(3) => [@field1, @field2],
      @user_with_role_on_other_project => [@field1], # should see field1 only on Project 1
      User.generate! => [@field1],
      User.anonymous => [@field1]
    }

    Member.where(:project_id => 1).each do |member|
      member.destroy unless @users_to_test.keys.include?(member.principal)
    end
  end

  def test_show_should_show_visible_custom_fields_only
    @users_to_test.each do |user, fields|
      @request.session[:user_id] = user.id
      get :show, :id => @issue.id
      @fields.each_with_index do |field, i|
        if fields.include?(field)
          assert_select '.value', {:text => "Value#{i}", :count => 1}, "User #{user.id} was not able to view #{field.name}"
        else
          assert_select '.value', {:text => "Value#{i}", :count => 0}, "User #{user.id} was able to view #{field.name}"
        end
      end
    end
  end

  def test_show_should_show_visible_custom_fields_only_in_api
    @users_to_test.each do |user, fields|
      with_settings :rest_api_enabled => '1' do
        get :show, :id => @issue.id, :format => 'xml', :include => 'custom_fields', :key => user.api_key
      end
      @fields.each_with_index do |field, i|
        if fields.include?(field)
          assert_select "custom_field[id=?] value", field.id.to_s, {:text => "Value#{i}", :count => 1}, "User #{user.id} was not able to view #{field.name} in API"
        else
          assert_select "custom_field[id=?] value", field.id.to_s, {:text => "Value#{i}", :count => 0}, "User #{user.id} was not able to view #{field.name} in API"
        end
      end
    end
  end

  def test_show_should_show_visible_custom_fields_only_in_history
    @issue.init_journal(User.find(1))
    @issue.custom_field_values = {@field1.id => 'NewValue0', @field2.id => 'NewValue1', @field3.id => 'NewValue2'}
    @issue.save!

    @users_to_test.each do |user, fields|
      @request.session[:user_id] = user.id
      get :show, :id => @issue.id
      @fields.each_with_index do |field, i|
        if fields.include?(field)
          assert_select 'ul.details i', {:text => "Value#{i}", :count => 1}, "User #{user.id} was not able to view #{field.name} change"
        else
          assert_select 'ul.details i', {:text => "Value#{i}", :count => 0}, "User #{user.id} was able to view #{field.name} change"
        end
      end
    end
  end

  def test_show_should_show_visible_custom_fields_only_in_history_api
    @issue.init_journal(User.find(1))
    @issue.custom_field_values = {@field1.id => 'NewValue0', @field2.id => 'NewValue1', @field3.id => 'NewValue2'}
    @issue.save!

    @users_to_test.each do |user, fields|
      with_settings :rest_api_enabled => '1' do
        get :show, :id => @issue.id, :format => 'xml', :include => 'journals', :key => user.api_key
      end
      @fields.each_with_index do |field, i|
        if fields.include?(field)
          assert_select 'details old_value', {:text => "Value#{i}", :count => 1}, "User #{user.id} was not able to view #{field.name} change in API"
        else
          assert_select 'details old_value', {:text => "Value#{i}", :count => 0}, "User #{user.id} was able to view #{field.name} change in API"
        end
      end
    end
  end

  def test_edit_should_show_visible_custom_fields_only
    Role.anonymous.add_permission! :edit_issues

    @users_to_test.each do |user, fields|
      @request.session[:user_id] = user.id
      get :edit, :id => @issue.id
      @fields.each_with_index do |field, i|
        if fields.include?(field)
          assert_select 'input[value=?]', "Value#{i}", 1, "User #{user.id} was not able to edit #{field.name}"
        else
          assert_select 'input[value=?]', "Value#{i}", 0, "User #{user.id} was able to edit #{field.name}"
        end
      end
    end
  end

  def test_update_should_update_visible_custom_fields_only
    Role.anonymous.add_permission! :edit_issues

    @users_to_test.each do |user, fields|
      @request.session[:user_id] = user.id
      put :update, :id => @issue.id,
        :issue => {:custom_field_values => {
          @field1.id.to_s => "User#{user.id}Value0",
          @field2.id.to_s => "User#{user.id}Value1",
          @field3.id.to_s => "User#{user.id}Value2",
        }}
      @issue.reload
      @fields.each_with_index do |field, i|
        if fields.include?(field)
          assert_equal "User#{user.id}Value#{i}", @issue.custom_field_value(field), "User #{user.id} was not able to update #{field.name}"
        else
          assert_not_equal "User#{user.id}Value#{i}", @issue.custom_field_value(field), "User #{user.id} was able to update #{field.name}"
        end
      end
    end
  end

  def test_index_should_show_visible_custom_fields_only
    @users_to_test.each do |user, fields|
      @request.session[:user_id] = user.id
      get :index, :c => (["subject"] + @fields.map{|f| "cf_#{f.id}"})
      @fields.each_with_index do |field, i|
        if fields.include?(field)
          assert_select 'td', {:text => "Value#{i}", :count => 1}, "User #{user.id} was not able to view #{field.name}"
        else
          assert_select 'td', {:text => "Value#{i}", :count => 0}, "User #{user.id} was able to view #{field.name}"
        end
      end
    end
  end

  def test_index_as_csv_should_show_visible_custom_fields_only
    @users_to_test.each do |user, fields|
      @request.session[:user_id] = user.id
      get :index, :c => (["subject"] + @fields.map{|f| "cf_#{f.id}"}), :format => 'csv'
      @fields.each_with_index do |field, i|
        if fields.include?(field)
          assert_include "Value#{i}", response.body, "User #{user.id} was not able to view #{field.name} in CSV"
        else
          assert_not_include "Value#{i}", response.body, "User #{user.id} was able to view #{field.name} in CSV"
        end
      end
    end
  end

  def test_index_with_partial_custom_field_visibility
    Issue.delete_all
    p1 = Project.generate!
    p2 = Project.generate!
    user = User.generate!
    User.add_to_project(user, p1, Role.where(:id => [1, 3]).to_a)
    User.add_to_project(user, p2, Role.where(:id => 3).to_a)
    Issue.generate!(:project => p1, :tracker_id => 1, :custom_field_values => {@field2.id => 'ValueA'})
    Issue.generate!(:project => p2, :tracker_id => 1, :custom_field_values => {@field2.id => 'ValueB'})
    Issue.generate!(:project => p1, :tracker_id => 1, :custom_field_values => {@field2.id => 'ValueC'})

    @request.session[:user_id] = user.id
    get :index, :c => ["subject", "cf_#{@field2.id}"]
    assert_select 'td', :text => 'ValueA'
    assert_select 'td', :text => 'ValueB', :count => 0
    assert_select 'td', :text => 'ValueC'

    get :index, :sort => "cf_#{@field2.id}"
    # ValueB is not visible to user and ignored while sorting
    assert_equal %w(ValueB ValueA ValueC), assigns(:issues).map{|i| i.custom_field_value(@field2)}

    get :index, :set_filter => '1', "cf_#{@field2.id}" => '*'
    assert_equal %w(ValueA ValueC), assigns(:issues).map{|i| i.custom_field_value(@field2)}

    CustomField.update_all(:field_format => 'list')
    get :index, :group => "cf_#{@field2.id}"
    assert_equal %w(ValueA ValueC), assigns(:issues).map{|i| i.custom_field_value(@field2)}
  end

  def test_create_should_send_notifications_according_custom_fields_visibility
    # anonymous user is never notified
    users_to_test = @users_to_test.reject {|k,v| k.anonymous?}

    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 1
    with_settings :bcc_recipients => '1' do
      assert_difference 'Issue.count' do
        post :create,
          :project_id => 1,
          :issue => {
            :tracker_id => 1,
            :status_id => 1,
            :subject => 'New issue',
            :priority_id => 5,
            :custom_field_values => {@field1.id.to_s => 'Value0', @field2.id.to_s => 'Value1', @field3.id.to_s => 'Value2'},
            :watcher_user_ids => users_to_test.keys.map(&:id)
          }
        assert_response 302
      end
    end
    assert_equal users_to_test.values.uniq.size, ActionMailer::Base.deliveries.size
    # tests that each user receives 1 email with the custom fields he is allowed to see only
    users_to_test.each do |user, fields|
      mails = ActionMailer::Base.deliveries.select {|m| m.bcc.include? user.mail}
      assert_equal 1, mails.size
      mail = mails.first
      @fields.each_with_index do |field, i|
        if fields.include?(field)
          assert_mail_body_match "Value#{i}", mail, "User #{user.id} was not able to view #{field.name} in notification"
        else
          assert_mail_body_no_match "Value#{i}", mail, "User #{user.id} was able to view #{field.name} in notification"
        end
      end
    end
  end

  def test_update_should_send_notifications_according_custom_fields_visibility
    # anonymous user is never notified
    users_to_test = @users_to_test.reject {|k,v| k.anonymous?}

    users_to_test.keys.each do |user|
      Watcher.create!(:user => user, :watchable => @issue)
    end
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 1
    with_settings :bcc_recipients => '1' do
      put :update,
        :id => @issue.id,
        :issue => {
          :custom_field_values => {@field1.id.to_s => 'NewValue0', @field2.id.to_s => 'NewValue1', @field3.id.to_s => 'NewValue2'}
        }
      assert_response 302
    end
    assert_equal users_to_test.values.uniq.size, ActionMailer::Base.deliveries.size
    # tests that each user receives 1 email with the custom fields he is allowed to see only
    users_to_test.each do |user, fields|
      mails = ActionMailer::Base.deliveries.select {|m| m.bcc.include? user.mail}
      assert_equal 1, mails.size
      mail = mails.first
      @fields.each_with_index do |field, i|
        if fields.include?(field)
          assert_mail_body_match "Value#{i}", mail, "User #{user.id} was not able to view #{field.name} in notification"
        else
          assert_mail_body_no_match "Value#{i}", mail, "User #{user.id} was able to view #{field.name} in notification"
        end
      end
    end
  end

  def test_updating_hidden_custom_fields_only_should_not_notifiy_user
    # anonymous user is never notified
    users_to_test = @users_to_test.reject {|k,v| k.anonymous?}

    users_to_test.keys.each do |user|
      Watcher.create!(:user => user, :watchable => @issue)
    end
    ActionMailer::Base.deliveries.clear
    @request.session[:user_id] = 1
    with_settings :bcc_recipients => '1' do
      put :update,
        :id => @issue.id,
        :issue => {
          :custom_field_values => {@field2.id.to_s => 'NewValue1', @field3.id.to_s => 'NewValue2'}
        }
      assert_response 302
    end
    users_to_test.each do |user, fields|
      mails = ActionMailer::Base.deliveries.select {|m| m.bcc.include? user.mail}
      if (fields & [@field2, @field3]).any?
        assert_equal 1, mails.size, "User #{user.id} was not notified"
      else
        assert_equal 0, mails.size, "User #{user.id} was notified"
      end
    end
  end
end
