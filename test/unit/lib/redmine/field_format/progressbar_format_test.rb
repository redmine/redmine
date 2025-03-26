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

require_relative '../../../../test_helper'
require 'redmine/field_format'

module Redmine::FieldFormat
  class ProgressbarFormatTest < ActiveSupport::TestCase
    def setup
      @field = IssueCustomField.new(name: 'ProgressbarTest', field_format: 'progressbar')
      @format = Redmine::FieldFormat::ProgressbarFormat.instance
    end

    def test_validate_invalid_value
      cv = CustomValue.new(custom_field: @field, value: '120')
      assert_include ::I18n.t('activerecord.errors.messages.invalid'), @format.validate_custom_value(cv)
    end

    def test_validate_numericality
      cv = CustomValue.new(custom_field: @field, value: 'abc')
      assert_include ::I18n.t('activerecord.errors.messages.not_a_number'), @format.validate_custom_value(cv)
    end

    def test_cast_value_clamping
      assert_equal 0, @field.cast_value('-10')
      assert_equal 0, @field.cast_value('0')
      assert_equal 50, @field.cast_value('50')
      assert_equal 100, @field.cast_value('120')
    end

    def test_empty_value
      assert_nil @field.cast_value('')
    end

    def test_totalable_support
      assert_not @format.totalable_supported?
    end

    def test_validate_non_numeric_value_should_fail
      assert_include ::I18n.t('activerecord.errors.messages.not_a_number'),
        @format.validate_single_value(@field, "abc")
    end

    def test_validate_negative_value_should_fail
      assert_include ::I18n.t('activerecord.errors.messages.invalid'),
        @format.validate_single_value(@field, "-10")
    end

    def test_validate_value_above_100_should_fail
      assert_include ::I18n.t('activerecord.errors.messages.invalid'),
        @format.validate_single_value(@field, "150")
    end

    def test_validate_valid_value_should_pass
      assert_empty @format.validate_single_value(@field, "50")
      assert_empty @format.validate_single_value(@field, "0")
      assert_empty @format.validate_single_value(@field, "100")
    end

    def test_validate_blank_value_should_pass
      assert_empty @format.validate_single_value(@field, "")
    end

    def test_query_filter_options
      options = @format.query_filter_options(@field, nil)
      assert_equal :integer, options[:type]
    end
  end
end
