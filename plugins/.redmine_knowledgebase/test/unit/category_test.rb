require File.dirname(__FILE__) + '/../test_helper'

class CategoryTest < ActiveSupport::TestCase
  plugin_fixtures :kb_categories

  test "should not save category without title" do
    category = KbCategory.new
    assert !category.save, "Saved the category without a title"
  end
end
