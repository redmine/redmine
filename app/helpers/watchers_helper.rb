# encoding: utf-8
#
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

module WatchersHelper

  def watcher_link(objects, user)
    return '' unless user && user.logged?
    objects = Array.wrap(objects)
    return '' unless objects.any?

    watched = Watcher.any_watched?(objects, user)
    css = [watcher_css(objects), watched ? 'icon icon-fav' : 'icon icon-fav-off'].join(' ')
    text = watched ? l(:button_unwatch) : l(:button_watch)
    url = watch_path(
      :object_type => objects.first.class.to_s.underscore,
      :object_id => (objects.size == 1 ? objects.first.id : objects.map(&:id).sort)
    )
    method = watched ? 'delete' : 'post'

    link_to text, url, :remote => true, :method => method, :class => css
  end

  # Returns the css class used to identify watch links for a given +object+
  def watcher_css(objects)
    objects = Array.wrap(objects)
    id = (objects.size == 1 ? objects.first.id : 'bulk')
    "#{objects.first.class.to_s.underscore}-#{id}-watcher"
  end

  # Returns a comma separated list of users watching the given object
  def watchers_list(object)
    remove_allowed = User.current.allowed_to?("delete_#{object.class.name.underscore}_watchers".to_sym, object.project)
    content = ''.html_safe
    lis = object.watcher_users.preload(:email_address).collect do |user|
      s = ''.html_safe
      s << avatar(user, :size => "16").to_s
      s << link_to_user(user, :class => 'user')
      if remove_allowed
        url = {:controller => 'watchers',
               :action => 'destroy',
               :object_type => object.class.to_s.underscore,
               :object_id => object.id,
               :user_id => user}
        s << ' '
        s << link_to(l(:button_delete), url,
                     :remote => true, :method => 'delete',
                     :class => "delete icon-only icon-del",
                     :title => l(:button_delete))
      end
      content << content_tag('li', s, :class => "user-#{user.id}")
    end
    content.present? ? content_tag('ul', content, :class => 'watchers') : content
  end

  def watchers_checkboxes(object, users, checked=nil)
    users.map do |user|
      c = checked.nil? ? object.watched_by?(user) : checked
      tag = check_box_tag 'issue[watcher_user_ids][]', user.id, c, :id => nil
      content_tag 'label', "#{tag} #{h(user)}".html_safe,
                  :id => "issue_watcher_user_ids_#{user.id}",
                  :class => "floating"
    end.join.html_safe
  end
end
