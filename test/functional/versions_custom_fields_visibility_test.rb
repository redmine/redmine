# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class VersionsCustomFieldsVisibilityTest < Redmine::ControllerTest
  tests VersionsController
  fixtures :projects,
           :users, :email_addresses,
           :roles,
           :members,
           :member_roles,
           :issue_statuses,
           :trackers,
           :projects_trackers,
           :enabled_modules,
           :versions,
           :custom_fields, :custom_values, :custom_fields_trackers

  def test_show_should_display_only_custom_fields_visible_to_user
    cf1 = VersionCustomField.create!(:name => 'cf1', :field_format => 'string')
    cf2 = VersionCustomField.create!(:name => 'cf2', :field_format => 'string', :visible => false, :role_ids => [1])
    cf3 = VersionCustomField.create!(:name => 'cf3', :field_format => 'string', :visible => false, :role_ids => [3])

    version = Version.find(2)
    version.custom_field_values = {cf1.id => 'Value1', cf2.id => 'Value2', cf3.id => 'Value3'}
    version.save!

    @request.session[:user_id] = 2
    get :show, :params => {
        :id => 2
    }
    assert_response :success

    assert_select '#roadmap' do
      assert_select 'span.label', :text => 'cf1:'
      assert_select 'span.label', :text => 'cf2:'
      assert_select 'span.label', {count: 0, text: 'cf3:'}
    end
  end

  def test_edit_should_display_only_custom_fields_visible_to_user
    cf1 = VersionCustomField.create!(:name => 'cf1', :field_format => 'string')
    cf2 = VersionCustomField.create!(:name => 'cf2', :field_format => 'string', :visible => false, :role_ids => [1])
    cf3 = VersionCustomField.create!(:name => 'cf3', :field_format => 'string', :visible => false, :role_ids => [3])

    version = Version.find(2)
    version.custom_field_values = {cf1.id => 'Value1', cf2.id => 'Value2', cf3.id => 'Value3'}
    version.save!

    @request.session[:user_id] = 2
    get :edit, :params => {
        :id => 2
    }
    assert_response :success

    assert_select 'form.edit_version' do
      assert_select 'input[id=?]', "version_custom_field_values_#{cf1.id}"
      assert_select 'input[id=?]', "version_custom_field_values_#{cf2.id}"
      assert_select 'input[id=?]', "version_custom_field_values_#{cf3.id}", 0
    end
  end
end
