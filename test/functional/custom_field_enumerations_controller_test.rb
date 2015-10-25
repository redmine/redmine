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

class CustomFieldEnumerationsControllerTest < ActionController::TestCase
  fixtures :users, :email_addresses

  def setup
    @request.session[:user_id] = 1
    @field = GroupCustomField.create!(:name => 'List', :field_format => 'enumeration', :is_required => false)
    @foo = CustomFieldEnumeration.new(:name => 'Foo')
    @bar = CustomFieldEnumeration.new(:name => 'Bar')
    @field.enumerations << @foo
    @field.enumerations << @bar
  end

  def test_index
    get :index, :custom_field_id => @field.id
    assert_response :success
    assert_template 'index'
  end

  def test_create
    assert_difference 'CustomFieldEnumeration.count' do
      post :create, :custom_field_id => @field.id, :custom_field_enumeration => { :name => 'Baz' }
      assert_redirected_to "/custom_fields/#{@field.id}/enumerations"
    end

    assert_equal 3, @field.reload.enumerations.count
    enum = @field.enumerations.last
    assert_equal 'Baz', enum.name
    assert_equal true, enum.active
    assert_equal 3, enum.position
  end

  def test_create_xhr
    assert_difference 'CustomFieldEnumeration.count' do
      xhr :post, :create, :custom_field_id => @field.id, :custom_field_enumeration => { :name => 'Baz' }
      assert_response :success
    end
  end

  def test_update_each
    put :update_each, :custom_field_id => @field.id, :custom_field_enumerations => {
      @bar.id => {:position => "1", :name => "Baz", :active => "1"},
      @foo.id => {:position => "2", :name => "Foo", :active => "0"}
    }
    assert_response 302

    @bar.reload
    assert_equal "Baz", @bar.name
    assert_equal true, @bar.active
    assert_equal 1, @bar.position

    @foo.reload
    assert_equal "Foo", @foo.name
    assert_equal false, @foo.active
    assert_equal 2, @foo.position
  end

  def test_destroy
    assert_difference 'CustomFieldEnumeration.count', -1 do
      delete :destroy, :custom_field_id => @field.id, :id => @foo.id
      assert_redirected_to "/custom_fields/#{@field.id}/enumerations"
    end

    assert_equal 1, @field.reload.enumerations.count
    enum = @field.enumerations.last
    assert_equal 'Bar', enum.name
  end

  def test_destroy_enumeration_in_use_should_display_destroy_form
    group = Group.generate!
    group.custom_field_values = {@field.id.to_s => @foo.id.to_s}
    group.save!

    assert_no_difference 'CustomFieldEnumeration.count' do
      delete :destroy, :custom_field_id => @field.id, :id => @foo.id
      assert_response 200
      assert_template 'destroy'
    end
  end

  def test_destroy_enumeration_in_use_should_destroy_and_reassign_values
    group = Group.generate!
    group.custom_field_values = {@field.id.to_s => @foo.id.to_s}
    group.save!

    assert_difference 'CustomFieldEnumeration.count', -1 do
      delete :destroy, :custom_field_id => @field.id, :id => @foo.id, :reassign_to_id => @bar.id
      assert_response 302
    end

    assert_equal @bar.id.to_s, group.reload.custom_field_value(@field)
  end
end
