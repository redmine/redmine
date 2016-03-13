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

require File.expand_path('../../../../../test_helper', __FILE__)
require 'redmine/field_format'

class Redmine::LinkFieldFormatTest < ActionView::TestCase
  def test_link_field_should_substitute_value
    field = IssueCustomField.new(:field_format => 'link', :url_pattern => 'http://foo/%value%')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "bar")

    assert_equal "bar", field.format.formatted_custom_value(self, custom_value, false)
    assert_equal '<a href="http://foo/bar">bar</a>', field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_link_field_should_substitute_object_id_in_url
    object = Issue.new
    object.stubs(:id).returns(10)

    field = IssueCustomField.new(:field_format => 'link', :url_pattern => 'http://foo/%id%')
    custom_value = CustomValue.new(:custom_field => field, :customized => object, :value => "bar")

    assert_equal "bar", field.format.formatted_custom_value(self, custom_value, false)
    assert_equal '<a href="http://foo/10">bar</a>', field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_link_field_should_substitute_project_id_in_url
    project = Project.new
    project.stubs(:id).returns(52)
    object = Issue.new
    object.stubs(:project).returns(project)

    field = IssueCustomField.new(:field_format => 'link', :url_pattern => 'http://foo/%project_id%')
    custom_value = CustomValue.new(:custom_field => field, :customized => object, :value => "bar")

    assert_equal "bar", field.format.formatted_custom_value(self, custom_value, false)
    assert_equal '<a href="http://foo/52">bar</a>', field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_link_field_should_substitute_project_identifier_in_url
    project = Project.new
    project.stubs(:identifier).returns('foo_project-00')
    object = Issue.new
    object.stubs(:project).returns(project)

    field = IssueCustomField.new(:field_format => 'link', :url_pattern => 'http://foo/%project_identifier%')
    custom_value = CustomValue.new(:custom_field => field, :customized => object, :value => "bar")

    assert_equal "bar", field.format.formatted_custom_value(self, custom_value, false)
    assert_equal '<a href="http://foo/foo_project-00">bar</a>', field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_link_field_should_substitute_regexp_groups
    field = IssueCustomField.new(:field_format => 'link', :regexp => /^(.+)-(.+)$/, :url_pattern => 'http://foo/%m2%/%m1%')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "56-142")

    assert_equal "56-142", field.format.formatted_custom_value(self, custom_value, false)
    assert_equal '<a href="http://foo/142/56">56-142</a>', field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_link_field_without_url_pattern_should_link_to_value
    field = IssueCustomField.new(:field_format => 'link')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "http://foo/bar")

    assert_equal "http://foo/bar", field.format.formatted_custom_value(self, custom_value, false)
    assert_equal '<a href="http://foo/bar">http://foo/bar</a>', field.format.formatted_custom_value(self, custom_value, true)
  end

  def test_link_field_without_url_pattern_should_link_to_value_with_http_by_default
    field = IssueCustomField.new(:field_format => 'link')
    custom_value = CustomValue.new(:custom_field => field, :customized => Issue.new, :value => "foo.bar")

    assert_equal "foo.bar", field.format.formatted_custom_value(self, custom_value, false)
    assert_equal '<a href="http://foo.bar">foo.bar</a>', field.format.formatted_custom_value(self, custom_value, true)
  end
end
