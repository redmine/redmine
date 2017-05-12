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

class CustomFieldsControllerTest < ActionController::TestCase
  fixtures :custom_fields, :custom_values,
           :custom_fields_projects, :custom_fields_trackers,
           :roles, :users,
           :members, :member_roles,
           :groups_users,
           :trackers, :projects_trackers,
           :enabled_modules,
           :projects, :issues,
           :issue_statuses,
           :issue_categories,
           :enumerations,
           :workflows

  def setup
    @request.session[:user_id] = 1
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
  end

  def test_new_without_type_should_render_select_type
    get :new
    assert_response :success
    assert_template 'select_type'
    assert_select 'input[name=type]', CustomFieldsHelper::CUSTOM_FIELDS_TABS.size
    assert_select 'input[name=type][checked=checked]', 1
  end

  def test_new_should_work_for_each_customized_class_and_format
    custom_field_classes.each do |klass|
      Redmine::FieldFormat.available_formats.each do |format_name|
        get :new, :type => klass.name, :custom_field => {:field_format => format_name}
        assert_response :success
        assert_template 'new'
        assert_kind_of klass, assigns(:custom_field)
        assert_equal format_name, assigns(:custom_field).format.name
        assert_select 'form#custom_field_form' do
          assert_select 'select#custom_field_field_format[name=?]', 'custom_field[field_format]'
          assert_select 'input[type=hidden][name=type][value=?]', klass.name
        end
      end
    end
  end

  def test_new_should_have_string_default_format
    get :new, :type => 'IssueCustomField'
    assert_response :success
    assert_equal 'string', assigns(:custom_field).format.name
  end

  def test_new_issue_custom_field
    get :new, :type => 'IssueCustomField'
    assert_response :success
    assert_template 'new'
    assert_select 'form#custom_field_form' do
      assert_select 'select#custom_field_field_format[name=?]', 'custom_field[field_format]' do
        assert_select 'option[value=user]', :text => 'User'
        assert_select 'option[value=version]', :text => 'Version'
      end
      assert_select 'input[type=checkbox][name=?]', 'custom_field[project_ids][]', Project.count
      assert_select 'input[type=hidden][name=?]', 'custom_field[project_ids][]', 1
      assert_select 'input[type=hidden][name=type][value=IssueCustomField]'
    end
  end

  def test_new_time_entry_custom_field_should_not_show_trackers_and_projects
    get :new, :type => 'TimeEntryCustomField'
    assert_response :success
    assert_template 'new'
    assert_select 'form#custom_field_form' do
      assert_select 'input[name=?]', 'custom_field[tracker_ids][]', 0
      assert_select 'input[name=?]', 'custom_field[project_ids][]', 0
    end
  end

  def test_default_value_should_be_an_input_for_string_custom_field
    get :new, :type => 'IssueCustomField', :custom_field => {:field_format => 'string'}
    assert_response :success
    assert_select 'input[name=?]', 'custom_field[default_value]'
  end

  def test_default_value_should_be_a_textarea_for_text_custom_field
    get :new, :type => 'IssueCustomField', :custom_field => {:field_format => 'text'}
    assert_response :success
    assert_select 'textarea[name=?]', 'custom_field[default_value]'
  end

  def test_default_value_should_be_a_checkbox_for_bool_custom_field
    get :new, :type => 'IssueCustomField', :custom_field => {:field_format => 'bool'}
    assert_response :success
    assert_select 'select[name=?]', 'custom_field[default_value]' do
      assert_select 'option', 3
    end
  end

  def test_default_value_should_not_be_present_for_user_custom_field
    get :new, :type => 'IssueCustomField', :custom_field => {:field_format => 'user'}
    assert_response :success
    assert_select '[name=?]', 'custom_field[default_value]', 0
  end

  def test_new_js
    xhr :get, :new, :type => 'IssueCustomField', :custom_field => {:field_format => 'list'}, :format => 'js'
    assert_response :success
    assert_template 'new'
    assert_equal 'text/javascript', response.content_type

    field = assigns(:custom_field)
    assert_equal 'list', field.field_format
  end

  def test_new_with_invalid_custom_field_class_should_render_select_type
    get :new, :type => 'UnknownCustomField'
    assert_response :success
    assert_template 'select_type'
  end

  def test_create_list_custom_field
    field = new_record(IssueCustomField) do
      post :create, :type => "IssueCustomField",
                 :custom_field => {:name => "test_post_new_list",
                                   :default_value => "",
                                   :min_length => "0",
                                   :searchable => "0",
                                   :regexp => "",
                                   :is_for_all => "1",
                                   :possible_values => "0.1\n0.2\n",
                                   :max_length => "0",
                                   :is_filter => "0",
                                   :is_required =>"0",
                                   :field_format => "list",
                                   :tracker_ids => ["1", ""]}
    end
    assert_redirected_to "/custom_fields/#{field.id}/edit"
    assert_equal "test_post_new_list", field.name
    assert_equal ["0.1", "0.2"], field.possible_values
    assert_equal 1, field.trackers.size
  end

  def test_create_with_project_ids
    assert_difference 'CustomField.count' do
      post :create, :type => "IssueCustomField", :custom_field => {
        :name => "foo", :field_format => "string", :is_for_all => "0", :project_ids => ["1", "3", ""]
      }
      assert_response 302
    end
    field = IssueCustomField.order("id desc").first
    assert_equal [1, 3], field.projects.map(&:id).sort
  end

  def test_create_with_failure
    assert_no_difference 'CustomField.count' do
      post :create, :type => "IssueCustomField", :custom_field => {:name => ''}
    end
    assert_response :success
    assert_template 'new'
  end

  def test_create_without_type_should_render_select_type
    assert_no_difference 'CustomField.count' do
      post :create, :custom_field => {:name => ''}
    end
    assert_response :success
    assert_template 'select_type'
  end

  def test_edit
    get :edit, :id => 1
    assert_response :success
    assert_template 'edit'
    assert_select 'input[name=?][value=?]', 'custom_field[name]', 'Database'
  end

  def test_edit_invalid_custom_field_should_render_404
    get :edit, :id => 99
    assert_response 404
  end

  def test_update
    put :update, :id => 1, :custom_field => {:name => 'New name'}
    assert_redirected_to '/custom_fields/1/edit'

    field = CustomField.find(1)
    assert_equal 'New name', field.name
  end

  def test_update_with_failure
    put :update, :id => 1, :custom_field => {:name => ''}
    assert_response :success
    assert_template 'edit'
  end

  def test_destroy
    custom_values_count = CustomValue.where(:custom_field_id => 1).count
    assert custom_values_count > 0

    assert_difference 'CustomField.count', -1 do
      assert_difference 'CustomValue.count', - custom_values_count do
        delete :destroy, :id => 1
      end
    end

    assert_redirected_to '/custom_fields?tab=IssueCustomField'
    assert_nil CustomField.find_by_id(1)
    assert_nil CustomValue.find_by_custom_field_id(1)
  end

  def custom_field_classes
    files = Dir.glob(File.join(Rails.root, 'app/models/*_custom_field.rb')).map {|f| File.basename(f).sub(/\.rb$/, '') }
    classes = files.map(&:classify).map(&:constantize)
    assert classes.size > 0
    classes
  end
end
