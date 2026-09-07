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

require_relative '../test_helper'

class IssueCustomFieldTest < ActiveSupport::TestCase
  include Redmine::I18n

  def setup
    User.current = nil
  end

  def test_custom_field_with_visible_set_to_false_should_validate_roles
    set_language_if_valid 'en'
    field = IssueCustomField.new(:name => 'Field', :field_format => 'string', :visible => false)
    assert !field.save
    assert_include "Roles cannot be blank", field.errors.full_messages
    field.role_ids = [1, 2]
    assert field.save
  end

  def test_changing_visible_to_true_should_clear_roles
    field = IssueCustomField.create!(:name => 'Field', :field_format => 'string', :visible => false, :role_ids => [1, 2])
    assert_equal 2, field.roles.count

    field.visible = true
    field.save!
    assert_equal 0, field.roles.count
  end

  def test_destroy_should_delete_workflow_rules
    field = IssueCustomField.create!(:name => 'Field', :field_format => 'string')
    WorkflowPermission.create!(:role_id => 1, :tracker_id => 1, :old_status_id => 1, :field_name => field.id.to_s, :rule => 'required')
    assert_equal 1, WorkflowPermission.where(:field_name => field.id.to_s).count

    field.destroy
    assert_equal 0, WorkflowPermission.where(:field_name => field.id.to_s).count
  end
end
