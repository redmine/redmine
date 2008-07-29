require File.dirname(__FILE__) + '/../../../test_helper'

class Redmine::PluginTest < Test::Unit::TestCase
  def test_sanity
    assert true
  end
  
  def test_add_hook
    assert_equal false, Redmine::Plugin::Hook::Manager.hook_registered?(:issue_show)
    Redmine::Plugin.add_hook(:issue_show, Proc.new { })
    assert Redmine::Plugin::Hook::Manager.hook_registered?(:issue_show)
  end
  
  def test_add_hook_invalid
    assert_equal false, Redmine::Plugin::Hook::Manager.hook_registered?(:invalid)
    Redmine::Plugin.add_hook(:invalid, Proc.new { })
    assert Redmine::Plugin::Hook::Manager.hook_registered?(:invalid)
  end
end

