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

module AvatarsHelper
  include GravatarHelper::PublicMethods

  def assignee_avatar(user, options={})
    return '' unless user

    options.merge!(:title => l(:field_assigned_to) + ": " + user.name)
    avatar(user, options).to_s.html_safe
  end

  def author_avatar(user, options={})
    return '' unless user

    options.merge!(:title => l(:field_author) + ": " + user.name)
    avatar(user, options).to_s.html_safe
  end

  # Returns the avatar image tag for the given +user+ if avatars are enabled
  # +user+ can be a User or a string that will be scanned for an email address (eg. 'joe <joe@foo.bar>')
  def avatar(user, options = { })
    if Setting.gravatar_enabled?
      options.merge!(:default => Setting.gravatar_default)
      options[:class] = GravatarHelper::DEFAULT_OPTIONS[:class] + " " + options[:class] if options[:class]
      email = nil
      if user.respond_to?(:mail)
        email = user.mail
        options[:title] = user.name unless options[:title]
      elsif user.to_s =~ %r{<(.+?)>}
        email = $1
      end
      if email.present?
        gravatar(email.to_s.downcase, options) rescue nil
      elsif user.is_a?(AnonymousUser)
        anonymous_avatar(options)
      else
        nil
      end
    else
      ''
    end
  end

  # Returns a link to edit user's avatar if avatars are enabled
  def avatar_edit_link(user, options={})
    if Setting.gravatar_enabled?
      url = Redmine::Configuration['avatar_server_url']
      link_to avatar(user, {:title => l(:button_edit)}.merge(options)), url, :target => '_blank'
    end
  end

  private

  def anonymous_avatar(options={})
    image_tag 'anonymous.png', GravatarHelper::DEFAULT_OPTIONS.except(:default, :rating, :ssl).merge(options)
  end
end
