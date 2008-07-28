require File.dirname(__FILE__) + '/../../../test_helper'

class Redmine::Plugin::Hook::ManagerTest < Test::Unit::TestCase
  def test_sanity
    assert true
  end
end

class Redmine::Plugin::Hook::BaseTest < Test::Unit::TestCase
  def test_sanity
    assert true
  end
  
  def test_help_should_be_a_singleton
    assert Redmine::Plugin::Hook::Base::Helper.include?(Singleton)
  end
  
  def test_helper_should_include_actionview_helpers
    [ActionView::Helpers::TagHelper,
     ActionView::Helpers::FormHelper,
     ActionView::Helpers::FormTagHelper,
     ActionView::Helpers::FormOptionsHelper,
     ActionView::Helpers::JavaScriptHelper, 
     ActionView::Helpers::PrototypeHelper,
     ActionView::Helpers::NumberHelper,
     ActionView::Helpers::UrlHelper].each do |helper|
      assert Redmine::Plugin::Hook::Base::Helper.include?(helper), "#{helper} wasn't included."
    end
  end
end
