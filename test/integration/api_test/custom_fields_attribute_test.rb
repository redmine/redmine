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

require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::CustomFieldsAttributeTest < Redmine::ApiTest::Base
  fixtures :users

  def test_integer_custom_fields_should_accept_strings
    field = GroupCustomField.generate!(:field_format => 'int')

    post '/groups.json', %({"group":{"name":"Foo","custom_field_values":{"#{field.id}":"52"}}}),
      {'CONTENT_TYPE' => 'application/json'}.merge(credentials('admin'))
    assert_response :created
    group = Group.order('id DESC').first
    assert_equal "52", group.custom_field_value(field)
  end

  def test_integer_custom_fields_should_accept_integers
    field = GroupCustomField.generate!(:field_format => 'int')

    post '/groups.json', %({"group":{"name":"Foo","custom_field_values":{"#{field.id}":52}}}),
      {'CONTENT_TYPE' => 'application/json'}.merge(credentials('admin'))
    assert_response :created
    group = Group.order('id DESC').first
    assert_equal "52", group.custom_field_value(field)
  end

  def test_multivalued_custom_fields_should_accept_an_array
    field = GroupCustomField.generate!(
      :field_format => 'list',
      :multiple => true,
      :possible_values => ["V1", "V2", "V3"],
      :default_value => "V2"
    )

payload = <<-JSON
{"group": {"name":"Foooo",
"custom_field_values":{"#{field.id}":["V1","V3"]}
}
}
JSON

    post '/groups.json', payload, {'CONTENT_TYPE' => 'application/json'}.merge(credentials('admin'))
    assert_response :created
    group = Group.order('id DESC').first
    assert_equal ["V1", "V3"], group.custom_field_value(field).sort
  end
end
