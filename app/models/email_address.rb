# Redmine - project management software
# Copyright (C) 2006-2017  Jean-Philippe Lang
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

class EmailAddress < ActiveRecord::Base
  include Redmine::SafeAttributes

  belongs_to :user

  after_update :destroy_tokens
  after_destroy :destroy_tokens

  after_create_commit :deliver_security_notification_create
  after_update_commit :deliver_security_notification_update
  after_destroy_commit :deliver_security_notification_destroy

  validates_presence_of :address
  validates_format_of :address, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i, :allow_blank => true
  validates_length_of :address, :maximum => User::MAIL_LENGTH_LIMIT, :allow_nil => true
  validates_uniqueness_of :address, :case_sensitive => false,
    :if => Proc.new {|email| email.address_changed? && email.address.present?}

  safe_attributes 'address'

  def address=(arg)
    write_attribute(:address, arg.to_s.strip)
  end

  def destroy
    if is_default?
      false
    else
      super
    end
  end

  private

  # send a security notification to user that a new email address was added
  def deliver_security_notification_create
    # only deliver if this isn't the only address.
    # in that case, the user is just being created and
    # should not receive this email.
    if user.mails != [address]
      deliver_security_notification(
        message: :mail_body_security_notification_add,
        field: :field_mail,
        value: address
      )
    end
  end

  # send a security notification to user that an email has been changed (notified/not notified)
  def deliver_security_notification_update
    if saved_change_to_address?
      options = {
        recipients: [address_before_last_save],
        message: :mail_body_security_notification_change_to,
        field: :field_mail,
        value: address
      }
    elsif saved_change_to_notify?
      options = {
        recipients: [address],
        message: notify_before_last_save ? :mail_body_security_notification_notify_disabled : :mail_body_security_notification_notify_enabled,
        value: address
      }
    end
    deliver_security_notification(options)
  end

  # send a security notification to user that an email address was deleted
  def deliver_security_notification_destroy
    deliver_security_notification(
      recipients: [address],
      message: :mail_body_security_notification_remove,
      field: :field_mail,
      value: address
    )
  end

  # generic method to send security notifications for email addresses
  def deliver_security_notification(options={})
    Mailer.deliver_security_notification(user,
      User.current,
      options.merge(
        title: :label_my_account,
        url: {controller: 'my', action: 'account'}
      )
    )
  end

  # Delete all outstanding password reset tokens on email change.
  # This helps to keep the account secure in case the associated email account
  # was compromised.
  def destroy_tokens
    if saved_change_to_address? || destroyed?
      tokens = ['recovery']
      Token.where(:user_id => user_id, :action => tokens).delete_all
    end
  end
end
