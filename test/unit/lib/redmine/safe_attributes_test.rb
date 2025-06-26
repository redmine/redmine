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

require File.expand_path('../../../../test_helper', __FILE__)

class Redmine::SafeAttributesTest < ActiveSupport::TestCase
  fixtures :users

  class Base
    def attributes=(attrs)
      attrs.each do |key, value|
        send("#{key}=", value)
      end
    end
  end

  class Person < Base
    attr_accessor :firstname, :lastname, :login
    include Redmine::SafeAttributes
    safe_attributes :firstname, :lastname
    safe_attributes :login, :if => lambda {|person, user| user.admin?}
  end

  class Book < Base
    attr_accessor :title
    include Redmine::SafeAttributes
    safe_attributes :title
  end

  def test_safe_attribute_names
    p = Person.new
    user = User.anonymous
    assert_equal ['firstname', 'lastname'], p.safe_attribute_names(user)
    assert p.safe_attribute?('firstname', user)
    assert !p.safe_attribute?('login', user)

    p = Person.new
    user = User.find(1)
    assert_equal ['firstname', 'lastname', 'login'], p.safe_attribute_names(user)
    assert p.safe_attribute?('firstname', user)
    assert p.safe_attribute?('login', user)
  end

  def test_safe_attribute_names_without_user
    p = Person.new
    User.current = nil
    assert_equal ['firstname', 'lastname'], p.safe_attribute_names
    assert p.safe_attribute?('firstname')
    assert !p.safe_attribute?('login')

    p = Person.new
    User.current = User.find(1)
    assert_equal ['firstname', 'lastname', 'login'], p.safe_attribute_names
    assert p.safe_attribute?('firstname')
    assert p.safe_attribute?('login')
  end

  def test_set_safe_attributes
    p = Person.new
    p.send(:safe_attributes=, {'firstname' => 'John', 'lastname' => 'Smith', 'login' => 'jsmith'}, User.anonymous)
    assert_equal 'John', p.firstname
    assert_equal 'Smith', p.lastname
    assert_nil p.login

    p = Person.new
    User.current = User.find(1)
    p.send(:safe_attributes=, {'firstname' => 'John', 'lastname' => 'Smith', 'login' => 'jsmith'}, User.find(1))
    assert_equal 'John', p.firstname
    assert_equal 'Smith', p.lastname
    assert_equal 'jsmith', p.login
  end

  def test_set_safe_attributes_without_user
    p = Person.new
    User.current = nil
    p.safe_attributes = {'firstname' => 'John', 'lastname' => 'Smith', 'login' => 'jsmith'}
    assert_equal 'John', p.firstname
    assert_equal 'Smith', p.lastname
    assert_nil p.login

    p = Person.new
    User.current = User.find(1)
    p.safe_attributes = {'firstname' => 'John', 'lastname' => 'Smith', 'login' => 'jsmith'}
    assert_equal 'John', p.firstname
    assert_equal 'Smith', p.lastname
    assert_equal 'jsmith', p.login
  end
end
