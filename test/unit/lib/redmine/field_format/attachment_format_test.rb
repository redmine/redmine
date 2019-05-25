# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-2019  Jean-Philippe Lang
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

class Redmine::AttachmentFieldFormatTest < ActionView::TestCase
  include ApplicationHelper
  include Redmine::I18n

  fixtures :users

  def setup
    User.current = nil
    set_language_if_valid 'en'
    set_tmp_attachments_directory
  end

  def test_should_accept_a_hash_with_upload_on_create
    field = GroupCustomField.generate!(:name => "File", :field_format => 'attachment')
    group = Group.new(:name => 'Group')
    attachment = nil

    custom_value = new_record(CustomValue) do
      attachment = new_record(Attachment) do
        group.custom_field_values = {field.id => {:file => mock_file}}
        assert group.save
      end
    end

    assert_equal 'a_file.png', attachment.filename
    assert_equal custom_value, attachment.container
    assert_equal field, attachment.container.custom_field
    assert_equal group, attachment.container.customized
  end

  def test_should_accept_a_hash_with_no_upload_on_create
    field = GroupCustomField.generate!(:name => "File", :field_format => 'attachment')
    group = Group.new(:name => 'Group')
    attachment = nil

    custom_value = new_record(CustomValue) do
      assert_no_difference 'Attachment.count' do
        group.custom_field_values = {field.id => {}}
        assert group.save
      end
    end

    assert_equal '', custom_value.value
  end

  def test_should_not_validate_with_invalid_upload_on_create
    field = GroupCustomField.generate!(:name => "File", :field_format => 'attachment')
    group = Group.new(:name => 'Group')

    with_settings :attachment_max_size => 0 do
      assert_no_difference 'CustomValue.count' do
        assert_no_difference 'Attachment.count' do
          group.custom_field_values = {field.id => {:file => mock_file}}
          assert_equal false, group.save
        end
      end
    end
  end

  def test_should_accept_a_hash_with_token_on_create
    field = GroupCustomField.generate!(:name => "File", :field_format => 'attachment')
    group = Group.new(:name => 'Group')

    attachment = Attachment.create!(:file => mock_file, :author => User.find(2))
    assert_nil attachment.container

    custom_value = new_record(CustomValue) do
      assert_no_difference 'Attachment.count' do
        group.custom_field_values = {field.id => {:token => attachment.token}}
        assert group.save
      end
    end

    attachment.reload
    assert_equal custom_value, attachment.container
    assert_equal field, attachment.container.custom_field
    assert_equal group, attachment.container.customized
  end

  def test_should_not_validate_with_invalid_token_on_create
    field = GroupCustomField.generate!(:name => "File", :field_format => 'attachment')
    group = Group.new(:name => 'Group')

    assert_no_difference 'CustomValue.count' do
      assert_no_difference 'Attachment.count' do
        group.custom_field_values = {field.id => {:token => "123.0123456789abcdef"}}
        assert_equal false, group.save
      end
    end
  end

  def test_should_replace_attachment_on_update
    field = GroupCustomField.generate!(:name => "File", :field_format => 'attachment')
    group = Group.new(:name => 'Group')
    attachment = nil
    custom_value = new_record(CustomValue) do
      attachment = new_record(Attachment) do
        group.custom_field_values = {field.id => {:file => mock_file}}
        assert group.save
      end
    end
    group.reload

    assert_no_difference 'Attachment.count' do
      assert_no_difference 'CustomValue.count' do
        group.custom_field_values = {field.id => {:file => mock_file}}
        assert group.save
      end
    end

    assert !Attachment.exists?(attachment.id)
    assert CustomValue.exists?(custom_value.id)

    new_attachment = Attachment.order(:id => :desc).first
    custom_value.reload
    assert_equal custom_value, new_attachment.container
  end

  def test_should_delete_attachment_on_update
    field = GroupCustomField.generate!(:name => "File", :field_format => 'attachment')
    group = Group.new(:name => 'Group')
    attachment = nil
    custom_value = new_record(CustomValue) do
      attachment = new_record(Attachment) do
        group.custom_field_values = {field.id => {:file => mock_file}}
        assert group.save
      end
    end
    group.reload

    assert_difference 'Attachment.count', -1 do
      assert_no_difference 'CustomValue.count' do
        group.custom_field_values = {field.id => {}}
        assert group.save
      end
    end

    assert !Attachment.exists?(attachment.id)
    assert CustomValue.exists?(custom_value.id)

    custom_value.reload
    assert_equal '', custom_value.value
  end
end
