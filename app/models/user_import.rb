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

class UserImport < Import
  AUTO_MAPPABLE_FIELDS = {
    'login' => 'field_login',
    'firstname' => 'field_firstname',
    'lastname' => 'field_lastname',
    'mail' => 'field_mail',
    'language' => 'field_language',
    'admin' => 'field_admin',
    'auth_source' => 'field_auth_source',
    'password' => 'field_password',
    'must_change_passwd' => 'field_must_change_passwd',
    'status' => 'field_status'
  }

  def self.menu_item
    :users
  end

  def self.layout
    'admin'
  end

  def self.authorized?(user)
    user.admin?
  end

  # Returns the objects that were imported
  def saved_objects
    User.where(:id => saved_items.pluck(:obj_id)).order(:id)
  end

  def mappable_custom_fields
    UserCustomField.all
  end

  private

  def build_object(row, item)
    object = User.new

    attributes = {
      :login     => row_value(row, 'login'),
      :firstname => row_value(row, 'firstname'),
      :lastname  => row_value(row, 'lastname'),
      :mail      => row_value(row, 'mail')
    }

    lang = nil
    if language = row_value(row, 'language')
      lang = find_language(language)
    end
    attributes[:language] = lang || Setting.default_language

    if admin = row_value(row, 'admin')
      if yes?(admin)
        attributes['admin'] = '1'
      end
    end

    if auth_source_name = row_value(row, 'auth_source')
      if auth_source = AuthSource.find_by(:name => auth_source_name)
        attributes[:auth_source_id] = auth_source.id
      end
    end

    if password = row_value(row, 'password')
      object.password = password
      object.password_confirmation = password
    end

    if must_change_passwd = row_value(row, 'must_change_passwd')
      if yes?(must_change_passwd)
        attributes[:must_change_passwd] = '1'
      end
    end

    if status_name = row_value(row, 'status')
      if status = User::LABEL_BY_STATUS.key(status_name)
        attributes[:status] = status
      end
    end

    attributes['custom_field_values'] = object.custom_field_values.each_with_object({}) do |v, h|
      value =
        case v.custom_field.field_format
        when 'date'
          row_date(row, "cf_#{v.custom_field.id}")
        else
          row_value(row, "cf_#{v.custom_field.id}")
        end
      if value
        h[v.custom_field.id.to_s] = v.custom_field.value_from_keyword(value, object)
      end
    end

    object.send(:safe_attributes=, attributes, user)
    object
  end

  def extend_object(row, item, object)
    Mailer.deliver_account_information(object, object.password) if yes?(settings['notifications'])
  end
end
