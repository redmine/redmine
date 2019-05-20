require File.expand_path('../../../../test_helper', __FILE__)

class Redmine::ProjectJumpBoxTest < ActiveSupport::TestCase
  fixtures :users, :projects, :user_preferences

  def setup
    @user = User.find_by_login 'dlopper'
    @ecookbook = Project.find 'ecookbook'
    @onlinestore = Project.find 'onlinestore'
  end

  def test_should_filter_bookmarked_projects
    pjb = Redmine::ProjectJumpBox.new @user
    pjb.bookmark_project @ecookbook

    assert_equal 1, pjb.bookmarked_projects.size
    assert_equal 0, pjb.bookmarked_projects('online').size
    assert_equal 1, pjb.bookmarked_projects('ecook').size
  end

  def test_should_not_include_bookmark_in_recently_used_list
    pjb = Redmine::ProjectJumpBox.new @user
    pjb.project_used @ecookbook

    assert_equal 1, pjb.recently_used_projects.size

    pjb.bookmark_project @ecookbook
    assert_equal 0, pjb.recently_used_projects.size
  end

  def test_should_filter_recently_used_projects
    pjb = Redmine::ProjectJumpBox.new @user
    pjb.project_used @ecookbook

    assert_equal 1, pjb.recently_used_projects.size
    assert_equal 0, pjb.recently_used_projects('online').size
    assert_equal 1, pjb.recently_used_projects('ecook').size
  end

  def test_should_limit_recently_used_projects
    pjb = Redmine::ProjectJumpBox.new @user
    pjb.project_used @ecookbook
    pjb.project_used Project.find 'onlinestore'

    @user.pref.recently_used_projects = 1

    assert_equal 1, pjb.recently_used_projects.size
    assert_equal 1, pjb.recently_used_projects('online').size
    assert_equal 0, pjb.recently_used_projects('ecook').size
  end

  def test_should_record_recently_used_projects_order
    pjb = Redmine::ProjectJumpBox.new @user
    other = Project.find 'onlinestore'
    pjb.project_used @ecookbook
    pjb.project_used other

    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 2, pjb.recently_used_projects.size
    assert_equal [other, @ecookbook], pjb.recently_used_projects

    pjb.project_used other

    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 2, pjb.recently_used_projects.size
    assert_equal [other, @ecookbook], pjb.recently_used_projects

    pjb.project_used @ecookbook
    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 2, pjb.recently_used_projects.size
    assert_equal [@ecookbook, other], pjb.recently_used_projects
  end

  def test_should_unbookmark_project
    pjb = Redmine::ProjectJumpBox.new @user
    assert pjb.bookmarked_projects.blank?

    # same instance should reflect new data
    pjb.bookmark_project @ecookbook
    assert pjb.bookmark?(@ecookbook)
    refute pjb.bookmark?(@onlinestore)
    assert_equal 1, pjb.bookmarked_projects.size
    assert_equal @ecookbook, pjb.bookmarked_projects.first

    # new instance should reflect new data as well
    pjb = Redmine::ProjectJumpBox.new @user
    assert pjb.bookmark?(@ecookbook)
    refute pjb.bookmark?(@onlinestore)
    assert_equal 1, pjb.bookmarked_projects.size
    assert_equal @ecookbook, pjb.bookmarked_projects.first

    pjb.bookmark_project @ecookbook
    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 1, pjb.bookmarked_projects.size
    assert_equal @ecookbook, pjb.bookmarked_projects.first

    pjb.delete_project_bookmark @onlinestore
    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 1, pjb.bookmarked_projects.size
    assert_equal @ecookbook, pjb.bookmarked_projects.first

    pjb.delete_project_bookmark @ecookbook
    pjb = Redmine::ProjectJumpBox.new @user
    assert pjb.bookmarked_projects.blank?
  end

  def test_should_update_recents_list
    pjb = Redmine::ProjectJumpBox.new @user
    assert pjb.recently_used_projects.blank?

    pjb.project_used @ecookbook
    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 1, pjb.recently_used_projects.size
    assert_equal @ecookbook, pjb.recently_used_projects.first

    pjb.project_used @ecookbook
    pjb = Redmine::ProjectJumpBox.new @user
    assert_equal 1, pjb.recently_used_projects.size
    assert_equal @ecookbook, pjb.recently_used_projects.first

    pjb.project_used @onlinestore
    assert_equal 2, pjb.recently_used_projects.size
    assert_equal @onlinestore, pjb.recently_used_projects.first
    assert_equal @ecookbook, pjb.recently_used_projects.last
  end
end
