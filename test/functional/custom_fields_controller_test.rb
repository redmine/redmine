# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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
  fixtures :custom_fields, :custom_values, :trackers, :users

  def setup
    @request.session[:user_id] = 1
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
  end

  def test_new
    custom_field_classes.each do |klass|
      get :new, :type => klass.name
      assert_response :success
      assert_template 'new'
      assert_kind_of klass, assigns(:custom_field)
      assert_select 'form#custom_field_form' do
        assert_select 'select#custom_field_field_format[name=?]', 'custom_field[field_format]'
        assert_select 'input[type=hidden][name=type][value=?]', klass.name
      end
    end
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
      assert_select 'input[type=hidden][name=type][value=IssueCustomField]'
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
    assert_select 'input[name=?][type=checkbox]', 'custom_field[default_value]'
  end

  def test_default_value_should_not_be_present_for_user_custom_field
    get :new, :type => 'IssueCustomField', :custom_field => {:field_format => 'user'}
    assert_response :success
    assert_select '[name=?]', 'custom_field[default_value]', 0
  end

  def test_new_js
    get :new, :type => 'IssueCustomField', :custom_field => {:field_format => 'list'}, :format => 'js'
    assert_response :success
    assert_template 'new'
    assert_equal 'text/javascript', response.content_type

    field = assigns(:custom_field)
    assert_equal 'list', field.field_format
  end

  def test_new_with_invalid_custom_field_class_should_render_404
    get :new, :type => 'UnknownCustomField'
    assert_response 404
  end

  def test_create_list_custom_field
    assert_difference 'CustomField.count' do
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
    assert_redirected_to '/custom_fields?tab=IssueCustomField'
    field = IssueCustomField.find_by_name('test_post_new_list')
    assert_not_nil field
    assert_equal ["0.1", "0.2"], field.possible_values
    assert_equal 1, field.trackers.size
  end

  def test_create_with_failure
    assert_no_difference 'CustomField.count' do
      post :create, :type => "IssueCustomField", :custom_field => {:name => ''}
    end
    assert_response :success
    assert_template 'new'
  end

  def test_edit
    get :edit, :id => 1
    assert_response :success
    assert_template 'edit'
    assert_tag 'input', :attributes => {:name => 'custom_field[name]', :value => 'Database'}
  end

  def test_edit_invalid_custom_field_should_render_404
    get :edit, :id => 99
    assert_response 404
  end

  def test_update
    put :update, :id => 1, :custom_field => {:name => 'New name'}
    assert_redirected_to '/custom_fields?tab=IssueCustomField'

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
