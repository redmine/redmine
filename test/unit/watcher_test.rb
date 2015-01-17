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

require File.expand_path('../../test_helper', __FILE__)

class WatcherTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :members, :member_roles, :roles, :enabled_modules,
           :issues, :issue_statuses, :enumerations, :trackers, :projects_trackers,
           :boards, :messages,
           :wikis, :wiki_pages,
           :watchers

  def setup
    @user = User.find(1)
    @issue = Issue.find(1)
  end

  def test_validate
    user = User.find(5)
    assert !user.active?
    watcher = Watcher.new(:user_id => user.id)
    assert !watcher.save
  end

  def test_watch
    assert @issue.add_watcher(@user)
    @issue.reload
    assert @issue.watchers.detect { |w| w.user == @user }
  end

  def test_cant_watch_twice
    assert @issue.add_watcher(@user)
    assert !@issue.add_watcher(@user)
  end

  def test_watched_by
    assert @issue.add_watcher(@user)
    @issue.reload
    assert @issue.watched_by?(@user)
    assert Issue.watched_by(@user).include?(@issue)
  end

  def test_watcher_users
    watcher_users = Issue.find(2).watcher_users
    assert_kind_of Array, watcher_users.collect{|w| w}
    assert_kind_of User, watcher_users.first
  end

  def test_watcher_users_should_not_validate_user
    User.where(:id => 1).update_all("firstname = ''")
    @user.reload
    assert !@user.valid?

    issue = Issue.new(:project => Project.find(1), :tracker_id => 1, :subject => "test", :author => User.find(2))
    issue.watcher_users << @user
    issue.save!
    assert issue.watched_by?(@user)
  end

  def test_watcher_user_ids
    assert_equal [1, 3], Issue.find(2).watcher_user_ids.sort
  end

  def test_watcher_user_ids=
    issue = Issue.new
    issue.watcher_user_ids = ['1', '3']
    assert issue.watched_by?(User.find(1))
  end

  def test_watcher_user_ids_should_make_ids_uniq
    issue = Issue.new(:project => Project.find(1), :tracker_id => 1, :subject => "test", :author => User.find(2))
    issue.watcher_user_ids = ['1', '3', '1']
    issue.save!
    assert_equal 2, issue.watchers.count
  end

  def test_addable_watcher_users
    addable_watcher_users = @issue.addable_watcher_users
    assert_kind_of Array, addable_watcher_users
    assert_kind_of User, addable_watcher_users.first
  end

  def test_addable_watcher_users_should_not_include_user_that_cannot_view_the_object
    issue = Issue.new(:project => Project.find(1), :is_private => true)
    assert_nil issue.addable_watcher_users.detect {|user| !issue.visible?(user)}
  end

  def test_any_watched_should_return_false_if_no_object_is_watched
    objects = (0..2).map {Issue.generate!}

    assert_equal false, Watcher.any_watched?(objects, @user)
  end

  def test_any_watched_should_return_true_if_one_object_is_watched
    objects = (0..2).map {Issue.generate!}
    objects.last.add_watcher(@user)

    assert_equal true, Watcher.any_watched?(objects, @user)
  end

  def test_any_watched_should_return_false_with_no_object
    assert_equal false, Watcher.any_watched?([], @user)
  end

  def test_recipients
    @issue.watchers.delete_all
    @issue.reload

    assert @issue.watcher_recipients.empty?
    assert @issue.add_watcher(@user)

    @user.mail_notification = 'all'
    @user.save!
    @issue.reload
    assert @issue.watcher_recipients.include?(@user.mail)

    @user.mail_notification = 'none'
    @user.save!
    @issue.reload
    assert !@issue.watcher_recipients.include?(@user.mail)
  end

  def test_unwatch
    assert @issue.add_watcher(@user)
    @issue.reload
    assert_equal 1, @issue.remove_watcher(@user)
  end

  def test_prune_with_user
    Watcher.delete_all("user_id = 9")
    user = User.find(9)

    # public
    Watcher.create!(:watchable => Issue.find(1), :user => user)
    Watcher.create!(:watchable => Issue.find(2), :user => user)
    Watcher.create!(:watchable => Message.find(1), :user => user)
    Watcher.create!(:watchable => Wiki.find(1), :user => user)
    Watcher.create!(:watchable => WikiPage.find(2), :user => user)

    # private project (id: 2)
    Member.create!(:project => Project.find(2), :principal => user, :role_ids => [1])
    Watcher.create!(:watchable => Issue.find(4), :user => user)
    Watcher.create!(:watchable => Message.find(7), :user => user)
    Watcher.create!(:watchable => Wiki.find(2), :user => user)
    Watcher.create!(:watchable => WikiPage.find(3), :user => user)

    assert_no_difference 'Watcher.count' do
      Watcher.prune(:user => User.find(9))
    end

    Member.delete_all

    assert_difference 'Watcher.count', -4 do
      Watcher.prune(:user => User.find(9))
    end

    assert Issue.find(1).watched_by?(user)
    assert !Issue.find(4).watched_by?(user)
  end

  def test_prune_with_project
    user = User.find(9)
    Watcher.new(:watchable => Issue.find(4), :user => User.find(9)).save(:validate => false) # project 2
    Watcher.new(:watchable => Issue.find(6), :user => User.find(9)).save(:validate => false) # project 5

    assert Watcher.prune(:project => Project.find(5)) > 0
    assert Issue.find(4).watched_by?(user)
    assert !Issue.find(6).watched_by?(user)
  end

  def test_prune_all
    user = User.find(9)
    Watcher.new(:watchable => Issue.find(4), :user => User.find(9)).save(:validate => false)

    assert Watcher.prune > 0
    assert !Issue.find(4).watched_by?(user)
  end
end
