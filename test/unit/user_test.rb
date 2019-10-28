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

require File.expand_path('../../test_helper', __FILE__)

class UserTest < ActiveSupport::TestCase
  fixtures :users, :email_addresses, :members, :projects, :roles, :member_roles, :auth_sources,
           :trackers, :issue_statuses,
           :projects_trackers,
           :watchers,
           :issue_categories, :enumerations, :issues,
           :journals, :journal_details,
           :groups_users,
           :enabled_modules,
           :tokens,
           :user_preferences

  include Redmine::I18n

  def setup
    @admin = User.find(1)
    @jsmith = User.find(2)
    @dlopper = User.find(3)
    User.current = nil
  end

  def test_admin_scope_without_args_should_return_admin_users
    users = User.admin.to_a
    assert users.any?
    assert users.all? {|u| u.admin == true}
  end

  def test_admin_scope_with_true_should_return_admin_users
    users = User.admin(true).to_a
    assert users.any?
    assert users.all? {|u| u.admin == true}
  end

  def test_admin_scope_with_false_should_return_non_admin_users
    users = User.admin(false).to_a
    assert users.any?
    assert users.all? {|u| u.admin == false}
  end

  def test_sorted_scope_should_sort_user_by_display_name
    # Use .active to ignore anonymous with localized display name
    assert_equal User.active.map(&:name).map(&:downcase).sort,
                 User.active.sorted.map(&:name).map(&:downcase)
  end

  def test_generate
    User.generate!(:firstname => 'Testing connection')
    User.generate!(:firstname => 'Testing connection')
    assert_equal 2, User.where(:firstname => 'Testing connection').count
  end

  def test_truth
    assert_kind_of User, @jsmith
  end

  def test_should_validate_status
    user = User.new
    user.status = 0

    assert !user.save
    assert_include I18n.translate('activerecord.errors.messages.invalid'), user.errors[:status]
  end

  def test_mail_should_be_stripped
    u = User.new
    u.mail = " foo@bar.com  "
    assert_equal "foo@bar.com", u.mail
  end

  def test_should_create_email_address
    u = User.new(:firstname => "new", :lastname => "user")
    u.login = "create_email_address"
    u.mail = "defaultemail@somenet.foo"
    assert u.save
    u.reload
    assert u.email_address
    assert_equal "defaultemail@somenet.foo", u.email_address.address
    assert_equal true, u.email_address.is_default
    assert_equal true, u.email_address.notify
  end

  def test_should_not_create_user_without_mail
    set_language_if_valid 'en'
    u = User.new(:firstname => "new", :lastname => "user")
    u.login = "user_without_mail"
    assert !u.save
    assert_equal ["Email #{I18n.translate('activerecord.errors.messages.blank')}"], u.errors.full_messages
  end

  def test_should_not_create_user_with_blank_mail
    set_language_if_valid 'en'
    u = User.new(:firstname => "new", :lastname => "user")
    u.login = "user_with_blank_mail"
    u.mail = ''
    assert !u.save
    assert_equal ["Email #{I18n.translate('activerecord.errors.messages.blank')}"], u.errors.full_messages
  end

  def test_should_not_update_user_with_blank_mail
    set_language_if_valid 'en'
    u = User.find(2)
    u.mail = ''
    assert !u.save
    assert_equal ["Email #{I18n.translate('activerecord.errors.messages.blank')}"], u.errors.full_messages
  end

  def test_login_length_validation
    user = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
    user.login = "x" * (User::LOGIN_LENGTH_LIMIT+1)
    assert !user.valid?

    user.login = "x" * (User::LOGIN_LENGTH_LIMIT)
    assert user.valid?
    assert user.save
  end

  def test_generate_password_should_respect_minimum_password_length
    with_settings :password_min_length => 15 do
      user = User.generate!(:generate_password => true)
      assert user.password.length >= 15
    end
  end

  def test_generate_password_should_not_generate_password_with_less_than_10_characters
    with_settings :password_min_length => 4 do
      user = User.generate!(:generate_password => true)
      assert user.password.length >= 10
    end
  end

  def test_generate_password_on_create_should_set_password
    user = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
    user.login = "newuser"
    user.generate_password = true
    assert user.save

    password = user.password
    assert user.check_password?(password)
  end

  def test_generate_password_on_update_should_update_password
    user = User.find(2)
    hash = user.hashed_password
    user.generate_password = true
    assert user.save

    password = user.password
    assert user.check_password?(password)
    assert_not_equal hash, user.reload.hashed_password
  end

  def test_create
    user = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")

    user.login = "jsmith"
    user.password, user.password_confirmation = "password", "password"
    # login uniqueness
    assert !user.save
    assert_equal 1, user.errors.count

    user.login = "newuser"
    user.password, user.password_confirmation = "password", "pass"
    # password confirmation
    assert !user.save
    assert_equal 1, user.errors.count

    user.password, user.password_confirmation = "password", "password"
    assert user.save
  end

  def test_user_before_create_should_set_the_mail_notification_to_the_default_setting
    @user1 = User.generate!
    assert_equal 'only_my_events', @user1.mail_notification
    with_settings :default_notification_option => 'all' do
      @user2 = User.generate!
      assert_equal 'all', @user2.mail_notification
    end
  end

  def test_user_login_should_be_case_insensitive
    u = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
    u.login = 'newuser'
    u.password, u.password_confirmation = "password", "password"
    assert u.save
    u = User.new(:firstname => "Similar", :lastname => "User",
                 :mail => "similaruser@somenet.foo")
    u.login = 'NewUser'
    u.password, u.password_confirmation = "password", "password"
    assert !u.save
    assert_include I18n.translate('activerecord.errors.messages.taken'), u.errors[:login]
  end

  def test_mail_uniqueness_should_not_be_case_sensitive
    set_language_if_valid 'en'
    u = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
    u.login = 'newuser1'
    u.password, u.password_confirmation = "password", "password"
    assert u.save

    u = User.new(:firstname => "new", :lastname => "user", :mail => "newUser@Somenet.foo")
    u.login = 'newuser2'
    u.password, u.password_confirmation = "password", "password"
    assert !u.save
    assert_include "Email #{I18n.translate('activerecord.errors.messages.taken')}", u.errors.full_messages
  end

  def test_update
    assert_equal "admin", @admin.login
    @admin.login = "john"
    assert @admin.save, @admin.errors.full_messages.join("; ")
    @admin.reload
    assert_equal "john", @admin.login
  end

  def test_update_should_not_fail_for_legacy_user_with_different_case_logins
    u1 = User.new(:firstname => "new", :lastname => "user", :mail => "newuser1@somenet.foo")
    u1.login = 'newuser1'
    assert u1.save

    u2 = User.new(:firstname => "new", :lastname => "user", :mail => "newuser2@somenet.foo")
    u2.login = 'newuser1'
    assert u2.save(:validate => false)

    user = User.find(u2.id)
    user.firstname = "firstname"
    assert user.save, "Save failed"
  end

  def test_destroy_should_delete_members_and_roles
    members = Member.where(:user_id => 2)
    ms = members.count
    rs = members.collect(&:roles).flatten.size
    assert ms > 0
    assert rs > 0
    assert_difference 'Member.count', - ms do
      assert_difference 'MemberRole.count', - rs do
        User.find(2).destroy
      end
    end
    assert_nil User.find_by_id(2)
    assert_equal 0, Member.where(:user_id => 2).count
  end

  def test_destroy_should_update_attachments
    set_tmp_attachments_directory
    attachment = Attachment.create!(:container => Project.find(1),
      :file => uploaded_test_file("testfile.txt", "text/plain"),
      :author_id => 2)

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, attachment.reload.author
  end

  def test_destroy_should_update_comments
    comment = Comment.create!(
      :commented => News.create!(:project_id => 1,
                                 :author_id => 1, :title => 'foo', :description => 'foo'),
      :author => User.find(2),
      :comments => 'foo'
    )

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, comment.reload.author
  end

  def test_destroy_should_update_issues
    issue = Issue.create!(:project_id => 1, :author_id => 2,
                          :tracker_id => 1, :subject => 'foo')

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, issue.reload.author
  end

  def test_destroy_should_unassign_issues
    issue = Issue.create!(:project_id => 1, :author_id => 1,
                          :tracker_id => 1, :subject => 'foo', :assigned_to_id => 2)

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil issue.reload.assigned_to
  end

  def test_destroy_should_update_journals
    issue = Issue.create!(:project_id => 1, :author_id => 2,
                          :tracker_id => 1, :subject => 'foo')
    issue.init_journal(User.find(2), "update")
    issue.save!

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, issue.journals.first.reload.user
  end

  def test_destroy_should_update_journal_details_old_value
    issue = Issue.create!(:project_id => 1, :author_id => 1,
                          :tracker_id => 1, :subject => 'foo', :assigned_to_id => 2)
    issue.init_journal(User.find(1), "update")
    issue.assigned_to_id = nil
    assert_difference 'JournalDetail.count' do
      issue.save!
    end
    journal_detail = JournalDetail.order('id DESC').first
    assert_equal '2', journal_detail.old_value

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous.id.to_s, journal_detail.reload.old_value
  end

  def test_destroy_should_update_journal_details_value
    issue = Issue.create!(:project_id => 1, :author_id => 1,
                          :tracker_id => 1, :subject => 'foo')
    issue.init_journal(User.find(1), "update")
    issue.assigned_to_id = 2
    assert_difference 'JournalDetail.count' do
      issue.save!
    end
    journal_detail = JournalDetail.order('id DESC').first
    assert_equal '2', journal_detail.value

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous.id.to_s, journal_detail.reload.value
  end

  def test_destroy_should_update_messages
    board = Board.create!(:project_id => 1, :name => 'Board', :description => 'Board')
    message = Message.create!(:board_id => board.id, :author_id => 2,
                              :subject => 'foo', :content => 'foo')
    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, message.reload.author
  end

  def test_destroy_should_update_news
    news = News.create!(:project_id => 1, :author_id => 2,
                        :title => 'foo', :description => 'foo')
    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, news.reload.author
  end

  def test_destroy_should_delete_private_queries
    query = Query.new(:name => 'foo', :visibility => Query::VISIBILITY_PRIVATE)
    query.project_id = 1
    query.user_id = 2
    query.save!

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil Query.find_by_id(query.id)
  end

  def test_destroy_should_update_public_queries
    query = Query.new(:name => 'foo', :visibility => Query::VISIBILITY_PUBLIC)
    query.project_id = 1
    query.user_id = 2
    query.save!

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, query.reload.user
  end

  def test_destroy_should_update_time_entries
    entry = TimeEntry.new(:hours => '2', :spent_on => Date.today,
                          :activity => TimeEntryActivity.create!(:name => 'foo'))
    entry.project_id = 1
    entry.user_id = 2
    entry.save!

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, entry.reload.user
  end

  def test_destroy_should_delete_tokens
    token = Token.create!(:user_id => 2, :value => 'foo')

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil Token.find_by_id(token.id)
  end

  def test_destroy_should_delete_watchers
    issue = Issue.create!(:project_id => 1, :author_id => 1,
                          :tracker_id => 1, :subject => 'foo')
    watcher = Watcher.create!(:user_id => 2, :watchable => issue)

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil Watcher.find_by_id(watcher.id)
  end

  def test_destroy_should_update_wiki_contents
    wiki_content = WikiContent.create!(
      :text => 'foo',
      :author_id => 2,
      :page => WikiPage.create!(:title => 'Foo',
                                :wiki => Wiki.create!(:project_id => 3,
                                                      :start_page => 'Start'))
    )
    wiki_content.text = 'bar'
    assert_difference 'WikiContent::Version.count' do
      wiki_content.save!
    end

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, wiki_content.reload.author
    wiki_content.versions.each do |version|
      assert_equal User.anonymous, version.reload.author
    end
  end

  def test_destroy_should_nullify_issue_categories
    category = IssueCategory.create!(:project_id => 1, :assigned_to_id => 2, :name => 'foo')

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil category.reload.assigned_to_id
  end

  def test_destroy_should_nullify_changesets
    changeset = Changeset.create!(
      :repository => Repository::Subversion.create!(
        :project_id => 1,
        :url => 'file:///tmp',
        :identifier => 'tmp'
      ),
      :revision => '12',
      :committed_on => Time.now,
      :committer => 'jsmith'
      )
    assert_equal 2, changeset.user_id

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil changeset.reload.user_id
  end

  def test_anonymous_user_should_not_be_destroyable
    assert_no_difference 'User.count' do
      assert_equal false, User.anonymous.destroy
    end
  end

  def test_password_change_should_destroy_tokens
    recovery_token = Token.create!(:user_id => 2, :action => 'recovery')
    autologin_token = Token.create!(:user_id => 2, :action => 'autologin')

    user = User.find(2)
    user.password, user.password_confirmation = "a new password", "a new password"
    assert user.save

    assert_nil Token.find_by_id(recovery_token.id)
    assert_nil Token.find_by_id(autologin_token.id)
  end

  def test_mail_change_should_destroy_tokens
    recovery_token = Token.create!(:user_id => 2, :action => 'recovery')
    autologin_token = Token.create!(:user_id => 2, :action => 'autologin')

    user = User.find(2)
    user.mail = "user@somwehere.com"
    assert user.save

    assert_nil Token.find_by_id(recovery_token.id)
    assert_equal autologin_token, Token.find_by_id(autologin_token.id)
  end

  def test_change_on_other_fields_should_not_destroy_tokens
    recovery_token = Token.create!(:user_id => 2, :action => 'recovery')
    autologin_token = Token.create!(:user_id => 2, :action => 'autologin')

    user = User.find(2)
    user.firstname = "Bobby"
    assert user.save

    assert_equal recovery_token, Token.find_by_id(recovery_token.id)
    assert_equal autologin_token, Token.find_by_id(autologin_token.id)
  end

  def test_validate_login_presence
    @admin.login = ""
    assert !@admin.save
    assert_equal 1, @admin.errors.count
  end

  def test_validate_mail_notification_inclusion
    u = User.new
    u.mail_notification = 'foo'
    u.save
    assert_not_equal [], u.errors[:mail_notification]
  end

  def test_password
    user = User.try_to_login("admin", "admin")
    assert_kind_of User, user
    assert_equal "admin", user.login
    user.password = "hello123"
    assert user.save

    user = User.try_to_login("admin", "hello123")
    assert_kind_of User, user
    assert_equal "admin", user.login
  end

  def test_validate_password_length
    with_settings :password_min_length => '100' do
      user = User.new(:firstname => "new100",
                      :lastname => "user100", :mail => "newuser100@somenet.foo")
      user.login = "newuser100"
      user.password, user.password_confirmation = "password100", "password100"
      assert !user.save
      assert_equal 1, user.errors.count
    end
  end

  def test_validate_password_format
    Setting::PASSWORD_CHAR_CLASSES.each do |key, regexp|
      with_settings :password_required_char_classes => key do
        user = User.new(:firstname => "new", :lastname => "user", :login => "random", :mail => "random@somnet.foo")
        p = 'PASSWDpasswd01234!@#$%'.gsub(regexp, '')
        user.password, user.password_confirmation = p, p
        assert !user.save
        assert_equal 1, user.errors.count
      end
    end
  end

  def test_name_format
    assert_equal 'John S.', @jsmith.name(:firstname_lastinitial)
    assert_equal 'Smith, John', @jsmith.name(:lastname_comma_firstname)
    assert_equal 'J. Smith', @jsmith.name(:firstinitial_lastname)
    assert_equal 'J.-P. Lang', User.new(:firstname => 'Jean-Philippe', :lastname => 'Lang').name(:firstinitial_lastname)
  end

  def test_name_should_use_setting_as_default_format
    with_settings :user_format => :firstname_lastname do
      assert_equal 'John Smith', @jsmith.reload.name
    end
    with_settings :user_format => :username do
      assert_equal 'jsmith', @jsmith.reload.name
    end
    with_settings :user_format => :lastname do
      assert_equal 'Smith', @jsmith.reload.name
    end
  end

  def test_today_should_return_the_day_according_to_user_time_zone
    preference = User.find(1).pref
    date = Date.new(2012, 05, 15)
    time = Time.gm(2012, 05, 15, 23, 30).utc # 2012-05-15 23:30 UTC
    Date.stubs(:today).returns(date)
    Time.stubs(:now).returns(time)

    preference.update_attribute :time_zone, 'Baku' # UTC+4
    assert_equal '2012-05-16', User.find(1).today.to_s

    preference.update_attribute :time_zone, 'La Paz' # UTC-4
    assert_equal '2012-05-15', User.find(1).today.to_s

    preference.update_attribute :time_zone, ''
    assert_equal '2012-05-15', User.find(1).today.to_s
  end

  def test_time_to_date_should_return_the_date_according_to_user_time_zone
    preference = User.find(1).pref
    time = Time.gm(2012, 05, 15, 23, 30).utc # 2012-05-15 23:30 UTC

    preference.update_attribute :time_zone, 'Baku' # UTC+4
    assert_equal '2012-05-16', User.find(1).time_to_date(time).to_s

    preference.update_attribute :time_zone, 'La Paz' # UTC-4
    assert_equal '2012-05-15', User.find(1).time_to_date(time).to_s

    preference.update_attribute :time_zone, ''
    assert_equal time.localtime.to_date.to_s, User.find(1).time_to_date(time).to_s
  end

  def test_convert_time_to_user_timezone_should_return_the_time_according_to_user_time_zone
    preference = User.find(1).pref
    time = Time.gm(2012, 05, 15, 23, 30).utc # 2012-05-15 23:30 UTC
    time_not_utc = Time.new(2012, 05, 15, 23, 30)

    preference.update_attribute :time_zone, 'Baku' # UTC+5
    assert_equal '2012-05-16 04:30:00 +0500', User.find(1).convert_time_to_user_timezone(time).to_s

    preference.update_attribute :time_zone, 'La Paz' # UTC-4
    assert_equal '2012-05-15 19:30:00 -0400', User.find(1).convert_time_to_user_timezone(time).to_s

    preference.update_attribute :time_zone, ''
    assert_equal time.localtime.to_s, User.find(1).convert_time_to_user_timezone(time).to_s
    assert_equal time_not_utc, User.find(1).convert_time_to_user_timezone(time_not_utc)
  end

  def test_fields_for_order_statement_should_return_fields_according_user_format_setting
    with_settings :user_format => 'lastname_comma_firstname' do
      assert_equal ['users.lastname', 'users.firstname', 'users.id'],
                   User.fields_for_order_statement
    end
  end

  def test_fields_for_order_statement_width_table_name_should_prepend_table_name
    with_settings :user_format => 'lastname_firstname' do
      assert_equal ['authors.lastname', 'authors.firstname', 'authors.id'],
                   User.fields_for_order_statement('authors')
    end
  end

  def test_fields_for_order_statement_with_blank_format_should_return_default
    with_settings :user_format => '' do
      assert_equal ['users.firstname', 'users.lastname', 'users.id'],
                   User.fields_for_order_statement
    end
  end

  def test_fields_for_order_statement_with_invalid_format_should_return_default
    with_settings :user_format => 'foo' do
      assert_equal ['users.firstname', 'users.lastname', 'users.id'],
                   User.fields_for_order_statement
    end
  end

  test ".try_to_login with good credentials should return the user" do
    user = User.try_to_login("admin", "admin")
    assert_kind_of User, user
    assert_equal "admin", user.login
  end

  test ".try_to_login with wrong credentials should return nil" do
    assert_nil User.try_to_login("admin", "foo")
  end

  def test_try_to_login_with_locked_user_should_return_nil
    @jsmith.status = User::STATUS_LOCKED
    @jsmith.save!

    user = User.try_to_login("jsmith", "jsmith")
    assert_nil user
  end

  def test_try_to_login_with_locked_user_and_not_active_only_should_return_user
    @jsmith.status = User::STATUS_LOCKED
    @jsmith.save!

    user = User.try_to_login("jsmith", "jsmith", false)
    assert_equal @jsmith, user
  end

  test ".try_to_login should fall-back to case-insensitive if user login is not found as-typed" do
    user = User.try_to_login("AdMin", "admin")
    assert_kind_of User, user
    assert_equal "admin", user.login
  end

  test ".try_to_login should select the exact matching user first" do
    case_sensitive_user = User.generate! do |user|
      user.password = "admin123"
    end
    # bypass validations to make it appear like existing data
    case_sensitive_user.update_attribute(:login, 'ADMIN')

    user = User.try_to_login("ADMIN", "admin123")
    assert_kind_of User, user
    assert_equal "ADMIN", user.login
  end

  if ldap_configured?
    test "#try_to_login using LDAP with failed connection to the LDAP server" do
      auth_source = AuthSourceLdap.find(1)
      AuthSource.any_instance.stubs(:initialize_ldap_con).raises(Net::LDAP::Error, 'Cannot connect')

      assert_nil User.try_to_login('edavis', 'wrong')
    end

    test "#try_to_login using LDAP" do
      assert_nil User.try_to_login('edavis', 'wrong')
    end

    test "#try_to_login using LDAP binding with user's account" do
      auth_source = AuthSourceLdap.find(1)
      auth_source.account = "uid=$login,ou=Person,dc=redmine,dc=org"
      auth_source.account_password = ''
      auth_source.save!

      ldap_user = User.new(:mail => 'example1@redmine.org', :firstname => 'LDAP', :lastname => 'user', :auth_source_id => 1)
      ldap_user.login = 'example1'
      ldap_user.save!

      assert_equal ldap_user, User.try_to_login('example1', '123456')
      assert_nil User.try_to_login('example1', '11111')
    end

    test "#try_to_login using LDAP on the fly registration" do
      AuthSourceLdap.find(1).update_attribute :onthefly_register, true

      assert_difference('User.count') do
        assert User.try_to_login('edavis', '123456')
      end

      assert_no_difference('User.count') do
        assert User.try_to_login('edavis', '123456')
      end

      assert_nil User.try_to_login('example1', '11111')
    end

    test "#try_to_login using LDAP on the fly registration and binding with user's account" do
      auth_source = AuthSourceLdap.find(1)
      auth_source.update_attribute :onthefly_register, true
      auth_source = AuthSourceLdap.find(1)
      auth_source.account = "uid=$login,ou=Person,dc=redmine,dc=org"
      auth_source.account_password = ''
      auth_source.save!

      assert_difference('User.count') do
        assert User.try_to_login('example1', '123456')
      end

      assert_no_difference('User.count') do
        assert User.try_to_login('example1', '123456')
      end

      assert_nil User.try_to_login('example1', '11111')
    end

  else
    puts "Skipping LDAP tests."
  end

  def test_create_anonymous
    AnonymousUser.delete_all
    anon = User.anonymous
    assert !anon.new_record?
    assert_kind_of AnonymousUser, anon
  end

  def test_ensure_single_anonymous_user
    AnonymousUser.delete_all
    anon1 = User.anonymous
    assert !anon1.new_record?
    assert_kind_of AnonymousUser, anon1
    anon2 = AnonymousUser.create(
                :lastname => 'Anonymous', :firstname => '',
                :login => '', :status => 0)
    assert_equal 1, anon2.errors.count
  end

  def test_rss_key
    assert_nil @jsmith.rss_token
    key = @jsmith.rss_key
    assert_equal 40, key.length

    @jsmith.reload
    assert_equal key, @jsmith.rss_key
  end

  def test_rss_key_should_not_be_generated_twice
    assert_difference 'Token.count', 1 do
      key1 = @jsmith.rss_key
      key2 = @jsmith.rss_key
      assert_equal key1, key2
    end
  end

  def test_api_key_should_not_be_generated_twice
    assert_difference 'Token.count', 1 do
      key1 = @jsmith.api_key
      key2 = @jsmith.api_key
      assert_equal key1, key2
    end
  end

  test "#api_key should generate a new one if the user doesn't have one" do
    user = User.generate!(:api_token => nil)
    assert_nil user.api_token

    key = user.api_key
    assert_equal 40, key.length
    user.reload
    assert_equal key, user.api_key
  end

  test "#api_key should return the existing api token value" do
    user = User.generate!
    token = Token.create!(:action => 'api')
    user.api_token = token
    assert user.save

    assert_equal token.value, user.api_key
  end

  test "#find_by_api_key should return nil if no matching key is found" do
    assert_nil User.find_by_api_key('zzzzzzzzz')
  end

  test "#find_by_api_key should return nil if the key is found for an inactive user" do
    user = User.generate!
    user.status = User::STATUS_LOCKED
    token = Token.create!(:action => 'api')
    user.api_token = token
    user.save

    assert_nil User.find_by_api_key(token.value)
  end

  test "#find_by_api_key should return the user if the key is found for an active user" do
    user = User.generate!
    token = Token.create!(:action => 'api')
    user.api_token = token
    user.save

    assert_equal user, User.find_by_api_key(token.value)
  end

  def test_default_admin_account_changed_should_return_false_if_account_was_not_changed
    user = User.find_by_login("admin")
    user.password = "admin"
    assert user.save(:validate => false)

    assert_equal false, User.default_admin_account_changed?
  end

  def test_default_admin_account_changed_should_return_true_if_password_was_changed
    user = User.find_by_login("admin")
    user.password = "newpassword"
    user.save!

    assert_equal true, User.default_admin_account_changed?
  end

  def test_default_admin_account_changed_should_return_true_if_account_is_disabled
    user = User.find_by_login("admin")
    user.password = "admin"
    user.status = User::STATUS_LOCKED
    assert user.save(:validate => false)

    assert_equal true, User.default_admin_account_changed?
  end

  def test_default_admin_account_changed_should_return_true_if_account_does_not_exist
    user = User.find_by_login("admin")
    user.destroy

    assert_equal true, User.default_admin_account_changed?
  end

  def test_membership_with_project_should_return_membership
    project = Project.find(1)

    membership = @jsmith.membership(project)
    assert_kind_of Member, membership
    assert_equal @jsmith, membership.user
    assert_equal project, membership.project
  end

  def test_membership_with_project_id_should_return_membership
    project = Project.find(1)

    membership = @jsmith.membership(1)
    assert_kind_of Member, membership
    assert_equal @jsmith, membership.user
    assert_equal project, membership.project
  end

  def test_membership_for_non_member_should_return_nil
    project = Project.find(1)

    user = User.generate!
    membership = user.membership(1)
    assert_nil membership
  end

  def test_roles_for_project_with_member_on_public_project_should_return_roles_and_non_member
    roles = @jsmith.roles_for_project(Project.find(1))
    assert_kind_of Role, roles.first
    assert_equal ["Manager"], roles.map(&:name)
  end

  def test_roles_for_project_with_member_on_private_project_should_return_roles
    Project.find(1).update_attribute :is_public, false

    roles = @jsmith.roles_for_project(Project.find(1))
    assert_kind_of Role, roles.first
    assert_equal ["Manager"], roles.map(&:name)
  end

  def test_roles_for_project_with_non_member_with_public_project_should_return_non_member
    set_language_if_valid 'en'
    roles = User.find(8).roles_for_project(Project.find(1))
    assert_equal ["Non member"], roles.map(&:name)
  end

  def test_roles_for_project_with_non_member_with_public_project_and_override_should_return_override_roles
    project = Project.find(1)
    Member.create!(:project => project, :principal => Group.non_member, :role_ids => [1, 2])
    roles = User.find(8).roles_for_project(project)
    assert_equal ["Developer", "Manager"], roles.map(&:name).sort
  end

  def test_roles_for_project_with_non_member_with_private_project_should_return_no_roles
    Project.find(1).update_attribute :is_public, false
    roles = User.find(8).roles_for_project(Project.find(1))
    assert_equal [], roles.map(&:name)
  end

  def test_roles_for_project_with_non_member_with_private_project_and_override_should_return_no_roles
    project = Project.find(1)
    project.update_attribute :is_public, false
    Member.create!(:project => project, :principal => Group.non_member, :role_ids => [1, 2])
    roles = User.find(8).roles_for_project(project)
    assert_equal [], roles.map(&:name).sort
  end

  def test_roles_for_project_with_anonymous_with_public_project_should_return_anonymous
    set_language_if_valid 'en'
    roles = User.anonymous.roles_for_project(Project.find(1))
    assert_equal ["Anonymous"], roles.map(&:name)
  end

  def test_roles_for_project_with_anonymous_with_public_project_and_override_should_return_override_roles
    project = Project.find(1)
    Member.create!(:project => project, :principal => Group.anonymous, :role_ids => [1, 2])
    roles = User.anonymous.roles_for_project(project)
    assert_equal ["Developer", "Manager"], roles.map(&:name).sort
  end

  def test_roles_for_project_with_anonymous_with_private_project_should_return_no_roles
    Project.find(1).update_attribute :is_public, false
    roles = User.anonymous.roles_for_project(Project.find(1))
    assert_equal [], roles.map(&:name)
  end

  def test_roles_for_project_with_anonymous_with_private_project_and_override_should_return_no_roles
    project = Project.find(1)
    project.update_attribute :is_public, false
    Member.create!(:project => project, :principal => Group.anonymous, :role_ids => [1, 2])
    roles = User.anonymous.roles_for_project(project)
    assert_equal [], roles.map(&:name).sort
  end

  def test_roles_for_project_should_be_unique
    m = Member.new(:user_id => 1, :project_id => 1)
    m.member_roles.build(:role_id => 1)
    m.member_roles.build(:role_id => 1)
    m.save!

    user = User.find(1)
    project = Project.find(1)
    assert_equal 1, user.roles_for_project(project).size
    assert_equal [1], user.roles_for_project(project).map(&:id)
  end

  def test_projects_by_role_for_user_with_role
    user = User.find(2)
    assert_kind_of Hash, user.projects_by_role
    assert_equal 2, user.projects_by_role.size
    assert_equal [1,5], user.projects_by_role[Role.find(1)].collect(&:id).sort
    assert_equal [2], user.projects_by_role[Role.find(2)].collect(&:id).sort
  end

  def test_project_ids_by_role_should_not_poison_cache_when_first_called_from_chained_scopes
    user = User.find(2)
    project = Project.find(1)

    project.children.visible(user)
    assert_equal [1, 2, 5], user.project_ids_by_role.values.flatten.sort
  end

  def test_accessing_projects_by_role_with_no_projects_should_return_an_empty_array
    user = User.find(2)
    assert_equal [], user.projects_by_role[Role.find(3)]
    # should not update the hash
    assert_nil user.projects_by_role.values.detect(&:blank?)
  end

  def test_projects_by_role_for_user_with_no_role
    user = User.generate!
    assert_equal({}, user.projects_by_role)
  end

  def test_projects_by_role_for_anonymous
    assert_equal({}, User.anonymous.projects_by_role)
  end

  def test_valid_notification_options
    # without memberships
    assert_equal 5, User.find(7).valid_notification_options.size
    # with memberships
    assert_equal 6, User.find(2).valid_notification_options.size
  end

  def test_valid_notification_options_class_method
    assert_equal 5, User.valid_notification_options.size
    assert_equal 5, User.valid_notification_options(User.find(7)).size
    assert_equal 6, User.valid_notification_options(User.find(2)).size
  end

  def test_notified_project_ids_setter_should_coerce_to_unique_integer_array
    @jsmith.notified_project_ids = ["1", "123", "2u", "wrong", "12", 6, 12, -35, ""]
    assert_equal [1, 123, 2, 12, 6], @jsmith.notified_projects_ids
  end

  def test_mail_notification_all
    @jsmith.mail_notification = 'all'
    @jsmith.notified_project_ids = []
    @jsmith.save
    @jsmith.reload
    assert @jsmith.projects.first.recipients.include?(@jsmith.mail)
  end

  def test_mail_notification_selected
    @jsmith.mail_notification = 'selected'
    @jsmith.notified_project_ids = [1]
    @jsmith.save
    @jsmith.reload
    assert Project.find(1).recipients.include?(@jsmith.mail)
  end

  def test_mail_notification_only_my_events
    @jsmith.mail_notification = 'only_my_events'
    @jsmith.notified_project_ids = []
    @jsmith.save
    @jsmith.reload
    assert !@jsmith.projects.first.recipients.include?(@jsmith.mail)
  end

  def test_comments_sorting_preference
    assert !@jsmith.wants_comments_in_reverse_order?
    @jsmith.pref.comments_sorting = 'asc'
    assert !@jsmith.wants_comments_in_reverse_order?
    @jsmith.pref.comments_sorting = 'desc'
    assert @jsmith.wants_comments_in_reverse_order?
  end

  def test_find_by_mail_should_be_case_insensitive
    u = User.find_by_mail('JSmith@somenet.foo')
    assert_not_nil u
    assert_equal 'jsmith@somenet.foo', u.mail
  end

  def test_random_password
    u = User.new
    u.random_password
    assert !u.password.blank?
    assert !u.password_confirmation.blank?
  end

  def test_random_password_include_required_characters
    with_settings :password_required_char_classes => Setting::PASSWORD_CHAR_CLASSES do
      u = User.new(:firstname => "new", :lastname => "user", :login => "random", :mail => "random@somnet.foo")
      u.random_password
      assert u.valid?
    end
  end

  test "#change_password_allowed? should be allowed if no auth source is set" do
    user = User.generate!
    assert user.change_password_allowed?
  end

  test "#change_password_allowed? should delegate to the auth source" do
    user = User.generate!

    allowed_auth_source = AuthSource.generate!
    def allowed_auth_source.allow_password_changes?; true; end

    denied_auth_source = AuthSource.generate!
    def denied_auth_source.allow_password_changes?; false; end

    assert user.change_password_allowed?

    user.auth_source = allowed_auth_source
    assert user.change_password_allowed?, "User not allowed to change password, though auth source does"

    user.auth_source = denied_auth_source
    assert !user.change_password_allowed?, "User allowed to change password, though auth source does not"
  end

  def test_own_account_deletable_should_be_true_with_unsubscrive_enabled
    with_settings :unsubscribe => '1' do
      assert_equal true, User.find(2).own_account_deletable?
    end
  end

  def test_own_account_deletable_should_be_false_with_unsubscrive_disabled
    with_settings :unsubscribe => '0' do
      assert_equal false, User.find(2).own_account_deletable?
    end
  end

  def test_own_account_deletable_should_be_false_for_a_single_admin
    User.admin.where("id <> ?", 1).delete_all

    with_settings :unsubscribe => '1' do
      assert_equal false, User.find(1).own_account_deletable?
    end
  end

  def test_own_account_deletable_should_be_true_for_an_admin_if_other_admin_exists
    User.generate! do |user|
      user.admin = true
    end

    with_settings :unsubscribe => '1' do
      assert_equal true, User.find(1).own_account_deletable?
    end
  end

  test "#allowed_to? for archived project should return false" do
    project = Project.find(1)
    project.archive
    project.reload
    assert_equal false, @admin.allowed_to?(:view_issues, project)
  end

  test "#allowed_to? for closed project should return true for read actions" do
    project = Project.find(1)
    project.close
    project.reload
    assert_equal false, @admin.allowed_to?(:edit_project, project)
    assert_equal true, @admin.allowed_to?(:view_project, project)
  end

  test "#allowed_to? for project with module disabled should return false" do
    project = Project.find(1)
    project.enabled_module_names = ["issue_tracking"]
    assert_equal true, @admin.allowed_to?(:add_issues, project)
    assert_equal false, @admin.allowed_to?(:view_wiki_pages, project)
  end

  test "#allowed_to? for admin users should return true" do
    project = Project.find(1)
    assert ! @admin.member_of?(project)
    %w(edit_issues delete_issues manage_news add_documents manage_wiki).each do |p|
      assert_equal true, @admin.allowed_to?(p.to_sym, project)
    end
  end

  test "#allowed_to? for normal users" do
    project = Project.find(1)
    # Manager
    assert_equal true, @jsmith.allowed_to?(:delete_messages, project)
    # Developer
    assert_equal false, @dlopper.allowed_to?(:delete_messages, project)
  end

  test "#allowed_to? with empty array should return false" do
    assert_equal false, @admin.allowed_to?(:view_project, [])
  end

  test "#allowed_to? with multiple projects" do
    assert_equal true, @admin.allowed_to?(:view_project, Project.all.to_a)
    # cannot see Project(2)
    assert_equal false, @dlopper.allowed_to?(:view_project, Project.all.to_a)
    # Manager or Developer everywhere
    assert_equal true, @jsmith.allowed_to?(:edit_issues, @jsmith.projects.to_a)
    # Dev cannot delete_issue_watchers
    assert_equal false, @jsmith.allowed_to?(:delete_issue_watchers, @jsmith.projects.to_a)
  end

  test "#allowed_to? with with options[:global] should return true if user has one role with the permission" do
    # only Developer on a project, not Manager anywhere
    @dlopper2 = User.find(5)
    @anonymous = User.find(6)
    assert_equal true, @jsmith.allowed_to?(:delete_issue_watchers, nil, :global => true)
    assert_equal false, @dlopper2.allowed_to?(:delete_issue_watchers, nil, :global => true)
    assert_equal true, @dlopper2.allowed_to?(:add_issues, nil, :global => true)
    assert_equal false, @anonymous.allowed_to?(:add_issues, nil, :global => true)
    assert_equal true, @anonymous.allowed_to?(:view_issues, nil, :global => true)
  end

  # this is just a proxy method, the test only calls it to ensure it doesn't break trivially
  test "#allowed_to_globally?" do
    # only Developer on a project, not Manager anywhere
    @dlopper2 = User.find(5)
    @anonymous = User.find(6)
    assert_equal true, @jsmith.allowed_to_globally?(:delete_issue_watchers)
    assert_equal false, @dlopper2.allowed_to_globally?(:delete_issue_watchers)
    assert_equal true, @dlopper2.allowed_to_globally?(:add_issues)
    assert_equal false, @anonymous.allowed_to_globally?(:add_issues)
    assert_equal true, @anonymous.allowed_to_globally?(:view_issues)
  end

  def test_notify_about_issue
    project = Project.find(1)
    author = User.generate!
    assignee = User.generate!
    Member.create!(:user => assignee, :project => project, :role_ids => [1])
    member = User.generate!
    Member.create!(:user => member, :project => project, :role_ids => [1])
    issue = Issue.generate!(:project => project, :assigned_to => assignee, :author => author)

    tests = {
      author => %w(all only_my_events only_owner selected),
      assignee => %w(all only_my_events only_assigned selected),
      member => %w(all)
    }

    tests.each do |user, expected|
      User::MAIL_NOTIFICATION_OPTIONS.map(&:first).each do |option|
        user.mail_notification = option
        assert_equal expected.include?(option), user.notify_about?(issue)
      end
    end
  end

  def test_notify_about_issue_for_previous_assignee
    assignee = User.generate!(:mail_notification => 'only_assigned')
    Member.create!(:user => assignee, :project_id => 1, :role_ids => [1])
    new_assignee = User.generate!(:mail_notification => 'only_assigned')
    Member.create!(:user => new_assignee, :project_id => 1, :role_ids => [1])
    issue = Issue.generate!(:assigned_to => assignee)

    assert assignee.notify_about?(issue)
    assert !new_assignee.notify_about?(issue)

    issue.assigned_to = new_assignee
    assert assignee.notify_about?(issue)
    assert new_assignee.notify_about?(issue)

    issue.save!
    assert assignee.notify_about?(issue)
    assert new_assignee.notify_about?(issue)

    issue.save!
    assert !assignee.notify_about?(issue)
    assert new_assignee.notify_about?(issue)
  end

  def test_notify_about_news
    user = User.generate!
    news = News.new

    User::MAIL_NOTIFICATION_OPTIONS.map(&:first).each do |option|
      user.mail_notification = option
      assert_equal (option != 'none'), user.notify_about?(news)
    end
  end

  def test_salt_unsalted_passwords
    # Restore a user with an unsalted password
    user = User.find(1)
    user.salt = nil
    user.hashed_password = User.hash_password("unsalted")
    user.save!

    User.salt_unsalted_passwords!

    user.reload
    # Salt added
    assert !user.salt.blank?
    # Password still valid
    assert user.check_password?("unsalted")
    assert_equal user, User.try_to_login(user.login, "unsalted")
  end

  def test_bookmarked_project_ids
    # User with bookmarked projects
    assert_equal [1, 5], User.find(1).bookmarked_project_ids
    # User without bookmarked projects
    assert_equal [], User.find(2).bookmarked_project_ids
  end

  if Object.const_defined?(:OpenID)
    def test_setting_identity_url
      normalized_open_id_url = 'http://example.com/'
      u = User.new( :identity_url => 'http://example.com/' )
      assert_equal normalized_open_id_url, u.identity_url
    end

    def test_setting_identity_url_without_trailing_slash
      normalized_open_id_url = 'http://example.com/'
      u = User.new( :identity_url => 'http://example.com' )
      assert_equal normalized_open_id_url, u.identity_url
    end

    def test_setting_identity_url_without_protocol
      normalized_open_id_url = 'http://example.com/'
      u = User.new( :identity_url => 'example.com' )
      assert_equal normalized_open_id_url, u.identity_url
    end

    def test_setting_blank_identity_url
      u = User.new( :identity_url => 'example.com' )
      u.identity_url = ''
      assert u.identity_url.blank?
    end

    def test_setting_invalid_identity_url
      u = User.new( :identity_url => 'this is not an openid url' )
      assert u.identity_url.blank?
    end
  else
    puts "Skipping openid tests."
  end
end
