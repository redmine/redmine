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

require File.expand_path('../../../test_helper', __FILE__)

class PatchesTest < ActiveSupport::TestCase
  include Redmine::I18n

  def setup
    Setting.default_language = 'en'
    @symbols = { :a => 1, :b => 2 }
    @keys = %w( blue green red pink orange )
    @values = %w( 000099 009900 aa0000 cc0066 cc6633 )
    @hash = Hash.new
    @ordered_hash = ActiveSupport::OrderedHash.new

    @keys.each_with_index do |key, index|
      @hash[key] = @values[index]
      @ordered_hash[key] = @values[index]
    end
  end

  test "ActiveRecord::Base.human_attribute_name should transform name to field_name" do
    assert_equal l('field_last_login_on'), ActiveRecord::Base.human_attribute_name('last_login_on')
  end

  test "ActiveRecord::Base.human_attribute_name should cut extra _id suffix for better validation" do
    assert_equal l('field_last_login_on'), ActiveRecord::Base.human_attribute_name('last_login_on_id')
  end

  test "ActiveRecord::Base.human_attribute_name should default to humanized value if no translation has been found (useful for custom fields)" do
    assert_equal 'Patch name', ActiveRecord::Base.human_attribute_name('Patch name')
  end

  # https://github.com/rails/rails/pull/14198/files
  def test_indifferent_select
    hash = ActiveSupport::HashWithIndifferentAccess.new(@symbols).select { |_ ,v| v == 1 }
    assert_equal({ 'a' => 1 }, hash)
    assert_instance_of ((Rails::VERSION::MAJOR < 4 && RUBY_VERSION < "2.1") ?
                          Hash : ActiveSupport::HashWithIndifferentAccess),
                        hash
  end

  def test_indifferent_select_bang
    indifferent_strings = ActiveSupport::HashWithIndifferentAccess.new(@symbols)
    indifferent_strings.select! { |_, v| v == 1 }
    assert_equal({ 'a' => 1 }, indifferent_strings)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, indifferent_strings
  end

  def test_indifferent_reject
    hash = ActiveSupport::HashWithIndifferentAccess.new(@symbols).reject { |_, v| v != 1 }
    assert_equal({ 'a' => 1 }, hash)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, hash
  end

  def test_indifferent_reject_bang
    indifferent_strings = ActiveSupport::HashWithIndifferentAccess.new(@symbols)
    indifferent_strings.reject! { |_, v| v != 1 }
    assert_equal({ 'a' => 1 }, indifferent_strings)
    assert_instance_of ActiveSupport::HashWithIndifferentAccess, indifferent_strings
  end

  def test_select
    assert_equal @keys, @ordered_hash.select { true }.map(&:first)
    new_ordered_hash = @ordered_hash.select { true }
    assert_equal @keys, new_ordered_hash.map(&:first)
    assert_instance_of ((Rails::VERSION::MAJOR < 4 && RUBY_VERSION < "2.1") ?
                          Hash : ActiveSupport::OrderedHash),
                        new_ordered_hash
  end

  def test_reject
    copy = @ordered_hash.dup
    new_ordered_hash = @ordered_hash.reject { |k, _| k == 'pink' }
    assert_equal copy, @ordered_hash
    assert !new_ordered_hash.keys.include?('pink')
    assert @ordered_hash.keys.include?('pink')
    assert_instance_of ActiveSupport::OrderedHash, new_ordered_hash
  end
end
