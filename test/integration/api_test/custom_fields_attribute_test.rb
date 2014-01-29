# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
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

  def setup
    Setting.rest_api_enabled = '1'
  end

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
end
