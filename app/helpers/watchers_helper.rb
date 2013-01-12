# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
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

  def watcher_tag(object, user, options={})
    content_tag("span", watcher_link(object, user), :class => watcher_css(object))
  end

  def watcher_link(object, user)
    return '' unless user && user.logged? && object.respond_to?('watched_by?')
    watched = object.watched_by?(user)
    url = {:controller => 'watchers',
           :action => (watched ? 'unwatch' : 'watch'),
           :object_type => object.class.to_s.underscore,
           :object_id => object.id}
    link_to((watched ? l(:button_unwatch) : l(:button_watch)), url,
            :remote => true, :method => 'post', :class => (watched ? 'icon icon-fav' : 'icon icon-fav-off'))

  end

  # Returns the css class used to identify watch links for a given +object+
  def watcher_css(object)
    "#{object.class.to_s.underscore}-#{object.id}-watcher"
  end

  # Returns a comma separated list of users watching the given object
  def watchers_list(object)
    remove_allowed = User.current.allowed_to?("delete_#{object.class.name.underscore}_watchers".to_sym, object.project)
    content = ''.html_safe
    lis = object.watcher_users.collect do |user|
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
        s << link_to(image_tag('delete.png'), url,
                     :remote => true, :method => 'post', :style => "vertical-align: middle", :class => "delete")
      end
      content << content_tag('li', s)
    end
    content.present? ? content_tag('ul', content) : content
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
