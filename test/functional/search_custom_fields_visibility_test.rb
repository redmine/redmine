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

class SearchCustomFieldsVisibilityTest < ActionController::TestCase
  tests SearchController
  fixtures :projects,
           :users,
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
    field_attributes = {:field_format => 'string', :is_for_all => true, :is_filter => true, :searchable => true, :trackers => Tracker.all}
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

  def test_search_should_search_visible_custom_fields_only
    @users_to_test.each do |user, fields|
      @request.session[:user_id] = user.id
      @fields.each_with_index do |field, i|
        get :index, :q => "value#{i}"
        assert_response :success
        # we should get a result only if the custom field is visible
        if fields.include?(field)
          assert_equal 1, assigns(:results).size
        else
          assert_equal 0, assigns(:results).size
        end
      end
    end
  end
end
