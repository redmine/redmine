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

require_relative '../../test_helper'

class Redmine::ApiTest::CustomFieldsTest < Redmine::ApiTest::Base
  test "GET /custom_fields.xml should return custom fields" do
    get '/custom_fields.xml', :headers => credentials('admin')
    assert_response :success
    assert_equal 'application/xml', response.media_type

    assert_select 'custom_fields' do
      assert_select 'custom_field' do
        assert_select 'name', :text => 'Database'
        assert_select 'description', :text => 'Select one of the databases'
        assert_select 'id', :text => '2'
        assert_select 'customized_type', :text => 'issue'
        assert_select 'possible_values[type=array]' do
          assert_select 'possible_value>value', :text => 'PostgreSQL'
          assert_select 'possible_value>label', :text => 'PostgreSQL'
        end
        assert_select 'trackers[type=array]'
        assert_select 'roles[type=array]'
        assert_select 'visible', :text => 'true'
        assert_select 'editable', :text => 'true'
      end
    end
  end

  test "GET /custom_fields.xml should include value and label for enumeration custom fields" do
    field = IssueCustomField.generate!(:field_format => 'enumeration')
    foo = field.enumerations.create!(:name => 'Foo')
    bar = field.enumerations.create!(:name => 'Bar')

    get '/custom_fields.xml', :headers => credentials('admin')
    assert_response :success

    assert_select 'possible_value' do
      assert_select "value:contains(?) + label:contains(?)", foo.id.to_s, 'Foo'
      assert_select "value:contains(?) + label:contains(?)", bar.id.to_s, 'Bar'
    end
  end

  test "GET /custom_fields.xml should include roles for custom fields visible by role" do
    custom_fields = [
      IssueCustomField.generate!(:visible => false, :role_ids => [1, 2]),
      TimeEntryCustomField.generate!(:visible => false, :role_ids => [1, 2]),
      ProjectCustomField.generate!(:visible => false, :role_ids => [1, 2]),
      VersionCustomField.generate!(:visible => false, :role_ids => [1, 2])
    ]

    get '/custom_fields.xml', :headers => credentials('admin')
    assert_response :success

    xml = Hash.from_xml(response.body)
    fields = xml['custom_fields']
    custom_fields.each do |custom_field|
      field = fields.detect {|f| f['id'] == custom_field.id.to_s}
      assert_kind_of Hash, field
      assert_kind_of Array, field['roles']
      roles = field['roles'].sort_by {|role| role['id'].to_i}
      assert_equal({'id' => '1', 'name' => 'Manager'}, roles[0])
      assert_equal({'id' => '2', 'name' => 'Developer'}, roles[1])
    end
  end

  test "GET /custom_fields.json should not include roles for custom fields that do not support role visibility" do
    custom_field = UserCustomField.generate!(:visible => false, :role_ids => [1, 2])

    get '/custom_fields.json', :headers => credentials('admin')
    assert_response :success

    json = ActiveSupport::JSON.decode(response.body)
    field = json['custom_fields'].detect {|f| f['id'] == custom_field.id}
    assert_kind_of Hash, field
    assert_not field.has_key?('roles')
  end

  test "GET /custom_fields.xml should include date offset default value mode" do
    field =
      IssueCustomField.generate!(
        :field_format => 'date',
        :default_value_mode => 'date_offset',
        :default_value => '-3'
      )

    get '/custom_fields.xml', :headers => credentials('admin')
    assert_response :success

    assert_select 'custom_field' do |elements|
      element = elements.detect {|e| e.at('id')&.text == field.id.to_s}
      assert_not_nil element
      assert_equal 'date_offset', element.at('default_value_mode').text
      assert_equal '-3', element.at('default_value').text
    end
  end
end
